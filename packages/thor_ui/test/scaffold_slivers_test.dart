@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

Future<String> page(Widget body, {Locale? locale}) =>
    renderDocument(ThorApp(child: body));

String bodyOf(String html) => html.substring(html.indexOf('<body'));

String stylesOf(String html) =>
    html.substring(html.indexOf('@layer thor.props'), html.indexOf('</style>'));

String ruleOf(String html, String name) {
  final cls = RegExp(
    'class="(t\\w+)"[^>]*data-thor="$name"',
  ).firstMatch(bodyOf(html))![1]!;
  final css = stylesOf(html);
  final start = css.indexOf('.$cls{');
  return css.substring(start, css.indexOf('}', start) + 1);
}

void main() {
  group('Scaffold skip link', () {
    test('is the first stop and points at the main landmark', () async {
      final html = bodyOf(
        await page(
          const Scaffold(
            appBar: AppBar(title: Text('A')),
            body: Text('x'),
          ),
        ),
      );
      expect(
        html.indexOf('data-thor="SkipLink"'),
        lessThan(html.indexOf('<header')),
      );
      expect(html, contains('href="#main-content"'));
      expect(html, contains('<main'));
      expect(html, contains('id="main-content"'));
      expect(html, contains('Skip to content'));
    });

    test('skipLink: false leaves it out; the label can be given', () async {
      final off = bodyOf(
        await page(const Scaffold(skipLink: false, body: Text('x'))),
      );
      expect(off, isNot(contains('SkipLink')));
      expect(off, isNot(contains('id="main-content"')));
      final custom = bodyOf(
        await page(const Scaffold(skipLinkLabel: 'Jump', body: Text('x'))),
      );
      expect(custom, contains('Jump'));
    });

    test('the texts are localized', () {
      expect(const ThorLocalizationsEs().skipToContent, 'Saltar al contenido');
      expect(const ThorLocalizationsEn().skipToContent, 'Skip to content');
    });

    test('a nested Scaffold and a page with a link add none', () async {
      final nested = bodyOf(
        await page(const Scaffold(body: Scaffold(body: Text('x')))),
      );
      expect('data-thor="SkipLink"'.allMatches(nested), hasLength(1));
      final provided = bodyOf(
        await page(const SkipLinkProvided(child: Scaffold(body: Text('x')))),
      );
      expect(provided, isNot(contains('SkipLink')));
    });
  });

  group('Scaffold parameters', () {
    test('floatingActionButtonLocation places the button', () async {
      final html = await page(
        const Scaffold(
          floatingActionButton: Text('fab'),
          floatingActionButtonLocation: FloatingActionButtonLocation.startTop,
          appBar: AppBar(title: Text('A')),
          body: Text('x'),
        ),
      );
      final css = stylesOf(html);
      expect(css, contains('inset-inline-start: max(16px'));
      expect(css, contains('top: calc(env(safe-area-inset-top, 0px) + 36px)'));
      final docked = stylesOf(
        await page(
          Scaffold(
            floatingActionButton: const Text('fab'),
            floatingActionButtonLocation:
                FloatingActionButtonLocation.centerDocked,
            bottomNavigationBar: NavigationBar(
              destinations: const [
                NavigationDestination(icon: Text('i'), label: 'x'),
                NavigationDestination(icon: Text('j'), label: 'y'),
              ],
            ),
            body: const Text('x'),
          ),
        ),
      );
      expect(docked, contains('left: 50%'));
      // The bar pads itself with the safe-area inset: so does the offset.
      expect(
        docked,
        contains('bottom: calc(52px + env(safe-area-inset-bottom, 0px))'),
      );
    });

    test(
      'floating button, footer and sheet clear the bar and its inset',
      () async {
        final bar = NavigationBar(
          destinations: const [
            NavigationDestination(icon: Text('i'), label: 'x'),
            NavigationDestination(icon: Text('j'), label: 'y'),
          ],
        );
        final html = await page(
          Scaffold(
            floatingActionButton: const Text('fab'),
            bottomNavigationBar: bar,
            persistentFooterButtons: const [Text('ok')],
            bottomSheet: const Text('sheet'),
            body: const Text('x'),
          ),
        );
        final css = stylesOf(html);
        const inset = 'env(safe-area-inset-bottom, 0px)';
        // 16px of air above the bar (and its inset), not max(16px, inset).
        expect(css, contains('bottom: calc(96px + $inset)'));
        expect(
          ruleOf(html, 'PersistentFooterButtons'),
          contains('bottom: calc(80px + $inset)'),
        );
        expect(
          ruleOf(html, 'BottomSheet'),
          contains('bottom: calc(136px + $inset)'),
        );
      },
    );

    test('bottomSheet, footer buttons and extend* take grid rows', () async {
      final html = await page(
        const Scaffold(
          bottomSheet: Text('sheet'),
          persistentFooterButtons: [Text('ok')],
          extendBody: true,
          extendBodyBehindAppBar: true,
          appBar: AppBar(title: Text('A')),
          body: Text('x'),
        ),
      );
      final css = stylesOf(html);
      expect(
        css,
        contains('grid-template-rows: auto minmax(0, 1fr) auto auto auto'),
      );
      expect(css, contains('grid-row: 1 / -1'));
      expect(bodyOf(html), contains('data-thor="PersistentFooterButtons"'));
      expect(ruleOf(html, 'BottomSheet'), contains('position: sticky'));
    });

    test('drawerScrimColor colors the drawer backdrop', () async {
      final css = stylesOf(
        await page(
          const Scaffold(
            drawer: Drawer(child: Text('d')),
            drawerScrimColor: Color(0xFF112233),
            body: Text('x'),
          ),
        ),
      );
      expect(css, contains('::backdrop'));
      expect(css, contains('#112233'));
    });

    test(
      'a CustomScrollView body scrolls inside a one-viewport scaffold',
      () async {
        final html = await page(
          const Scaffold(
            appBar: AppBar(title: Text('A'), scrolledUnderElevation: 4),
            body: CustomScrollView(
              slivers: [SliverToBoxAdapter(child: Text('x'))],
            ),
          ),
        );
        final css = stylesOf(html);
        expect(css, contains('height: 100dvh'));
        expect(css, contains('timeline-scope: --t-body-scroll'));
        expect(css, contains('scroll-timeline: --t-body-scroll block'));
        expect(css, contains('@supports (animation-timeline: scroll())'));
        expect(css, contains('animation-timeline: --t-body-scroll'));
        expect(html, contains('@keyframes t-appbar-under-'));
      },
    );
  });

  group('AppBar parameters', () {
    test('flexibleSpace, shape, shadowColor, leadingWidth, primary', () async {
      final html = await page(
        const AppBar(
          title: Text('A'),
          leading: Text('L'),
          leadingWidth: 100,
          elevation: 2,
          shadowColor: Color(0xFFFF0000),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          flexibleSpace: Text('bg'),
        ),
      );
      final rule = ruleOf(html, 'AppBar');
      expect(rule, contains('border-radius: 12px'));
      expect(rule, contains('#ff0000'));
      expect(rule, contains('overflow: clip'));
      expect(rule, contains('padding-top: env(safe-area-inset-top'));
      expect(stylesOf(html), contains('width: 100px'));
      final flat = ruleOf(
        await page(const AppBar(title: Text('A'), primary: false)),
        'AppBar',
      );
      expect(flat, isNot(contains('safe-area-inset-top')));
    });
  });

  group('slivers', () {
    test('a CustomScrollView stacks its slivers', () async {
      final html = bodyOf(
        await page(
          SizedBox(
            height: 300,
            child: CustomScrollView(
              slivers: [
                const SliverAppBar(pinned: true, title: Text('T')),
                SliverList.builder(
                  itemCount: 3,
                  itemBuilder: (c, i) => Text('row $i'),
                ),
                const SliverList(
                  delegate: SliverChildListDelegate([Text('list')]),
                ),
                SliverGrid.count(
                  crossAxisCount: 2,
                  children: const [Text('g1'), Text('g2')],
                ),
                const SliverPadding(
                  padding: EdgeInsets.all(8),
                  sliver: SliverToBoxAdapter(child: Text('box')),
                ),
                const SliverFillRemaining(child: Text('fill')),
              ],
            ),
          ),
        ),
      );
      for (final t in ['row 0', 'row 2', 'list', 'g1', 'g2', 'box', 'fill']) {
        expect(html, contains('>$t<'));
      }
      expect('data-thor="CustomScrollView"'.allMatches(html), hasLength(1));
      expect('<header'.allMatches(html), hasLength(1));
    });

    test(
      'pinned sticks, a plain bar scrolls away, expanded collapses',
      () async {
        final pinned = await page(
          const CustomScrollView(
            slivers: [SliverAppBar(pinned: true, title: Text('T'))],
          ),
        );
        expect(ruleOf(pinned, 'AppBar'), contains('position: sticky'));
        final loose = await page(
          const CustomScrollView(slivers: [SliverAppBar(title: Text('T'))]),
        );
        expect(ruleOf(loose, 'AppBar'), isNot(contains('sticky')));
        final tall = await page(
          const CustomScrollView(
            slivers: [
              SliverAppBar(pinned: true, expandedHeight: 200, title: Text('T')),
            ],
          ),
        );
        final css = stylesOf(tall);
        expect(css, contains('top: -136px'));
        expect(css, contains('min-height: 200px'));
        expect(tall, contains('@keyframes t-sliver-collapse-136_0'));
      },
    );

    test('builder delegates stop at null and the separated list', () async {
      final html = bodyOf(
        await page(
          CustomScrollView(
            slivers: [
              SliverList.separated(
                itemCount: 3,
                itemBuilder: (c, i) => Text('i$i'),
                separatorBuilder: (c, i) => Text('s$i'),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (c, i) => i < 2 ? Text('b$i') : null,
                ),
              ),
            ],
          ),
        ),
      );
      final order = RegExp(
        '>(i\\d|s\\d|b\\d)<',
      ).allMatches(html).map((m) => m[1]);
      expect(order, ['i0', 's0', 'i1', 's1', 'i2', 'b0', 'b1']);
    });

    test('an unbounded separated list builds each item once', () async {
      final built = <int>[];
      final html = bodyOf(
        await page(
          CustomScrollView(
            slivers: [
              SliverList.separated(
                itemBuilder: (c, i) {
                  built.add(i);
                  return i < 3 ? Text('i$i') : null;
                },
                separatorBuilder: (c, i) => Text('s$i'),
              ),
            ],
          ),
        ),
      );
      final order = RegExp('>(i\\d|s\\d)<').allMatches(html).map((m) => m[1]);
      expect(order, ['i0', 's0', 'i1', 's1', 'i2']);
      // 0, 1, 2 and the null that ends it: once each.
      expect(built, [0, 1, 2, 3]);
    });

    test('a horizontal or reversed view is refused', () async {
      expect(
        () => page(const CustomScrollView(scrollDirection: Axis.horizontal)),
        throwsA(isA<UnsupportedError>()),
      );
      expect(
        () => page(const CustomScrollView(reverse: true)),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });
}
