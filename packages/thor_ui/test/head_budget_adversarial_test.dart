@TestOn('vm')
library;

// Adversarial cases of the head budget: a page that must be
// complete, shared caches, and the cost of the bot check.
import 'dart:async';
import 'dart:convert';

import 'package:test/test.dart';
import 'package:thor_ui/router.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

void main() {
  initializeThorTests();

  late Completer<String> name;

  RouteHandler<Widget> handler({
    bool head = true,
    Duration? cache,
    Duration? budget = const Duration(milliseconds: 30),
  }) => RouteHandler<Widget>(
    renderer: WidgetRenderer(app: (page) => ThorApp(child: page)),
    routes: [
      PageRoute<Widget, ({Future<String> v})>(
        path: 'p',
        cache: cache,
        load: (r) => (v: defer(name.future, head: head, headBudget: budget)),
        meta: (s) => PageMeta(title: resolvedValue(s.data.v) ?? 'Fallback'),
        build: (s) => FutureBuilder<String>(
          future: s.data.v,
          builder: (c, snap) => Text(snap.data ?? 'loading'),
        ),
      ),
    ],
  );

  PageRequest get({String? agent}) => PageRequest(
    method: HttpMethod.get,
    uri: Uri.parse('http://site.test/p'),
    headers: {HttpHeader.host: 'site.test', HttpHeader.userAgent: ?agent},
  );

  setUp(() {
    name = Completer();
    name.future.ignore();
  });

  test('a complete page (cache, export) waits for the head future, not '
      'the budget: no fallback title in a kept page', () async {
    Future<void>.delayed(
      const Duration(milliseconds: 150),
      () => name.complete('Real'),
    );
    final r = await handler().handle(get(), stream: false);
    expect(utf8.decode(r.body), contains('<title>Real</title>'));
  });

  test('a page cached by route: the title is the real one', () async {
    Future<void>.delayed(
      const Duration(milliseconds: 150),
      () => name.complete('Real'),
    );
    final h = handler(cache: const Duration(minutes: 1));
    // The first visitor of a cache miss is streamed; the copy the cache keeps
    // for the next visitors is drawn complete, with the real title.
    final first = await h.handle(get());
    await first.stream?.drain<void>();
    final second = await h.handle(get());
    expect(second.stream, isNull);
    expect(utf8.decode(second.body), contains('<title>Real</title>'));
  });

  test('a page whose head depends on the User-Agent says Vary', () async {
    name.complete('Real');
    final r = await handler().handle(get());
    expect(r.headers['vary'], contains('User-Agent'));
  });

  test('a head future with no budget does not vary by User-Agent', () async {
    name.complete('Real');
    final r = await handler(budget: null).handle(get());
    expect(r.headers['vary'] ?? '', isNot(contains('User-Agent')));
  });

  test('a budget as long as the bot budget does not vary either', () async {
    name.complete('Real');
    final h = RouteHandler<Widget>(
      headBotBudget: const Duration(milliseconds: 30),
      renderer: WidgetRenderer(app: (page) => ThorApp(child: page)),
      routes: [
        PageRoute<Widget, ({Future<String> v})>(
          path: 'p',
          load: (r) => (
            v: defer(
              name.future,
              head: true,
              headBudget: const Duration(milliseconds: 30),
            ),
          ),
          build: (s) => const Text('x'),
        ),
      ],
    );
    final r = await h.handle(get());
    expect(r.headers['vary'] ?? '', isNot(contains('User-Agent')));
  });

  test('a page with no head future does not vary by User-Agent', () async {
    name.complete('Real');
    final r = await handler(head: false).handle(get());
    expect(r.headers['vary'] ?? '', isNot(contains('User-Agent')));
  });

  test('the bot check is cheap on a hostile User-Agent', () async {
    name.complete('Real');
    final h = handler();
    final started = Stopwatch()..start();
    for (final agent in ['a' * 8000, 'a-' * 4000, 'Google-${'-' * 8000}']) {
      await h.handle(get(agent: agent));
    }
    expect(started.elapsedMilliseconds, lessThan(500));
  });
}
