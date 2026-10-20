import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:thor_cli/src/dev/inspect.dart';
import 'package:thor_cli/src/dev_proxy.dart';
import 'package:thor_server/thor_server.dart' show DevHosts;

/// A stand-in for the app's server.
class _App {
  /// The streamed page waits for this before its late piece.
  var release = Completer<void>();
  late HttpServer server;
  final requests =
      <({String method, String path, String body, String? gzip})>[];

  Future<void> start([int port = 0]) async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    server.listen((r) async {
      final body = await utf8.decodeStream(r);
      requests.add((
        method: r.method,
        path: r.uri.toString(),
        body: body,
        gzip: r.headers.value(HttpHeaders.acceptEncodingHeader),
      ));
      final res = r.response;
      switch (r.uri.path) {
        case '/page':
          res
            ..headers.contentType = ContentType.html
            ..write('<html><BODY><p>hola</p></BODY></html>');
        case '/fragment':
          res
            ..headers.contentType = ContentType.html
            ..write('<p>sin body</p>');
        case '/twice':
          res
            ..headers.contentType = ContentType.html
            ..write('<body><pre>"</body>" is text</pre></body>');
        case '/slow':
          // Like a streamed page: the document, a pause, the late piece.
          res
            ..headers.contentType = ContentType.html
            ..bufferOutput = false
            ..write('<html><body><p>shell</p>');
          await res.flush();
          await release.future;
          res.write('<p>late</p></body></html>');
        case '/split':
          // `</body>` and an error block cut between two chunks.
          res
            ..headers.contentType = ContentType.html
            ..bufferOutput = false
            ..write(
              '<body><p>a</p><script type="application/json" '
              'id="thor-dev-error">{"phase":"load","where":"GET /",'
              '"type":"StateError","message":"bo',
            );
          await res.flush();
          await Future<void>.delayed(const Duration(milliseconds: 50));
          res.write('om","stack":""}</scr');
          await res.flush();
          await Future<void>.delayed(const Duration(milliseconds: 50));
          res.write('ipt><p>b</p></bo');
          await res.flush();
          await Future<void>.delayed(const Duration(milliseconds: 50));
          res.write('dy></html>');
        case '/data':
          res
            ..headers.contentType = ContentType.json
            ..write('{"a":1}');
        case '/redirect':
          res
            ..statusCode = HttpStatus.seeOther
            ..headers.set(HttpHeaders.locationHeader, '/page')
            ..headers.add(HttpHeaders.setCookieHeader, 'a=1; Path=/')
            ..headers.add(HttpHeaders.setCookieHeader, 'b=2; Path=/');
        case '/echo':
          res
            ..headers.contentType = ContentType.text
            ..write('got $body');
        default:
          res.statusCode = HttpStatus.notFound;
      }
      await res.close();
    });
  }

  Future<void> stop() => server.close(force: true);
}

