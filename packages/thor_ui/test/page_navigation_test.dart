import 'dart:convert';

import 'package:test/test.dart';
import 'package:thor_ui/router.dart';
import 'package:thor_ui/src/engine/form_script.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

/// The parsed `<script type="speculationrules">` of [html], or `null`.
Map<String, Object?>? _rules(String html) {
  final m = RegExp(
    r'<script type="speculationrules">(.*?)</script>',
    dotAll: true,
  ).allMatches(html).toList();
  if (m.isEmpty) return null;
  expect(m, hasLength(1), reason: 'one rule set per page');
  return jsonDecode(m.single[1]!) as Map<String, Object?>;
}

/// The `where` of the only rule of [action] (`prefetch`/`prerender`).
Map<String, Object?> _where(Map<String, Object?> rules, String action) {
  final list = rules[action]! as List<Object?>;
  expect(list, hasLength(1));
  final rule = list.single! as Map<String, Object?>;
  expect(rule['source'], 'document');
  return rule['where']! as Map<String, Object?>;
}

/// The attributes of every `<script>` of [html], minus the debug-only
/// inspector (tests run in debug mode; release never emits it).
List<String> _scripts(String html) => [
  for (final m in RegExp(r'<script([^>]*)>').allMatches(html))
    if (!m[1]!.contains('thor-debug-inspector')) m[1]!,
];

/// A page that ships the engine without any state of its own.
class _WithEngine extends StatelessWidget {
  const _WithEngine(this.child);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    ThorStyleRegistry.active(context)?.useEngine();
    return child;
  }
}

class _Links extends StatelessWidget implements ThorElementWidget {
  const _Links();

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const Link(href: RouteUrl('/about'), child: Text('about')),
      const Link(
        href: RouteUrl('/heavy'),
        prefetch: false,
        child: Text('heavy'),
      ),
      const Link(
        href: RouteUrl('https://other.test/'),
        newTab: true,
        child: Text('x'),
      ),
      Form(
        // The string form still works (deprecated path).
        // ignore: thor_lints/untyped_form_action
        action: '?/logout',
        child: FilledButton(
          onPressed: () {},
          buttonType: ButtonType.submit,
          child: const Text('Log out'),
        ),
      ),
    ],
  );
}

RouteHandler<Widget> _handler(Widget Function(Widget page) app) =>
    RouteHandler<Widget>(
      renderer: WidgetRenderer(app: app),
      onError: (request, error, stack) {},
      routes: [
        PageRoute<Widget, void>(
          build: (state) => const _Links(),
          actions: {'logout': (r) => null},
        ),
      ],
    );

Future<String> _get(RouteHandler<Widget> handler, [String path = '/']) async {
  final r = await handler.handle(
    PageRequest(
      method: HttpMethod.get,
      uri: Uri.parse('http://site.test$path'),
      headers: {HttpHeader.host: 'site.test'},
    ),
  );
  return r.text;
}

