@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:thor_server/thor_server.dart';

/// A local backend: `handle` answers each request; `requests` counts them.
class _Backend {
  _Backend._(this._server);

  static Future<_Backend> start(
    FutureOr<void> Function(HttpRequest request) handle,
  ) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final backend = _Backend._(server);
    server.listen((r) async {
      backend.requests++;
      backend.methods.add(r.method);
      try {
        await handle(r);
      } catch (_) {
        // The client may have aborted.
      }
    });
    return backend;
  }

  final HttpServer _server;
  var requests = 0;
  final methods = <String>[];

  String url(String path) => 'http://127.0.0.1:${_server.port}$path';

  Future<void> close() => _server.close(force: true);
}

/// A raw TCP backend: each connection reads the request head, then
/// `onConnection` decides what to do with the socket (close it, reset it,
/// answer). `connections` counts them.
class _RawBackend {
  _RawBackend._(this._server);

  static Future<_RawBackend> start(
    void Function(Socket socket, int connection) onConnection,
  ) async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final backend = _RawBackend._(server);
    server.listen((socket) {
      final n = ++backend.connections;
      final head = <int>[];
      // Paused, not cancelled: the socket must stay open for the test.
      // ignore: cancel_subscriptions
      late StreamSubscription<Uint8List> sub;
      sub = socket.listen((data) {
        head.addAll(data);
        if (latin1.decode(head, allowInvalid: true).contains('\r\n\r\n')) {
          sub.pause();
          onConnection(socket, n);
        }
      }, onError: (Object _) {});
    });
    return backend;
  }

  final ServerSocket _server;
  var connections = 0;

  String url(String path) => 'http://127.0.0.1:${_server.port}$path';

  Future<void> close() => _server.close();
}

void _answer(Socket socket, String body) {
  socket.add(
    latin1.encode(
      'HTTP/1.1 200 OK\r\ncontent-type: application/json\r\n'
      'content-length: ${body.length}\r\nconnection: close\r\n\r\n$body',
    ),
  );
  unawaited(socket.close());
}

/// Closes the socket with a TCP reset (SO_LINGER 0), not a FIN.
void _reset(Socket socket) {
  final linger = Uint8List(8)..[0] = 1; // l_onoff = 1, l_linger = 0
  socket.setRawOption(
    RawSocketOption(
      RawSocketOption.levelSocket,
      Platform.isMacOS ? 0x80 : 13, // SO_LINGER
      linger,
    ),
  );
  socket.destroy();
}

Matcher _upstream(int status) =>
    isA<UpstreamError>().having((e) => e.status, 'status', status);