void main() {
  late _App app;
  late DevProxy proxy;
  final client = HttpClient();

  Future<HttpClientResponse> send(
    String path, {
    String method = 'GET',
    String? body,
  }) async {
    final req = await client.open(method, 'localhost', proxy.port, path);
    req.followRedirects = false;
    req.headers.set(HttpHeaders.acceptEncodingHeader, 'gzip');
    if (body != null) req.write(body);
    return req.close();
  }

  Future<String> text(HttpClientResponse r) => utf8.decodeStream(r);

  setUp(() async {
    app = _App();
    await app.start();
    proxy = DevProxy(
      upstream: app.server.port,
      wait: const Duration(milliseconds: 500),
    );
    await proxy.start(0);
    proxy.ready();
  });

  tearDown(() async {
    if (!app.release.isCompleted) app.release.complete();
    await proxy.close();
    await app.stop();
  });

  group('pages', () {
    // What every page gets: live reload, then the inspector.
    // (the stamp of the moment: nothing reloaded since setUp)
    String devScripts() =>
        '${liveReloadScriptFor(proxy.stamp)}${inspectScript()}';

    test('HTML gets the script before its closing body, in any case', () async {
      final r = await send('/page');
      final html = await text(r);
      expect(html, contains('<p>hola</p>${devScripts()}</BODY>'));
      expect(r.headers.contentLength, anyOf(-1, utf8.encode(html).length));
    });

    test('a fragment without </body> gets it at the end', () async {
      expect(await text(await send('/fragment')), endsWith(devScripts()));
    });

    test('only the last </body> counts (one inside text stays)', () async {
      final html = await text(await send('/twice'));
      expect(RegExp('thor-live-reload').allMatches(html), hasLength(1));
      expect(html, endsWith('</pre>${devScripts()}</body>'));
    });

    test(
      'a streamed page reaches the browser in pieces, injected once',
      () async {
        final r = await send('/slow');
        final chunks = <({bool released, String text})>[];
        await for (final c in r) {
          chunks.add((released: app.release.isCompleted, text: utf8.decode(c)));
          // The app finishes the page only once the shell has arrived.
          if (!app.release.isCompleted) app.release.complete();
        }
        final html = chunks.map((c) => c.text).join();
        // The shell is out long before the app finishes the page.
        expect(chunks.first.text, contains('<p>shell</p>'));
        expect(chunks.first.text, isNot(contains('late')));
        expect(chunks.first.released, isFalse);
        expect(chunks.last.released, isTrue, reason: 'the late piece');
        expect(RegExp('thor-live-reload').allMatches(html), hasLength(1));
        expect(html, endsWith('<p>late</p>${devScripts()}</body></html>'));
      },
    );

    test('a block or a </body> cut between chunks still works', () async {
      final html = await text(await send('/split'));
      expect(html, isNot(contains('thor-dev-error')));
      expect(html, contains('<p>a</p>'));
      expect(html, contains('<p>b</p>'));
      expect(html, contains('boom'), reason: 'the overlay shows the error');
      expect(RegExp('thor-live-reload').allMatches(html), hasLength(1));
      expect(html, endsWith('</body></html>'));
    });

    test('anything else goes through untouched', () async {
      final r = await send('/data');
      expect(await text(r), '{"a":1}');
      expect(r.headers.contentType?.mimeType, 'application/json');
    });

    test('the app is asked for plain bodies (it can gzip otherwise)', () async {
      await text(await send('/page'));
      expect(app.requests.single.gzip, isNull);
    });

    test('redirects are not followed and every cookie arrives', () async {
      final r = await send('/redirect');
      await r.drain<void>();
      expect(r.statusCode, HttpStatus.seeOther);
      expect(r.headers.value(HttpHeaders.locationHeader), '/page');
      expect(r.headers[HttpHeaders.setCookieHeader], hasLength(2));
    });

    test('a form post reaches the app with its body and query', () async {
      final r = await send('/echo?x=1', method: 'POST', body: 'name=ana');
      expect(await text(r), 'got name=ana');
      expect(app.requests.single.path, '/echo?x=1');
    });

    test('status codes of the app are kept', () async {
      final r = await send('/nope');
      await r.drain<void>();
      expect(r.statusCode, HttpStatus.notFound);
    });
  });

  group('restarts', () {
    test(
      'a request made while the app restarts waits and then succeeds',
      () async {
        proxy.restarting();
        final pending = send('/page').then(text);
        await Future<void>.delayed(const Duration(milliseconds: 100));
        proxy.ready();
        expect(await pending, contains('hola'));
      },
    );

    test(
      'an app that never comes back is a 503 page that reloads itself',
      () async {
        proxy.restarting();
        final r = await send('/page');
        expect(r.statusCode, HttpStatus.serviceUnavailable);
        expect(await text(r), contains('thor-live-reload'));
      },
    );

    test(
      'a failed start shows its error, escaped, until the next ready',
      () async {
        proxy
          ..restarting()
          ..failed('lib/a.dart:1: Error: <script>alert(1)</script>');
        final r = await send('/page');
        final html = await text(r);
        expect(r.statusCode, HttpStatus.internalServerError);
        expect(html, contains('&lt;script&gt;alert(1)'));
        expect(html, isNot(contains('<script>alert')));
        proxy.ready();
        expect(await text(await send('/page')), contains('hola'));
      },
    );

    test(
      'the app dying mid-request is a 502, and the proxy stays up',
      () async {
        await app.stop();
        final r = await send('/page');
        expect(r.statusCode, HttpStatus.badGateway);
        await r.drain<void>();
        app = _App();
        await app.start();
        proxy.upstream = app.server.port;
        expect(await text(await send('/page')), contains('hola'));
      },
    );
  });

  group('live reload', () {
    Future<(Stream<String>, HttpClientResponse)> listen() async {
      final r = await send(DevProxy.eventsPath);
      final events = r
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .where((l) => l.startsWith('event: ') && l != 'event: result')
          .map((l) => l.substring(7))
          .asBroadcastStream();
      return (events, r);
    }

    test(
      'a page hears hello with this run, then reload on each ready',
      () async {
        final (events, r) = await listen();
        expect(r.headers.contentType?.mimeType, 'text/event-stream');
        final seen = events.take(3).toList();
        await Future<void>.delayed(const Duration(milliseconds: 50));
        proxy
          ..restarting()
          ..ready()
          ..restarting()
          ..failed('boom');
        expect(await seen, ['hello', 'reload', 'reload']);
      },
    );

    test('each run has its own id (a newer run makes pages reload)', () {
      expect(DevProxy(upstream: 1).run, isNot(proxy.run));
      expect(liveReloadScript, contains('e.data!==run'));
    });

    test('a page that goes away is forgotten; the others still hear', () async {
      final (_, gone) = await listen();
      final (events, _) = await listen();
      gone.detachSocket().then((s) => s.destroy()).ignore();
      final next = events.skip(1).first;
      await Future<void>.delayed(const Duration(milliseconds: 50));
      proxy.ready();
      expect(await next.timeout(const Duration(seconds: 2)), 'reload');
    });
  });

  group('result', () {
    Future<Map<String, Object?>> getStatus() async {
      final r = await send(DevProxy.statusPath);
      expect(r.statusCode, HttpStatus.ok);
      expect(r.headers.contentType?.mimeType, 'application/json');
      return jsonDecode(await text(r)) as Map<String, Object?>;
    }

    test('GET /__thor/status says ready, with the stamp', () async {
      final status = await getStatus();
      expect(status['state'], 'ready');
      expect(status['ok'], isTrue);
      expect(status['failure'], isNull);
      expect(status['problems'], isEmpty);
      expect(status['stamp'], proxy.stamp);
      expect(app.requests, isEmpty, reason: 'answered by the proxy');
    });

    test('open problems and a failed app show in it', () async {
      proxy.problem(
        'engine',
        'Engine',
        'lib/a.dart:3:1: Error: nope',
        strict: true,
      );
      var status = await getStatus();
      expect(status['ok'], isFalse);
      final problems = status['problems']! as List;
      expect(problems, hasLength(1));
      expect((problems.single as Map)['key'], 'engine');
      proxy.clearProblem('engine');
      expect((await getStatus())['problems'], isEmpty);

      proxy.failed('boom');
      status = await getStatus();
      expect(status['state'], 'failed');
      expect(status['failure'], 'boom');
      expect(status['ok'], isFalse);
      proxy.restarting();
      expect((await getStatus())['state'], 'restarting');
    });

    test('a result event follows each reload, with the same stamp', () async {
      final r = await send(DevProxy.eventsPath);
      final lines = r
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .asBroadcastStream();
      final data = lines.skipWhile((l) => l != 'event: result').skip(1).first;
      await Future<void>.delayed(const Duration(milliseconds: 50));
      proxy.failed('boom');
      final line = await data.timeout(const Duration(seconds: 2));
      final result = jsonDecode(line.substring(6)) as Map<String, Object?>;
      expect(result['state'], 'failed');
      expect(result['stamp'], proxy.stamp);
    });
  });

  test(
    'the script keys what it keeps by path (behavior: live_reload_web_test)',
    () {
      expect(liveReloadScript, contains('p=location.pathname'));
      expect(liveReloadScript, contains("K='thor:scroll:'+p"));
      // The engine reads the state under the same key (thor_engine's
      // devStateKey, pinned in its dev_state_test).
      expect(liveReloadStateKey, 'thor:state:');
      expect(liveReloadScript, contains("S='thor:state:'+p"));
      expect(liveReloadScript, contains('__thorDevState'));
    },
  );

  test('a busy port fails to start, with the socket error', () async {
    final other = DevProxy(upstream: 1);
    expect(() => other.start(proxy.port), throwsA(isA<SocketException>()));
  });

  group('who can reach it', () {
    Future<String> raw(String request) async {
      final socket = await Socket.connect('127.0.0.1', proxy.port);
      socket.write(request);
      final answer = await utf8.decodeStream(socket);
      socket.destroy();
      return answer;
    }

    /// A request with exactly this `Host` (the HttpClient would add its
    /// port to a name with none).
    Future<({int status, String body})> sendHost(
      String host, {
      String path = '/page',
    }) async {
      final answer = await raw(
        'GET $path HTTP/1.1\r\nHost: $host\r\nConnection: close\r\n\r\n',
      );
      return (
        status: int.parse(answer.split(' ')[1]),
        body: answer.substring(answer.indexOf('\r\n\r\n') + 4),
      );
    }

    test(
      'a foreign Host gets 403 and a message, and never reaches the app',
      () async {
        final r = await sendHost('evil.example');
        expect(r.status, 403);
        final html = r.body;
        expect(html, contains('evil.example'));
        expect(html, contains('--allowed-host'));
        expect(html, isNot(contains('hola')));
        expect(app.requests, isEmpty);
      },
    );

    test('the reload events and the app are refused too', () async {
      expect(
        (await sendHost('evil.example', path: DevProxy.eventsPath)).status,
        403,
      );
      expect((await sendHost('evil.example', path: '/data')).status, 403);
      expect(app.requests, isEmpty);
    });

    test('localhost, 127.0.0.1 and [::1], with a port, in any case', () async {
      for (final host in [
        'localhost:${proxy.port}',
        'LocalHost:${proxy.port}',
        '127.0.0.1:${proxy.port}',
        '[::1]:${proxy.port}',
        'localhost',
        'app.localhost:${proxy.port}',
      ]) {
        expect((await sendHost(host)).status, 200, reason: host);
      }
    });

    test('a tricky Host is refused', () async {
      for (final host in [
        'localhost@evil.example',
        'evil.example:80',
        'localhost.evil.example',
      ]) {
        expect((await sendHost(host)).status, 403, reason: host);
      }
    });

    test(
      'a request without Host (HTTP/1.0) is served: a browser sends one',
      () async {
        final answer = await raw('GET /page HTTP/1.0\r\n\r\n');
        expect(answer, matches(RegExp(r'^HTTP/1\.[01] 200')));
      },
    );

    test('a Host of the --allowed-host list passes', () async {
      final other = DevProxy(
        upstream: app.server.port,
        hosts: const DevHosts(['dev.example', '.lan.test']),
      );
      await other.start(0);
      other.ready();
      Future<int> status(String host) async {
        final socket = await Socket.connect('127.0.0.1', other.port);
        socket.write(
          'GET /page HTTP/1.1\r\nHost: $host\r\nConnection: close\r\n\r\n',
        );
        final answer = await utf8.decodeStream(socket);
        socket.destroy();
        return int.parse(answer.split(' ')[1]);
      }

      expect(await status('dev.example'), 200);
      expect(await status('x.lan.test'), 200);
      expect(await status('evil.example'), 403);
      await other.close();
    });

    // A non-loopback address of this machine (none on a box with no
    // network: then there is nothing to check).
    Future<InternetAddress?> lan() async {
      for (final i in await NetworkInterface.list(
        type: InternetAddressType.IPv4,
      )) {
        for (final a in i.addresses) {
          if (!a.isLoopback && !a.isLinkLocal) return a;
        }
      }
      return null;
    }

    test('listens on loopback only by default', () async {
      final address = await lan();
      if (address == null) return;
      await expectLater(
        Socket.connect(
          address,
          proxy.port,
          timeout: const Duration(seconds: 2),
        ),
        throwsA(isA<SocketException>()),
      );
      // ...and both loopbacks answer.
      final v4 = await Socket.connect(InternetAddress.loopbackIPv4, proxy.port);
      v4.destroy();
    });

    test('binds the IPv6 loopback too, when the machine has one', () async {
      Socket? v6;
      try {
        v6 = await Socket.connect(
          InternetAddress.loopbackIPv6,
          proxy.port,
          timeout: const Duration(seconds: 2),
        );
      } on SocketException {
        // No IPv6 here.
        return;
      }
      v6.destroy();
      final req = await client.open('GET', '::1', proxy.port, '/page');
      final r = await req.close();
      expect(r.statusCode, 200);
      await text(r);
    });

    test('an address given (--host) opens it to the network', () async {
      final address = await lan();
      if (address == null) return;
      final open = DevProxy(upstream: app.server.port);
      await open.start(0, host: InternetAddress.anyIPv4);
      open.ready();
      final socket = await Socket.connect(address, open.port);
      socket.destroy();
      await open.close();
    });
  });
  group('THOR_OVERLAY=off', () {
    Future<String> page(String path, {required bool ui}) async {
      final quiet = DevProxy(upstream: app.server.port, overlayUi: ui);
      await quiet.start(0);
      quiet.ready();
      try {
        final req = await client.open('GET', 'localhost', quiet.port, path);
        return await utf8.decodeStream(await req.close());
      } finally {
        await quiet.close();
      }
    }

    test('a clean page gets the error list without drawing it', () async {
      final html = await page('/page', ui: false);
      expect(html, contains('window.__thorDevErrors=[];'));
      expect(html, contains('const UI=false;'));
      // With the overlay on, a clean page carries no overlay script.
      expect(await page('/page', ui: true), isNot(contains('__thorDevErrors')));
    });

    test('a page error reaches the list, not drawn', () async {
      final html = await page('/split', ui: false);
      expect(html, contains('boom'));
      expect(html, contains('const UI=false;'));
    });
  });
}
