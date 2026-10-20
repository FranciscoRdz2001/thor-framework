@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

/// Full-document render (so `<head>` is present), returning the HTML.
Future<String> page(Widget body) async {
  return renderDocument(ThorApp(child: body));
}

String head(String html) => html.substring(0, html.indexOf('</head>'));
String bodyOf(String html) => html.substring(html.indexOf('<body'));

void main() {
  setUpAll(() => initializeThorTests(compactHtml: false));

  group('ThorApp style extraction', () {
    test(
      'identical widgets share one generated class, no inline styles',
      () async {
        final html = await page(
          Column(
            children: [
              for (var i = 0; i < 5; i++)
                Container(
                  padding: const EdgeInsets.all(12),
                  color: Colors.white,
                  child: Text('card $i', style: const TextStyle(fontSize: 14)),
                ),
            ],
          ),
        );
        final body = bodyOf(html);
        expect(
          body,
          isNot(contains('style="')),
          reason: 'thor elements use classes',
        );
        final boxClasses = RegExp(
          r'<div class="(t\w+)" data-thor="Container"',
        ).allMatches(body).map((m) => m[1]).toSet();
        expect(
          boxClasses,
          hasLength(1),
          reason: '5 equal Containers → 1 class',
        );
        final css = head(html);
        expect(css, contains('<style id="thor-styles">'));
        expect(css, contains(thorLayerOrder));
        expect('.${boxClasses.single}{'.allMatches(css), hasLength(1));
      },
    );

    test(
      'Flex layout per breakpoint: media queries on the same class',
      () async {
        final html = await page(
          Column(
            spacing: 8,
            layout: const FlexLayout().when(
              medium: const FlexLayout(direction: Axis.horizontal, spacing: 24),
            ),
            children: const [Text('a'), Text('b')],
          ),
        );
        expect(
          head(html),
          matches(
            RegExp(
              // The class's base rule, then the breakpoint (conditions go
              // after every base rule, grouped per condition).
              r'\.(t\w+)\{[^}]*gap: 8px\}.*@media screen and '
              r'\(min-width: 600px\)\{(?:[^{}]*\{[^{}]*\})*?\.\1\{'
              r'flex-direction: row; gap: 24px\}',
            ),
          ),
        );
      },
    );

    test('Styled + StyleProps.when: states in the element class', () async {
      final html = await page(
        Styled(
          style: const StyleProps().when(hover: const StyleProps(opacity: 0.8)),
          child: const Container(padding: EdgeInsets.all(8)),
        ),
      );
      final css = head(html);
      // Merged into the Container's own class: one class, no overrides
      // layer needed (conditional rules come after the base rule).
      expect(
        bodyOf(html),
        matches(RegExp(r'<div class="t\w+" data-thor="Container">')),
      );
      expect(css, matches(RegExp(r'\.t\w+:hover\{opacity: 0\.8\}')));
      expect(bodyOf(html), isNot(contains('style="')));
    });

    test('Theme darkData follows prefers-color-scheme without JS', () async {
      final html = await page(
        Theme(
          data: ThemeData.light(),
          darkData: ThemeData.dark(),
          child: const Text('x'),
        ),
      );
      // The subtree's colors are light-dark() on its class; its dark rule
      // (system dark with the switch off, or light with it on) keeps only
      // color-scheme, which picks the side.
      final css = head(html);
      expect(
        css,
        matches(
          RegExp(r'\.t\w+\{[^}]*--t-primary: light-dark\(#\w+, #d0bcff\)'),
        ),
      );
      expect(
        css,
        matches(
          RegExp(
            r'@media \(prefers-color-scheme: dark\)\{:where\(:root:not\('
            r':has\(#thor-theme:checked\)\)\) \.t\w+\{(?:--t-[\w-]+: #\w+; )?color-scheme: dark\}\}',
          ),
        ),
      );
      expect(
        css,
        matches(
          RegExp(
            r'@media not all and \(prefers-color-scheme: dark\)\{:where\('
            r':root:has\(#thor-theme:checked\)\) \.t\w+\{(?:--t-[\w-]+: #\w+; )?color-scheme: dark\}\}',
          ),
        ),
      );
    });

    test(
      'ResponsiveLayout renders each variant with visibility rules',
      () async {
        final html = await page(
          const ResponsiveLayout(
            mobile: Text('m'),
            tablet: Text('t'),
            desktop: Text('d'),
          ),
        );
        final css = head(html);
        // mobile hidden from md, tablet between md and lg, desktop from lg.
        expect(css, contains('@media screen and (min-width: 600px){'));
        expect(css, contains('@media screen and (max-width: 599.98px){'));
        expect(css, isNot(contains('revert-layer')));
        expect(css, contains('@media screen and (min-width: 840px){'));
        expect(RegExp('>[mtd]</span>').allMatches(bodyOf(html)), hasLength(3));
      },
    );

    test('GridView columns per breakpoint, no inline styles', () async {
      final html = await page(
        GridView.count(
          crossAxisCount: 2,
          layout: const GridLayout().when(
            medium: const GridLayout(columns: 3),
            expanded: const GridLayout(columns: 4),
          ),
          children: const [Text('a')],
        ),
      );
      final css = head(html);
      expect(css, contains('grid-template-columns: repeat(2, minmax(0, 1fr))'));
      expect(css, contains('@media screen and (min-width: 840px){'));
      expect(css, contains('repeat(4, minmax(0, 1fr))'));
      expect(
        bodyOf(html),
        isNot(contains('<style>')),
        reason: 'no per-instance style tags',
      );
    });

    test('container variants: @container rules of the same class', () async {
      final html = await page(
        LayoutScope(
          child: GridView.count(
            crossAxisCount: 1,
            layout: const GridLayout().when(
              container: {
                400: const GridLayout(columns: 2),
                700: const GridLayout(columns: 4),
              },
            ),
            children: const [Text('a')],
          ),
        ),
      );
      final css = head(html);
      expect(
        css,
        matches(
          RegExp(
            r'@container \(min-width: 400px\)\{\.t\w+\{grid-template-columns: '
            r'repeat\(2, minmax\(0, 1fr\)\)\}\}',
          ),
        ),
      );
      expect(css, contains('@container (min-width: 700px)'));
      expect(css, contains('container-type: inline-size'));
    });
  });

  group('security (values come from app data)', () {
    test(
      'declaration injection through a font family stays a string',
      () async {
        final html = await page(
          const Text(
            'x',
            style: TextStyle(fontFamily: 'Evil; background: red'),
          ),
        );
        // Names with spaces are quoted: inside a CSS string `;` is literal.
        expect(html, contains('font-family: "Evil; background: red"'));
      },
    );

    test('unquoted declaration injection is escaped', () async {
      final html = await page(
        const Container(color: Color.css('red;background:blue')),
      );
      expect(html, isNot(contains('red;background:blue')));
      expect(html, contains(r'background-color: red\3b background:blue'));
    });

    test('</style> in a value cannot break out of the stylesheet', () async {
      final html = await page(
        const Text(
          'x',
          style: TextStyle(fontFamily: '</style><script>alert(1)</script>'),
        ),
      );
      expect(html, isNot(contains('<script>alert(1)')));
      expect(html.indexOf('</style>'), greaterThan(0));
      expect(
        '</style>'.allMatches(head(html)).length,
        '<style'.allMatches(head(html)).length,
      );
    });

    test('rule injection with braces is neutralized', () async {
      final html = await page(
        const Container(color: Color.css('red} body{display:none')),
      );
      expect(html, isNot(contains('body{display:none')));
    });

    test('image URLs are quoted and escaped', () async {
      final html = await page(
        const DecoratedBox(
          decoration: BoxDecoration(
            image: DecorationImage(url: 'x.png") ; } body { display:none'),
          ),
        ),
      );
      expect(html, contains(r'url("x.png\") ; } body { display:none")'));
    });

    test('text and attributes are escaped by the renderer', () async {
      final html = await page(
        const Text(
          '<img src=x onerror=alert(1)>',
          semanticsLabel: '" onmouseover="alert(1)',
        ),
      );
      expect(html, isNot(contains('<img src=x')));
      expect(html, isNot(contains('" onmouseover="')));
    });

    test('invalid property names are dropped', () async {
      final html = await page(
        Styled(
          style: const StyleProps().when(
            hover: const StyleProps(
              // The escape hatch is what's tested.
              // ignore: thor_lints/avoid_raw_css
              raw: {'color:red;x': 'blue', 'color': 'green'},
            ),
          ),
          child: const Text('x'),
        ),
      );
      expect(html, isNot(contains('color:red;x')));
      expect(html, contains('color: green'));
    });
  });

  group('edge cases', () {
    test('empty collections render valid, empty containers', () async {
      final html = await page(
        Column(
          children: [
            const Row(),
            const Wrap(),
            const GridView.count(crossAxisCount: 3),
            ListView.builder(
              itemCount: 0,
              itemBuilder: (_, _) => const Text('never'),
            ),
            ListView.separated(
              itemCount: 1,
              itemBuilder: (_, i) => Text('only $i'),
              separatorBuilder: (_, _) => const Divider(),
            ),
          ],
        ),
      );
      expect(html, isNot(contains('never')));
      expect(html, contains('only 0'));
      expect(
        html,
        isNot(contains('<hr')),
        reason: 'no separator after the last item',
      );
    });

    test('empty and whitespace-only text', () async {
      final html = await page(const Column(children: [Text(''), Text('   ')]));
      expect(
        html,
        matches(RegExp(r'<span class="t\w+" data-thor="Text"></span>')),
      );
    });

    test('ResponsiveVisibility keeps a fused Row flex when visible', () async {
      // Regression: the fused wrapper shared the Row's layer, so a
      // `revert-layer` "show" rule reverted `display: flex` to `block`.
      final html = await page(
        const ResponsiveVisibility(
          visibleFrom: WindowSizeClass.expanded,
          child: Row(children: [Text('a'), Text('b')]),
        ),
      );
      final css = head(html);
      expect(css, contains('@media screen and (max-width: 839.98px){'));
      expect(css, isNot(contains('revert-layer')));
      expect(css, contains('display: flex'));
    });

    test('ResponsiveLayout with only mobile adds no wrappers', () async {
      final html = await page(const ResponsiveLayout(mobile: Text('m')));
      expect(bodyOf(html), isNot(contains('revert-layer')));
      expect(head(html), isNot(contains('revert-layer')));
    });

    test(
      'same widget without ThorApp falls back to inline + scoped <style>',
      () async {
        final html = await renderHtml(
          Column(
            layout: const FlexLayout().when(
              medium: const FlexLayout(direction: Axis.horizontal),
            ),
            children: const [Text('a')],
          ),
        );
        expect(html, contains('<style>'));
        expect(html, matches(RegExp(r'<div class="tl\w+" style="')));
      },
    );
  });

  test('stable hash is platform independent (known vectors)', () {
    expect(ThorStyleRegistry.stableHash(''), 'ztntfp');
    expect(ThorStyleRegistry.stableHash('0|padding: 12px'), 'lwktor');
  });

  group('debug checks (Flutter-style asserts)', () {
    test('Opacity out of range asserts', () {
      expect(
        () => const Opacity(opacity: 1.5, child: Text('x')).wrapData,
        throwsA(isA<AssertionError>()),
      );
    });

    test('negative EdgeInsets are detected', () {
      expect(const EdgeInsets.all(-4).isNonNegative, isFalse);
      expect(const EdgeInsets.all(0).isNonNegative, isTrue);
    });

    test('one class of thor per element and layer', () {
      final r = ThorStyleRegistry.server();
      final a = r.classFor(const {'color': 'red'});
      final b = r.classFor(const {'color': 'blue'});
      final o = r.classFor(const {'order': '1'}, layer: ThorLayer.overrides);
      // One per layer, and classes thor did not register (the app's), pass.
      r.debugCheckOneClassPerLayer([a, o, 'app-card'], 'div');
      r.debugCheckOneClassPerLayer([a, a], 'div');
      expect(
        () => r.debugCheckOneClassPerLayer([a, 'app-card', b], 'div'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            allOf(contains(a), contains(b), contains('thor.props')),
          ),
        ),
      );
    });

    test('every element of a real page passes the check', () async {
      // Debug render: element.dart runs the check on each element.
      await page(
        const Column(
          children: [
            Opacity(
              opacity: 0.5,
              child: SizedBox(
                width: 10,
                child: ColoredBox(color: Color(0xFF00FF00)),
              ),
            ),
            Expanded(child: Text('x')),
          ],
        ),
      );
    });

    test(
      'debug builds ship the layout inspector, next to the styles',
      () async {
        final html = await page(const Text('x'));
        expect(head(html), contains('id="thor-debug-inspector"'));
        expect(head(html), contains('overflowed by'));
      },
    );
  });

  group('icons and semantics', () {
    const search = IconData.svg(
      'lucide-search',
      '<path d="m21 21-4.34-4.34"/><circle cx="11" cy="11" r="8"/>',
      strokeWidth: 2,
    );

    test('SVG icons are shipped once per page in a sprite', () async {
      final html = await page(
        const Row(
          children: [Icon(search), Icon(search), Icon(search, size: 16)],
        ),
      );
      expect('<symbol id="lucide-search"'.allMatches(html), hasLength(1));
      expect('<use href="#lucide-search">'.allMatches(html), hasLength(3));
      expect(html, contains('stroke-linecap: round'));
      expect(html, isNot(contains('stroke-linecap=')));
      expect(html, contains('<svg id="thor-sprite" aria-hidden="true"'));
    });

    test('without ThorApp the SVG is inlined', () async {
      final html = await renderHtml(const Icon(search));
      expect(html, contains('<circle cx="11" cy="11" r="8"/>'));
      expect(html, isNot(contains('<use')));
    });

    test('Scaffold emits no empty landmarks', () async {
      final html = await page(const Scaffold(body: Text('x')));
      expect(html, contains('<main'));
      expect(html, isNot(contains('<header')));
      expect(html, isNot(contains('<footer')));
    });

    test('TextField hint doubles as the accessible name', () async {
      final html = await page(
        const TextField(decoration: InputDecoration(hintText: 'Search')),
      );
      expect(html, contains('aria-label="Search"'));
    });

    test('ExcludeSemantics and Semantics(enabled: false)', () async {
      final html = await page(
        const Semantics(
          enabled: false,
          child: Row(children: [ExcludeSemantics(child: Text('CHAI'))]),
        ),
      );
      expect(html, contains('aria-disabled="true"'));
      expect(html, contains('aria-hidden="true"'));
    });
  });

  test('one at-rule per condition, each class keeping its order', () {
    final registry = ThorStyleRegistry.server();
    const md = CssCondition.media('screen and (min-width: 7340px)');
    final a = registry.classFor(
      {'color': '#734001'},
      conditions: const [
        ConditionalCss(md, {'color': '#734002'}),
        ConditionalCss(CssCondition.hover, {'color': '#734003'}),
        ConditionalCss(CssCondition.disabled, {'color': '#734004'}),
      ],
    );
    final b = registry.classFor(
      {'color': '#734011'},
      conditions: const [
        ConditionalCss(md, {'color': '#734012'}),
        ConditionalCss(CssCondition.hover, {'color': '#734013'}),
      ],
    );
    final css = registry.cssText;
    expect(
      '@media screen and (min-width: 7340px)'.allMatches(css),
      hasLength(1),
    );
    expect('@media (hover: hover)'.allMatches(css), hasLength(1));
    expect(
      css,
      contains(
        '@media screen and (min-width: 7340px){.$a{color: #734002}'
        '.$b{color: #734012}}',
      ),
    );
    // .a's :disabled still comes after its hover rule.
    expect(
      css.indexOf('.$a:hover') < css.indexOf('.$a:is(:disabled'),
      isTrue,
      reason: css,
    );
  });

  test('a 32-bit hash collision gets a distinct class', () {
    final registry = ThorStyleRegistry.server();
    // Two different styles whose keys share the same FNV-1a hash.
    const a = {'color': '#0059db'};
    const b = {'color': '#042828'};
    final nameA = registry.classFor(a);
    final nameB = registry.classFor(b);
    expect(nameB, isNot(nameA));
    // Stable: asking again returns the same names.
    expect(registry.classFor(a), nameA);
    expect(registry.classFor(b), nameB);
    expect(registry.ruleCount, 2);
  });

  test('the per-process class cache is exact across pages', () {
    const wide = CssCondition.media('(min-width: 7331px)');
    const narrow = CssCondition.media('(max-width: 7331px)');
    Map<String, String> css() => {'color': '#7331aa', 'padding': '7px'};
    List<ConditionalCss> when(CssCondition c) => [
      ConditionalCss(c, {'color': '#7331bb'}),
    ];

    final first = ThorStyleRegistry.server();
    final reused = css();
    final name = first.classFor(reused, conditions: when(wide));
    final rules = first.cssText;
    // The caller's map may be reused after the call.
    reused['color'] = '#7331cc';

    final second = ThorStyleRegistry.server();
    expect(second.classFor(css(), conditions: when(wide)), name);
    expect(second.cssText, rules);
    // Same declarations in another order, or under another condition, or in
    // another layer: another class.
    expect(
      second.classFor({
        'padding': '7px',
        'color': '#7331aa',
      }, conditions: when(wide)),
      isNot(name),
    );
    expect(second.classFor(css(), conditions: when(narrow)), isNot(name));
    expect(
      second.classFor(
        css(),
        conditions: when(wide),
        layer: ThorLayer.overrides,
      ),
      isNot(name),
    );
    expect(second.classFor(reused, conditions: when(wide)), isNot(name));
  });
}
