// Adversarial edges of the cache bus, in one isolate: dead peers, bursts
// against the window edge, failing writes, and every cached variant.
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

PageRequest _req(String method, String path, {String cookie = ''}) =>
    PageRequest(
      method: HttpMethod.tryParse(method)!,
      uri: Uri.parse('http://site.test$path'),
      headers: {
        HttpHeader.host: 'site.test',
        if (cookie.isNotEmpty) HttpHeader.cookie: cookie,
        if (method == 'POST') ...{
          HttpHeader.origin: 'http://site.test',
          HttpHeader.contentType: 'application/x-www-form-urlencoded',
        },
      },
      body: method == 'POST' ? Stream.value(utf8.encode('a=1')) : null,
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

  Future<void> pause(int ms) =>
      Future<void>.delayed(Duration(milliseconds: ms));
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

  test('a peer that died (closed port) does not break announcing', () async {
    final dead = ReceivePort();
    final port = dead.sendPort;
    dead.close();
    CacheBus.connect([port, probe.sendPort]);
    expect(CacheBus.announce, returnsNormally);
    CacheBus.announce();
    await settle();
    expect(heard, isNotEmpty, reason: 'the live peer still hears');
  });

  test('a peer whose isolate exited does not break announcing', () async {
    final port = ReceivePort();
    final exited = ReceivePort();
    await Isolate.spawn(
      (SendPort p) {
        final r = ReceivePort();
        p.send(r.sendPort);
        r.listen((_) => Isolate.exit());
      },
      port.sendPort,
      onExit: exited.sendPort,
    );
    final peer = await port.first as SendPort;
    peer.send(0);
    await exited.first; // it is gone
    CacheBus.connect([peer, probe.sendPort]);
    for (var i = 0; i < 5; i++) {
      CacheBus.announce();
      await settle();
    }
    expect(heard, isNotEmpty);
    port.close();
    exited.close();
  });

  test(
    'after any burst the last write is announced within the window',
    () async {
      // Writes spaced around the window edge: just under, just over, exactly.
      // A loaded machine moves the real gaps, and the property holds for any
      // of them: whatever went out before the last write, one more follows
      // (or went with it), and nothing is left pending afterwards.
      for (final gap in [1, 25, 49, 50, 51, 52, 75, 99, 100, 101]) {
        await settle();
        heard.clear();
        for (var i = 0; i < 4; i++) {
          CacheBus.announce();
          await pause(gap);
        }
        await settle();
        expect(heard.length, greaterThanOrEqualTo(1), reason: 'gap $gap');
        expect(CacheBus.pending, isFalse, reason: 'gap $gap');
        // Nothing is left pending: a later quiet period sends nothing.
        final after = heard.length;
        await pause(CacheBus.window.inMilliseconds + 20);
        await settle();
        expect(heard.length, after, reason: 'gap $gap: nothing pending');
      }
    },
  );

  test(
    'the last write of a burst is never the one that goes unannounced',
    () async {
      // The window is wider than any stall: the first write goes out at
      // once, the second lands inside it and waits for its end.
      CacheBus.window = const Duration(seconds: 1);
      CacheBus.announce();
      await until(() => heard.length == 1);
      CacheBus.announce();
      await pause(3);
      expect(heard.length, 1, reason: 'held for the window');
      await until(() => heard.length == 2);
      await settle();
      expect(heard.length, 2);
    },
  );

  test('an action that throws (500) announces nothing', () async {
    final h = RouteHandler<String>(
      renderer: _Renderer(),
      onError: (_, _, _) {},
      routes: [
        PageRoute<String, void>(
          build: (_) => 'p',
          cache: const Duration(minutes: 1),
          actions: {'boom': (_) => throw StateError('x')},
        ),
      ],
    );
    final r = await h.handle(_req('POST', '/?/boom'));
    expect(r.status, 500);
    await settle();
    expect(heard, isEmpty);
  });

  test('a peer clears every cached variant of a page', () async {
    var renders = 0;
    final h = RouteHandler<String>(
      renderer: _Renderer(),
      routes: [
        PageRoute<String, void>(
          load: (_) => renders++,
          build: (_) => 'p',
          cache: const Duration(minutes: 1),
        ),
      ],
    );
    for (final path in ['/', '/?a=1', '/?a=2', '/?a=1&b=2', '/?']) {
      await h.handle(_req('GET', path));
    }
    expect(h.cachedPaths.length, greaterThanOrEqualTo(4));
    final cleared = _Cleared();
    CacheBus.listen(cleared.listener); // after the handler's: runs after it
    CacheBus.inbox.send(0);
    await until(() => cleared.count == 1);
    expect(h.cachedPaths, isEmpty);
  });

  test('two peers\' messages in a row clear twice without error', () async {
    final h = RouteHandler<String>(
      renderer: _Renderer(),
      routes: [
        PageRoute<String, void>(
          build: (_) => 'p',
          cache: const Duration(minutes: 1),
        ),
      ],
    );
    await h.handle(_req('GET', '/'));
    final cleared = _Cleared();
    CacheBus.listen(cleared.listener); // after the handler's: runs after it
    CacheBus.inbox.send(0);
    CacheBus.inbox.send(0);
    await until(() => cleared.count == 2);
    expect(h.cachedPaths, isEmpty);
    await h.handle(_req('GET', '/'));
    expect(h.cachedPaths, isNotEmpty);
  });

  test('a listener held by the caller hears a peer', () async {
    var cleared = 0;
    void listener() => cleared++;
    CacheBus.listen(listener);
    CacheBus.inbox.send(0);
    await until(() => cleared == 1);
    expect(cleared, 1);
  });

  test(
    'a personalized page is never cached, so no clear has to reach it',
    () async {
      final h = RouteHandler<String>(
        renderer: _Renderer(),
        routes: [
          PageRoute<String, String?>(
            load: (r) => r.cookies['sid'],
            build: (s) => 'hi ${s.data}',
            cache: const Duration(minutes: 1),
            personalized: true,
          ),
        ],
      );
      await h.handle(_req('GET', '/', cookie: 'sid=ana'));
      expect(h.cachedPaths, isEmpty);
      final other = await h.handle(_req('GET', '/', cookie: 'sid=bob'));
      expect(other.text, 'hi bob');
    },
  );
}
