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
  String errorPage(ErrorState state) =>
      'error ${state.status}: ${state.message}';
}

// Global limit 1000; /avatar allows 5000; /tiny allows 10.
const _global = 1000;
const _avatar = 5000;

void main() {
  late HttpServer http;
  var bytesRead = <String, int>{};

  FormAction reading(String name) => (r) async {
    final bytes = await r.bytes();
    bytesRead[name] = bytes.length;
    return null;
  };

  setUp(() async {
    bytesRead = {};
    final server = ThorServer(
      maxBodyBytes: _global,
      handler: RouteHandler<String>(
        renderer: _Renderer(),
        onError: (request, error, stack) {},
        routes: [
          PageRoute<String, void>(
            path: 'plain',
            build: (s) => 'plain',
            actions: {'default': reading('plain')},
          ),
          PageRoute<String, void>(
            path: 'avatar',
            build: (s) => 'avatar',
            maxBodyBytes: _avatar,
            actions: {'default': reading('avatar')},
          ),
          PageRoute<String, void>(
            path: 'tiny',
            build: (s) => 'tiny',
            maxBodyBytes: 10,
            actions: {'default': reading('tiny')},
          ),
        ],
      ),
    );
    http = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    http.listen(server.handleHttp);
  });

  tearDown(() => http.close(force: true));

  /// Sends raw bytes and returns the status line's code and the whole reply.
  Future<(int, String)> raw(
    String head,
    List<List<int>> chunks, {
    Duration gap = Duration.zero,
  }) async {
    final socket = await Socket.connect('127.0.0.1', http.port);
    final reply = <int>[];
    final done = Completer<void>();
    socket.listen(
      reply.addAll,
      onDone: done.complete,
      onError: (_) => done.complete(),
    );
    socket.add(utf8.encode(head));
    for (final c in chunks) {
      try {
        socket.add(c);
        await socket.flush();
      } on SocketException {
        break;
      }
      if (gap > Duration.zero) await Future<void>.delayed(gap);
    }
    await done.future.timeout(const Duration(seconds: 20), onTimeout: () {});
    socket.destroy();
    final text = latin1.decode(reply);
    final code =
        int.tryParse(
          RegExp(r'^HTTP/1\.\d (\d+)').firstMatch(text)?.group(1) ?? '',
        ) ??
        0;
    return (code, text);
  }

  String head(
    String path, {
    int? length,
    bool chunked = false,
    String type = 'text/plain',
  }) =>
      'POST $path HTTP/1.1\r\n'
      'Host: 127.0.0.1:${http.port}\r\n'
      'Origin: http://127.0.0.1:${http.port}\r\n'
      'Content-Type: $type\r\n'
      '${length != null ? 'Content-Length: $length\r\n' : ''}'
      '${chunked ? 'Transfer-Encoding: chunked\r\n' : ''}'
      'Connection: close\r\n\r\n';

  Future<(int, String)> post(
    String path,
    int n, {
    String type = 'text/plain',
  }) => raw(head(path, length: n, type: type), [List.filled(n, 97)]);

  List<int> chunk(int n) => [
    ...utf8.encode('${n.toRadixString(16)}\r\n'),
    ...List.filled(n, 97),
    ...utf8.encode('\r\n'),
  ];
  final end = utf8.encode('0\r\n\r\n');

  group('per-route limit', () {
    test(
      'a route with its own limit accepts what the global refuses',
      () async {
        final (code, _) = await post('/avatar', 3000);
        expect(code, 303);
        expect(bytesRead['avatar'], 3000);
      },
    );

    test('the global limit still applies to the other routes', () async {
      final (code, _) = await post('/plain', 3000);
      expect(code, 413);
      expect(bytesRead, isEmpty);
    });

    test('a route can be stricter than the global limit', () async {
      expect((await post('/tiny', 10)).$1, 303);
      expect((await post('/tiny', 11)).$1, 413);
    });

    test('exact boundary: limit passes, limit + 1 is a 413', () async {
      expect((await post('/plain', _global)).$1, 303);
      expect(bytesRead['plain'], _global);
      expect((await post('/plain', _global + 1)).$1, 413);
      expect((await post('/avatar', _avatar)).$1, 303);
      expect((await post('/avatar', _avatar + 1)).$1, 413);
    });

    test('the 413 says what the limit is', () async {
      final (code, text) = await post('/plain', _global + 1);
      expect(code, 413);
      expect(text, contains('$_global'));
    });
  });

  group('Content-Length', () {
    test(
      'a declared length over the limit is refused before reading it',
      () async {
        // Announces 4 GB and sends nothing: a server that buffers waits for
        // the body; this one answers at once.
        final (code, _) = await raw(head('/plain', length: 4 << 30), const []);
        expect(code, 413);
        expect(bytesRead, isEmpty);
      },
    );

    test(
      'a length that lies short (more bytes than declared) is not read past it',
      () async {
        // 5 declared, 2000 sent: dart:io reads the 5 bytes; the rest is not
        // part of this request.
        final (code, _) = await raw(head('/plain', length: 5), [
          List.filled(2000, 97),
        ]);
        expect(code, anyOf(303, 400));
        expect(bytesRead['plain'] ?? 5, 5);
      },
    );

    test(
      'a length that lies long (fewer bytes than declared) never over-reads',
      () async {
        final socket = await Socket.connect('127.0.0.1', http.port);
        socket.add(utf8.encode(head('/plain', length: 900)));
        socket.add(List.filled(100, 97));
        await socket.flush();
        await Future<void>.delayed(const Duration(milliseconds: 200));
        socket.destroy();
        expect(bytesRead, isEmpty);
      },
    );
  });

  group('chunked', () {
    test('over the limit is a 413', () async {
      final (code, _) = await raw(head('/plain', chunked: true), [
        chunk(600),
        chunk(600),
        end,
      ]);
      expect(code, 413);
      expect(bytesRead, isEmpty);
    });

    test('exactly at the limit passes', () async {
      final (code, _) = await raw(head('/plain', chunked: true), [
        chunk(500),
        chunk(500),
        end,
      ]);
      expect(code, 303);
      expect(bytesRead['plain'], _global);
    });

    test('limit + 1 is a 413', () async {
      final (code, _) = await raw(head('/plain', chunked: true), [
        chunk(500),
        chunk(501),
        end,
      ]);
      expect(code, 413);
    });

    test('the route limit applies to chunked bodies too', () async {
      final ok = await raw(head('/avatar', chunked: true), [
        chunk(2000),
        chunk(2000),
        end,
      ]);
      expect(ok.$1, 303);
      final big = await raw(head('/avatar', chunked: true), [
        chunk(3000),
        chunk(2001),
        end,
      ]);
      expect(big.$1, 413);
    });
  });

  group('multipart', () {
    String body(int fileBytes) =>
        '--b\r\nContent-Disposition: form-data; name="f"; filename="a.png"\r\n'
        'Content-Type: image/png\r\n\r\n${'x' * fileBytes}\r\n--b--\r\n';

    Future<(int, String)> upload(String path, int fileBytes) {
      final b = utf8.encode(body(fileBytes));
      return raw(
        head(path, length: b.length, type: 'multipart/form-data; boundary=b'),
        [b],
      );
    }

    test('an avatar-sized file passes on the route that allows it', () async {
      expect((await upload('/avatar', 3000)).$1, 303);
    });

    test('the same file on another route is a 413', () async {
      expect((await upload('/plain', 3000)).$1, 413);
    });
  });
}
