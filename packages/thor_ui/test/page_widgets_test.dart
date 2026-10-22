// Fixture: fields without a label on purpose (focus, state and form behavior).
// ignore_for_file: thor_lints/text_field_without_label
@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/src/core/document.dart' show DocumentAttributes;
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

// Page-building widgets and APIs: links, drawer, popover, grid, button
// styles, theme and a few Flutter APIs.

Future<String> page(Widget body) => renderDocument(ThorApp(child: body));

Future<String> render(Widget body) => renderHtml(body);

String head(String html) => html.substring(0, html.indexOf('</head>'));
String bodyOf(String html) => html.substring(html.indexOf('<body'));

void main() {
  setUpAll(() => initializeThorTests(compactHtml: false));

  group('Link', () {
    test('makes a Text an <a> without an extra node', () async {
      final html = bodyOf(
        await page(const Link(href: RouteUrl('#faq'), child: Text('FAQ'))),
      );
      expect(html, contains('href="#faq"'));
      expect(RegExp(r'<a [^>]*>\s*FAQ\s*</a>').hasMatch(html), isTrue);
      expect(html, isNot(contains('<span')));
    });

    test('opens a new tab safely', () async {
      final html = await page(
        const Link(
          href: RouteUrl('https://x.dev'),
          newTab: true,
          child: Text('x'),
        ),
      );
      expect(html, contains('target="_blank"'));
      expect(html, contains('rel="noopener noreferrer"'));
    });

    test('nests an icon (an svg can not become an <a>)', () async {
      const icon = IconData.svg('t-dot', '<circle cx="12" cy="12" r="4"/>');
      final doc = await page(
        const Link(href: RouteUrl('/'), label: 'Home', child: Icon(icon)),
      );
      final html = bodyOf(doc);
      expect(
        RegExp(r'<a [^>]*href="/"[^>]*>\s*<svg ').hasMatch(html),
        isTrue,
        reason: html,
      );
      expect(html, contains('aria-label="Home"'));
      // The <a> itself carries the link reset (else the icon turns blue),
      // as a class, not an inline style.
      expect(html, isNot(contains('style="display')));
      final classes = RegExp(
        r'<a class="([^"]+)"',
      ).firstMatch(html)!.group(1)!.split(' ');
      expect(
        classes.any(
          (c) => RegExp('\\.$c\\{[^}]*color: inherit').hasMatch(head(doc)),
        ),
        isTrue,
        reason: head(doc),
      );
    });

    test("the child's color wins over the link reset", () async {
      final html = await page(
        const Link(
          href: RouteUrl('/'),
          child: Text('x', style: TextStyle(color: Color(0xFFFF0000))),
        ),
      );
      final css = head(html);
      // The reset sits in the lowest layer only: no class above it has it.
      final above = css.replaceAll(RegExp(r'@layer thor\.reset\{.*?\}\}'), '');
      expect(above, isNot(contains('color: inherit')));
      expect(css, contains('#ff0000'));
    });
  });

  test('Drawer is a light-dismiss dialog that slides in', () async {
    final html = await page(
      Column(
        children: [
          DialogTrigger(
            id: 'nav',
            child: TextButton(onPressed: () {}, child: const Text('Menu')),
          ),
          const Drawer(id: 'nav', child: Text('links')),
        ],
      ),
    );
    expect(bodyOf(html), contains('commandfor="nav"'));
    expect(bodyOf(html), contains('closedby="any"'));
    expect(RegExp('<dialog [^>]*id="nav"').hasMatch(html), isTrue);
    expect(head(html), contains('@starting-style'));
  });

  test('Popover anchors its panel to the button', () async {
    final html = await page(
      const Popover(
        id: 'menu',
        width: 300,
        trigger: Text('Open'),
        child: Text('panel'),
      ),
    );
    expect(bodyOf(html), contains('popovertarget="menu"'));
    expect(bodyOf(html), contains('popover="auto"'));
    expect(head(html), contains('anchor-name: --menu'));
    expect(head(html), contains('position-anchor: --menu'));
    // The panel is free content, not a menu: no `aria-haspopup="true"`.
    expect(bodyOf(html), isNot(contains('aria-haspopup="true"')));
    expect(bodyOf(html), contains('aria-haspopup="dialog"'));
  });

  test('a bare Popover paints the theme surface, not the browser\'s', () async {
    // `[popover]` defaults to Canvas/CanvasText (`#121212` in a dark scheme):
    // the panel follows the theme's surface and text, and the page's scheme.
    final html = await page(
      const Popover(id: 'm', trigger: Text('o'), child: Text('p')),
    );
    final rule = RegExp(
      r'\.[\w-]+ ?\{[^}]*position-anchor[^}]*\}',
    ).firstMatch(head(html))![0]!;
    expect(rule, contains('background-color: var(--t-surface-container'));
    expect(rule, contains('color: var(--t-on-surface'));
    expect(rule, contains('color-scheme: inherit'));
    // A decoration still wins.
    final styled = await page(
      const Popover(
        id: 'm',
        trigger: Text('o'),
        decoration: BoxDecoration(color: Color(0xFFFF0000)),
        child: Text('p'),
      ),
    );
    final r2 = RegExp(
      r'\.[\w-]+ ?\{[^}]*position-anchor[^}]*\}',
    ).firstMatch(head(styled))![0]!;
    expect(RegExp('background-color').allMatches(r2), hasLength(1));
    expect(r2, contains('#ff0000'));
  });

  group('Popover look, typed', () {
    // The panel's rule and the trigger's rule, from the document head.
    (String, String) rules(String html) {
      final css = head(html);
      String ruleWith(String marker) => RegExp(
        r'\.[\w-]+ ?\{[^}]*' + RegExp.escape(marker) + r'[^}]*\}',
      ).firstMatch(css)![0]!;
      return (ruleWith('position-anchor'), ruleWith('anchor-name'));
    }

    test('decoration, menuPadding and constraints style the panel', () async {
      final html = await page(
        const Popover(
          id: 'menu',
          trigger: Text('Open'),
          decoration: BoxDecoration(
            color: Color(0xFFFFFFFF),
            borderRadius: BorderRadius.all(Radius.circular(8)),
            border: Border.fromBorderSide(BorderSide(color: Color(0xFFE0E0E0))),
            boxShadow: [
              BoxShadow(
                color: Color(0x26000000),
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
            ],
          ),
          menuPadding: EdgeInsets.all(12),
          constraints: BoxConstraints(minWidth: 260, maxWidth: 560),
          child: Text('panel'),
        ),
      );
      final (panel, _) = rules(html);
      expect(panel, contains('background-color: #ffffff'));
      expect(panel, contains('border-radius: 8px'));
      expect(panel, contains('border: 1px solid #e0e0e0'));
      expect(panel, contains('box-shadow: 0px 4px 16px'));
      expect(panel, contains('padding: 12px'));
      expect(panel, contains('min-width: 260px'));
      // A max width still leaves the page's gutter on a phone.
      expect(panel, contains('max-width: min(560px, calc(100vw - 16px))'));
      expect(panel, isNot(contains('border: 0')));
      // One element for the panel: no wrapper around the child.
      expect(RegExp('<div').allMatches(bodyOf(html)), hasLength(1));
    });

    test('style is the trigger\'s ButtonStyle', () async {
      final html = await page(
        const Popover(
          id: 'menu',
          trigger: Text('Features'),
          style: ButtonStyle(
            padding: WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            minimumSize: WidgetStatePropertyAll(Size(0, 40)),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(6)),
              ),
            ),
            textStyle: WidgetStatePropertyAll(
              TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            overlayColor: WidgetStatePropertyAll(Color(0xFFF4F4F5)),
          ),
          child: Text('panel'),
        ),
      );
      final (_, trigger) = rules(html);
      expect(trigger, contains('padding: 8px 16px'));
      expect(trigger, contains('min-height: 40px'));
      expect(trigger, contains('border-radius: 6px'));
      expect(trigger, contains('font-size: 14px'));
      expect(trigger, contains('font-weight: 500'));
      expect(head(html), contains(':hover'));
      expect(head(html), contains('background-color: #f4f4f5'));
    });

    test('without a look, the panel stays bare', () async {
      final html = await page(
        const Popover(id: 'menu', trigger: Text('Open'), child: Text('x')),
      );
      final (panel, _) = rules(html);
      expect(panel, contains('padding: 0'));
      expect(panel, contains('border: 0'));
      expect(panel, contains('max-width: calc(100vw - 16px)'));
    });
  });

  test('Grid adds columns per breakpoint', () async {
    final html = await page(
      Grid(
        layout: const GridLayout(columns: 1, gap: 16).when(
          medium: const GridLayout(columns: 2),
          expanded: const GridLayout(columns: 3),
        ),
        children: const [Text('a'), Text('b'), Text('c')],
      ),
    );
    final css = head(html);
    expect(css, contains('grid-template-columns: repeat(1, minmax(0, 1fr))'));
    expect(css, contains('grid-template-columns: repeat(2, minmax(0, 1fr))'));
    expect(css, contains('grid-template-columns: repeat(3, minmax(0, 1fr))'));
    expect(css, contains('column-gap: 16px'));
  });

  group('buttons', () {
    test('href makes an <a> without type/disabled', () async {
      final html = bodyOf(
        await page(
          const FilledButton(
            href: '#pricing',
            onPressed: null,
            child: Text('Go'),
          ),
        ),
      );
      expect(RegExp('<a [^>]*href="#pricing"').hasMatch(html), isTrue);
      expect(html, isNot(contains('disabled')));
      expect(html, isNot(contains('type="button"')));
    });

    test('ButtonStyle overrides colors, size and shape', () async {
      final html = await page(
        FilledButton(
          onPressed: () {},
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF112233),
            minimumSize: const Size.fromHeight(40),
            shape: const StadiumBorder(),
          ),
          child: const Text('Go'),
        ),
      );
      final css = head(html);
      expect(css, contains('#112233'));
      expect(css, contains('min-height: 40px'));
      expect(css, isNot(contains('min-width: Infinity')));
      expect(css, contains('border-radius: 9999px'));
    });
  });

  group('Flutter APIs', () {
    test('Row(textDirection: rtl) reverses the children', () async {
      final html = await page(
        const Row(
          textDirection: TextDirection.rtl,
          children: [Text('a'), Text('b')],
        ),
      );
      expect(head(html), contains('flex-direction: row-reverse'));
    });

    test('Transform.flip mirrors', () async {
      final html = await page(
        const Transform.flip(flipX: true, child: Text('x')),
      );
      expect(head(html), contains('transform: scale(-1, 1)'));
    });

    test('FractionallySizedBox sizes as a percentage', () async {
      final html = await page(
        const FractionallySizedBox(widthFactor: 0.8, child: Text('x')),
      );
      expect(head(html), contains('width: 80%'));
    });

    test('TextField(maxLines: 5) is a textarea with 5 rows', () async {
      final html = bodyOf(
        await page(
          const TextField(maxLines: 5, initialValue: 'hi', name: 'body'),
        ),
      );
      expect(RegExp('<textarea [^>]*rows="5"').hasMatch(html), isTrue);
      expect(RegExp(r'>\s*hi\s*</textarea>').hasMatch(html), isTrue);
      expect(html, isNot(contains('type="text"')));
    });

    test('InputDecoration.copyWith replaces only the given fields', () {
      const base = InputDecoration(labelText: 'Email', filled: true);
      final copy = base.copyWith(hintText: 'you@x.dev');
      expect(copy.labelText, 'Email');
      expect(copy.filled, isTrue);
      expect(copy.hintText, 'you@x.dev');
    });
  });

  group('theme', () {
    final light = ThemeData(colorTokens: const {'soft': Color(0xFFEEEEEE)});
    final dark = ThemeData(
      colorScheme: const ColorScheme.dark(),
      colorTokens: const {'soft': Color(0xFF111111)},
    );

    group('the theme switch input', () {
      String input(String html) =>
          RegExp(r'<input[^>]*id="thor-theme"[^>]*>').firstMatch(html)![0]!;

      test('comes after the page content in tab order', () async {
        final html = bodyOf(
          await renderDocument(
            ThorApp(
              theme: light,
              darkTheme: dark,
              child: Column(
                children: [
                  TextButton(onPressed: () {}, child: const Text('first')),
                  const ThemeToggle(light: Text('sun'), dark: Text('moon')),
                ],
              ),
            ),
          ),
        );
        expect(
          html.indexOf('id="thor-theme"'),
          greaterThan(html.indexOf('first')),
        );
        expect(
          html.indexOf('id="thor-theme"'),
          greaterThan(html.indexOf('moon')),
        );
      });

      test('prefers a toggle outside a dialog (a phone drawer)', () async {
        final html = bodyOf(
          await renderDocument(
            ThorApp(
              theme: light,
              darkTheme: dark,
              child: const Column(
                children: [
                  Drawer(
                    id: 'menu',
                    child: ThemeToggle(
                      light: Text('sun1'),
                      dark: Text('moon1'),
                    ),
                  ),
                  ThemeToggle(light: Text('sun2'), dark: Text('moon2')),
                ],
              ),
            ),
          ),
        );
        final at = html.indexOf('id="thor-theme"');
        expect(at, greaterThan(html.indexOf('</dialog>')));
        expect(at, greaterThan(html.indexOf('moon2')));
        expect(RegExp('id="thor-theme"').allMatches(html), hasLength(1));
      });

      test('is named in the page language: Spanish, else English', () async {
        final es = await renderDocument(
          ThorApp(
            theme: light,
            darkTheme: dark,
            locale: const Locale('es', 'MX'),
            supportedLocales: const [Locale('es', 'MX')],
            child: const Text('x'),
          ),
        );
        expect(
          input(es),
          contains('aria-label="Cambiar entre tema claro y oscuro"'),
        );
        final en = await renderDocument(
          ThorApp(theme: light, darkTheme: dark, child: const Text('x')),
        );
        expect(input(en), contains('aria-label="Switch light/dark theme"'));
      });

      test('follows a lang the app sets on the document itself', () async {
        final html = await renderDocument(
          ThorApp(
            theme: light,
            darkTheme: dark,
            child: const Widget.fragment([
              DocumentAttributes(attributes: {'lang': 'es'}),
              Text('x'),
            ]),
          ),
        );
        expect(input(html), contains('Cambiar entre tema claro y oscuro'));
      });

      test('themeToggleLabel overrides the name', () async {
        final html = await renderDocument(
          ThorApp(
            theme: light,
            darkTheme: dark,
            themeToggleLabel: 'Modo oscuro',
            child: const Text('x'),
          ),
        );
        expect(input(html), contains('aria-label="Modo oscuro"'));
      });
    });

    test('ThorApp publishes the theme on :root and paints body', () async {
      final html = await renderDocument(
        ThorApp(theme: light, child: const Text('x')),
      );
      final css = head(html);
      expect(css, contains(':root{--t-primary:#6750a4'));
      expect(css, contains('--t-soft:#eeeeee'));
      expect(css, contains('body{margin:0;background-color:var(--t-surface)'));
      expect(html, isNot(contains('id="thor-theme"')), reason: 'no dark');
    });

    test('a dark theme adds the no-JS switch, flipped by the checkbox', () async {
      final html = await renderDocument(
        ThorApp(
          theme: light,
          darkTheme: dark,
          child: const ThemeToggle(light: Text('sun'), dark: Text('moon')),
        ),
      );
      expect(bodyOf(html), contains('id="thor-theme"'));
      expect(bodyOf(html), contains('for="thor-theme"'));
      final css = head(html);
      // One list of variables: each color is light-dark(); the dark rule
      // (system dark with the switch off, or light with it on) keeps
      // color-scheme, which picks the side, and the dark-only roles (the
      // dark scheme's `surfaceContainerHigh`: the light side has no
      // variable, the widgets' own fallback).
      expect(css, contains(':root{--t-primary:light-dark(#6750a4, #d0bcff)'));
      expect(css, contains('--t-soft:light-dark(#eeeeee, #111111)'));
      expect(
        css,
        contains(
          '@media (prefers-color-scheme: dark){'
          ':root:not(:has(#thor-theme:checked)){--t-surface-container-high:#2b2930;color-scheme:dark}}',
        ),
      );
      expect(
        css,
        contains(
          '@media not all and (prefers-color-scheme: dark){'
          ':root:has(#thor-theme:checked){--t-surface-container-high:#2b2930;color-scheme:dark}}',
        ),
      );
      // No second copy of the variables for the dark theme.
      expect('--t-primary:'.allMatches(css), hasLength(1));
    });

    // The theme's page rules are cached per theme instance (a server renders
    // the same app-level theme on every request).
    test(
      'the cached theme rules follow the theme, dark theme and mode',
      () async {
        Future<String> css(Widget app) async => head(await renderDocument(app));
        final lightOnly = await css(
          ThorApp(theme: light, child: const Text('x')),
        );
        expect(
          await css(ThorApp(theme: light, child: const Text('x'))),
          lightOnly,
        );
        final withDark = await css(
          ThorApp(theme: light, darkTheme: dark, child: const Text('x')),
        );
        expect(withDark, contains('prefers-color-scheme: dark'));
        final forcedDark = await css(
          ThorApp(
            theme: light,
            darkTheme: dark,
            themeMode: ThemeMode.dark,
            child: const Text('x'),
          ),
        );
        expect(forcedDark, contains(':root{--t-primary:#d0bcff'));
        final other = await css(
          ThorApp(
            theme: ThemeData(colorTokens: const {'soft': Color(0xFF222222)}),
            child: const Text('x'),
          ),
        );
        expect(other, contains('--t-soft:#222222'));
        expect(
          await css(ThorApp(theme: light, child: const Text('x'))),
          lightOnly,
        );
      },
    );

    test('ThemeColor.withValues mixes the variable', () {
      expect(
        ThemeColor.primary.withValues(alpha: 0.5).css,
        'color-mix(in srgb, var(--t-primary) 50%, transparent)',
      );
    });

    test(
      'ResponsiveVisibility(brightness:) hides in the other theme',
      () async {
        final html = await page(
          const ResponsiveVisibility(
            brightness: Brightness.dark,
            child: Text('dark only'),
          ),
        );
        expect(
          head(html),
          matches(
            RegExp(
              r'not all and \(prefers-color-scheme: dark\)\{:where\(:root:not'
              r'\(:has\(#thor-theme:checked\)\)\) \.t\w+\{display: none',
            ),
          ),
        );
      },
    );
  });

  test('HoverGroup + groupHover: one ancestor selector, no state', () async {
    final html = await page(
      HoverGroup(
        child: Column(
          children: [
            Styled(
              style: const StyleProps().when(
                groupHover: const StyleProps(scale: 1.05, widthFactor: 0.5),
              ),
              child: const Text('zoom'),
            ),
          ],
        ),
      ),
    );
    expect(bodyOf(html), contains('t-group'));
    final css = head(html);
    expect(css, contains(':where(.t-group:hover) .t'));
    expect(css, contains('scale: 1.05'));
    expect(css, contains('width: 50%'));
  });

  test('LazyLayout skips off-screen layout with an estimate', () async {
    final html = await page(
      const LazyLayout(extentEstimate: 900, child: Text('below')),
    );
    expect(head(html), contains('content-visibility: auto'));
    expect(head(html), contains('contain-intrinsic-size: auto 900px'));
  });

  test(
    'CarouselView: snap, items per view by breakpoint, scoped arrows',
    () async {
      final html = await page(
        CarouselView(
          label: 'Reviews',
          layout: const CarouselLayout(itemsPerView: 1).when(
            medium: const CarouselLayout(itemsPerView: 2),
            expanded: const CarouselLayout(itemsPerView: 3),
          ),
          children: const [Text('a'), Text('b'), Text('c')],
        ),
      );
      final css = head(html);
      expect(css, contains('scroll-snap-type: x mandatory'));
      expect(css, contains('--t-per-view: 1'));
      expect(css, contains('--t-per-view: 3'));
      expect(css, contains('::scroll-button(left)'));
      expect(css, contains('anchor-scope: --t-carousel'));
      expect(bodyOf(html), contains('aria-roledescription="carousel"'));
      expect(bodyOf(html), contains('aria-label="Reviews"'));
    },
  );

  test('a fractional child is centered by Center, not stretched', () async {
    final html = await page(
      const Center(
        child: FractionallySizedBox(
          widthFactor: 0.8,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [Text('x')],
          ),
        ),
      ),
    );
    final css = head(html);
    expect(css, contains('width: 80%'));
    expect(css, isNot(contains('margin-left: 0; margin-right: 0')));
  });

  test('ButtonStyle(alignment:) places the label', () async {
    final html = await page(
      TextButton(
        onPressed: () {},
        style: const ButtonStyle(alignment: Alignment.centerLeft),
        child: const Text('Menu'),
      ),
    );
    expect(head(html), contains('justify-content: flex-start'));
  });

  test('ButtonStyle(animationDuration:) animates the whole look', () async {
    final animated = await page(
      FilledButton(
        onPressed: () {},
        style: const ButtonStyle(
          animationDuration: Duration(milliseconds: 250),
        ),
        child: const Text('Save'),
      ),
    );
    final property = RegExp(
      r'transition-property: ([^;}]*)',
    ).firstMatch(head(animated))!.group(1)!.split(', ');
    expect(
      property,
      containsAll([
        'background-color',
        'color',
        'border-color',
        'box-shadow',
        'opacity',
      ]),
    );
    expect(head(animated), contains('transition-duration: 250ms'));
    // Instant under reduced motion.
    expect(head(animated), contains('prefers-reduced-motion'));

    // Without it the button keeps its default (fill and shadow only).
    final plain = await page(
      FilledButton(onPressed: () {}, child: const Text('Save')),
    );
    expect(head(plain), isNot(contains('opacity; transition-duration')));
  });

  test('Image never exceeds its parent and keeps its ratio', () async {
    final html = await page(
      const Image.asset('hero.jpg', width: 1200, height: 825, lazy: false),
    );
    final css = head(html);
    expect(css, contains('max-width: 100%'));
    expect(css, contains('aspect-ratio: 1200 / 825'));
    expect(css, contains('height: auto'));
    expect(bodyOf(html), contains('width="1200"'));
  });

  test('Image.srcSet lets the browser pick the smallest file', () async {
    final html = bodyOf(
      await page(
        const Image.asset(
          'hero.webp',
          width: 1200,
          height: 825,
          srcSet: {640: 'hero-640.webp', 1250: 'hero.webp'},
        ),
      ),
    );
    expect(html, contains('srcset="hero-640.webp 640w, hero.webp 1250w"'));
    expect(html, contains('sizes="(min-width: 1200px) 1200px, 100vw"'));
  });

  group('theme: text roles, breakpoints, extensions', () {
    test('a TextTheme style reads its role variable, value as fallback', () {
      final t = TextTheme();
      expect(
        t.headlineLarge.toCss()['font-size'],
        'var(--t-headline-large-size, 32px)',
      );
      expect(
        ThemeText.labelLarge.toCss()['font-size'],
        'var(--t-label-large-size)',
      );
      // An override is emitted as is; the other values keep the role.
      final custom = t.headlineLarge.copyWith(fontSize: 20).toCss();
      expect(custom['font-size'], '20px');
      expect(custom['line-height'], 'var(--t-headline-large-line, 1.25)');
      expect(
        ThemeText.titleMedium.copyWith(letterSpacing: 0.9).toCss(),
        containsPair('font-size', 'var(--t-title-medium-size)'),
      );
      expect(
        t.headlineLarge.copyWith(color: const Color(0xFFFF0000)).role,
        TextThemeRole.headlineLarge,
      );
    });

    test(
      'ThorApp publishes roles, body text and per-breakpoint changes',
      () async {
        final base = TextTheme(displayLarge: const TextStyle(fontSize: 48));
        final html = await renderDocument(
          ThorApp(
            theme: ThemeData(
              textTheme: base.when(
                medium: base.copyWith(
                  displayLarge: const TextStyle(fontSize: 60),
                ),
              ),
              breakpoints: const Breakpoints(
                medium: 768,
                expanded: 1024,
                large: 1280,
              ),
            ),
            // A role the page reads (the unread ones are left out).
            child: const Text('x', style: ThemeText.displayLarge),
          ),
        );
        final css = head(html);
        expect(css, contains('--t-display-large-size:48px'));
        expect(
          css,
          contains('body{margin:0;background-color:var(--t-surface)'),
        );
        expect(css, contains('font-size:var(--t-body-medium-size, 14px)'));
        // Only the changed role, at the theme's md width.
        expect(
          css,
          contains(
            '@media screen and (min-width: 768px){:root{--t-display-large-size:60px}}',
          ),
        );
      },
    );

    test('Responsive/Grid breakpoints follow ThemeData.breakpoints', () async {
      final html = await renderDocument(
        ThorApp(
          theme: ThemeData(
            breakpoints: const Breakpoints(
              medium: 768,
              expanded: 1024,
              large: 1280,
            ),
          ),
          child: Column(
            children: [
              Grid(
                layout: const GridLayout().when(
                  expanded: const GridLayout(columns: 3),
                ),
                children: const [Text('a')],
              ),
              const ResponsiveVisibility(
                visibleFrom: WindowSizeClass.large,
                child: Text('wide'),
              ),
            ],
          ),
        ),
      );
      final css = head(html);
      expect(css, contains('(min-width: 1024px)'));
      expect(css, contains('(max-width: 1279.98px)'));
      expect(css, isNot(contains('{bp:')));
    });

    test('without a theme the default widths apply', () async {
      final html = await page(
        Styled(
          style: const StyleProps().when(
            medium: const StyleProps(opacity: 0.5),
          ),
          child: const Text('x'),
        ),
      );
      expect(head(html), contains('(min-width: 600px)'));
    });

    test('ThemeExtension: typed lookup and CSS variables', () async {
      final theme = ThemeData(extensions: const [_Shape(radius: 8)]);
      expect(theme.extension<_Shape>()!.radius, 8);
      final html = await renderDocument(
        ThorApp(theme: theme, child: const Text('x')),
      );
      expect(head(html), contains('--t-shape-radius:8px'));
    });
  });

  group('Adaptable.from: values that change per breakpoint', () {
    test('Container padding → @media rule of the same class', () async {
      final html = await page(
        Container(
          padding: const EdgeInsets.all(
            24,
          ).when(medium: const EdgeInsets.all(32)),
          child: const Text('x'),
        ),
      );
      final css = head(html);
      final cls = RegExp(r'<div class="(t\w+)"').firstMatch(bodyOf(html))![1];
      expect(css, contains('.$cls{'));
      expect(css, contains('padding: 24px'));
      expect(
        css,
        contains('@media screen and (min-width: 600px){.$cls{padding: 32px}}'),
      );
      expect(html, isNot(contains('\u27E6')));
    });

    test(
      'Padding, decoration color and text style, with theme widths',
      () async {
        final html = await renderDocument(
          ThorApp(
            theme: ThemeData(
              breakpoints: const Breakpoints(
                medium: 768,
                expanded: 1024,
                large: 1280,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(
                8,
              ).when(expanded: const EdgeInsets.all(16)),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(
                    0xFF000000,
                  ).when(expanded: const Color(0xFFFFFFFF)),
                ),
                child: Text(
                  'x',
                  style: const TextStyle(
                    fontSize: 16,
                  ).when(medium: const TextStyle(fontSize: 20)),
                ),
              ),
            ),
          ),
        );
        final css = head(html);
        expect(css, contains('(min-width: 1024px)'));
        expect(css, contains('margin: 16px'));
        expect(css, contains('background-color: #ffffff'));
        expect(css, contains('font-size: 20px'));
        expect(css, isNot(contains('\u27E6')));
        expect(css, isNot(contains('\u241F')));
      },
    );

    test(
      'without ThorApp the variants still become a scoped media rule',
      () async {
        final html = await render(
          Container(
            padding: const EdgeInsets.all(
              4,
            ).when(medium: const EdgeInsets.all(12)),
            child: const Text('x'),
          ),
        );
        expect(html, contains('@media screen and (min-width: 600px)'));
        expect(html, contains('padding: 12px'));
      },
    );
  });

  group('Adaptable.from: states', () {
    test('hover and group hover become states of the same class', () async {
      final html = await page(
        HoverGroup(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: const Color(
                0xFFEEEEEE,
              ).when(hover: const Color(0xFFFFFFFF)),
            ),
            child: Text(
              '01',
              style: const TextStyle(
                color: Color(0xFF999999),
              ).when(groupHover: const TextStyle(color: Color(0xFF333333))),
            ),
          ),
        ),
      );
      final css = head(html);
      expect(css, matches(RegExp(r'\.t\w+:hover\{background-color: #ffffff')));
      expect(css, contains(':where(.t-group:hover) .t'));
      expect(css, contains('color: #333333'));
      expect(css, contains('transition-property'));
    });
  });
}

class _Shape extends ThemeExtension<_Shape> {
  const _Shape({required this.radius});

  final double radius;

  @override
  CssDeclarations toCssVariables() => {'--t-shape-radius': cssPx(radius)};
}
