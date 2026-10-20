@TestOn('vm')
library;

// Streaming SSR over a real socket, adversarial: gzip flushes each
// piece, a client that leaves, HTTP/1.0, a client that reads slowly.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:thor_server/thor_server.dart';

/// Pages are `{{name}}` placeholders; `late[name]` completes them. Each
/// completed value is a chunk `<b id=name>value</b>`; a value of the form
/// `big:N` is N kilobytes.
class _Renderer implements PageRenderer<String>, DeferredRender {
  _Renderer(this.late);

  final Map<String, Completer<String>> late;
  final _tails = Expando<Stream<List<int>>>();
  var started = 0;
  var cancelled = 0;

  @override
  List<int> render(String page, RenderContext context) {
    final pending = [
      for (final m in RegExp(r'\{\{(\w+)\}\}').allMatches(page)) m[1]!,
    ];
    if (!context.stream || pending.isEmpty) {
      return utf8.encode('<!DOCTYPE html><html><body>done</body></html>');
    }
    started++;
    final out = StreamController<List<int>>(onCancel: () => cancelled++);
    var left = pending.length;
    for (final name in pending) {
      late[name]!.future.then((v) {
        final body = v.startsWith('big:')
            ? 'x' * (int.parse(v.substring(4)) * 1024)
            : v;
        if (!out.isClosed) out.add(utf8.encode('<b id="$name">$body</b>'));
        if (--left == 0 && !out.isClosed) {
          out.add(utf8.encode('</body></html>'));
          out.close();
        }
      });
    }
    _tails[context] = out.stream;
    return utf8.encode('<!DOCTYPE html><html><body>shell');
  }

  @override
  Stream<List<int>>? lateOf(RenderContext context) => _tails[context];

  @override
  String errorPage(ErrorState state) => 'error ${state.status}';
}

