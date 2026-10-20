// The cache bus in one isolate: what a handler announces, and when.
import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:test/test.dart';
import 'package:thor_server/src/cache_bus.dart';
import 'package:thor_server/thor_server.dart';

class _Renderer implements PageRenderer<String> {
  @override
  List<int> render(String page, RenderContext context) => utf8.encode(page);

  @override
  String errorPage(ErrorState state) => 'error ${state.status}';
}

PageRequest _get(String path) => PageRequest(
  method: HttpMethod.get,
  uri: Uri.parse('http://site.test$path'),
  headers: {HttpHeader.host: 'site.test'},
);

PageRequest _post(String path) => PageRequest(
  method: HttpMethod.post,
  uri: Uri.parse('http://site.test$path'),
  headers: {
    HttpHeader.host: 'site.test',
    HttpHeader.origin: 'http://site.test',
    HttpHeader.contentType: 'application/x-www-form-urlencoded',
  },
  body: Stream.value(utf8.encode('a=1')),
);

RouteHandler<String> _handler(void Function() onLoad) => RouteHandler<String>(
  renderer: _Renderer(),
  routes: [
    PageRoute<String, int>(
      load: (_) {
        onLoad();
        return 1;
      },
      build: (s) => 'page',
      cache: const Duration(minutes: 1),
      actions: {
        'ok': (_) => null,
        'bad': (_) => const ActionResult.fail(422, {'error': 'x'}),
        'redirect': (_) => const Redirect(RouteUrl('/')),
      },
    ),
  ],
);

/// Counts the peers' clears heard (kept referenced: the bus holds it weakly).
class _Cleared {
  int count = 0;
  void call() => count++;
  late final void Function() listener = call;
}

void main() {
  late ReceivePort probe;
  late List<Object?> heard;

  setUp(() {
    CacheBus.reset();
    probe = ReceivePort();
    heard = [];
    probe.listen(heard.add);
    CacheBus.connect([probe.sendPort]);
  });

  tearDown(() {
    CacheBus.reset();
    probe.close();
  });

  Future<void> until(bool Function() ok) async {
    final end = DateTime.now().add(const Duration(seconds: 20));
    while (!ok() && DateTime.now().isBefore(end)) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
  }

  // Everything announced so far has been heard: no message waits for the end
  // of the window, and a marker sent after the last one (same sender, same
  // port, so in order) has come back.
  Future<void> settle() async {
    await until(() => !CacheBus.pending);
    probe.sendPort.send('flush');
    await until(() => heard.contains('flush'));
    heard.remove('flush');
  }

  test('a successful action tells the other isolates once', () async {
    final h = _handler(() {});
    await h.handle(_post('/?/ok'));
    await settle();
    expect(heard, hasLength(1));
  });

  test('a redirecting action counts as success', () async {
    final h = _handler(() {});
    await h.handle(_post('/?/redirect'));
    await settle();
    expect(heard, hasLength(1));
  });

  test('a failed action (4xx) tells nobody', () async {
    final h = _handler(() {});
    final r = await h.handle(_post('/?/bad'));
    expect(r.status, 422);
    await settle();
    expect(heard, isEmpty);
  });

  test('a page that is not found or a GET tells nobody', () async {
    final h = _handler(() {});
    await h.handle(_get('/'));
    await h.handle(_get('/missing'));
    await h.handle(_post('/missing'));
    await settle();
    expect(heard, isEmpty);
  });

  test('a flood of 1000 writes sends at most one message per window', () async {
    final h = _handler(() {});
    final clock = Stopwatch()..start();
    for (var i = 0; i < 1000; i++) {
      await h.handle(_post('/?/ok'));
    }
    final windows = clock.elapsed.inMilliseconds ~/ 50 + 2;
    // Leading message at once; the rest waits for the end of the window.
    await settle();
    expect(heard.length, inInclusiveRange(2, windows));
    // Bounded by time, not by writes.
    final count = heard.length;
    await settle();
    expect(heard, hasLength(count), reason: 'nothing pending afterwards');
  });

  test('the write after a quiet window goes out at once', () async {
    // A window far wider than any stall of a loaded machine: at the end of
    // it would be a second away, so arriving sooner is arriving at once.
    CacheBus.window = const Duration(seconds: 2);
    final h = _handler(() {});
    await h.handle(_post('/?/ok'));
    await until(() => heard.isNotEmpty);
    await Future<void>.delayed(CacheBus.window); // a quiet window
    heard.clear();
    final since = Stopwatch()..start();
    await h.handle(_post('/?/ok'));
    await until(() => heard.isNotEmpty);
    expect(heard, hasLength(1));
    expect(since.elapsed, lessThan(CacheBus.window ~/ 2));
  });

  test('a write inside the window is not lost: it goes at its end', () async {
    CacheBus.window = const Duration(seconds: 2);
    final h = _handler(() {});
    await h.handle(_post('/?/ok'));
    await until(() => heard.isNotEmpty);
    expect(heard, hasLength(1));
    await h.handle(_post('/?/ok'));
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(heard, hasLength(1), reason: 'held for the window');
    await until(() => heard.length == 2);
    expect(heard, hasLength(2));
  });

  test('a message from a peer clears the cache and is not repeated', () async {
    var renders = 0;
    final h = _handler(() => renders++);
    await h.handle(_get('/'));
    await h.handle(_get('/'));
    expect(renders, 1);
    final cleared = _Cleared();
    CacheBus.listen(cleared.listener); // after the handler's own: runs after it
    CacheBus.inbox.send(0);
    await until(() => cleared.count > 0);
    expect(h.cachedPaths, isEmpty);
    await h.handle(_get('/'));
    expect(renders, 2);
    await settle();
    expect(heard, isEmpty, reason: 'a peer\'s clear is not announced again');
  });

  test('a render started before a peer\'s write is not cached', () async {
    final gate = Completer<void>();
    final started = Completer<void>();
    var first = true;
    final h = RouteHandler<String>(
      renderer: _Renderer(),
      routes: [
        PageRoute<String, int>(
          load: (_) async {
            if (first) {
              first = false;
              started.complete();
              await gate.future;
            }
            return 1;
          },
          build: (s) => 'page',
          cache: const Duration(minutes: 1),
        ),
      ],
    );
    final inFlight = h.handle(_get('/'));
    await started.future; // the render is under way
    final cleared = _Cleared();
    CacheBus.listen(cleared.listener); // after the handler's own: runs after it
    CacheBus.inbox.send(0);
    await until(() => cleared.count > 0);
    gate.complete();
    await inFlight;
    expect(h.cachedPaths, isEmpty);
  });

  test('with no peers a write costs nothing', () async {
    CacheBus.connect(const []);
    final h = _handler(() {});
    await h.handle(_post('/?/ok'));
    await settle();
    expect(heard, isEmpty);
  });
}
