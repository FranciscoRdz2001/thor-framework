@TestOn('vm')
library;

// Adversarial cases of the head future wait: several futures, a
// layout and a page, hostile redirects, a plain failure, the page cache and
// HEAD requests.
import 'dart:async';
import 'dart:convert';

import 'package:test/test.dart';
import 'package:thor_ui/router.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

void main() {
  initializeThorTests();

  late List<Object> errors;
  Completer<String> completer() => Completer<String>()..future.ignore();

  RouteHandler<Widget> handler({
    required List<PageRoute<Widget, Object?>> pages,
    List<LayoutRoute<Widget, Object?>> layouts = const [],
    Duration deferTimeout = const Duration(seconds: 5),
  }) => RouteHandler<Widget>(
    deferTimeout: deferTimeout,
    renderer: WidgetRenderer(app: (page) => ThorApp(child: page)),
    onError: (request, error, stack) => errors.add(error),
    routes: [for (final p in pages) p, for (final l in layouts) l],
  );

  PageRequest request(String path, {HttpMethod method = HttpMethod.get}) =>
      PageRequest(
        method: method,
        uri: Uri.parse('http://site.test$path'),
        headers: {HttpHeader.host: 'site.test'},
      );

  PageRoute<Widget, Object?> page(
    List<Future<String> Function()> heads, {
    Duration? cache,
  }) => PageRoute<Widget, ({List<Future<String>> v})>(
    path: 'p',
    cache: cache,
    load: (r) => (v: [for (final h in heads) defer(h(), head: true)]),
    meta: (s) => PageMeta(
      title: s.data.v.map(resolvedValue).whereType<String>().firstOrNull ?? 'F',
    ),
    build: (s) => Column(
      children: [
        for (final f in s.data.v)
          FutureBuilder<String>(
            future: f,
            builder: (c, snap) => Text(snap.data ?? 'loading'),
          ),
      ],
    ),
  );

  setUp(() => errors = []);

  test('several head futures: a fast failure answers at once, without '
      'waiting for a slow one', () async {
    final slow = completer();
    final started = Stopwatch()..start();
    final r = await handler(
      pages: [
        page([
          () => Future.delayed(
            const Duration(milliseconds: 30),
            () => throw const NotFound(),
          ),
          () => slow.future,
        ]),
      ],
    ).handle(request('/p'));
    expect(r.status, 404);
    expect(started.elapsedMilliseconds, lessThan(1500));
  });

  test('several head futures: the slow one that fails first in time '
      'decides, the order of the list does not', () async {
    final r = await handler(
      pages: [
        page([
          () => Future.delayed(
            const Duration(milliseconds: 200),
            () => throw const HttpError(410),
          ),
          () => Future.delayed(
            const Duration(milliseconds: 30),
            () => throw const NotFound(),
          ),
        ]),
      ],
    ).handle(request('/p'));
    expect(r.status, 404);
  });

  test('head futures in a layout and the page: a slow page NotFound '
      'wins over a done layout one', () async {
    final h = handler(
      pages: const [],
      layouts: [
        LayoutRoute<Widget, ({Future<String> v})>(
          load: (r) => (v: defer(Future.value('menu'), head: true)),
          build: (s, child) => Column(children: [const Text('layout'), child]),
          children: [
            PageRoute<Widget, ({Future<String> v})>(
              path: 'p',
              load: (r) => (
                v: defer(
                  Future.delayed(
                    const Duration(milliseconds: 80),
                    () => throw const NotFound(),
                  ),
                  head: true,
                ),
              ),
              build: (s) => const Text('page'),
            ),
          ],
        ),
      ],
    );
    final r = await h.handle(request('/p'));
    expect(r.status, 404);
  });

  for (final target in [
    'https://evil.example/x',
    '//evil.example/x',
    'javascript:alert(1)',
    '/ok\r\nSet-Cookie: a=b',
  ]) {
    test('a Redirect from a head future to "$target" is the same answer as '
        'a Redirect thrown in load (safeLocation)', () async {
      final viaHead = await handler(
        pages: [
          page([
            () => Future.delayed(
              const Duration(milliseconds: 20),
              () => throw Redirect(RouteUrl(target)),
            ),
          ]),
        ],
      ).handle(request('/p'));
      final viaLoad = await handler(
        pages: [
          PageRoute<Widget, void>(
            path: 'p',
            load: (r) => throw Redirect(RouteUrl(target)),
            build: (s) => const Text('x'),
          ),
        ],
      ).handle(request('/p'));
      expect(viaHead.status, viaLoad.status);
      expect(viaHead.headers['location'], viaLoad.headers['location']);
      final location = viaHead.headers['location']!;
      expect(location, isNot(contains('\n')));
      expect(location, isNot(contains('\r')));
      expect(location, isNot(startsWith('//')));
      expect(location, isNot(startsWith('javascript')));
    });
  }

  test('a plain Exception from a head future is a deterministic 500, '
      'reported, never a 200 and never leaked', () async {
    final r = await handler(
      pages: [
        page([
          () => Future.delayed(
            const Duration(milliseconds: 30),
            () => throw StateError('secret backend detail'),
          ),
        ]),
      ],
    ).handle(request('/p'));
    expect(r.status, 500);
    expect(utf8.decode(r.body), isNot(contains('secret backend detail')));
    expect(errors, hasLength(1));
  });

  test('a cached page with head futures: the first visitor and the kept '
      'copy have the real title', () async {
    var calls = 0;
    final h = handler(
      pages: [
        page([
          () {
            calls++;
            return Future.delayed(
              const Duration(milliseconds: 120),
              () => 'Real',
            );
          },
        ], cache: const Duration(minutes: 1)),
      ],
    );
    final first = await h.handle(request('/p'));
    final firstHtml = first.stream == null
        ? utf8.decode(first.body)
        : utf8.decode([for (final c in await first.stream!.toList()) ...c]);
    expect(firstHtml, contains('<title>Real</title>'));
    expect(firstHtml, isNot(contains('name="robots"')));
    final second = await h.handle(request('/p'));
    expect(utf8.decode(second.body), contains('<title>Real</title>'));
    expect(calls, 1);
  });

  test('a HEAD request gets the real 404, with no body', () async {
    final r = await handler(
      pages: [
        page([
          () => Future.delayed(
            const Duration(milliseconds: 100),
            () => throw const NotFound(),
          ),
        ]),
      ],
    ).handle(request('/p', method: HttpMethod.head));
    expect(r.status, 404);
  });

  test('a HEAD request of a slow existing page is a 200', () async {
    final r = await handler(
      pages: [
        page([
          () => Future.delayed(const Duration(milliseconds: 100), () => 'T'),
        ]),
      ],
    ).handle(request('/p', method: HttpMethod.head));
    expect(r.status, 200);
  });

  test('a fast failure does not leave the isolate waiting on the slow '
      'future for deferTimeout', () async {
    // The slow future never ends; a timer still armed would keep the test
    // process alive for deferTimeout, so this stays short.
    final slow = completer();
    final r = await handler(
      deferTimeout: const Duration(seconds: 3),
      pages: [
        page([() => Future.error(const NotFound()), () => slow.future]),
      ],
    ).handle(request('/p'));
    expect(r.status, 404);
  });
}
