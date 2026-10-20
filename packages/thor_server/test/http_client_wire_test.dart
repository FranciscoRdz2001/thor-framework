@TestOn('vm')
library;

// ThorHttpClient speaks HTTP/1.1 over a plain socket: what dart:io's
// HttpClient did for it, checked against dart:io's server and raw sockets.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:thor_server/thor_server.dart';

/// A raw backend: [answer] gets each request head and writes the response.
Future<(ServerSocket, List<String>)> _raw(
  void Function(Socket socket, String head) answer,
) async {
  final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final heads = <String>[];
  server.listen((s) {
    var buffer = '';
    s.listen((d) {
      buffer += latin1.decode(d);
      while (buffer.contains('\r\n\r\n')) {
        final end = buffer.indexOf('\r\n\r\n');
        final head = buffer.substring(0, end);
        buffer = buffer.substring(end + 4);
        final length = RegExp(
          r'content-length: (\d+)',
          caseSensitive: false,
        ).firstMatch(head);
        if (length != null) {
          buffer = buffer.substring(int.parse(length.group(1)!));
        }
        heads.add(head);
        answer(s, head);
      }
    }, onError: (_) {});
  });
  addTearDown(server.close);
  return (server, heads);
}

void main() {
  test('a chunked body, split anywhere, is read whole', () async {
    final (server, _) = await _raw((s, _) async {
      const parts = [
        'HTTP/1.1 200 OK\r\ntransfer-',
        'encoding: chunked\r\n\r\n5\r\nhel',
        'lo\r\n6;ext=1\r\n world\r\n0\r\nx-trailer: 1\r\n\r\n',
      ];
      for (final p in parts) {
        s.add(latin1.encode(p));
        await s.flush();
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
    });
    final client = ThorHttpClient();
    final r = await client.get('http://127.0.0.1:${server.port}/');
    expect(r.text, 'hello world');
    // The connection is kept: a second call goes out on it.
    expect(
      (await client.get('http://127.0.0.1:${server.port}/')).text,
      'hello world',
    );
  });

  test('a response that arrives a byte at a time', () async {
    final (server, _) = await _raw((s, _) async {
      final bytes = latin1.encode(
        'HTTP/1.1 200 OK\r\ncontent-length: 5\r\nx-a: 1\r\n\r\nhello',
      );
      for (final b in bytes) {
        s.add([b]);
        await s.flush();
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
    });
    final r = await ThorHttpClient().get('http://127.0.0.1:${server.port}/');
    expect(r.text, 'hello');
    expect(r.headers[const HttpHeader('x-a')], '1');
  });

  test('a body without a length runs to the close', () async {
    final (server, _) = await _raw((s, _) {
      s.add(latin1.encode('HTTP/1.1 200 OK\r\n\r\nall of it'));
      unawaited(s.close());
    });
    final r = await ThorHttpClient().get('http://127.0.0.1:${server.port}/');
    expect(r.text, 'all of it');
  });

  test('an interim 100 Continue is skipped', () async {
    final (server, _) = await _raw((s, _) {
      s.add(
        latin1.encode(
          'HTTP/1.1 100 Continue\r\n\r\n'
          'HTTP/1.1 201 Created\r\ncontent-length: 2\r\n\r\nok',
        ),
      );
    });
    final r = await ThorHttpClient().post(
      'http://127.0.0.1:${server.port}/',
      json: {'a': 1},
    );
    expect(r.statusCode, 201);
    expect(r.text, 'ok');
  });

  test('the request: host, json body, lower-case headers, one socket', () async {
    final (server, heads) = await _raw((s, _) {
      s.add(
        latin1.encode(
          'HTTP/1.1 200 OK\r\nX-Two: a\r\nx-two: b\r\ncontent-length: 0\r\n\r\n',
        ),
      );
    });
    final client = ThorHttpClient(
      headers: {const HttpHeader('Accept'): 'application/json'},
    );
    final url = 'http://127.0.0.1:${server.port}/a/b?x=1&y=%20';
    final r = await client.post(url, json: {'k': 'v'});
    await client.get(url);
    expect(r.headers[const HttpHeader('x-two')], 'a, b');
    expect(heads, hasLength(2));
    final lines = heads.first.split('\r\n');
    expect(lines.first, 'POST /a/b?x=1&y=%20 HTTP/1.1');
    expect(lines, contains('host: 127.0.0.1:${server.port}'));
    expect(lines, contains('accept: application/json'));
    expect(lines, contains('content-type: application/json; charset=utf-8'));
    expect(lines, contains('content-length: 9'));
    expect(heads.last.split('\r\n').first, 'GET /a/b?x=1&y=%20 HTTP/1.1');
  });

  test('a gzip body is decoded', () async {
    final backend = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => backend.close(force: true));
    backend.listen((r) {
      expect(r.headers.value('accept-encoding'), contains('gzip'));
      r.response
        ..headers.set('content-encoding', 'gzip')
        ..add(gzip.encode(utf8.encode('{"zipped":true}')))
        ..close();
    });
    final json = await ThorHttpClient().getJson(
      'http://127.0.0.1:${backend.port}/',
    );
    expect(json, {'zipped': true});
  });

  group('redirects', () {
    late HttpServer backend;
    late List<String> seen;
    setUp(() async {
      seen = [];
      backend = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      backend.listen((r) {
        seen.add('${r.method} ${r.uri.path}');
        final to = switch (r.uri.path) {
          '/a' => '/b',
          '/post' => '/done',
          '/loop' => '/loop2',
          '/loop2' => '/loop',
          final p when p.startsWith('/n') =>
            '/n${int.parse(p.substring(2)) + 1}',
          _ => null,
        };
        if (to != null) {
          r.response
            ..statusCode = r.method == 'POST' ? 303 : 302
            ..headers.set('location', to);
        } else {
          r.response.write('at ${r.uri.path}');
        }
        r.response.close();
      });
    });
    tearDown(() => backend.close(force: true));
    String url(String path) => 'http://127.0.0.1:${backend.port}$path';

    test('a GET follows them', () async {
      final r = await ThorHttpClient().get(url('/a'));
      expect(r.text, 'at /b');
      expect(seen, ['GET /a', 'GET /b']);
    });

    test('a POST answered 303 continues as a GET', () async {
      final r = await ThorHttpClient().post(url('/post'), json: {'a': 1});
      expect(r.text, 'at /done');
      expect(seen, ['POST /post', 'GET /done']);
    });

    test('too many, or a loop, is a 502', () async {
      final client = ThorHttpClient(maxRedirects: 3);
      await expectLater(
        client.get(url('/n0')),
        throwsA(isA<UpstreamError>().having((e) => e.status, 'status', 502)),
      );
      await expectLater(
        client.get(url('/loop')),
        throwsA(isA<UpstreamError>().having((e) => e.status, 'status', 502)),
      );
    });
  });

  test('more calls than connections wait for one', () async {
    var open = 0;
    var peak = 0;
    final (server, _) = await _raw((s, _) async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      s.add(latin1.encode('HTTP/1.1 200 OK\r\ncontent-length: 2\r\n\r\nok'));
    });
    final counter = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(counter.close);
    // Counts connections by proxying to [server].
    counter.listen((s) async {
      open++;
      if (open > peak) peak = open;
      final up = await Socket.connect(
        InternetAddress.loopbackIPv4,
        server.port,
      );
      s.listen(up.add, onDone: up.destroy, onError: (_) {});
      up.listen(
        s.add,
        onDone: () {
          open--;
          s.destroy();
        },
        onError: (_) {},
      );
    });
    final client = ThorHttpClient(maxConnectionsPerHost: 3);
    final results = await Future.wait([
      for (var i = 0; i < 12; i++)
        client.get('http://127.0.0.1:${counter.port}/$i'),
    ]);
    expect(results.map((r) => r.text).toSet(), {'ok'});
    expect(peak, lessThanOrEqualTo(3));
    client.close(force: true);
  });

  test('a header value with a line break is a 502, nothing sent', () async {
    final (server, heads) = await _raw((s, _) {});
    await expectLater(
      ThorHttpClient().get(
        'http://127.0.0.1:${server.port}/',
        headers: {const HttpHeader('x-bad'): 'a\r\nx-injected: 1'},
      ),
      throwsA(isA<UpstreamError>().having((e) => e.status, 'status', 502)),
    );
    expect(heads, isEmpty);
  });
}
