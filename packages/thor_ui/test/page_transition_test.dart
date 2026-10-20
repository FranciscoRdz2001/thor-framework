import 'package:test/test.dart';
import 'package:thor_ui/router.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

Future<String> _page(Widget child, {PageNavigation? navigation}) =>
    renderDocument(ThorApp(navigation: navigation, child: child));

RouteHandler<Widget> _handler(List<RouteNode<Widget>> routes) =>
    RouteHandler<Widget>(
      renderer: WidgetRenderer(
        app: (page) => ThorApp(
          navigation: const PageNavigation(transition: PageTransition.fade()),
          child: page,
        ),
      ),
      onError: (request, error, stack) {},
      routes: routes,
    );

Future<String> _get(RouteHandler<Widget> handler, String path) async {
  final r = await handler.handle(
    PageRequest(
      method: HttpMethod.get,
      uri: Uri.parse('http://site.test$path'),
      headers: {HttpHeader.host: 'site.test'},
    ),
  );
  return r.text;
}

const _optIn = '@view-transition{navigation:auto}';

void main() {
  setUpAll(initializeThorTests);

  group('PageTransition', () {
    test('fade without timing is the browser cross-fade, the old rule', () {
      expect(
        const PageTransition.fade().css,
        '@media (prefers-reduced-motion:no-preference) and (scripting:enabled)'
        '{@view-transition{navigation:auto}'
        '::view-transition{pointer-events:none}}',
      );
      expect(
        const PageNavigation(viewTransition: true).viewTransitionCss,
        const PageTransition.fade().css,
      );
    });

    test('with scripting off there is no transition (no frame would run)', () {
      for (final t in const [
        PageTransition.fade(),
        PageTransition.slide(),
        PageTransition.fadeUp(),
      ]) {
        expect(t.css, contains('and (scripting:enabled)'));
      }
    });

    test('no transition ever takes a click: its overlay lets it through', () {
      // A click during the animation must reach the new page (a fast
      // visitor, or a test suite navigating without JavaScript).
      for (final t in const [
        PageTransition.fade(),
        PageTransition.slide(),
        PageTransition.fadeUp(),
        PageTransition.fade(duration: Duration(milliseconds: 300)),
      ]) {
        expect(t.css, contains('::view-transition{pointer-events:none}'));
      }
    });

    test('every rule sits under prefers-reduced-motion: no-preference', () {
      for (final t in const [
        PageTransition.fade(duration: Duration(milliseconds: 150)),
        PageTransition.slide(),
        PageTransition.fadeUp(),
      ]) {
        final css = t.css!;
        expect(
          css,
          startsWith(
            '@media (prefers-reduced-motion:no-preference) and (scripting:enabled){',
          ),
        );
        expect(css, endsWith('}'));
        // One block: nothing escapes the media query.
        expect(
          '{'.allMatches(css).length,
          '}'.allMatches(css).length,
          reason: css,
        );
        expect(css, contains(_optIn));
      }
    });

    test('a duration and a curve time every group, heroes included', () {
      final css = const PageTransition.fade(
        duration: Duration(milliseconds: 150),
        curve: Curves.linear,
      ).css!;
      expect(
        css,
        contains(
          '::view-transition-group(*){animation-duration:150ms;'
          'animation-timing-function:linear}',
        ),
      );
    });

    test('slide and fadeUp animate the root snapshots, blend normal', () {
      final slide = const PageTransition.slide().css!;
      expect(slide, contains('@keyframes t-vt-slide-out'));
      expect(
        slide,
        contains('::view-transition-new(root){animation-name:t-vt-slide-in'),
      );
      final up = const PageTransition.fadeUp().css!;
      expect(up, contains('::view-transition-old(root){animation:none'));
      expect(up, contains('mix-blend-mode:normal'));
    });

    test('slide reverses on a back navigation (view-transition type back)', () {
      final slide = const PageTransition.slide().css!;
      // Reversed keyframes under the `back` type; forward stays the default.
      expect(slide, contains(':active-view-transition-type(back)'));
      expect(slide, contains('@keyframes t-vt-slide-out-back'));
      expect(slide, contains('@keyframes t-vt-slide-in-back'));
      expect(
        slide,
        contains(
          ':root:active-view-transition-type(back)::view-transition-old(root)'
          '{animation-name:t-vt-slide-out-back}',
        ),
      );
      // The others have no direction.
      expect(const PageTransition.fade().css, isNot(contains('back')));
      expect(const PageTransition.fadeUp().css, isNot(contains('-back')));
    });

    test('only slide needs the script that tags a back navigation', () {
      expect(const PageTransition.slide().script, contains('pagereveal'));
      expect(
        const PageTransition.slide().script,
        contains('types.add("back")'),
      );
      expect(const PageTransition.fade().script, isNull);
      expect(const PageTransition.fadeUp().script, isNull);
      expect(PageTransition.none.script, isNull);
    });

    test('none opts out: no rule at all', () {
      expect(PageTransition.none.css, isNull);
    });
  });

  group('on a page', () {
    test(
      'a slide page carries the pagereveal script, a fade page none',
      () async {
        final slide = await _page(
          const Text('a'),
          navigation: const PageNavigation(transition: PageTransition.slide()),
        );
        expect(headOfPage(slide), contains('pagereveal'));
        final fade = await _page(
          const Text('a'),
          navigation: const PageNavigation(transition: PageTransition.fade()),
        );
        expect(headOfPage(fade), isNot(contains('pagereveal')));
      },
    );

    test('no navigation, no transition', () async {
      expect(await _page(const Text('a')), isNot(contains('view-transition')));
    });

    test("the app's transition goes to the page's <style>", () async {
      final html = await _page(
        const Text('a'),
        navigation: const PageNavigation(transition: PageTransition.slide()),
      );
      expect(headOfPage(html), contains(const PageTransition.slide().css));
    });

    test('the nearest scope wins; none turns it off', () async {
      final html = await _page(
        const PageTransitionScope(
          transition: PageTransition.slide(),
          child: PageTransitionScope(
            transition: PageTransition.fadeUp(),
            child: Text('a'),
          ),
        ),
        navigation: const PageNavigation(viewTransition: true),
      );
      final head = headOfPage(html);
      expect(head, contains(const PageTransition.fadeUp().css));
      expect(head, isNot(contains('t-vt-slide')));
      final off = await _page(
        const PageTransitionScope(
          transition: PageTransition.none,
          child: Text('a'),
        ),
        navigation: const PageNavigation(viewTransition: true),
      );
      expect(off, isNot(contains('view-transition')));
    });

    test("a page's scope overrides its layout's and the app's", () async {
      // Per level, at runtime: a layout wraps its pages, a page wraps itself.
      final handler = _handler([
        LayoutRoute<Widget, void>(
          build: (state, child) => PageTransitionScope(
            transition: const PageTransition.fadeUp(),
            child: child,
          ),
          children: [
            PageRoute<Widget, void>(build: (state) => const Text('home')),
            PageRoute<Widget, void>(
              path: 'article',
              build: (state) => const PageTransitionScope(
                transition: PageTransition.slide(),
                child: Text('article'),
              ),
            ),
          ],
        ),
      ]);
      final home = headOfPage(await _get(handler, '/'));
      expect(home, contains(const PageTransition.fadeUp().css));
      final article = headOfPage(await _get(handler, '/article'));
      expect(article, contains(const PageTransition.slide().css));
      expect(article, isNot(contains('t-vt-fade-up')));
    });
  });

  test(
    'with shared styles, the base sheet never holds the transition',
    () async {
      final renderer = WidgetRenderer(
        app: (page) => ThorApp(
          theme: ThemeData(),
          navigation: const PageNavigation(transition: PageTransition.slide()),
          child: page,
        ),
        shareStyles: true,
        specimens: const [Text('specimen')],
      );
      final handler = RouteHandler<Widget>(
        renderer: renderer,
        onError: (request, error, stack) {},
        routes: [PageRoute<Widget, void>(build: (state) => const Text('a'))],
      );
      final html = await _get(handler, '/');
      expect(headOfPage(html), contains(const PageTransition.slide().css));
      final base = [
        for (final p in await renderer.assetPaths())
          if (p.startsWith('/_thor/base.')) p,
      ];
      expect(base, hasLength(1));
      final css = String.fromCharCodes(
        (await renderer.asset(base.single))!.body,
      );
      expect(css, isNot(contains('view-transition')));
    },
  );

  group('Hero', () {
    test('names its child element: no extra node, one class', () async {
      final html = bodyOfPage(
        await _page(
          const Hero(
            tag: 'article-1',
            child: Padding(padding: EdgeInsets.all(8), child: Text('Title')),
          ),
        ),
      );
      final page = await _page(
        const Hero(
          tag: 'article-1',
          child: Padding(padding: EdgeInsets.all(8), child: Text('Title')),
        ),
      );
      expect(
        page,
        contains(RegExp(r'style="view-transition-name:t-hero-article-1')),
      );
      // The Padding and the Text: no wrapper for the Hero.
      expect(
        RegExp(r'<(div|span)\b').allMatches(html).length,
        RegExp(r'<(div|span)\b')
            .allMatches(
              bodyOfPage(
                await _page(
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text('Title'),
                  ),
                ),
              ),
            )
            .length,
      );
    });

    test('a Padding around a Hero still merges into the text', () async {
      int elements(String html) =>
          RegExp(r'<(div|span|h1)\b').allMatches(bodyOfPage(html)).length;
      final plain = await _page(
        const Padding(padding: EdgeInsets.only(bottom: 3), child: Text('T')),
      );
      final hero = await _page(
        const Padding(
          padding: EdgeInsets.only(bottom: 3),
          child: Hero(tag: 't', child: Text('T')),
        ),
      );
      expect(elements(hero), elements(plain), reason: bodyOfPage(hero));
      expect(hero, contains('style="view-transition-name:t-hero-t"'));
    });

    test('two Heroes keep sharing their children\'s class', () async {
      const style = TextStyle(fontSize: 24, fontWeight: FontWeight.w600);
      final html = bodyOfPage(
        await _page(
          const Column(
            children: [
              Hero(
                tag: 'a',
                child: Text('x', style: style),
              ),
              Hero(
                tag: 'b',
                child: Text('y', style: style),
              ),
            ],
          ),
        ),
      );
      final classes = [
        for (final m in RegExp(
          r'<span class="([^"]+)"[^>]*style="view-transition-name',
        ).allMatches(html))
          m[1],
      ];
      expect(classes, hasLength(2), reason: html);
      expect(classes.toSet(), hasLength(1));
    });

    test('names are escaped and never shared by two tags', () {
      expect(Hero.nameFor('a-1'), 't-hero-a-1');
      expect(Hero.nameFor('a b'), 't-hero-a_0020b');
      expect(Hero.nameFor('a_0020b'), 't-hero-a_005f0020b');
      expect(Hero.nameFor('ñ/"}'), 't-hero-_00f1_002f_0022_007d');
      expect(Hero.nameFor(42), 't-hero-42');
    });

    test('two Heroes with one tag on a page are THOR-R019', () async {
      await expectLater(
        _page(
          const Column(
            children: [
              Hero(tag: 'x', child: Text('a')),
              Hero(tag: 'x', child: Text('b')),
            ],
          ),
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('THOR-R019'),
          ),
        ),
      );
    });

    test('the same tag on two pages is fine (one per page)', () async {
      for (var i = 0; i < 2; i++) {
        final html = await _page(const Hero(tag: 'x', child: Text('a')));
        expect(html, contains(RegExp(r'style="view-transition-name:t-hero-x')));
      }
    });

    test('inside Cached: replayed with its name, still checked', () async {
      const hero = Cached(
        cacheKey: 'hero-card',
        child: Hero(tag: 'card', child: Text('a')),
      );
      final first = await _page(const Column(children: [hero]));
      final replayed = await _page(const Column(children: [hero]));
      for (final html in [first, replayed]) {
        expect(
          html,
          contains(RegExp(r'style="view-transition-name:t-hero-card')),
        );
      }
      await expectLater(
        _page(
          const Column(
            children: [
              Hero(tag: 'card', child: Text('b')),
              hero,
            ],
          ),
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('THOR-R019'),
          ),
        ),
      );
    });
  });
}
