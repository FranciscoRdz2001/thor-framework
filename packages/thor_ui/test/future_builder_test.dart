@TestOn('vm')
library;

// Fixtures: these builders tell waiting from done with `hasData` only, which
// is not the pattern the guide teaches for a nullable future.
// ignore_for_file: thor_lints/future_builder_nullable_has_data

// Streaming SSR: a page whose `FutureBuilder`s wait for futures
// goes out with their skeletons, then each result as it arrives.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:thor_server/thor_server.dart' show ThorDev, exportSite;
import 'package:thor_ui/router.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

class LateCounter extends ThorState {
  LateCounter();
  final count = state(0);
  String label() => '${count.value}';
  void increment() => count.value++;
}

final lateCounter = LateCounter();

class LateBad extends ThorState {
  LateBad();
  final value = state<Object?>(0);
  String label() => '${value.value}';
}

final lateBad = LateBad();

class _Data {
  _Data() : a = Completer<String>(), b = Completer<String>();
  final Completer<String> a;
  final Completer<String> b;
  Completer<String>? inner;
  final Completer<String?> maybe = Completer<String?>();
}

void main() {
  initializeThorTests();
  setUpAll(
    () => ThorState.register({
      LateBad: ThorStateType('LateBad', (state) {
        final s = state as LateBad;
        return [
          ThorMember.state('value', s.value),
          ThorMember('label', s.label, call: (_) => s.label()),
        ];
      }),
      LateCounter: ThorStateType('LateCounter', (state) {
        final s = state as LateCounter;
        return [
          ThorMember.state('count', s.count),
          ThorMember('label', s.label, call: (_) => s.label()),
          ThorMember('increment', s.increment, call: (_) => s.increment()),
        ];
      }),
    }),
  );

  late _Data data;
  late List<Object> errors;

  Widget text(AsyncSnapshot<String> s, String name) => s.hasError
      ? Text('$name failed: ${s.error}')
      : s.hasData
      ? Text('$name = ${s.data}')
      : Text('$name loading');

  RouteHandler<Widget> handler({
    Duration timeout = const Duration(seconds: 30),
    Duration? cache,
  }) => RouteHandler<Widget>(
    renderer: WidgetRenderer(app: (page) => ThorApp(child: page)),
    deferTimeout: timeout,
    onError: (request, error, stack) => errors.add(error),
    routes: [
      PageRoute<Widget, _Data>(
        path: 'shop',
        load: (r) => data,
        cache: cache,
        meta: (s) => const PageMeta(title: 'Shop'),
        build: (s) => Column(
          children: [
            const Text('header'),
            FutureBuilder<String>(
              future: s.data.a.future,
              builder: (context, snap) => text(snap, 'a'),
            ),
            FutureBuilder<String>(
              future: s.data.b.future,
              builder: (context, snap) => snap.hasData
                  ? Container(
                      color: const Color(0xFFAB1234),
                      child: text(snap, 'b'),
                    )
                  : text(snap, 'b'),
            ),
            const Text('footer'),
          ],
        ),
      ),
      // `hasData` is false for a future that answers null: this one draws the
      // waiting branch for it too.
      PageRoute<Widget, _Data>(
        path: 'maybe',
        load: (r) => data,
        build: (s) => FutureBuilder<String?>(
          future: s.data.maybe.future,
          builder: (context, snap) =>
              snap.hasData ? Text('got ${snap.data}') : const Text('skeleton'),
        ),
      ),
      PageRoute<Widget, _Data>(
        path: 'maybe-done',
        load: (r) => data,
        build: (s) => FutureBuilder<String?>(
          future: s.data.maybe.future,
          builder: (context, snap) =>
              snap.connectionState != ConnectionState.done
              ? const Text('skeleton')
              : snap.hasData
              ? Text('got ${snap.data}')
              : const Text('nothing'),
        ),
      ),
      // Throws for the value it was not written for (null).
      PageRoute<Widget, _Data>(
        path: 'maybe-throws',
        load: (r) => data,
        build: (s) => FutureBuilder<String?>(
          future: s.data.maybe.future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.done &&
                snap.data == null) {
              throw StateError('no value');
            }
            return Text(snap.hasData ? 'got ${snap.data}' : 'skeleton');
          },
        ),
      ),
      PageRoute<Widget, _Data>(
        path: 'counter',
        load: (r) {
          // The server's value of a field: it travels in the page's state.
          lateCounter.count.value = 7;
          return data;
        },
        build: (s) => Column(
          children: [
            const Text('header'),
            FutureBuilder<String>(
              future: s.data.a.future,
              builder: (context, snap) => snap.hasData
                  ? Column(
                      children: [
                        Text(snap.data!),
                        Watch(lateCounter.label),
                        FilledButton(
                          onPressed: lateCounter.increment,
                          child: const Text('+'),
                        ),
                      ],
                    )
                  : const Text('loading'),
            ),
          ],
        ),
      ),
      PageRoute<Widget, _Data>(
        path: 'bad-state',
        load: (r) {
          // A value that is not JSON.
          lateBad.value.value = Object();
          return data;
        },
        build: (s) => FutureBuilder<String>(
          future: s.data.a.future,
          builder: (context, snap) =>
              snap.hasData ? Watch(lateBad.label) : const Text('loading'),
        ),
      ),
      PageRoute<Widget, _Data>(
        path: 'counter-twice',
        load: (r) {
          lateCounter.count.value = 7;
          return data;
        },
        build: (s) => Column(
          children: [
            Watch(lateCounter.label),
            FutureBuilder<String>(
              future: s.data.a.future,
              builder: (context, snap) => snap.hasData
                  ? Watch(lateCounter.label)
                  : const Text('loading'),
            ),
          ],
        ),
      ),
      PageRoute<Widget, _Data>(
        path: 'known',
        load: (r) {
          // Started in `load`, one of them done before the page is drawn.
          defer(data.a.future);
          defer(data.b.future);
          return data;
        },
        build: (s) => Column(
          children: [
            FutureBuilder<String>(
              future: s.data.a.future,
              builder: (context, snap) => text(snap, 'a'),
            ),
            FutureBuilder<String>(
              future: s.data.b.future,
              builder: (context, snap) => text(snap, 'b'),
            ),
          ],
        ),
      ),
      PageRoute<Widget, _Data>(
        path: 'nested',
        load: (r) => data,
        build: (s) => FutureBuilder<String>(
          future: s.data.a.future,
          builder: (context, snap) => snap.hasData
              ? Column(
                  children: [
                    Text('outer ${snap.data}'),
                    FutureBuilder<String>(
                      future: s.data.inner!.future,
                      builder: (context, inner) => text(inner, 'inner'),
                    ),
                  ],
                )
              : const Text('outer loading'),
        ),
      ),
    ],
  );

  PageRequest get(String path) => PageRequest(
    method: HttpMethod.get,
    uri: Uri.parse('http://site.test$path'),
    headers: {HttpHeader.host: 'site.test'},
  );

  Future<List<String>> pieces(
    ThorResponse r, {
    void Function()? onShell,
  }) async {
    final chunks = <String>[];
    final done = Completer<void>();
    r.stream!.listen((c) => chunks.add(utf8.decode(c)), onDone: done.complete);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    onShell?.call();
    await done.future;
    return chunks;
  }

  setUp(() {
    data = _Data();
    errors = [];
  });

  test('the shell goes out with the skeletons, before any value', () async {
    final r = await handler().handle(get('/shop'));
    expect(r.status, 200);
    expect(r.stream, isNotNull);
    final chunks = <String>[];
    final sub = r.stream!.listen((c) => chunks.add(utf8.decode(c)));
    addTearDown(sub.cancel);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(chunks, hasLength(1));
    final shell = chunks.single;
    expect(shell, startsWith('<!DOCTYPE html>'));
    expect(shell, contains('<title>Shop</title>'));
    expect(shell, contains('header'));
    expect(shell, contains('footer'));
    expect(shell, contains('<!--thor:1-->'));
    expect(shell, contains('a loading'));
    expect(shell, contains('b loading'));
    expect(shell, isNot(contains('</body>')));
    expect(shell, contains(r'function $thor('));
    data.a.complete('A');
    data.b.complete('B');
    await sub.asFuture<void>();
    expect(chunks.join(), endsWith('</body></html>\n'));
  });

  test('each value follows when it is done, in completion order', () async {
    final r = await handler().handle(get('/shop'));
    final all = pieces(
      r,
      onShell: () {
        data.b.complete('B');
        Future<void>.delayed(const Duration(milliseconds: 20), () {
          data.a.complete('A');
        });
      },
    );
    final chunks = await all;
    // shell, b, a, closing
    expect(chunks, hasLength(4));
    expect(chunks[1], contains('b = B'));
    expect(chunks[1], contains('data-thor-end="2"'));
    expect(chunks[1], contains('id="thor-d2"'));
    expect(chunks[2], contains('a = A'));
    expect(chunks[2], contains('data-thor-end="1"'));
  });

  test('the classes of what comes late come with it', () async {
    final r = await handler().handle(get('/shop'));
    final chunks = await pieces(
      r,
      onShell: () {
        data.a.complete('A');
        data.b.complete('B');
      },
    );
    final shell = chunks.first;
    final late = chunks.skip(1).join();
    // A color only the late `Container` has.
    expect(shell.toLowerCase(), isNot(contains('ab1234')));
    expect(late.toLowerCase(), contains('ab1234'));
    expect(late, contains('<style>@layer'));
    // The class is on the element, not inline.
    expect(
      RegExp(r'<div class="[^"]+">b = B').hasMatch(late) ||
          late.contains('b = B'),
      isTrue,
    );
  });

  test('a failed future draws its error state, reported once', () async {
    final r = await handler().handle(get('/shop'));
    final chunks = await pieces(
      r,
      onShell: () {
        data.a.completeError(StateError('backend down'));
        data.b.complete('B');
      },
    );
    final late = chunks.skip(1).join();
    // The visitor's message, never the exception.
    expect(late, contains('a failed: Something went wrong'));
    expect(late, isNot(contains('backend down')));
    expect(errors.whereType<StateError>(), hasLength(1));
  });

  test(
    'a future that fails before the page reads it is not unhandled',
    () async {
      final failed = _Data()..a.completeError(StateError('early'));
      data = failed;
      // Marked handled like `defer(...)` does.
      data.a.future.ignore();
      final r = await handler().handle(get('/shop'));
      data.b.complete('B');
      final chunks = await pieces(r);
      expect(chunks.skip(1).join(), contains('a failed'));
    },
  );

  test(
    'a future that takes too long: the timeout error, the response ends',
    () async {
      final r = await handler(
        timeout: const Duration(milliseconds: 60),
      ).handle(get('/shop'));
      final chunks = await pieces(r, onShell: () => data.b.complete('B'));
      final late = chunks.skip(1).join();
      expect(late, contains('a failed: The server took too long to answer'));
      expect(late, contains('b = B'));
      expect(chunks.last, endsWith('</body></html>\n'));
    },
  );

  test('a deferred value that holds another one', () async {
    data.inner = Completer<String>();
    final r = await handler().handle(get('/nested'));
    final chunks = await pieces(
      r,
      onShell: () {
        data.a.complete('A');
        Future<void>.delayed(const Duration(milliseconds: 20), () {
          data.inner!.complete('I');
        });
      },
    );
    final text = chunks.join();
    expect(chunks[0], contains('outer loading'));
    expect(chunks[1], contains('outer A'));
    // The inner place came with the first piece, filled by the second.
    expect(chunks[1], contains('<!--thor:2-->'));
    expect(chunks[1], contains('inner loading'));
    expect(chunks[2], contains('inner = I'));
    expect(chunks[2], contains('data-thor-end="2"'));
    expect(
      text.indexOf('data-thor-end="1"'),
      lessThan(text.indexOf('data-thor-end="2"')),
    );
  });

  test('without streaming the values are awaited: one complete page', () async {
    data.a.complete('A');
    data.b.complete('B');
    final r = await handler().handle(get('/shop'), stream: false);
    expect(r.stream, isNull);
    final html = r.text;
    expect(html, contains('a = A'));
    expect(html, contains('b = B'));
    expect(html, isNot(contains('loading')));
    expect(html, isNot(contains('<!--thor')));
    expect(html, isNot(contains(r'$thor')));
    expect(html, endsWith('</html>\n'));
  });

  test('without streaming, a nested value is awaited too', () async {
    data.inner = Completer<String>()..complete('I');
    data.a.complete('A');
    final r = await handler().handle(get('/nested'), stream: false);
    expect(r.text, contains('outer A'));
    expect(r.text, contains('inner = I'));
  });

  test('a page with cache: streams to the first visitor and keeps the '
      'finished page for the next', () async {
    final h = handler(cache: const Duration(minutes: 1));
    final first = await h.handle(get('/shop'));
    expect(first.stream, isNotNull);
    final chunks = await pieces(
      first,
      onShell: () {
        data.a.complete('A');
        data.b.complete('B');
      },
    );
    expect(chunks.first, contains('a loading'));
    await Future<void>.delayed(Duration.zero);
    final second = await h.handle(get('/shop'));
    expect(second.stream, isNull);
    expect(second.text, contains('a = A'));
    expect(second.text, contains('b = B'));
    // The stored copy is the page as a complete render makes it.
    final whole = await handler().handle(get('/shop'), stream: false);
    expect(second.text, whole.text);
    expect(errors, isEmpty);
  });

  group('a future that answers null, drawn as waiting (THOR-R033)', () {
    late List<String> lines;
    late void Function(String) oldSink;
    late bool oldEnabled;

    setUp(() {
      lines = [];
      oldSink = ThorDev.errorSink;
      oldEnabled = ThorDev.enabled;
      ThorDev.errorSink = lines.add;
    });
    tearDown(() {
      ThorDev.errorSink = oldSink;
      ThorDev.enabled = oldEnabled;
    });

    Future<String> late(String path, {bool stream = true}) async {
      final r = await handler().handle(get(path), stream: stream);
      if (!stream) return r.text;
      return (await pieces(r, onShell: () => data.maybe.complete(null))).join();
    }

    test('under thor dev the terminal says so, once, with the fix', () async {
      ThorDev.enabled = true;
      final html = await late('/maybe');
      // The visitor is left with the skeleton: that is the bug.
      expect(html, contains('skeleton'));
      expect(lines, hasLength(1));
      expect(lines.single, contains('THOR-R033'));
      expect(lines.single, contains('FutureBuilder<String?>'));
      expect(lines.single, contains('/maybe'));
      expect(lines.single, contains('ConnectionState.done'));
    });

    test('also when the page is drawn complete (cache, export)', () async {
      ThorDev.enabled = true;
      final done = handler().handle(get('/maybe'), stream: false);
      data.maybe.complete(null);
      final r = await done;
      expect(r.text, contains('skeleton'));
      expect(lines, hasLength(1));
      expect(lines.single, contains('THOR-R033'));
    });

    test('a builder that reads connectionState is not told anything', () async {
      ThorDev.enabled = true;
      final html = await late('/maybe-done');
      expect(html, contains('nothing'));
      expect(lines, isEmpty);
    });

    test('a value that is not null is not either', () async {
      ThorDev.enabled = true;
      final r = await handler().handle(get('/maybe'));
      final all = await pieces(r, onShell: () => data.maybe.complete('x'));
      expect(all.join(), contains('got x'));
      expect(lines, isEmpty);
    });

    test('a builder that throws for null breaks the same with and without '
        'the check, and the page still ends', () async {
      Future<String> run(bool dev) async {
        ThorDev.enabled = dev;
        data = _Data();
        final r = await handler().handle(get('/maybe-throws'));
        return (await pieces(
          r,
          onShell: () => data.maybe.complete(null),
        )).join();
      }

      final plain = await run(false);
      final checked = await run(true);
      expect(checked, plain);
      expect(checked, contains('</html>'));
    });

    test('a release says nothing', () async {
      ThorDev.enabled = false;
      await late('/maybe');
      expect(lines, isEmpty);
    });
  });

  test('a page with no deferred value is a whole response', () async {
    final h = RouteHandler<Widget>(
      renderer: WidgetRenderer(app: (page) => ThorApp(child: page)),
      routes: [
        PageRoute<Widget, void>(
          path: 'plain',
          load: (r) {},
          build: (s) => const Text('plain'),
        ),
      ],
    );
    final r = await h.handle(get('/plain'));
    expect(r.stream, isNull);
    expect(r.headers['etag'], isNotNull);
  });

  test('a state used only by late content: its values and the engine come '
      'with it', () async {
    final r = await handler().handle(get('/counter'));
    final chunks = await pieces(r, onShell: () => data.a.complete('A'));
    final shell = chunks.first;
    // The shell has no state and no engine.
    expect(shell, isNot(contains('type="application/json" id="thor-state"')));
    expect(shell, isNot(contains('data-thor-engine')));
    final late = chunks[1];
    expect(late, contains('data-tt="LateCounter.label"'));
    expect(late, contains('data-t-on="click:LateCounter.increment"'));
    expect(
      late,
      contains(
        '<script type="application/json" id="thor-s1">{"LateCounter.count":7}</script>',
      ),
    );
    expect(late, contains('data-thor-engine'));
    // Before the swap script, which reads them.
    expect(
      late.indexOf('id="thor-s1"'),
      lessThan(late.indexOf('data-thor-end="1"')),
    );
  });

  test('a streamed piece names the state field that is not JSON', () async {
    final r = await handler().handle(get('/bad-state'));
    final errorsSeen = <Object>[];
    final done = Completer<void>();
    r.stream!.listen(
      (_) {},
      onError: errorsSeen.add,
      onDone: done.complete,
      cancelOnError: false,
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    data.a.complete('A');
    await done.future;
    expect(errorsSeen, hasLength(1));
    expect(errorsSeen.single.toString(), contains('THOR-S041'));
  });

  test('the engine that comes late brings the prefetch loader with it, '
      'once', () async {
    final r = await handler().handle(get('/counter'));
    final chunks = await pieces(r, onShell: () => data.a.complete('A'));
    // The shell is a page with no engine: no script of the fallback.
    expect(chunks.first, isNot(contains('data-thor-prefetch')));
    expect(chunks[1], contains('data-thor-prefetch="/_thor/prefetch.'));
    expect('data-thor-prefetch='.allMatches(chunks.join()), hasLength(1));
    // An engine the shell has: its loader is in the head, not again.
    data = _Data();
    final twice = await handler().handle(get('/counter-twice'));
    final all = await pieces(twice, onShell: () => data.a.complete('A'));
    expect('data-thor-prefetch='.allMatches(all.join()), hasLength(1));
    expect(all.first, contains('data-thor-prefetch='));
  });

  test('a state the shell uses too is not sent again', () async {
    final r = await handler().handle(get('/counter-twice'));
    final chunks = await pieces(r, onShell: () => data.a.complete('A'));
    expect(chunks.first, contains('id="thor-state"'));
    expect(chunks.first, contains('data-thor-engine'));
    final late = chunks[1];
    expect(late, contains('data-tt="LateCounter.label"'));
    expect(late, isNot(contains('id="thor-s1"')));
    expect(late, isNot(contains('data-thor-engine')));
  });

  test(
    'a future that is done when the page is drawn: drawn done, no skeleton',
    () async {
      data.a.complete('A');
      final r = await handler().handle(get('/known'));
      data.b.complete('B');
      final chunks = await pieces(r);
      final shell = chunks.first;
      // `a` was done: in the shell. `b` was not: a place and a piece.
      expect(shell, contains('a = A'));
      expect(shell, isNot(contains('a loading')));
      expect('<!--thor:'.allMatches(shell), hasLength(1));
      expect(shell, contains('b loading'));
      expect(chunks.skip(1).join(), contains('b = B'));
    },
  );

  test('thor export awaits what the page defers and writes it whole', () async {
    data.a.complete('A');
    data.b.complete('B');
    final out = await Directory.systemTemp.createTemp('thor_defer_export');
    addTearDown(() => out.delete(recursive: true));
    final report = await exportSite(
      handler(),
      paths: ['/shop'],
      outDir: out.path,
    );
    expect(report.ok, isTrue);
    final html = File('${out.path}/shop.html').readAsStringSync();
    expect(html, contains('a = A'));
    expect(html, contains('b = B'));
    expect(html, isNot(contains('<!--thor')));
    expect(html, isNot(contains(r'$thor')));
  });
}