void main() {
  setUpAll(initializeThorTests);

  group('routed app (WidgetRenderer)', () {
    test('prefetches same-origin links on hover by default', () async {
      final html = await _get(_handler((page) => ThorApp(child: page)));
      final rules = _rules(html)!;
      expect(rules.keys, ['prefetch'], reason: 'no prerender unless asked');
      final rule = (rules['prefetch']! as List).single as Map;
      expect(rule['eagerness'], 'moderate');
      // In the head, before any link it governs.
      expect(
        html.indexOf('type="speculationrules"'),
        lessThan(html.indexOf('</head>')),
      );
    });

    test('only same-origin links, never the excluded kinds', () async {
      final where = _where(
        _rules(await _get(_handler((page) => ThorApp(child: page))))!,
        'prefetch',
      );
      final and = where['and']! as List<Object?>;
      // `/*` resolves against the page: another origin never matches.
      expect(and.first, {'href_matches': '/*'});
      final selector =
          ((and[1]! as Map)['not'] as Map)['selector_matches'] as String;
      for (final excluded in [
        '[data-no-prefetch]',
        '[rel~=nofollow]',
        '[download]',
        '[target]:not([target=_self])',
      ]) {
        expect(selector, contains(excluded));
      }
      // No exclude patterns: no empty `href_matches` list (which Chrome
      // rejects, dropping the whole rule set).
      expect(and, hasLength(2));
    });

    test(
      'a page without state ships no engine, only its form script',
      () async {
        final html = await _get(_handler((page) => ThorApp(child: page)));
        // The page has a posting Form: the one inline script is the form's
        // «sending» state (no engine, no other script).
        expect(_scripts(html), [
          ' type="speculationrules"',
          // No loader for the prefetch fallback: a page without the engine
          // carries no script of its own (the form's is the only one).
          '',
        ]);
        expect(html, contains(formScript));
        expect(html, isNot(contains('data-thor-engine')));
        expect(html, isNot(contains('data-thor-prefetch')));
      },
    );

    test('forms (actions) are untouched: only <a> links speculate', () async {
      final html = await _get(_handler((page) => ThorApp(child: page)));
      final form = RegExp(r'<form[^>]*>').firstMatch(html)![0]!;
      expect(form, contains('method="post"'));
      expect(form, isNot(contains('prefetch')));
      // Document rules match links (`<a href>`/`<area href>`), never a
      // form's action: the rules name no `?/` action URL either.
      expect(_rules(html).toString(), isNot(contains('?/')));
    });

    test('Link(prefetch: false) opts one link out', () async {
      final html = await _get(_handler((page) => ThorApp(child: page)));
      expect(
        html,
        matches(RegExp(r'<a[^>]*href="/heavy"[^>]*data-no-prefetch')),
      );
      expect(
        RegExp(r'<a[^>]*href="/about"[^>]*>').firstMatch(html)![0],
        isNot(contains('data-no-prefetch')),
      );
      // A new-tab link is left out by its target, not by a mark.
      expect(
        RegExp(r'<a[^>]*href="https://other.test/"[^>]*>').firstMatch(html)![0],
        allOf(contains('target="_blank"'), isNot(contains('no-prefetch'))),
      );
    });

    test('PageNavigation.none opts the whole app out', () async {
      final html = await _get(
        _handler(
          (page) => ThorApp(navigation: PageNavigation.none, child: page),
        ),
      );
      expect(html, isNot(contains('speculationrules')));
      expect(html, isNot(contains('view-transition')));
    });

    test('exclude patterns become a negated href_matches', () async {
      final html = await _get(
        _handler(
          (page) => ThorApp(
            navigation: const PageNavigation(exclude: ['/logout', '/admin/*']),
            child: page,
          ),
        ),
      );
      final and = _where(_rules(html)!, 'prefetch')['and']! as List;
      expect(and.last, {
        'not': {
          'href_matches': ['/logout', '/admin/*'],
        },
      });
    });

    test('a pattern cannot close the script element', () async {
      const evil = '/x</script><script>alert(1)</script><!--';
      final html = await _get(
        _handler(
          (page) => ThorApp(
            navigation: const PageNavigation(exclude: [evil]),
            child: page,
          ),
        ),
      );
      expect(html, isNot(contains('alert(1)</script>')));
      expect(html, isNot(contains('<!--')));
      // Still valid JSON that round-trips to the same pattern.
      final and = _where(_rules(html)!, 'prefetch')['and']! as List;
      expect(((and.last as Map)['not'] as Map)['href_matches'], [evil]);
    });

    test('prerender and prefetch with their own eagerness', () async {
      final html = await _get(
        _handler(
          (page) => ThorApp(
            navigation: const PageNavigation(
              prefetch: SpeculationEagerness.eager,
              prerender: SpeculationEagerness.conservative,
            ),
            child: page,
          ),
        ),
      );
      final rules = _rules(html)!;
      expect(
        ((rules['prefetch']! as List).single as Map)['eagerness'],
        'eager',
      );
      expect(
        ((rules['prerender']! as List).single as Map)['eagerness'],
        'conservative',
      );
    });

    test('prerender only (no prefetch) still emits its rule', () async {
      final html = await _get(
        _handler(
          (page) => ThorApp(
            navigation: const PageNavigation(
              prefetch: null,
              prerender: SpeculationEagerness.moderate,
            ),
            child: page,
          ),
        ),
      );
      expect(_rules(html)!.keys, ['prerender']);
    });

    test('view transitions: opt-in, skipped under reduced motion', () async {
      final off = await _get(_handler((page) => ThorApp(child: page)));
      expect(off, isNot(contains('view-transition')));
      final on = await _get(
        _handler(
          (page) => ThorApp(
            navigation: const PageNavigation(viewTransition: true),
            child: page,
          ),
        ),
      );
      final style = headOfPage(on);
      expect(
        style,
        contains(
          '@media (prefers-reduced-motion:no-preference) and (scripting:enabled)'
          '{@view-transition{navigation:auto}'
          '::view-transition{pointer-events:none}}',
        ),
      );
    });

    test('error pages keep the rules (the layout links still work)', () async {
      final html = await _get(
        _handler((page) => ThorApp(child: page)),
        '/missing',
      );
      expect(_rules(html), isNotNull);
    });
  });

  group('single-document app (no routes)', () {
    test('emits nothing by default', () async {
      final html = await renderDocument(
        const ThorApp(
          child: Link(href: RouteUrl('/other'), child: Text('other')),
        ),
      );
      expect(html, isNot(contains('speculationrules')));
      expect(_scripts(html), isEmpty);
    });

    test('opts in with an explicit PageNavigation', () async {
      final html = await renderDocument(
        const ThorApp(
          navigation: PageNavigation(
            prefetch: SpeculationEagerness.conservative,
          ),
          child: Link(href: RouteUrl('/other'), child: Text('other')),
        ),
      );
      expect(
        ((_rules(html)!['prefetch']! as List).single as Map)['eagerness'],
        'conservative',
      );
    });

    test('without extracted styles there is no head to put rules in', () async {
      final html = await renderDocument(
        const ThorApp(
          extractStyles: false,
          navigation: PageNavigation(),
          child: Text('x'),
        ),
      );
      expect(html, isNot(contains('speculationrules')));
    });
  });

  test('PageNavigation equality includes the exclude list', () {
    expect(
      const PageNavigation(exclude: ['/a']),
      const PageNavigation(exclude: ['/a']),
    );
    expect(
      const PageNavigation(exclude: ['/a']),
      isNot(const PageNavigation(exclude: ['/b'])),
    );
    expect(PageNavigation.none.speculationRules, isNull);
    expect(PageNavigation.none.viewTransitionCss, isNull);
  });

  group('rules in a header (strict CSP)', () {
    const nav = PageNavigation(delivery: SpeculationDelivery.header);

    Future<(String, Map<String, String>)> get(
      WidgetRenderer renderer, {
      bool prefetch = true,
    }) async {
      final handler = RouteHandler<Widget>(
        renderer: renderer,
        onError: (request, error, stack) {},
        routes: [
          PageRoute<Widget, void>(
            build: (state) => const _Links(),
            prefetch: prefetch,
          ),
        ],
      );
      final r = await handler.handle(
        PageRequest(
          method: HttpMethod.get,
          uri: Uri.parse('http://site.test/'),
          headers: {HttpHeader.host: 'site.test'},
        ),
      );
      return (r.text, r.headers);
    }

    test(
      'the page has no inline script; the header names a JSON file',
      () async {
        final renderer = WidgetRenderer.router(
          ThorApp.router(routerConfig: ThorRouter(const []), navigation: nav),
        );
        final (html, headers) = await get(renderer);
        expect(html, isNot(contains('speculationrules')));
        final path = RegExp(
          r'^"(/_thor/speculation\.[^"]+\.json)"$',
        ).firstMatch(headers['speculation-rules'] ?? '')?[1];
        expect(path, isNotNull);
        final asset = await renderer.asset(path!);
        expect(asset!.contentType, 'application/speculationrules+json');
        final rules =
            jsonDecode(utf8.decode(asset.body)) as Map<String, Object?>;
        expect(_where(rules, 'prefetch'), isNotEmpty);
        expect(await renderer.asset('/_thor/speculation.other.json'), isNull);
      },
    );

    test('a route with prefetch: false has no header', () async {
      final renderer = WidgetRenderer.router(
        ThorApp.router(routerConfig: ThorRouter(const []), navigation: nav),
      );
      final (html, headers) = await get(renderer, prefetch: false);
      expect(headers.containsKey('speculation-rules'), isFalse);
      expect(html, isNot(contains('speculationrules')));
    });

    test('inline rules: a route with prefetch: false has no script', () async {
      final (html, _) = await get(
        WidgetRenderer(app: (page) => ThorApp(child: page)),
        prefetch: false,
      );
      expect(html, isNot(contains('speculationrules')));
      final (withRules, _) = await get(
        WidgetRenderer(app: (page) => ThorApp(child: page)),
      );
      expect(_rules(withRules), isNotNull);
    });

    test(
      'the file is named by its content: other rules, another URL',
      () async {
        Future<String?> href(PageNavigation n) async {
          final renderer = WidgetRenderer.router(
            ThorApp.router(routerConfig: ThorRouter(const []), navigation: n),
          );
          final (_, headers) = await get(renderer);
          return headers['speculation-rules'];
        }

        final a = await href(
          const PageNavigation(delivery: SpeculationDelivery.header),
        );
        final b = await href(
          const PageNavigation(
            delivery: SpeculationDelivery.header,
            exclude: ['/admin/*'],
          ),
        );
        final again = await href(
          const PageNavigation(delivery: SpeculationDelivery.header),
        );
        expect(a, isNotNull);
        expect(a, isNot(b));
        expect(a, again);
      },
    );

    test(
      'a layout with prefetch: false leaves its pages without rules',
      () async {
        for (final delivery in SpeculationDelivery.values) {
          final renderer = WidgetRenderer.router(
            ThorApp.router(
              routerConfig: ThorRouter(const []),
              navigation: PageNavigation(delivery: delivery),
            ),
          );
          final handler = RouteHandler<Widget>(
            renderer: renderer,
            onError: (request, error, stack) {},
            routes: [
              routeLayout<void>(
                path: 'admin',
                prefetch: false,
                children: [
                  routePage<void>(path: 'x', build: (c, s) => const _Links()),
                ],
              ),
              routePage<void>(path: 'open', build: (c, s) => const _Links()),
            ],
          );
          Future<(String, Map<String, String>)> at(String path) async {
            final r = await handler.handle(
              PageRequest(
                method: HttpMethod.get,
                uri: Uri.parse('http://site.test$path'),
                headers: {HttpHeader.host: 'site.test'},
              ),
            );
            return (r.text, r.headers);
          }

          final (quiet, quietHeaders) = await at('/admin/x');
          expect(
            quiet,
            isNot(contains('speculationrules')),
            reason: '$delivery',
          );
          expect(quietHeaders.containsKey('speculation-rules'), isFalse);
          final (open, openHeaders) = await at('/open');
          expect(
            open.contains('speculationrules') ||
                openHeaders.containsKey('speculation-rules'),
            isTrue,
            reason: '$delivery',
          );
        }
      },
    );
  });

  group('prefetch fallback (no Speculation Rules)', () {
    final src = RegExp(r'data-thor-prefetch="(/_thor/prefetch\.[^"]+\.js)"');

    Future<String> page(
      WidgetRenderer renderer, {
      bool prefetch = true,
      bool engine = true,
    }) async {
      final handler = RouteHandler<Widget>(
        renderer: renderer,
        onError: (request, error, stack) {},
        routes: [
          PageRoute<Widget, void>(
            build: (state) =>
                engine ? const _WithEngine(_Links()) : const _Links(),
            prefetch: prefetch,
          ),
        ],
      );
      final r = await handler.handle(
        PageRequest(
          method: HttpMethod.get,
          uri: Uri.parse('http://site.test/'),
          headers: {HttpHeader.host: 'site.test'},
        ),
      );
      return r.text;
    }

    WidgetRenderer routed(PageNavigation nav) => WidgetRenderer.router(
      ThorApp.router(routerConfig: ThorRouter(const []), navigation: nav),
    );

    test('only a page that ships the engine carries the loader', () async {
      Future<bool> has(PageNavigation nav, {required bool engine}) async =>
          src.hasMatch(await page(routed(nav), engine: engine));
      // The default: a page without the engine stays script-free, an engine page
      // pays the 241 B test.
      expect(await has(const PageNavigation(), engine: false), isFalse);
      expect(await has(const PageNavigation(), engine: true), isTrue);
      // Explicit opt-in: also the page with no engine.
      expect(
        await has(const PageNavigation(prefetchFallback: true), engine: false),
        isTrue,
      );
      // Explicit opt-out: not even the engine page.
      expect(
        await has(const PageNavigation(prefetchFallback: false), engine: true),
        isFalse,
      );
      // The file is served whichever page asks for it.
      final renderer = routed(const PageNavigation());
      final path = src.firstMatch(await page(renderer))![1]!;
      expect(await renderer.asset(path), isNotNull);
    });

    test('a tiny inline test loads the file only without the rules', () async {
      final html = await page(routed(const PageNavigation()));
      expect(src.hasMatch(html), isTrue);
      final stub = RegExp(
        r'<script data-thor-prefetch[^>]*>(.*?)</script>',
        dotAll: true,
      ).firstMatch(html)![1]!;
      expect(stub, contains('HTMLScriptElement.supports("speculationrules")'));
      // After load: never in the way of the first paint.
      expect(stub, contains('"load"'));
      // The behavior is in the file, not in every page.
      expect(stub, isNot(contains('pointerover')));
      expect(stub.length, lessThan(250), reason: 'the per-page cost');
    });

    test('the file: hover and focus, Save-Data, a few in flight', () async {
      final renderer = routed(const PageNavigation(exclude: ['/admin/*']));
      final path = src.firstMatch(await page(renderer))![1]!;
      final asset = await renderer.asset(path);
      expect(asset!.contentType, startsWith('text/javascript'));
      final js = utf8.decode(asset.body);
      expect(js, contains('rel="prefetch"'));
      // A link element leaves the head once it loaded or failed (the visited
      // set is in memory): the head does not grow with every hovered link.
      expect(js, contains('l.onload=l.onerror=()=>{f();l.remove()}'));
      for (final event in ['pointerover', 'focusin', 'pointerdown']) {
        expect(js, contains('"$event"'));
      }
      expect(js, contains('saveData'));
      expect(js, contains('prefers-reduced-data'));
      // The same links the rules leave out.
      expect(js, contains('[data-no-prefetch],[rel~=nofollow],[download]'));
      expect(js, contains('[target]:not([target=_self])'));
      // The exclude patterns, as regular expressions of the path.
      expect(js, contains(r'^\/admin\/.*$'));
      // Never an action URL.
      expect(js, contains('"?/"'));
      expect(js.length, lessThan(2200));
      expect(await renderer.asset('/_thor/prefetch.other.js'), isNull);
    });

    test('moderate waits on hover, conservative only presses', () async {
      Future<String> js(SpeculationEagerness e) async {
        final renderer = routed(PageNavigation(prefetch: e));
        final path = src.firstMatch(await page(renderer))![1]!;
        return utf8.decode((await renderer.asset(path))!.body);
      }

      final moderate = await js(SpeculationEagerness.moderate);
      final conservative = await js(SpeculationEagerness.conservative);
      expect(moderate, contains('"pointerover"'));
      expect(conservative, isNot(contains('"pointerover"')));
      expect(conservative, isNot(contains('"focusin"')));
      expect(conservative, contains('"pointerdown"'));
      expect(moderate, isNot(conservative));
    });

    test('named by its content: other settings, another file', () async {
      Future<String?> at(PageNavigation n) async =>
          src.firstMatch(await page(routed(n)))?[1];
      final a = await at(const PageNavigation());
      expect(a, await at(const PageNavigation()));
      expect(a, isNot(await at(const PageNavigation(exclude: ['/x']))));
    });

    test('no stub when nothing prefetches or the page opted out', () async {
      Future<bool> has(WidgetRenderer r, {bool prefetch = true}) async =>
          src.hasMatch(await page(r, prefetch: prefetch));
      expect(await has(routed(const PageNavigation())), isTrue);
      expect(
        await has(routed(const PageNavigation()), prefetch: false),
        isFalse,
        reason: 'PageRoute(prefetch: false)',
      );
      expect(await has(routed(PageNavigation.none)), isFalse);
      expect(
        await has(routed(const PageNavigation(prefetchFallback: false))),
        isFalse,
      );
      expect(
        await has(
          routed(const PageNavigation(prefetchFallback: true)),
          prefetch: false,
        ),
        isFalse,
        reason: 'opt-in does not bring it back to a page that opted out',
      );
      expect(
        await has(
          routed(const PageNavigation(delivery: SpeculationDelivery.header)),
        ),
        isFalse,
        reason: 'a strict CSP has no inline script',
      );
      // Not a routed app: nothing serves the file.
      final html = await renderDocument(
        const ThorApp(navigation: PageNavigation(), child: Text('x')),
      );
      expect(src.hasMatch(html), isFalse);
    });

    test('a static export writes the file next to the pages', () async {
      final renderer = routed(const PageNavigation());
      final path = src.firstMatch(await page(renderer))![1]!;
      expect(await renderer.assetPaths(), contains(path));
      expect(
        await routed(PageNavigation.none).assetPaths(),
        isNot(contains(path)),
      );
    });
  });
}
