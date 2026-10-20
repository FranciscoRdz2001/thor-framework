import 'dart:async';
import 'dart:convert';

import 'package:test/test.dart';
import 'package:thor_server/thor_server.dart';

/// A page is a string; `{{name}}` in it is a value that arrives later
/// (a completer of the test), sent after the document in the order they
/// complete. Stands for the widget renderer, which is tested in thor_ui.
class _Renderer implements PageRenderer<String>, DeferredRender, EarlyHints {
  _Renderer(this.late);

  final Map<String, Completer<String>> late;
  final contexts = <RenderContext>[];
  final _tails = Expando<Stream<List<int>>>();

  @override
  List<int> render(String page, RenderContext context) {
    contexts.add(context);
    final pending = [
      for (final m in RegExp(r'\{\{(\w+)\}\}').allMatches(page)) m[1]!,
    ];
    var shell = page;
    for (final name in pending) {
      shell = shell.replaceAll('{{$name}}', '<i>skeleton $name</i>');
    }
    if (!context.stream || pending.isEmpty) {
      return utf8.encode(
        '<!DOCTYPE html><html><body>${_settle(page)}</body></html>',
      );
    }
    final out = StreamController<List<int>>();
    var left = pending.length;
    for (final name in pending) {
      late[name]!.future
          .then(
            (v) => out.add(utf8.encode('<b id="$name">$v</b>')),
            onError: (Object e, StackTrace st) {
              context.reportDeferred?.call(e, st);
              out.add(utf8.encode('<b id="$name">failed</b>'));
            },
          )
          .whenComplete(() {
            if (--left == 0) {
              out.add(utf8.encode('</body></html>'));
              out.close();
            }
          });
    }
    _tails[context] = out.stream;
    return utf8.encode('<!DOCTYPE html><html><body>$shell');
  }

  // A complete document needs every value: only used when nothing streams.
  String _settle(String page) => page.replaceAllMapped(
    RegExp(r'\{\{(\w+)\}\}'),
    (m) => '<b id="${m[1]}">done</b>',
  );

  @override
  List<LinkHint> linksFor(
    PageRequest request,
    List<LayoutRoute<Object?, Object?>> layouts,
  ) => const [LinkHint.style('/_thor/base.css')];

  @override
  Stream<List<int>>? lateOf(RenderContext context) => _tails[context];

  @override
  String errorPage(ErrorState state) => 'error ${state.status}';
}

PageRequest _get(String path, {HttpMethod method = HttpMethod.get}) =>
    PageRequest(
      method: method,
      uri: Uri.parse('http://site.test$path'),
      headers: const {HttpHeader.host: 'site.test'},
    );

