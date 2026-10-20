@TestOn('vm')
library;

// A page that streamed 200 because an opt-in headBudget ran out carries
// `noindex`: a soft 404 stays out of indexes. In time: no tag.
import 'dart:async';
import 'dart:convert';

import 'package:test/test.dart';
import 'package:thor_ui/router.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

void main() {
  initializeThorTests();

  late Completer<String> name;

  RouteHandler<Widget> handler({String? robots, Duration? cache}) =>
      RouteHandler<Widget>(
        renderer: WidgetRenderer(app: (page) => ThorApp(child: page)),
        routes: [
          PageRoute<Widget, ({Future<String> v})>(
            path: 'p',
            cache: cache,
            load: (r) => (
              v: defer(
                name.future,
                head: true,
                headBudget: const Duration(milliseconds: 30),
              ),
            ),
            meta: (s) => PageMeta(
              title: resolvedValue(s.data.v) ?? 'Fallback',
              robotsMeta: robots == null ? null : RobotsMeta.parse(robots),
            ),
            build: (s) => FutureBuilder<String>(
              future: s.data.v,
              builder: (c, snap) => Text(snap.data ?? 'loading'),
            ),
          ),
        ],
      );

  PageRequest get() => PageRequest(
    method: HttpMethod.get,
    uri: Uri.parse('http://site.test/p'),
    headers: {HttpHeader.host: 'site.test'},
  );

  // The chunks up to the one that closes the `<head>`.
  Future<String> shell(ThorResponse r) async {
    if (r.stream == null) return utf8.decode(r.body);
    final all = StringBuffer();
    await for (final c in r.stream!) {
      all.write(utf8.decode(c));
      if (all.toString().contains('</head>')) break;
    }
    return all.toString();
  }

  setUp(() {
    name = Completer();
    name.future.ignore();
  });

  test('budget expired: the 200 head says noindex', () async {
    final r = await handler().handle(get());
    expect(r.status, 200);
    expect(await shell(r), contains('<meta name="robots" content="noindex"'));
  });

  test('value in time: no robots tag', () async {
    name.complete('Real');
    final r = await handler().handle(get());
    final html = await shell(r);
    expect(html, contains('<title>Real</title>'));
    expect(html, isNot(contains('name="robots"')));
  });

  test('the page already says noindex: not repeated, nofollow kept', () async {
    final r = await handler(robots: 'noindex, nofollow').handle(get());
    final html = await shell(r);
    expect('name="robots"'.allMatches(html), hasLength(1));
    expect(html, contains('noindex, nofollow'));
  });

  test('the page says index: the expired budget wins', () async {
    final r = await handler(robots: 'index, follow').handle(get());
    final html = await shell(r);
    expect('name="robots"'.allMatches(html), hasLength(1));
    expect(html, contains('noindex'));
    expect(html, isNot(contains('content="index')));
  });

  test('the cached copy is complete and carries no noindex', () async {
    Future<void>.delayed(
      const Duration(milliseconds: 100),
      () => name.complete('Real'),
    );
    final h = handler(cache: const Duration(minutes: 1));
    final first = await h.handle(get());
    final streamed = utf8.decode([
      for (final c in await first.stream!.toList()) ...c,
    ]);
    expect(streamed, contains('content="noindex"'));
    final second = await h.handle(get());
    final html = utf8.decode(second.body);
    expect(html, contains('<title>Real</title>'));
    expect(html, isNot(contains('name="robots"')));
  });

  group('RobotsMeta', () {
    test('writes its directives', () {
      expect(const RobotsMeta().content, 'index, follow');
      expect(RobotsMeta.noindex.content, 'noindex');
      expect(RobotsMeta.none.content, 'noindex, nofollow');
      expect(
        const RobotsMeta(index: true, follow: false, noArchive: true).content,
        'index, nofollow, noarchive',
      );
    });

    test('parse keeps what it does not know', () {
      final r = RobotsMeta.parse('noindex, max-snippet:50, nosnippet');
      expect(r.index, isFalse);
      expect(r.noSnippet, isTrue);
      expect(r.content, 'noindex, nosnippet, max-snippet:50');
      expect(RobotsMeta.parse('none').content, 'noindex, nofollow');
    });

    test('PageMeta: robotsMeta merges by level', () {
      const typed = PageMeta(robotsMeta: RobotsMeta.noindex);
      const other = PageMeta(robotsMeta: RobotsMeta());
      expect(typed.robotsContent, 'noindex');
      expect(other.robotsContent, 'index, follow');
      expect(typed.merge(other).robotsContent, 'index, follow');
      expect(other.merge(typed).robotsContent, 'noindex');
      expect(typed.merge(const PageMeta(title: 'x')).robotsContent, 'noindex');
    });

    test(
      'a page with robotsMeta writes the tag; the budget keeps nofollow',
      () async {
        final h = RouteHandler<Widget>(
          renderer: WidgetRenderer(app: (page) => ThorApp(child: page)),
          routes: [
            PageRoute<Widget, void>(
              path: 'p',
              meta: (s) => const PageMeta(robotsMeta: RobotsMeta.none),
              build: (s) => const Text('x'),
            ),
          ],
        );
        final r = await h.handle(get());
        expect(
          utf8.decode(r.body),
          contains('<meta name="robots" content="noindex, nofollow"'),
        );
      },
    );
  });
}