void main() {
  group('responses', () {
    late _Backend backend;
    late ThorHttpClient client;

    setUp(() async {
      backend = await _Backend.start((r) async {
        final body = await utf8.decodeStream(r);
        final res = r.response;
        switch (r.uri.path) {
          case '/echo':
            res.headers.contentType = ContentType.json;
            res.write(
              jsonEncode({
                'method': r.method,
                'accept': r.headers.value('accept'),
                'x-call': r.headers.value('x-call'),
                'type': r.headers.contentType?.mimeType,
                'body': body,
              }),
            );
          case '/missing':
            res.statusCode = 404;
            res.write('{"errors":{"article":["not found"]}}');
          case '/empty':
            res.statusCode = 204;
          case '/not-json':
            res.write('<html>proxy error</html>');
          case '/latin1':
            res.add([0xff, 0xfe]);
        }
        await res.close();
      });
      client = ThorHttpClient(headers: {HttpHeader.accept: 'application/json'});
    });

    tearDown(() async {
      client.close(force: true);
      await backend.close();
    });

    test('client headers go with every call; a call header wins', () async {
      final json =
          await client.getJson(
                backend.url('/echo'),
                headers: {const HttpHeader('x-call'): 'yes'},
              )
              as Map<String, Object?>;
      expect(json['accept'], 'application/json');
      expect(json['x-call'], 'yes');
      final other =
          await client.getJson(
                backend.url('/echo'),
                headers: {HttpHeader.accept: 'text/plain'},
              )
              as Map<String, Object?>;
      expect(other['accept'], 'text/plain');
    });

    test('json: is encoded as the body with its content type', () async {
      final r = await client.post(backend.url('/echo'), json: {'a': 'ñ'});
      final echo = r.json()! as Map<String, Object?>;
      expect(echo['method'], 'POST');
      expect(echo['type'], 'application/json');
      expect(jsonDecode(echo['body']! as String), {'a': 'ñ'});
    });

    test('a non-2xx status is returned to send/get, not thrown', () async {
      final r = await client.get(backend.url('/missing'));
      expect(r.statusCode, 404);
      expect(r.ok, isFalse);
      expect((r.json()! as Map)['errors'], isNotNull);
      expect(r.ensureOk, throwsA(_upstream(502)));
    });

    test('getJson turns a non-2xx status into a 502', () async {
      await expectLater(
        client.getJson(backend.url('/missing')),
        throwsA(_upstream(502)),
      );
    });

    test('an empty body is null JSON', () async {
      final r = await client.delete(backend.url('/empty'));
      expect(r.statusCode, 204);
      expect(r.json(), isNull);
    });

    test('invalid JSON or UTF-8 from the backend is a 502', () async {
      await expectLater(
        client.getJson(backend.url('/not-json')),
        throwsA(_upstream(502)),
      );
      final r = await client.get(backend.url('/latin1'));
      expect(() => r.text, throwsA(_upstream(502)));
    });

    test('a refused connection is a 502', () async {
      final closed = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = closed.port;
      await closed.close();
      await expectLater(
        client.getJson('http://127.0.0.1:$port/x'),
        throwsA(_upstream(502)),
      );
    });

    test('the error says nothing to the visitor and hides secrets in logs', () {
      final e = UpstreamError(
        502,
        method: HttpMethod.get,
        uri: Uri.parse('https://user:pw@api.test:8443/a?token=secret'),
        reason: 'answered 500',
      );
      expect(e.message, isNull);
      expect(e.toString(), contains('https://api.test:8443/a'));
      expect(e.toString(), isNot(contains('secret')));
      expect(e.toString(), isNot(contains('pw')));
    });
  });

  group('deadline', () {
    test('headers that never come: 504 at the deadline, no retry', () async {
      final backend = await _Backend.start((r) async {
        await Future<void>.delayed(const Duration(seconds: 3));
        await r.response.close();
      });
      addTearDown(backend.close);
      final client = ThorHttpClient(timeout: const Duration(milliseconds: 200));
      addTearDown(() => client.close(force: true));
      final clock = Stopwatch()..start();
      await expectLater(
        client.getJson(backend.url('/slow')),
        throwsA(_upstream(504)),
      );
      expect(clock.elapsedMilliseconds, lessThan(1500));
      expect(backend.requests, 1);
    });

    test('a body that trickles past the deadline is a 504', () async {
      final backend = await _Backend.start((r) async {
        r.response.headers.contentType = ContentType.json;
        r.response.write('[');
        await r.response.flush();
        await Future<void>.delayed(const Duration(seconds: 3));
        r.response.write(']');
        await r.response.close();
      });
      addTearDown(backend.close);
      final client = ThorHttpClient(timeout: const Duration(milliseconds: 200));
      addTearDown(() => client.close(force: true));
      await expectLater(
        client.getJson(backend.url('/trickle')),
        throwsA(_upstream(504)),
      );
    });

    test('the deadline covers the retry', () async {
      // First connection closed at once; the second never answers.
      final backend = await _RawBackend.start((socket, n) {
        if (n == 1) socket.destroy();
      });
      addTearDown(backend.close);
      final client = ThorHttpClient(timeout: const Duration(milliseconds: 300));
      addTearDown(() => client.close(force: true));
      final clock = Stopwatch()..start();
      await expectLater(
        client.getJson(backend.url('/x')),
        throwsA(_upstream(504)),
      );
      expect(clock.elapsedMilliseconds, lessThan(1500));
      expect(backend.connections, 2);
    });
  });

  group('retry', () {
    test('a GET on a socket closed before answering is retried once', () async {
      final backend = await _RawBackend.start((socket, n) {
        n == 1 ? socket.destroy() : _answer(socket, '{"ok":true}');
      });
      addTearDown(backend.close);
      final client = ThorHttpClient();
      addTearDown(() => client.close(force: true));
      expect(await client.getJson(backend.url('/x')), {'ok': true});
      expect(backend.connections, 2);
    });

    test('a GET on a reset connection is retried once', () async {
      final backend = await _RawBackend.start((socket, n) {
        n == 1 ? _reset(socket) : _answer(socket, '[1]');
      });
      addTearDown(backend.close);
      final client = ThorHttpClient();
      addTearDown(() => client.close(force: true));
      expect(await client.getJson(backend.url('/x')), [1]);
      expect(backend.connections, 2);
    });

    test('only once: a backend that keeps closing is a 502', () async {
      final backend = await _RawBackend.start((socket, n) => socket.destroy());
      addTearDown(backend.close);
      final client = ThorHttpClient();
      addTearDown(() => client.close(force: true));
      await expectLater(
        client.getJson(backend.url('/x')),
        throwsA(_upstream(502)),
      );
      expect(backend.connections, 2);
    });

    for (final method in ['POST', 'PUT', 'DELETE', 'PATCH']) {
      test('a $method is never retried (it may have run)', () async {
        final backend = await _RawBackend.start((socket, n) {
          n == 1 ? socket.destroy() : _answer(socket, '{}');
        });
        addTearDown(backend.close);
        final client = ThorHttpClient();
        addTearDown(() => client.close(force: true));
        await expectLater(
          client.send(
            HttpMethod.tryParse(method)!,
            backend.url('/x'),
            json: {'a': 1},
          ),
          throwsA(_upstream(502)),
        );
        expect(backend.connections, 1);
      });
    }

    test('a failure after the headers arrived is not retried', () async {
      final backend = await _RawBackend.start((socket, n) {
        socket.add(
          latin1.encode('HTTP/1.1 200 OK\r\ncontent-length: 100\r\n\r\n{"cut'),
        );
        unawaited(socket.flush().then((_) => socket.destroy()));
      });
      addTearDown(backend.close);
      final client = ThorHttpClient();
      addTearDown(() => client.close(force: true));
      await expectLater(
        client.getJson(backend.url('/x')),
        throwsA(_upstream(502)),
      );
      expect(backend.connections, 1);
    });

    test('an idle socket closed by the backend does not fail a GET', () async {
      // The backend's keep-alive (100 ms) is shorter than the client's
      // idleTimeout: the next GET finds its pooled socket closed.
      final backend = await _Backend.start((r) async {
        r.response.write('[${r.uri.path.length}]');
        await r.response.close();
      });
      addTearDown(backend.close);
      backend._server.idleTimeout = const Duration(milliseconds: 100);
      final client = ThorHttpClient(idleTimeout: const Duration(seconds: 30));
      addTearDown(() => client.close(force: true));
      expect(await client.getJson(backend.url('/a')), [2]);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(await client.getJson(backend.url('/bb')), [3]);
    });
  });

  group('size limit', () {
    late _Backend backend;
    late ThorHttpClient client;

    setUp(() async {
      backend = await _Backend.start((r) async {
        final chunk = List.filled(1000, 0x20);
        if (r.uri.path == '/declared') {
          r.response.contentLength = 5000;
          for (var i = 0; i < 5; i++) {
            r.response.add(chunk);
          }
        } else {
          // Chunked: no length up front.
          for (var i = 0; i < 5; i++) {
            r.response.add(chunk);
            await r.response.flush();
          }
        }
        await r.response.close();
      });
      client = ThorHttpClient(maxResponseBytes: 4096);
    });

    tearDown(() async {
      client.close(force: true);
      await backend.close();
    });

    test('a declared length over the limit is a 502', () async {
      await expectLater(
        client.get(backend.url('/declared')),
        throwsA(_upstream(502)),
      );
    });

    test('a chunked body that grows past the limit is a 502', () async {
      await expectLater(
        client.get(backend.url('/chunked')),
        throwsA(_upstream(502)),
      );
    });

    test('up to the limit is fine', () async {
      final big = ThorHttpClient(maxResponseBytes: 5000);
      addTearDown(big.close);
      expect((await big.get(backend.url('/chunked'))).bytes, hasLength(5000));
    });
  });

  test('concurrent calls: a slow one fails alone', () async {
    final backend = await _Backend.start((r) async {
      await Future<void>.delayed(
        Duration(milliseconds: r.uri.path == '/slow' ? 3000 : 20),
      );
      r.response.write(r.uri.path.substring(1));
      await r.response.close();
    });
    addTearDown(backend.close);
    final client = ThorHttpClient(
      timeout: const Duration(milliseconds: 500),
      maxConnectionsPerHost: 4,
    );
    addTearDown(() => client.close(force: true));
    final slow = client.get(backend.url('/slow'));
    final fast = [for (var i = 0; i < 20; i++) client.get(backend.url('/$i'))];
    final texts = [for (final r in await Future.wait(fast)) r.text];
    expect(texts, [for (var i = 0; i < 20; i++) '$i']);
    await expectLater(slow, throwsA(_upstream(504)));
  });

  group('in a load', () {
    late List<Object> reported;
    late RouteHandler<String> handler;
    late ThorHttpClient client;

    setUp(() {
      reported = [];
      client = ThorHttpClient(timeout: const Duration(milliseconds: 200));
      handler = RouteHandler<String>(
        renderer: _Renderer(),
        onError: (request, error, stack) => reported.add(error),
        routes: [
          LayoutRoute<String, void>(
            build: (s, child) => child,
            error: (e) => 'error ${e.status}: ${e.message ?? ''}',
            children: [
              PageRoute<String, Object?>(
                path: '[port]',
                load: (r) => client.getJson(
                  'http://127.0.0.1:${r.pathParameters['port']}/items?token=s3cret',
                ),
                build: (s) => 'data ${s.data}',
              ),
            ],
          ),
        ],
      );
    });

    tearDown(() => client.close(force: true));

    Future<ThorResponse> get(int port) => handler.handle(
      PageRequest(
        method: HttpMethod.get,
        uri: Uri.parse('http://site.test/$port'),
        headers: const {HttpHeader.host: 'site.test'},
      ),
    );

    test('a backend down is a 502 page that leaks nothing', () async {
      final closed = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = closed.port;
      await closed.close();
      final r = await get(port);
      expect(r.status, 502);
      expect(r.text, contains('error 502: Internal error'));
      expect(r.text, isNot(contains('127.0.0.1')));
      expect(r.text, isNot(contains('s3cret')));
      expect(r.headers, isNot(contains('etag')));
      expect(reported, [_upstream(502)]);
    });

    test('a backend too slow is a 504 page, reported', () async {
      final backend = await _Backend.start((r) async {
        await Future<void>.delayed(const Duration(seconds: 3));
        await r.response.close();
      });
      addTearDown(backend.close);
      final r = await get(Uri.parse(backend.url('/')).port);
      expect(r.status, 504);
      expect(r.text, contains('error 504: Internal error'));
      expect(reported, [_upstream(504)]);
    });
  });
}

class _Renderer implements PageRenderer<String> {
  @override
  List<int> render(String page, RenderContext context) => utf8.encode(page);

  @override
  String errorPage(ErrorState state) => 'plain error ${state.status}';
}
