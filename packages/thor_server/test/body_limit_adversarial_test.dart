@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:thor_server/thor_server.dart';

class _Renderer implements PageRenderer<String> {
  @override
  List<int> render(String page, RenderContext context) => utf8.encode(page);

  @override
  String errorPage(ErrorState state) => 'error ${state.status}';
}

void main() {
  late HttpServer http;
  var read = <String, int>{};
  var middlewareRead = -1;

  setUp(() async {
    read = {};
    middlewareRead = -1;
    final server = ThorServer(
      maxBodyBytes: 1000,
      handler: RouteHandler<String>(
        renderer: _Renderer(),
        onError: (request, error, stack) {},
        routes: [
          PageRoute<String, void>(
            path: 'plain',
            build: (s) => 'plain',
            actions: {
              'default': (r) async {
                read['plain'] = (await r.bytes()).length;
                return null;
              },
            },
          ),
          PageRoute<String, void>(
            path: 'big',
            build: (s) => 'big',
            maxBodyBytes: 5000,
            actions: {
              'default': (r) async {
                read['big'] = (await r.bytes()).length;
                return null;
              },
            },
          ),
          PageRoute<String, void>(
            path: 'form',
            build: (s) => 'form',
            maxBodyBytes: 100000,
            actions: {
              'default': (r) async {
                await r.form();
                read['form'] = 1;
                return null;
              },
            },
          ),
          LayoutRoute<String, void>(
            path: 'm',
            build: (s, child) => child,
            middleware: (r, next) async {
              try {
                middlewareRead = (await r.bytes()).length;
              } on HttpError catch (e) {
                middlewareRead = -e.status;
              }
              return next();
            },
            children: [
              PageRoute<String, void>(
                path: 'x',
                build: (s) => 'x',
                maxBodyBytes: 5000,
                actions: {'default': (r) => null},
              ),
            ],
          ),
        ],
      ),
    );
    http = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    http.listen(server.handleHttp);
  });

  tearDown(() => http.close(force: true));

  Future<String> raw(
    String data, {
    List<List<int>> after = const [],
    bool expectClose = false,
    Duration wait = const Duration(seconds: 4),
  }) async {
    final socket = await Socket.connect('127.0.0.1', http.port);
    final reply = <int>[];
    final done = Completer<void>();
    socket.listen(
      reply.addAll,
      onDone: done.complete,
      onError: (_) => done.complete(),
    );
    socket.add(latin1.encode(data));
    for (final a in after) {
      try {
        socket.add(a);
        await socket.flush();
      } on SocketException {
        break;
      }
    }
    await done.future.timeout(wait, onTimeout: () {});
    final closed = done.isCompleted;
    socket.destroy();
    final text = latin1.decode(reply);
    return expectClose && !closed ? '$text<<NOT CLOSED>>' : text;
  }

  String req(
    String path,
    String headers, {
    String method = 'POST',
    String type = 'text/plain',
    bool close = true,
  }) =>
      '$method $path HTTP/1.1\r\nHost: 127.0.0.1:${http.port}\r\n'
      'Origin: http://127.0.0.1:${http.port}\r\nContent-Type: $type\r\n'
      '$headers${close ? 'Connection: close\r\n' : ''}\r\n';

  List<int> a(int n) => List.filled(n, 97);
  List<int> chunk(int n) => [
    ...utf8.encode('${n.toRadixString(16)}\r\n'),
    ...a(n),
    ...utf8.encode('\r\n'),
  ];
  final end = utf8.encode('0\r\n\r\n');

  int code(String r) =>
      int.tryParse(
        RegExp(r'^HTTP/1\.\d (\d+)').firstMatch(r)?.group(1) ?? '',
      ) ??
      0;
  int count(String r) => 'HTTP/1.1 '.allMatches(r).length;

  group('unknown and method-dependent routes', () {
    test(
      'an unknown route with a huge body is a 404 or 413, never read',
      () async {
        final r = await raw(
          req('/nope', 'Content-Length: ${4 << 30}\r\n'),
          expectClose: true,
        );
        expect(code(r), anyOf(404, 413, 403, 405), reason: r);
        expect(r, isNot(contains('NOT CLOSED')));
      },
    );

    test('a GET with a body is not read and does not hang', () async {
      final r = await raw(
        req('/plain', 'Content-Length: 5\r\n', method: 'GET'),
        after: [a(5)],
      );
      expect(code(r), 200, reason: r);
    });

    test('a HEAD with an over-limit declared length does not hang', () async {
      final r = await raw(
        req('/plain', 'Content-Length: ${4 << 30}\r\n', method: 'HEAD'),
        expectClose: true,
      );
      expect(code(r), isNot(0), reason: r);
    });

    test('GET with a huge declared length answers without reading', () async {
      final r = await raw(
        req('/plain', 'Content-Length: ${4 << 30}\r\n', method: 'GET'),
        expectClose: true,
      );
      expect(code(r), 200, reason: r);
    });
  });

  group('middleware order', () {
    test('a middleware that reads first sees the page limit', () async {
      final r = await raw(
        req('/m/x', 'Content-Length: 3000\r\n'),
        after: [a(3000)],
      );
      expect(code(r), anyOf(303, 200), reason: r);
      expect(middlewareRead, 3000);
    });

    test('and its over-limit is a 413 for it too', () async {
      await raw(req('/m/x', 'Content-Length: 6000\r\n'), after: [a(6000)]);
      expect(middlewareRead, -413);
    });
  });

  group('Content-Length framing', () {
    for (final cl in [
      '0003000',
      '+3000',
      ' 3000',
      '3000 ',
      '3,000',
      '0x10',
      '-1',
      '3000, 3000',
      '',
    ]) {
      test('Content-Length ${jsonEncode(cl)} on a 1000 B route', () async {
        final r = await raw(
          req('/plain', 'Content-Length: $cl\r\n'),
          after: [a(3000)],
          expectClose: true,
        );
        // Either rejected as malformed or counted as 3000 > 1000: never a
        // successful read of more than the limit.
        expect(code(r), anyOf(400, 413, 0), reason: r);
        expect(read, isEmpty);
      });
    }

    test('two Content-Length headers that disagree', () async {
      final r = await raw(
        req('/plain', 'Content-Length: 5\r\nContent-Length: 3000\r\n'),
        after: [a(3000)],
        expectClose: true,
      );
      expect(code(r), anyOf(400, 413, 0), reason: r);
      expect(read, isEmpty);
    });

    test('two Content-Length headers that agree are not over-read', () async {
      final r = await raw(
        req('/plain', 'Content-Length: 5\r\nContent-Length: 5\r\n'),
        after: [a(5)],
      );
      expect(code(r), anyOf(303, 400, 0), reason: r);
      expect(read['plain'] ?? 5, 5);
    });

    test('Content-Length plus Transfer-Encoding: chunked', () async {
      // Smuggling shape: a front proxy that trusts CL would see 5 bytes.
      final r = await raw(
        req('/plain', 'Content-Length: 5\r\nTransfer-Encoding: chunked\r\n'),
        after: [chunk(600), chunk(600), end],
        expectClose: true,
      );
      expect(code(r), anyOf(400, 413), reason: r);
      expect(read, isEmpty);
    });

    test(
      'chunked under the limit with a bogus Content-Length is read once',
      () async {
        final r = await raw(
          req(
            '/plain',
            'Content-Length: 99999\r\nTransfer-Encoding: chunked\r\n',
          ),
          after: [chunk(10), end],
          expectClose: true,
        );
        // Chunked wins (RFC 9112 6.3) or the request is rejected; the huge
        // Content-Length must not refuse a body that is 10 bytes.
        expect(code(r), anyOf(303, 400), reason: r);
      },
    );

    test('Transfer-Encoding with an unknown coding', () async {
      final r = await raw(
        req('/plain', 'Transfer-Encoding: gzip, chunked\r\n'),
        after: [chunk(2000), end],
        expectClose: true,
      );
      expect(code(r), anyOf(400, 413, 501, 0), reason: r);
      expect(read, isEmpty);
    });
  });

  group('Expect: 100-continue', () {
    test('over the limit is a 413 without a 100 Continue', () async {
      final r = await raw(
        req('/plain', 'Content-Length: 3000\r\nExpect: 100-continue\r\n'),
        expectClose: true,
      );
      expect(r, isNot(contains('100 Continue')));
      expect(code(r), 413, reason: r);
    });

    test('over 64 MB is a 413 without a 100 Continue and closes', () async {
      final r = await raw(
        req('/plain', 'Content-Length: ${1 << 30}\r\nExpect: 100-continue\r\n'),
        expectClose: true,
      );
      expect(r, isNot(contains('100 Continue')));
      expect(code(r), 413, reason: r);
      expect(r, isNot(contains('NOT CLOSED')));
    });
  });

  group('keep-alive', () {
    test('after a drained 413 the next request is parsed correctly', () async {
      final first = req('/plain', 'Content-Length: 3000\r\n', close: false);
      const second =
          'GET /big HTTP/1.1\r\nHost: x\r\nConnection: close\r\n\r\n';
      final r = await raw(first, after: [a(3000), latin1.encode(second)]);
      expect(count(r), 2, reason: r);
      expect(code(r), 413);
      expect(r, contains('HTTP/1.1 200'));
    });

    test('a body that smuggles a request is not parsed as one', () async {
      const smuggled =
          'GET /big HTTP/1.1\r\nHost: x\r\nConnection: close\r\n\r\n';
      final body = [...a(2000), ...latin1.encode(smuggled)];
      final r = await raw(
        req('/plain', 'Content-Length: ${body.length}\r\n', close: false),
        after: [body],
        expectClose: false,
        wait: const Duration(seconds: 2),
      );
      expect(count(r), 1, reason: r);
      expect(code(r), 413);
    });

    test('after a refused (> 64 MB) body the connection is closed', () async {
      final r = await raw(
        req('/plain', 'Content-Length: ${1 << 30}\r\n', close: false),
        expectClose: true,
      );
      expect(code(r), 413);
      expect(r.toLowerCase(), contains('connection: close'));
      expect(r, isNot(contains('NOT CLOSED')));
    });

    test(
      'the refused body that keeps streaming after the 413 does not wedge',
      () async {
        final r = await raw(
          req('/plain', 'Content-Length: ${1 << 30}\r\n', close: false),
          after: [a(100000)],
          expectClose: true,
        );
        expect(code(r), 413);
      },
    );
  });

  group('shape of the body', () {
    test('many tiny multipart parts under the limit', () async {
      final b = StringBuffer();
      for (var i = 0; i < 3000; i++) {
        b.write(
          '--b\r\nContent-Disposition: form-data; name="f$i"\r\n\r\nx\r\n',
        );
      }
      b.write('--b--\r\n');
      final body = latin1.encode(b.toString());
      final r = await raw(
        req(
          '/form',
          'Content-Length: ${body.length}\r\n',
          type: 'multipart/form-data; boundary=b',
        ),
        after: [body],
      );
      expect(code(r), anyOf(303, 400, 413), reason: r.split('\r\n').first);
    });

    test('a gzip Content-Encoding body is not inflated', () async {
      final bomb = gzip.encode(List.filled(5 << 20, 0));
      final r = await raw(
        req(
          '/big',
          'Content-Length: ${bomb.length}\r\nContent-Encoding: gzip\r\n',
        ),
        after: [bomb],
      );
      expect(code(r), anyOf(303, 413, 415));
      expect(read['big'] ?? 0, lessThanOrEqualTo(5000));
    });

    test('slow chunked body under the limit still completes', () async {
      final r = await raw(
        req('/plain', 'Transfer-Encoding: chunked\r\n'),
        after: [chunk(100), end],
      );
      expect(code(r), 303);
    });
  });
}
