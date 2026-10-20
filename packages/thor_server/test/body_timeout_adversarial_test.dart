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
  late Directory dir;
  const timeout = Duration(milliseconds: 600);

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('thor_slow');
    final server = ThorServer(
      bodyReadTimeout: timeout,
      handler: RouteHandler<String>(
        renderer: _Renderer(),
        onError: (request, error, stack) {},
        routes: [
          PageRoute<String, void>(
            path: 'up',
            build: (s) => 'up',
            actions: {
              'default': (r) async {
                await r.bytes();
                return null;
              },
            },
          ),
          PageRoute<String, void>(
            path: 'save',
            build: (s) => 'save',
            maxBodyBytes: 1 << 20,
            actions: {
              'default': (r) async {
                await r.saveBody(File('${dir.path}/out.bin'));
                return null;
              },
            },
          ),
          PageRoute<String, void>(
            path: 'form',
            build: (s) => 'form',
            actions: {
              'default': (r) async {
                final form = await r.form();
                return Redirect(RouteUrl('/up?n=${form.files.length}'));
              },
            },
          ),
          PageRoute<String, void>(path: 'ok', build: (s) => 'fine'),
        ],
      ),
    );
    http = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    http.listen(server.handleHttp);
  });

  tearDown(() async {
    await http.close(force: true);
    dir.deleteSync(recursive: true);
  });

  String head(String path, String framing, {String? type}) =>
      'POST $path HTTP/1.1\r\nHost: 127.0.0.1:${http.port}\r\n'
      'Origin: http://127.0.0.1:${http.port}\r\n'
      'Content-Type: ${type ?? 'text/plain'}\r\n$framing\r\n\r\n';

  /// Sends [parts] with [gap] between them, and gives the whole reply and
  /// whether the server closed the connection.
  Future<(String, bool)> send(
    String request,
    List<List<int>> parts,
    Duration gap, {
    bool read = true,
  }) async {
    final socket = await Socket.connect('127.0.0.1', http.port);
    final reply = <int>[];
    final done = Completer<void>();
    socket.listen(
      reply.addAll,
      onDone: done.complete,
      onError: (_) => done.complete(),
    );
    socket.add(utf8.encode(request));
    for (final p in parts) {
      if (done.isCompleted) break;
      try {
        socket.add(p);
        await socket.flush();
      } on SocketException {
        break;
      }
      await Future<void>.delayed(gap);
    }
    await done.future.timeout(const Duration(seconds: 4), onTimeout: () {});
    socket.destroy();
    return (latin1.decode(reply), done.isCompleted);
  }

  List<List<int>> bytes(int n) => [
    for (var i = 0; i < n; i++) [97],
  ];

  test('a chunked body that trickles is a 408 too', () async {
    final chunks = [
      for (var i = 0; i < 60; i++) utf8.encode('1\r\na\r\n'),
      utf8.encode('0\r\n\r\n'),
    ];
    final (reply, closed) = await send(
      head('/up', 'Transfer-Encoding: chunked'),
      chunks,
      const Duration(milliseconds: 50),
    );
    expect(reply, startsWith('HTTP/1.1 408'));
    expect(closed, isTrue);
  });

  test('a body that arrives just under the deadline is read', () async {
    final (reply, _) = await send(head('/up', 'Content-Length: 4'), [
      utf8.encode('aaa'),
      utf8.encode('a'),
    ], const Duration(milliseconds: 250));
    expect(reply, startsWith('HTTP/1.1 303'));
  });

  test('a slow but complete body leaves the connection usable', () async {
    final socket = await Socket.connect('127.0.0.1', http.port);
    final text = StringBuffer();
    socket.listen((d) => text.write(latin1.decode(d)), onError: (_) {});
    socket.add(utf8.encode(head('/up', 'Content-Length: 3')));
    for (var i = 0; i < 3; i++) {
      socket.add([97]);
      await socket.flush();
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    await Future<void>.delayed(const Duration(milliseconds: 200));
    // Idle for longer than the body deadline: it was a deadline for the body
    // only, so the second request still gets through.
    await Future<void>.delayed(timeout + const Duration(milliseconds: 200));
    socket.add(
      utf8.encode('GET /ok HTTP/1.1\r\nHost: 127.0.0.1:${http.port}\r\n\r\n'),
    );
    await socket.flush();
    await Future<void>.delayed(const Duration(milliseconds: 400));
    socket.destroy();
    expect(text.toString(), contains('HTTP/1.1 303'));
    expect(text.toString(), contains('HTTP/1.1 200'));
    expect(text.toString(), contains('fine'));
  });

  test('a trickled saveBody is a 408 and leaves nothing behind', () async {
    final (reply, closed) = await send(
      head('/save', 'Content-Length: 100'),
      bytes(100),
      const Duration(milliseconds: 100),
    );
    expect(reply, startsWith('HTTP/1.1 408'));
    expect(closed, isTrue);
    expect(dir.listSync(), isEmpty);
  });

  test('a trickled multipart body is a 408', () async {
    const boundary = 'xBOUNDARYx';
    final body = utf8.encode(
      '--$boundary\r\nContent-Disposition: form-data; name="f"; '
      'filename="a.txt"\r\nContent-Type: text/plain\r\n\r\n'
      '${'a' * 100}\r\n--$boundary--\r\n',
    );
    final (reply, closed) = await send(
      head(
        '/form',
        'Content-Length: ${body.length}',
        type: 'multipart/form-data; boundary=$boundary',
      ),
      [
        for (var i = 0; i < body.length; i += 2)
          body.sublist(i, i + 2 > body.length ? body.length : i + 2),
      ],
      const Duration(milliseconds: 30),
    );
    expect(reply, startsWith('HTTP/1.1 408'));
    expect(closed, isTrue);
  });
}
