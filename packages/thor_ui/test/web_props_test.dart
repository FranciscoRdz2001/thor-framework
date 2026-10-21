@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/html.dart' as html;
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

String _head(String html) => html.substring(0, html.indexOf('</head>'));

// The class of an element with descendant rules that holds them (its last).
String _insideClass(String html) =>
    RegExp('<div class="(?:[^" ]+ )*([^" ]+)"').firstMatch(html)![1]!;

void main() {
  setUpAll(() => initializeThorTests(compactHtml: false));

  group('StyleProps web extras', () {
    test('typed values become their declarations', () {
      final css = StyleProps(
        position: BoxPosition.sticky(top: 60.px),
        overflowY: Overflow.auto,
        overflowX: Overflow.hidden,
        minHeight: 100.dvh,
        maxHeight: 100.dvh - 72.px,
        maxWidth: Length.min([100.percent, 720.px]),
        alignSelf: CrossAxisAlignment.start,
        outline: const BorderSide(color: Color(0xFF4F46E5), width: 2),
        outlineOffset: 2,
        scrollMargin: const EdgeInsets.only(top: 72),
        transformOrigin: Alignment.centerLeft,
        turns: 0.25,
        blur: 64,
        ignorePointer: true,
        viewTransitionName: 'nav',
      ).toCss();
      expect(css, {
        'position': 'sticky',
        'top': '60px',
        'overflow-x': 'hidden',
        'overflow-y': 'auto',
        'min-height': '100dvh',
        'max-height': 'calc(100dvh - 72px)',
        'max-width': 'min(100%, 720px)',
        'align-self': 'flex-start',
        'outline': '2px solid #4f46e5',
        'outline-offset': '2px',
        'scroll-margin': '72px 0px 0px',
        'transform-origin': '0% 50%',
        'rotate': '0.25turn',
        'filter': 'blur(64px)',
        'pointer-events': 'none',
        'view-transition-name': 'nav',
      });
    });

    test('every offset of a fixed box', () {
      expect(
        BoxPosition.fixed(
          top: Length.zero,
          right: 16.px,
          bottom: 16.px,
          left: Length.auto,
        ).toCss(),
        {
          'position': 'fixed',
          'top': '0',
          'right': '16px',
          'bottom': '16px',
          'left': 'auto',
        },
      );
    });

    test('they vary with .when() on an element', () async {
      final html = await renderDocument(
        ThorApp(
          child: Styled(
            style: const StyleProps(
              overflowY: Overflow.visible,
            ).when(medium: const StyleProps(overflowY: Overflow.auto)),
            child: const SizedBox(width: 10),
          ),
        ),
      );
      expect(_head(html), contains('overflow-y: auto'));
    });

    test('a stylesheet rule takes them with props()', () {
      final rule = html
          .css('.toc')
          .props(
            StyleProps(position: BoxPosition.sticky(top: 0.px), zIndex: 20),
          );
      expect(rule.toCss(), contains('position: sticky'));
      expect(rule.toCss(), contains('z-index: 20'));
    });

    test('offstage hides the box, and only hides it', () {
      expect(const StyleProps(offstage: true).toCss(), {'display': 'none'});
      // web: showing is the element's own display (a Row stays flex): false
      // writes nothing instead of a display that would override it.
      expect(const StyleProps(offstage: false).toCss(), isEmpty);
    });

    test('offstage wins over display', () {
      expect(const StyleProps(offstage: true, display: Display.flex).toCss(), {
        'display': 'none',
      });
    });

    test('a stylesheet hides a set of elements with offstage', () {
      final rule = html
          .css('.grid:has(> .hide-2) .cell-2')
          .props(const StyleProps(offstage: true));
      expect(rule.toCss(), contains('.grid:has(> .hide-2) .cell-2 {'));
      expect(rule.toCss(), contains('display: none;'));
    });

    test('offstage varies per breakpoint on an element', () async {
      final html = await renderDocument(
        ThorApp(
          child: Styled(
            style: const StyleProps().when(
              medium: const StyleProps(offstage: true),
            ),
            child: const SizedBox(width: 10),
          ),
        ),
      );
      expect(_head(html), contains('display: none'));
    });

    test('Styled points a static offstage to the Offstage widget', () {
      expect(
        const StyleProps(offstage: true).widgetProps(),
        contains('offstage → Offstage'),
      );
      expect(
        const StyleProps()
            .when(medium: const StyleProps(offstage: true))
            .widgetProps(),
        isEmpty,
      );
    });

    test('a stylesheet rule refuses .when() values', () {
      expect(
        () => html
            .css('.x')
            .props(
              const StyleProps(
                opacity: 1,
              ).when(medium: const StyleProps(opacity: 0)),
            ),
        throwsArgumentError,
      );
    });
  });

  test('descendants style the HTML inside, scoped to the element', () async {
    final html = await renderDocument(
      const ThorApp(
        child: Styled(
          descendants: {
            'h2': StyleProps(textStyle: TextStyle(fontSize: 20)),
            'th, td': StyleProps(padding: EdgeInsets.all(8)),
          },
          child: SizedBox(width: 10),
        ),
      ),
    );
    final head = _head(html);
    final cls = _insideClass(html);
    // Up to the first thor element inside, with the specificity of
    // `.x h2` (the limit is in :where).
    final limit = ':where(:not(.$cls [data-tb],.$cls [data-tb] *))';
    expect(head, contains('.$cls h2$limit{font-size: 20px}'));
    expect(head, contains('.$cls :is(th, td)$limit{padding: 8px}'));
  });

  test('whenWithin styles the widget when an ancestor matches', () async {
    final html = await renderDocument(
      const ThorApp(
        child: Styled(
          whenWithin: {
            '[data-selection="none"]': StyleProps(opacity: 0.7),
            '.dark': StyleProps(opacity: 0.5),
          },
          child: SizedBox(width: 10),
        ),
      ),
    );
    final cls = _insideClass(html);
    // The ancestor sits in :where() (no specificity), like `within`.
    expect(
      _head(html),
      contains(':where([data-selection="none"]) .$cls{opacity: 0.7}'),
    );
    expect(_head(html), contains(':where(.dark) .$cls{opacity: 0.5}'));
  });

  test('a descendant pseudo-element keeps the limit before it', () async {
    final html = await renderDocument(
      const ThorApp(
        child: Styled(
          descendants: {'li::marker': StyleProps(opacity: 0.5)},
          child: SizedBox(width: 10),
        ),
      ),
    );
    final cls = _insideClass(html);
    expect(
      _head(html),
      contains(
        '.$cls li:where(:not(.$cls [data-tb],.$cls [data-tb] *))::marker{',
      ),
    );
  });

  test('a list of relative selectors is one selector per item', () async {
    // `:is(> a, > b)` is invalid CSS (no relative selectors in `:is()`):
    // the browser would drop the whole rule.
    final html = await renderDocument(
      const ThorApp(
        child: Styled(
          descendants: {
            '> :first-child, > :is(p, ul) > li::marker': StyleProps(
              opacity: 0.5,
            ),
          },
          child: SizedBox(width: 10),
        ),
      ),
    );
    final cls = _insideClass(html);
    final limit = ':where(:not(.$cls [data-tb],.$cls [data-tb] *))';
    expect(
      _head(html),
      contains(
        '.$cls > :first-child$limit,'
        '.$cls > :is(p, ul) > li$limit::marker{opacity: 0.5}',
      ),
    );
  });

  test('variants of the element share one class with its descendant '
      'rules', () async {
    // The element's own values (a flex its parent sets, a width) vary;
    // the descendant rules, written once, don't.
    const rules = {'h2': StyleProps(textStyle: TextStyle(fontSize: 20))};
    final html = await renderDocument(
      const ThorApp(
        child: Column(
          children: [
            Styled(descendants: rules, child: SizedBox(width: 10)),
            Styled(descendants: rules, child: SizedBox(width: 20)),
          ],
        ),
      ),
    );
    final classes = [
      for (final m in RegExp(
        '<div class="([^"]+)" data-thor="SizedBox"',
      ).allMatches(html))
        m[1]!.split(' '),
    ];
    expect(classes, hasLength(2));
    final [first, second] = classes;
    // Own classes differ, the rules' class is the same one.
    expect(first.first, isNot(second.first));
    expect(first.last, second.last);
    expect(RegExp(r'h2:where\(').allMatches(_head(html)), hasLength(1));
  });

  group('descendant rules stop at thor elements', () {
    Future<String> page(Widget body) => renderDocument(ThorApp(child: body));

    const prose = {'p': StyleProps(margin: EdgeInsets.only(top: 14))};

    test('raw HTML alone: no mark anywhere (prose pages unchanged)', () async {
      final out = await page(
        const Styled(
          descendants: prose,
          child: Container(child: html.RawText('<p>a</p><p>b</p>')),
        ),
      );
      // The stylesheet names the limit; no element carries it.
      expect(out.substring(out.indexOf('<body')), isNot(contains('data-tb')));
    });

    test('thor elements inside are marked, the root is not', () async {
      final out = await page(
        const Styled(
          descendants: prose,
          child: Column(
            children: [
              html.RawText('<p>raw</p>'),
              Card(child: Text('nested', style: TextStyle(fontSize: 13))),
            ],
          ),
        ),
      );
      final body = out.substring(out.indexOf('<body'));
      // The element with the rules (the Column) is the scope, not a limit.
      final root = RegExp(r'<div([^>]*)>\s*<p>raw').firstMatch(body);
      expect(root, isNotNull, reason: body);
      expect(root![1], isNot(contains('data-tb')));
      // The Card (one element with its text) is a limit.
      expect(
        body,
        matches(RegExp(r'<div class="[^"]+"[^>]* data-tb>nested</div>')),
      );
      expect(body, contains('<p>raw</p>'), reason: 'raw HTML untouched');
    });

    test('outside a scope, no element is marked', () async {
      final out = await page(
        const Column(children: [Card(child: Text('alone'))]),
      );
      expect(out, isNot(contains('data-tb')));
    });
  });

  test('descendants refuse .when() values', () {
    final styled = Styled(
      descendants: {
        'h2': const StyleProps(
          opacity: 1,
        ).when(medium: const StyleProps(opacity: 0)),
      },
      child: const SizedBox(),
    );
    expect(() => styled.wrapData, throwsA(isA<AssertionError>()));
  });

  test('a preload carries the font file\'s own type', () {
    expect(const FontFace('A', url: '/a.woff2').mimeType, 'font/woff2');
    expect(const FontFace('A', url: '/a.WOFF?v=2').mimeType, 'font/woff');
    expect(const FontFace('A', url: '/a.otf').mimeType, 'font/otf');
    expect(const FontFace('A', url: '/a.ttf').mimeType, 'font/ttf');
    expect(
      const FontFace('A', url: '/a.ttf').css,
      contains('format("truetype")'),
    );
  });

  test('a subset face covers its unicode-range; a bad one is THOR-R016', () {
    expect(
      const FontFace(
        'A',
        url: '/a.woff2',
        unicodeRange: 'U+0000-00FF, U+2013',
      ).css,
      contains('unicode-range: U+0000-00FF, U+2013'),
    );
    expect(
      () => const FontFace('A', url: '/a.woff2', unicodeRange: 'latin;}').css,
      throwsA(
        isA<ArgumentError>().having(
          (e) => '${e.message}',
          'message',
          contains('THOR-R016'),
        ),
      ),
    );
  });

  test('a metric fallback: a local face resized, right after its family', () {
    const face = FontFace(
      'Figtree',
      url: '/fonts/figtree.woff2',
      fallback: FontFallback(
        sizeAdjust: 1.012,
        ascentOverride: 0.94,
        descentOverride: 0.25,
        lineGapOverride: 0,
      ),
    );
    expect(face.fallbackFamily, 'Figtree Fallback');
    final css = face.css;
    expect(css, contains('font-family: "Figtree Fallback"'));
    expect(
      css,
      contains(
        'src: local("Arial"),local("Helvetica Neue"),local("Helvetica")',
      ),
    );
    expect(css, contains('size-adjust: 101.2%'));
    expect(css, contains('ascent-override: 94%'));
    expect(css, contains('descent-override: 25%'));
    expect(css, contains('line-gap-override: 0%'));
    final vars = ThemeData(
      fontFamily: "'figtree', system-ui, sans-serif",
      fonts: const [
        face,
        FontFace('Mono', url: '/m.woff2'),
      ],
    ).toCssVariables();
    expect(
      vars['font-family'],
      "'figtree', \"Figtree Fallback\", system-ui, sans-serif",
    );
    expect(
      ThemeData(
        fontFamily: 'Mono, monospace',
        fonts: const [FontFace('Mono', url: '/m.woff2')],
      ).toCssVariables()['font-family'],
      'Mono, monospace',
    );
    // Flutter's shape: one name and a list of fallbacks.
    expect(
      ThemeData(
        fontFamily: 'Mono',
        fontFamilyFallback: const [
          'IBM Plex Mono',
          'ui-monospace',
          'monospace',
        ],
        fonts: const [FontFace('Mono', url: '/m.woff2')],
      ).toCssVariables()['font-family'],
      'Mono, "IBM Plex Mono", ui-monospace, monospace',
    );
    expect(
      ThemeData(
        fontFamily: null,
        fontFamilyFallback: const ['serif'],
      ).toCssVariables()['font-family'],
      'serif',
    );
    expect(
      ThemeData(
        fontFamily: 'A',
      ).copyWith(fontFamilyFallback: ['B']).fontFamilyFallback,
      ['B'],
    );
  });

  group('ThemeData page rules', () {
    final theme = ThemeData(
      fontFamily: 'Figtree',
      fonts: const [
        FontFace(
          'Figtree',
          url: '/fonts/figtree.woff2',
          weight: FontWeight.w300,
          maxWeight: FontWeight.w900,
          preload: true,
        ),
        FontFace(
          'Mono',
          url: '/fonts/mono.woff2',
          style: FontStyle.italic,
          display: FontDisplay.optional,
        ),
      ],
      textSelectionTheme: const TextSelectionThemeData(
        selectionColor: Color.variable(CssVariable('--t-accent-tint')),
        cursorColor: Color(0xFF4F46E5),
      ),
      focusColor: const Color.variable(CssVariable('--t-accent')),
    );

    test('fonts, selection, caret and focus ring', () async {
      final head = _head(
        await renderDocument(ThorApp(theme: theme, child: const Text('x'))),
      );
      expect(
        head,
        contains(
          '@font-face{font-family: "Figtree"; '
          'src: url("/fonts/figtree.woff2") format("woff2"); '
          'font-weight: 300 900; font-style: normal; font-display: swap}',
        ),
      );
      expect(head, contains('font-style: italic; font-display: optional'));
      expect(
        head,
        contains('::selection{background-color:var(--t-accent-tint'),
      );
      expect(head, contains('caret-color:#4f46e5'));
      expect(head, contains(':focus-visible{outline:2px solid var(--t-accent'));
    });

    test('only the preload faces are fetched with the page', () async {
      final head = _head(
        await renderDocument(ThorApp(theme: theme, child: const Text('x'))),
      );
      final links = RegExp(
        '<link[^>]*rel="preload"[^>]*>',
      ).allMatches(head).map((m) => m[0]!).toList();
      expect(links, hasLength(1));
      expect(links.single, contains('href="/fonts/figtree.woff2"'));
      expect(links.single, contains('crossorigin'));
      expect(links.single, contains('type="font/woff2"'));
    });

    test('a font name or url cannot break out of the rule', () {
      const face = FontFace('X"; } body{color:red', url: 'a") ; } x{');
      // Outside the quoted strings, only the rule's own braces are left.
      final bare = face.css.replaceAll(RegExp(r'"(\\.|[^"\\])*"'), '""');
      expect(RegExp('[{}]').allMatches(bare).map((m) => m[0]), ['{', '}']);
    });
  });
}
