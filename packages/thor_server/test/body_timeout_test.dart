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

  Future<void> start({Duration? timeout}) async {
    final server = timeout == null
        ? ThorServer(handler: _handler())
        : ThorServer(bodyReadTimeout: timeout, handler: _handler());
    http = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    http.listen(server.handleHttp);
  }

  tearDown(() => http.close(force: true));

  /// Sends [n] bytes of a body one by one, [gap] apart, and returns the reply
  /// and whether the server closed the connection.
  Future<(String, bool)> trickle(int n, Duration gap) async {
    final socket = await Socket.connect('127.0.0.1', http.port);
    final reply = <int>[];
    final done = Completer<void>();
    socket.listen(
      reply.addAll,
      onDone: done.complete,
      onError: (_) => done.complete(),
    );
    socket.add(
      utf8.encode(
        'POST /up HTTP/1.1\r\nHost: 127.0.0.1:${http.port}\r\n'
        'Origin: http://127.0.0.1:${http.port}\r\n'
        'Content-Type: text/plain\r\nContent-Length: $n\r\n\r\n',
      ),
    );
    for (var i = 0; i < n && !done.isCompleted; i++) {
      try {
        socket.add([97]);
        await socket.flush();
      } on SocketException {
        break;
      }
      await Future<void>.delayed(gap);
    }
    await done.future.timeout(const Duration(seconds: 5), onTimeout: () {});
    socket.destroy();
    return (latin1.decode(reply), done.isCompleted);
  }

  test(
    'a body trickled under the limit is a 408 and the connection closes',
    () async {
      await start(timeout: const Duration(milliseconds: 400));
      final watch = Stopwatch()..start();
      // 100 bytes, one every 100 ms: each arrives in time, the whole never does.
      final (reply, closed) = await trickle(
        100,
        const Duration(milliseconds: 100),
      );
      expect(reply, startsWith('HTTP/1.1 408'));
      expect(closed, isTrue);
      expect(watch.elapsed, lessThan(const Duration(seconds: 3)));
    },
  );

  test('a body that arrives in time is read', () async {
    await start(timeout: const Duration(seconds: 5));
    final (reply, _) = await trickle(5, const Duration(milliseconds: 10));
    expect(reply, startsWith('HTTP/1.1 303'));
  });

  test('the default is 30 seconds', () {
    expect(
      ThorServer(handler: _handler()).bodyReadTimeout,
      const Duration(seconds: 30),
    );
  });
}

RouteHandler<String> _handler() => RouteHandler<String>(
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
  ],
);