void main() {
  late Map<String, Completer<String>> late;
  late _Renderer renderer;
  late HttpServer http;
  late List<Object> uncaught;

  setUp(() async {
    late = {'a': Completer(), 'b': Completer()};
    renderer = _Renderer(late);
    uncaught = [];
    final server = ThorServer(
      compress: true,
      handler: RouteHandler<String>(
        renderer: renderer,
        routes: [
          PageRoute<String, void>(
            path: 'shop',
            load: (r) {},
            build: (s) => '{{a}}{{b}}',
          ),
          PageRoute<String, void>(
            path: 'plain',
            load: (r) {},
            build: (s) => 'plain',
          ),
        ],
      ),
    );
    http = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    runZonedGuarded(
      () => http.listen(server.handleHttp),
      (e, st) => uncaught.add(e),
    );
  });

  tearDown(() async {
    for (final c in late.values) {
      if (!c.isCompleted) c.complete('x');
    }
    await http.close(force: true);
  });

  Future<List<int>> raw(String request, {Duration? readFor}) async {
    final socket = await Socket.connect('127.0.0.1', http.port);
    socket.write(request);
    final bytes = <int>[];
    final done = Completer<void>();
    socket.listen(bytes.addAll, onDone: done.complete, onError: (_) {});
    await done.future.timeout(const Duration(seconds: 5));
    socket.destroy();
    return bytes;
  }

  test('gzip: the shell is readable before the late values exist', () async {
    final client = HttpClient();
    addTearDown(() => client.close(force: true));
    final request = await client.get('127.0.0.1', http.port, '/shop');
    request.headers.set('accept-encoding', 'gzip');
    final response = await request.close().timeout(const Duration(seconds: 5));
    expect(response.headers.value('content-encoding'), 'gzip');
    expect(response.headers.value('transfer-encoding'), 'chunked');
    final seen = <String>[];
    final done = Completer<void>();
    // `autoUncompress` decodes as the bytes arrive.
    response.listen((c) => seen.add(utf8.decode(c)), onDone: done.complete);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(seen.join(), contains('shell'));
    expect(late['a']!.isCompleted, isFalse);
    late['a']!.complete('A');
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(seen.join(), contains('<b id="a">A</b>'));
    late['b']!.complete('B');
    await done.future.timeout(const Duration(seconds: 5));
    expect(seen.join(), endsWith('</body></html>'));
  });

  test('a client that leaves mid-stream: the server keeps serving', () async {
    final socket = await Socket.connect('127.0.0.1', http.port);
    socket.write('GET /shop HTTP/1.1\r\nhost: x\r\n\r\n');
    final got = Completer<void>();
    socket.listen((_) {
      if (!got.isCompleted) got.complete();
    }, onError: (_) {});
    await got.future.timeout(const Duration(seconds: 5));
    socket.destroy();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    // The values come after the client is gone.
    late['a']!.complete('A');
    late['b']!.complete('B');
    await Future<void>.delayed(const Duration(milliseconds: 100));
    // Cancelled, not left running: nothing listens to the pieces any more.
    expect(renderer.cancelled, 1);
    final client = HttpClient();
    addTearDown(() => client.close(force: true));
    final req = await client.get('127.0.0.1', http.port, '/plain');
    final res = await req.close();
    expect(res.statusCode, 200);
    expect(await utf8.decodeStream(res), contains('done'));
    expect(uncaught, isEmpty);
  });

  test('many clients leaving at once: no unhandled errors', () async {
    final sockets = <Socket>[];
    final before = renderer.started;
    for (var i = 0; i < 30; i++) {
      final s = await Socket.connect('127.0.0.1', http.port);
      s.write('GET /shop HTTP/1.1\r\nhost: x\r\n\r\n');
      s.listen((_) {}, onError: (_) {});
      sockets.add(s);
    }
    // Waits on what happened, not on a clock: a loaded machine is slow.
    Future<void> until(bool Function() done) async {
      final deadline = DateTime.now().add(const Duration(seconds: 10));
      while (!done() && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    }

    await until(() => renderer.started - before >= 30);
    for (final s in sockets) {
      s.destroy();
    }
    late['a']!.complete('big:512');
    late['b']!.complete('B');
    await until(() => renderer.cancelled >= 30);
    expect(uncaught, isEmpty);
    expect(renderer.cancelled, 30);
  });

  test('HTTP/1.0 client: the whole document, the connection closes', () async {
    late['a']!.complete('A');
    late['b']!.complete('B');
    final bytes = await raw('GET /shop HTTP/1.0\r\n\r\n');
    final text = latin1.decode(bytes);
    expect(text, startsWith('HTTP/1.0 200'));
    expect(text.toLowerCase(), isNot(contains('transfer-encoding: chunked')));
    expect(text, contains('<b id="a">A</b>'));
    expect(text, endsWith('</body></html>'));
  });

  test('a slow reader of big pieces does not block other clients', () async {
    final slow = await Socket.connect('127.0.0.1', http.port);
    addTearDown(slow.destroy);
    slow.write('GET /shop HTTP/1.1\r\nhost: x\r\n\r\n');
    // ignore: cancel_subscriptions
    final sub = slow.listen((_) {}, onError: (_) {});
    sub.pause();
    late['a']!.complete('big:2048');
    late['b']!.complete('big:2048');
    await Future<void>.delayed(const Duration(milliseconds: 100));
    // Another visitor is answered meanwhile.
    final client = HttpClient();
    addTearDown(() => client.close(force: true));
    final req = await client.get('127.0.0.1', http.port, '/plain');
    final res = await req.close().timeout(const Duration(seconds: 5));
    expect(await utf8.decodeStream(res), contains('done'));
    // The slow one reads it all in the end.
    var total = 0;
    final done = Completer<void>();
    sub
      ..onData((c) {
        total += c.length;
        // The last chunk of a keep-alive connection: `0\r\n\r\n`.
        if (c.length >= 5 &&
            latin1.decode(c.sublist(c.length - 5)) == '0\r\n\r\n') {
          if (!done.isCompleted) done.complete();
        }
      })
      ..resume();
    await done.future.timeout(const Duration(seconds: 10));
    expect(total, greaterThan(4 * 1024 * 1024));
  });
}
