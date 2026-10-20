@TestOn('vm')
library;

// `ThorHttpClient(warmUp:)` / `preconnect`: the first real call after boot
// finds an open keep-alive socket (the TLS handshake of a cold start is paid
// before it), and a warm-up that fails never throws.
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:thor_server/thor_server.dart';

void main() {
  late HttpServer server;
  late List<String> methods;
  var connections = 0;

  setUp(() async {
    methods = [];
    connections = 0;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((r) {
      methods.add(r.method);
      r.response
        ..write('ok')
        ..close();
    });
  });
  tearDown(() => server.close(force: true));

  Uri url() => Uri.parse('http://127.0.0.1:${server.port}/ping');

  test('preconnect opens the socket the next call reuses', () async {
    await server.close(force: true);
    final raw = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(raw.close);
    raw.listen((s) {
      connections++;
      final buffer = StringBuffer();
      s.listen((d) {
        buffer.write(String.fromCharCodes(d));
        while (buffer.toString().contains('\r\n\r\n')) {
          final head = buffer.toString();
          buffer.clear();
          final method = head.split(' ').first;
          methods.add(method);
          s.write(
            'HTTP/1.1 200 OK\r\ncontent-length: 2\r\n'
            'connection: keep-alive\r\n\r\n${method == 'HEAD' ? '' : 'ok'}',
          );
        }
      }, onError: (_) {});
    });
    final uri = Uri.parse('http://127.0.0.1:${raw.port}/ping');
    final client = ThorHttpClient();
    await client.preconnect(uri);
    expect(connections, 1);
    expect(methods, ['HEAD']);
    final res = await client.get(uri);
    expect(res.statusCode, 200);
    expect(connections, 1, reason: 'the call reused the warmed socket');
  });

  test('warmUp at construction connects without blocking', () async {
    final client = ThorHttpClient(warmUp: [url(), url().toString()]);
    // Order, not a clock: the constructor returned before the stub saw a
    // single request (the event loop has not run yet).
    expect(methods, isEmpty);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(methods, isNotEmpty);
    expect((await client.get(url())).statusCode, 200);
  });

  test('a warm-up that fails does not throw', () async {
    final dead = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = dead.port;
    await dead.close();
    final client = ThorHttpClient(
      warmUp: [Uri.parse('http://127.0.0.1:$port/')],
    );
    await client.preconnect(Uri.parse('http://127.0.0.1:$port/'));
    await client.preconnect('not a url at all ::');
    await Future<void>.delayed(const Duration(milliseconds: 100));
  });

  test('a warm-up that never answers is cut off, never throws', () async {
    final silent = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(silent.close);
    final held = <Socket>[];
    silent.listen(held.add);
    addTearDown(() {
      for (final s in held) {
        s.destroy();
      }
    });
    final client = ThorHttpClient(timeout: const Duration(milliseconds: 200));
    final started = Stopwatch()..start();
    await client.preconnect(Uri.parse('http://127.0.0.1:${silent.port}/'));
    expect(started.elapsedMilliseconds, lessThan(1500));
  });

  test('under a test transport the warm-up does nothing', () async {
    final client = ThorHttpClient();
    var faked = 0;
    await runWithThorHttpTransport((req) {
      faked++;
      return ThorHttpResponse(
        uri: req.uri,
        method: req.method,
        statusCode: 200,
        bytes: Uint8List(0),
      );
    }, () => client.preconnect(url()));
    // The fake answers calls; there is no real socket to warm, and a test
    // must not touch the network.
    expect(faked, 0);
    expect(methods, isEmpty);
  });

  test(
    'invalid or unsupported URLs are ignored: no throw, no connection',
    () async {
      final client = ThorHttpClient(timeout: const Duration(milliseconds: 300));
      for (final bad in <Object>[
        '',
        '/relative',
        'http://',
        'http://:80/',
        'ftp://127.0.0.1:${server.port}/',
        'file:///etc/passwd',
        'javascript:alert(1)',
        5,
        Object(),
      ]) {
        await client.preconnect(bad);
      }
      // The same through the constructor.
      ThorHttpClient(warmUp: ['', 5, 'ftp://x/', Uri.parse('/a')]);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(methods, isEmpty);
    },
  );

  test('a host that does not resolve ends within the timeout', () async {
    final client = ThorHttpClient(timeout: const Duration(seconds: 2));
    final started = Stopwatch()..start();
    await client.preconnect('http://thor-no-such-host.invalid/');
    expect(started.elapsedMilliseconds, lessThan(4000));
  });

  test('a hundred URLs of one origin warm it once', () async {
    ThorHttpClient(warmUp: [for (var i = 0; i < 100; i++) '${url()}?n=$i']);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(methods, hasLength(1));
  });

  test('many origins are warmed a few at a time', () async {
    var live = 0;
    var peak = 0;
    final sockets = <ServerSocket>[];
    final held = <Socket>[];
    addTearDown(() {
      for (final s in held) {
        s.destroy();
      }
      for (final s in sockets) {
        s.close();
      }
    });
    final urls = <String>[];
    for (var i = 0; i < 40; i++) {
      final raw = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      sockets.add(raw);
      raw.listen((s) {
        held.add(s);
        live++;
        if (live > peak) peak = live;
        s.listen((_) {}, onDone: () => live--, onError: (_) {});
      });
      urls.add('http://127.0.0.1:${raw.port}/');
    }
    // They never answer: each warm-up holds its slot until the timeout.
    ThorHttpClient(timeout: const Duration(milliseconds: 500), warmUp: urls);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(peak, lessThanOrEqualTo(8));
    expect(peak, greaterThan(0));
  });
}