void main() {
  late Map<String, Completer<String>> late;
  late _Renderer renderer;
  late List<Object> errors;

  RouteHandler<String> handler({Duration? cache, Completer<void>? slowLoad}) =>
      RouteHandler<String>(
        renderer: renderer,
        earlyHintsAfter: const Duration(milliseconds: 10),
        onError: (request, error, stack) => errors.add(error),
        routes: [
          LayoutRoute<String, void>(
            build: (s, child) => child,
            earlyHints: true,
            children: [
              PageRoute<String, void>(
                path: 'early',
                load: (request) => slowLoad?.future,
                build: (s) => '<main>{{a}}</main>',
              ),
            ],
          ),
          PageRoute<String, void>(
            path: 'shop',
            load: (request) {},
            build: (s) => '<main>{{a}}{{b}}</main>',
            cache: cache,
          ),
          PageRoute<String, void>(
            path: 'plain',
            load: (request) {},
            build: (s) => '<main>nothing late</main>',
          ),
        ],
      );

  setUp(() {
    late = {'a': Completer(), 'b': Completer()};
    renderer = _Renderer(late);
    errors = [];
  });

  test(
    'the shell goes out before the values, then each as it arrives',
    () async {
      final r = await handler().handle(_get('/shop'));
      expect(r.status, 200);
      expect(r.stream, isNotNull);
      expect(r.headers['etag'], isNull);
      final chunks = <String>[];
      final done = r.stream!.listen((c) => chunks.add(utf8.decode(c)));
      addTearDown(done.cancel);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(chunks, hasLength(1));
      expect(chunks.single, contains('skeleton a'));
      expect(chunks.single, isNot(contains('</body>')));
      late['a']!.complete('A');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(chunks.last, '<b id="a">A</b>');
      late['b']!.complete('B');
      await done.asFuture<void>();
      expect(chunks.last, '</body></html>');
    },
  );

  test(
    'two values finishing in reverse order: sent in completion order',
    () async {
      final r = await handler().handle(_get('/shop'));
      final all = r.stream!.toList();
      late['b']!.complete('B');
      await Future<void>.delayed(Duration.zero);
      late['a']!.complete('A');
      final text = utf8.decode([for (final c in await all) ...c]);
      expect(text.indexOf('id="b"'), lessThan(text.indexOf('id="a"')));
    },
  );

  test('a failed value: reported, the response still ends', () async {
    final r = await handler().handle(_get('/shop'));
    final all = r.stream!.toList();
    late['a']!.completeError(StateError('backend down'));
    late['b']!.complete('B');
    final text = utf8.decode([for (final c in await all) ...c]);
    expect(text, contains('<b id="a">failed</b>'));
    expect(text, endsWith('</body></html>'));
    expect(errors.single, isA<StateError>());
  });

  test('a not-found of a late value is not a fault', () async {
    final r = await handler().handle(_get('/shop'));
    final all = r.stream!.toList();
    late['a']!.completeError(const NotFound());
    late['b']!.complete('B');
    await all;
    expect(errors, isEmpty);
  });

  test('the context says to stream, with the handler timeout', () async {
    final h = RouteHandler<String>(
      renderer: renderer,
      deferTimeout: const Duration(seconds: 3),
      routes: [
        PageRoute<String, void>(
          path: 'shop',
          load: (request) {},
          build: (s) => '{{a}}',
        ),
      ],
    );
    await h.handle(_get('/shop'));
    expect(renderer.contexts.single.stream, isTrue);
    expect(renderer.contexts.single.deferTimeout, const Duration(seconds: 3));
  });

  test(
    'a page with nothing late is one whole response with its ETag',
    () async {
      final r = await handler().handle(_get('/plain'));
      expect(r.stream, isNull);
      expect(r.headers['etag'], isNotNull);
    },
  );

  test('stream: false awaits the values: one complete response', () async {
    final r = await handler().handle(_get('/shop'), stream: false);
    expect(r.stream, isNull);
    expect(r.text, contains('<b id="a">done</b>'));
    expect(r.text, endsWith('</html>'));
    expect(renderer.contexts.single.stream, isFalse);
  });

  test('a page with cache: streams to the first visitor, and the cache keeps '
      'the complete page for the next', () async {
    final h = handler(cache: const Duration(minutes: 1));
    final first = await h.handle(_get('/shop'));
    expect(first.stream, isNotNull);
    expect(renderer.contexts.single.stream, isTrue);
    final chunks = <String>[];
    final done = Completer<void>();
    first.stream!.listen(
      (c) => chunks.add(utf8.decode(c)),
      onDone: done.complete,
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    // Nothing cached while the page is still waiting for its values.
    expect(h.cachedPaths, isEmpty);
    late['a']!.complete('A');
    late['b']!.complete('B');
    await done.future;
    await Future<void>.delayed(Duration.zero);
    expect(chunks.join(), contains('skeleton a'));
    expect(h.cachedPaths, hasLength(1));
    // The next visit gets the finished page, with no skeleton.
    final again = await h.handle(_get('/shop'));
    expect(again.stream, isNull);
    expect(again.text, contains('<b id="a">done</b>'));
    expect(again.text, isNot(contains('skeleton')));
    expect(again.headers['etag'], isNotNull);
    expect(renderer.contexts.map((c) => c.stream), [true, false]);
  });

  test('a first visitor that leaves caches nothing', () async {
    final h = handler(cache: const Duration(minutes: 1));
    final first = await h.handle(_get('/shop'));
    final sub = first.stream!.listen((_) {});
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await sub.cancel();
    late['a']!.complete('A');
    late['b']!.complete('B');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(h.cachedPaths, isEmpty);
  });

  test(
    'a failing deferred value reports once, not again for the cache',
    () async {
      final h = handler(cache: const Duration(minutes: 1));
      final first = await h.handle(_get('/shop'));
      final done = first.stream!.drain<void>();
      late['a']!.completeError(StateError('backend'));
      late['b']!.complete('B');
      await done;
      await Future<void>.delayed(Duration.zero);
      expect(errors, hasLength(1));
    },
  );

  test('a page whose deferred value failed is not kept in the cache', () async {
    final h = handler(cache: const Duration(minutes: 1));
    final first = await h.handle(_get('/shop'));
    final done = first.stream!.drain<void>();
    late['a']!.completeError(StateError('backend'));
    late['b']!.complete('B');
    await done;
    await Future<void>.delayed(Duration.zero);
    expect(h.cachedPaths, isEmpty);
  });

  test('two first visitors both stream; one complete page is kept', () async {
    final h = handler(cache: const Duration(minutes: 1));
    final one = await h.handle(_get('/shop'));
    final two = await h.handle(_get('/shop'));
    expect(one.stream, isNotNull);
    expect(two.stream, isNotNull);
    final both = Future.wait([
      one.stream!.drain<void>(),
      two.stream!.drain<void>(),
    ]);
    late['a']!.complete('A');
    late['b']!.complete('B');
    await both;
    await Future<void>.delayed(Duration.zero);
    expect(h.cachedPaths, hasLength(1));
    final again = await h.handle(_get('/shop'));
    expect(again.text, contains('<b id="a">done</b>'));
    expect(again.text, endsWith('</body></html>'));
  });

  test('another query string is kept apart', () async {
    final h = handler(cache: const Duration(minutes: 1));
    final one = await h.handle(_get('/shop?x=1'));
    final two = await h.handle(_get('/shop?x=2'));
    final both = Future.wait([
      one.stream!.drain<void>(),
      two.stream!.drain<void>(),
    ]);
    late['a']!.complete('A');
    late['b']!.complete('B');
    await both;
    await Future<void>.delayed(Duration.zero);
    expect(h.cachedPaths, hasLength(2));
  });

  test(
    'HEAD and a stale refresh are complete (nothing to stream to)',
    () async {
      // Stale means older than the TTL but younger than twice it: a wide
      // window, so a loaded machine still lands inside it.
      final h = handler(cache: const Duration(milliseconds: 200));
      final head = await h.handle(_get('/shop', method: HttpMethod.head));
      expect(head.stream, isNull);
      expect(h.cachedPaths, hasLength(1));
      await Future<void>.delayed(const Duration(milliseconds: 300));
      // Stale: served from the cache, rendered again complete behind it.
      final stale = await h.handle(_get('/shop'));
      expect(stale.stream, isNull);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(renderer.contexts.map((c) => c.stream), [false, false]);
      expect(h.cachedPaths, hasLength(1));
    },
  );

  test('HEAD is complete too', () async {
    final head = await handler().handle(_get('/shop', method: HttpMethod.head));
    expect(head.stream, isNull);
    expect(renderer.contexts.single.stream, isFalse);
  });

  test('the response says a proxy must not buffer it', () async {
    final r = await handler().handle(_get('/shop'));
    expect(r.headers['x-accel-buffering'], 'no');
    late['a']!.complete('A');
    late['b']!.complete('B');
    await r.stream!.drain<void>();
  });

  test(
    'an early answer and late values: the doctype, the page, the values',
    () async {
      final slow = Completer<void>();
      final r = await handler(slowLoad: slow).handle(_get('/early'));
      expect(r.stream, isNotNull);
      final chunks = <String>[];
      final done = Completer<void>();
      r.stream!.listen(
        (c) => chunks.add(utf8.decode(c)),
        onDone: done.complete,
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));
      // The slow load has not ended: only the doctype is out.
      expect(chunks, ['<!DOCTYPE html>']);
      slow.complete();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(chunks, hasLength(2));
      expect(chunks[1], startsWith('<html>'));
      expect(chunks[1], contains('skeleton a'));
      late['a']!.complete('A');
      await done.future;
      final text = chunks.join();
      expect('<!DOCTYPE'.allMatches(text), hasLength(1));
      expect(text, contains('<b id="a">A</b>'));
      expect(text, endsWith('</body></html>'));
    },
  );
}
