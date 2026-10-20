import 'dart:io';
import 'dart:math';

import 'package:test/test.dart';
import 'package:thor_studio/thor_studio.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

final _theme = StudioTheme.light();

/// A whole studio page, like a docs page.
Widget _page() => ThorApp(
  theme: _theme,
  child: const StudioScaffold(
    appBar: StudioTopBar(
      brand: StudioBrand(name: 'thor'),
      links: [
        StudioNavDestination('Guía', href: '/'),
        StudioNavDestination('API', href: '/api'),
      ],
      selectedIndex: 0,
      search: StudioSearchPill(href: '/search', placeholder: 'Buscar'),
      actions: [
        StudioIconButton(
          icon: Icon(StudioIcons.github, size: 18),
          tooltip: 'Repositorio en GitHub',
          href: 'https://github.com',
        ),
      ],
    ),
    drawer: StudioSideNav(
      label: 'Navegación',
      selectedIndex: 0,
      sections: [
        StudioNavSection(
          title: 'Empezar',
          items: [
            StudioNavDestination('Introducción', href: '/intro'),
            StudioNavDestination('Instalación', href: '/install'),
          ],
        ),
      ],
    ),
    tableOfContents: StudioTableOfContents(
      title: 'En esta página',
      entries: [StudioTocEntry('Intro', href: '#intro')],
    ),
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        StudioPageHeader(title: 'Estado reactivo', lead: 'Sin JS.'),
        StudioCodeBlock('final count = state(0);', title: 'a.dart'),
        StudioCallout(title: 'Nota', body: 'Sin cambios.'),
      ],
    ),
    footer: StudioFooter(legal: 'MIT'),
  ),
);

void main() {
  setUpAll(initializeThorTests);

  group('tokens', () {
    test('the theme publishes the palette and the fonts', () async {
      final head = headOfPage(await renderDocument(_page()));
      for (final token in [
        '--t-accent:#4f46e5',
        '--t-canvas:#eff1f6',
        '--t-ink:#0a0b14',
        '--t-faint:#5a5e74',
        '--t-code-keyword:#7c3aed',
      ]) {
        expect(head, contains(token));
      }
      expect(head, contains('Inter'));
    });

    test('the theme self-hosts the fonts with swap', () async {
      final faces = StudioTheme.light(fontsPath: '/assets/fonts').fonts;
      // Inter is one variable face with every weight, fetched with the
      // page.
      expect(faces, hasLength(3));
      final inter = faces.singleWhere((f) => f.family == 'Inter');
      expect(inter.css, contains('font-weight: 100 900'));
      expect(inter.preload, isTrue);
      for (final face in faces) {
        expect(face.css, contains('font-display: swap'));
        expect(face.url, startsWith('/assets/fonts/'));
        expect(face.css, contains('format("woff2")'));
      }
      expect(faces.where((f) => f.family == 'IBM Plex Mono'), hasLength(2));
      final head = headOfPage(await renderDocument(_page()));
      expect(head, contains('@font-face{font-family: "Inter"'));
      expect(head, contains('rel="preload"'));
      expect(head, contains('::selection{background-color:var(--t-selection'));
      expect(head, contains(':focus-visible{outline:2px solid var(--t-accent'));
    });

    test('every palette color is published once, with its light value', () {
      final tokens = StudioTheme.light().colorTokens;
      for (final c in StudioPalette.values) {
        expect(tokens[c.name], c.light);
      }
      expect(tokens, hasLength(StudioPalette.values.length));
      for (final c in StudioSyntaxColors.values) {
        expect(tokens.containsKey(c.name), isTrue, reason: c.name);
      }
    });

    test('text on white meets 4.5:1, down to the faint tone', () {
      // WCAG relative luminance (sRGB → linear).
      double luminance(int argb) {
        double lin(int c) {
          final s = c / 255;
          return s <= 0.03928 ? s / 12.92 : pow((s + 0.055) / 1.055, 2.4) * 1.0;
        }

        final r = (argb >> 16) & 0xFF, g = (argb >> 8) & 0xFF, b = argb & 0xFF;
        return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b);
      }

      double contrast(int a, int b) {
        final (l1, l2) = (luminance(a), luminance(b));
        return (l1 > l2 ? l1 + 0.05 : l2 + 0.05) /
            (l1 > l2 ? l2 + 0.05 : l1 + 0.05);
      }

      const white = 0xFFFFFFFF;
      for (final (name, color) in const [
        ('ink', 0xFF0A0B14),
        ('muted', 0xFF4B4F63),
        ('faint', 0xFF5A5E74),
        ('accent', 0xFF4F46E5),
        ('code-keyword', 0xFF7C3AED),
        ('code-string', 0xFF047857),
        ('code-number', 0xFF0369A1),
        ('code-type', 0xFFC2410C),
      ]) {
        expect(
          contrast(color, white),
          greaterThanOrEqualTo(4.5),
          reason: '$name on white',
        );
      }
      // The faint tone also on the raised rows it is used on; on the canvas
      // only muted is used (the artboard's label).
      expect(contrast(0xFF5A5E74, 0xFFF1F2F7), greaterThanOrEqualTo(4.5));
      expect(contrast(0xFF4B4F63, 0xFFEFF1F6), greaterThanOrEqualTo(4.5));
    });
  });

  group('dark theme', () {
    final dark = StudioTheme.dark();

    Widget both() => ThorApp(
      theme: _theme,
      darkTheme: dark,
      child: const StudioScaffold(
        appBar: StudioTopBar(
          brand: StudioBrand(name: 'thor'),
          actions: [ThemeToggle(light: Text('sol'), dark: Text('luna'))],
        ),
        body: Text('cuerpo'),
      ),
    );

    test('StudioTheme.dark is the same system with the dark side', () {
      expect(dark.colorScheme.brightness, Brightness.dark);
      expect(_theme.colorScheme.brightness, Brightness.light);
      // The roles point at the same variables: only the values change.
      expect(dark.colorScheme.primary, _theme.colorScheme.primary);
      expect(dark.colorScheme.surface, _theme.colorScheme.surface);
      expect(dark.fonts.map((f) => f.url), _theme.fonts.map((f) => f.url));
      expect(dark.colorTokens.keys, _theme.colorTokens.keys);
      for (final c in StudioPalette.values) {
        expect(dark.colorTokens[c.name], c.dark);
        expect(c.dark, isNot(c.light), reason: '${c.name} has a dark value');
      }
      expect(
        StudioTheme.dark(fontsPath: '/a').fonts.first.url,
        startsWith('/a/'),
      );
    });

    test('the page publishes both sides of every color', () async {
      final head = headOfPage(await renderDocument(both()));
      expect(head, contains('--t-accent:light-dark(#4f46e5,'));
      expect(head, contains('--t-ink:light-dark(#0a0b14,'));
      expect(head, contains('--t-code-keyword:light-dark(#7c3aed,'));
      expect(head, contains('color-scheme:'));
    });

    test('the Material roles follow the dark side too (no flat hex)', () async {
      // A role published as its token's light hex would stay light in the
      // dark theme: `body` paints with `--t-surface` / `--t-on-surface`.
      final head = headOfPage(await renderDocument(both()));
      expect(head, contains('--t-surface:var(--t-app)'));
      expect(head, contains('--t-on-surface:var(--t-ink)'));
      expect(head, contains('--t-primary:var(--t-action)'));
      expect(head, contains('--t-error:var(--t-danger)'));
    });

    test('dialogs, drawers and tooltips take the studio surfaces', () async {
      // Their Material fallbacks are lavender light values: without the
      // roles a dark theme's dialog is light text on a light card.
      final head = headOfPage(await renderDocument(both()));
      expect(head, contains('--t-surface-container-low:var(--t-panel)'));
      expect(head, contains('--t-surface-container-high:var(--t-panel)'));
      expect(head, contains('--t-inverse-surface:var(--t-ink)'));
      expect(head, contains('--t-inverse-on-surface:var(--t-panel)'));
    });

    test('the switch ships with the page, no JavaScript file', () async {
      final doc = await renderDocument(both());
      expect(doc, contains('sol'));
      expect(doc, contains('luna'));
      expect(doc, contains('<label'));
      expect(doc, contains('type="checkbox"'));
      expect(doc, isNot(contains('src="')));
    });

    test('no component paints an opaque literal color', () {
      // A literal is the same in both themes: every color is a token
      // variable (Colors.transparent for a reset).
      final literal = RegExp(r'Color\(0x[0-9A-Fa-f]{2}[0-9A-Fa-f]{6}\)');
      for (final file in Directory(
        'lib/src',
      ).listSync(recursive: true).whereType<File>()) {
        // The tokens are where the literals live (the v1 shims only alias).
        if (file.path.contains('/tokens/') || !file.path.endsWith('.dart')) {
          continue;
        }
        for (final m in literal.allMatches(file.readAsStringSync())) {
          fail('${file.path} paints ${m[0]} in both themes');
        }
      }
    });
  });

  group('contrast, light and dark', () {
    // WCAG relative luminance (sRGB → linear).
    double luminance(Color c) {
      double lin(int v) {
        final s = v / 255;
        return s <= 0.03928 ? s / 12.92 : pow((s + 0.055) / 1.055, 2.4) * 1.0;
      }

      final argb = c.value;
      return 0.2126 * lin((argb >> 16) & 0xFF) +
          0.7152 * lin((argb >> 8) & 0xFF) +
          0.0722 * lin(argb & 0xFF);
    }

    double ratio(Color a, Color b) {
      final (l1, l2) = (luminance(a), luminance(b));
      return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05);
    }

    // Where each color is used: text 4.5:1 (also at 12–13px), icons,
    // the focus ring and the primary action 3:1 (WCAG 1.4.11).
    final text = <(ColorToken, ColorToken)>[
      (StudioContentColors.ink, StudioSurfaceColors.panel),
      (StudioContentColors.ink, StudioSurfaceColors.app),
      (StudioContentColors.ink, StudioSurfaceColors.raised),
      (StudioContentColors.ink, StudioSurfaceColors.hover),
      (StudioContentColors.inkSoft, StudioSurfaceColors.panel),
      (StudioContentColors.muted, StudioSurfaceColors.panel),
      (StudioContentColors.muted, StudioSurfaceColors.raised),
      (StudioContentColors.muted, StudioSurfaceColors.hover),
      (StudioContentColors.muted, StudioSurfaceColors.canvas),
      (StudioContentColors.faint, StudioSurfaceColors.panel),
      (StudioContentColors.faint, StudioSurfaceColors.raised),
      (StudioAccentColors.accent, StudioSurfaceColors.panel),
      (StudioAccentColors.accent, StudioAccentColors.accentTint),
      (StudioAccentColors.accent, StudioAccentColors.accentWash),
      (StudioAccentColors.accentInk, StudioAccentColors.accent),
      (StudioStatusColors.ok, StudioSurfaceColors.panel),
      (StudioStatusColors.warn, StudioSurfaceColors.panel),
      (StudioStatusColors.danger, StudioSurfaceColors.panel),
      (StudioStatusColors.danger, StudioSurfaceColors.raised),
      (StudioStatusColors.danger, StudioSurfaceColors.app),
      // A chip paints its tone's color as text on the tone's background.
      (StudioStatusColors.ok, StudioStatusColors.okBg),
      (StudioStatusColors.warn, StudioStatusColors.warnBg),
      (StudioStatusColors.danger, StudioStatusColors.dangerBg),
      (StudioAccentColors.accent, StudioStatusColors.infoBg),
      // A tooltip or a snackbar: inverse surface, its text and its action.
      (StudioSurfaceColors.panel, StudioContentColors.ink),
      (StudioAccentColors.accentTint, StudioContentColors.ink),
      (StudioContentColors.ink, StudioStatusColors.infoBg),
      (StudioContentColors.ink, StudioStatusColors.okBg),
      (StudioContentColors.ink, StudioStatusColors.warnBg),
      (StudioContentColors.ink, StudioStatusColors.dangerBg),
      for (final c in StudioSyntaxColors.values) (c, StudioSurfaceColors.panel),
      for (final c in StudioSyntaxColors.values)
        (c, StudioSurfaceColors.raised),
    ];
    // The callout's tone icons, on their tinted backgrounds (3:1).
    final icons = <(ColorToken, ColorToken)>[
      (StudioAccentColors.accent, StudioStatusColors.infoBg),
      (StudioStatusColors.ok, StudioStatusColors.okBg),
      (StudioStatusColors.warn, StudioStatusColors.warnBg),
      (StudioStatusColors.danger, StudioStatusColors.dangerBg),
      (StudioContentColors.muted, StudioSurfaceColors.panel),
    ];
    for (final dark in [false, true]) {
      Color side(ColorToken t) => dark ? t.dark : t.light;
      final mode = dark ? 'dark' : 'light';
      test('text meets 4.5:1 in the $mode theme', () {
        for (final (fg, bg) in text) {
          expect(
            ratio(side(fg), side(bg)),
            greaterThanOrEqualTo(4.5),
            reason: '${fg.name} on ${bg.name}',
          );
        }
      });

      test('icons meet 3:1 in the $mode theme', () {
        for (final (fg, bg) in icons) {
          expect(
            ratio(side(fg), side(bg)),
            greaterThanOrEqualTo(3),
            reason: '${fg.name} on ${bg.name}',
          );
        }
      });

      test('the focus ring and the accent meet 3:1 in the $mode theme', () {
        for (final bg in [
          StudioSurfaceColors.panel,
          StudioSurfaceColors.app,
          StudioSurfaceColors.canvas,
          StudioSurfaceColors.raised,
        ]) {
          expect(
            ratio(side(StudioAccentColors.accent), side(bg)),
            greaterThanOrEqualTo(3),
            reason: 'accent on ${bg.name}',
          );
        }
      });

      test('the dark side is darker than its panels, the light lighter', () {
        final app = luminance(side(StudioSurfaceColors.app));
        final ink = luminance(side(StudioContentColors.ink));
        expect(dark ? app < ink : app > ink, isTrue);
      });
    }
  });

  group('v2 scheme: contrast in both themes', () {
    double luminance(Color c) {
      double lin(int v) {
        final s = v / 255;
        return s <= 0.03928 ? s / 12.92 : pow((s + 0.055) / 1.055, 2.4) * 1.0;
      }

      final argb = c.value;
      return 0.2126 * lin((argb >> 16) & 0xFF) +
          0.7152 * lin((argb >> 8) & 0xFF) +
          0.0722 * lin(argb & 0xFF);
    }

    double ratio(Color a, Color b) {
      final (l1, l2) = (luminance(a), luminance(b));
      return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05);
    }

    // The component themes' own pairs, read from their defaults: a theme
    // that sets a text color on a surface must pass.
    final bench = StudioBenchThemeData.resolve(StudioTheme.light());
    final segmented = StudioSegmentedButtonThemeData.resolve(
      StudioTheme.light(),
    );
    final slider = StudioSliderThemeData.resolve(StudioTheme.light());
    final button = StudioButtonThemeData.resolve(StudioTheme.light());
    final chip = StudioChipThemeData.resolve(StudioTheme.light());
    final nav = StudioNavThemeData.resolve(StudioTheme.light());
    final callout = StudioCalloutThemeData.resolve(StudioTheme.light());
    final code = StudioCodeThemeData.resolve(StudioTheme.light());
    final card = StudioCardThemeData.resolve(StudioTheme.light());
    final panel = StudioPanelThemeData.resolve(StudioTheme.light());
    final cs = StudioTheme.colorScheme(Brightness.light);
    const x = StudioExtraColors.standard;

    final text = <(String, Color, Color)>[
      ('ink on page', cs.onSurface, cs.surface),
      ('ink on card', cs.onSurface, cs.surfaceContainer),
      ('ink-soft on card', x.onSurfaceSoft, cs.surfaceContainer),
      ('muted on page', cs.onSurfaceVariant!, cs.surface),
      ('muted on canvas', cs.onSurfaceVariant!, cs.surfaceContainerLowest!),
      ('muted on card', cs.onSurfaceVariant!, cs.surfaceContainer),
      ('muted on raised', cs.onSurfaceVariant!, cs.surfaceContainerHighest!),
      ('muted on hover', cs.onSurfaceVariant!, x.hover),
      ('faint on card', x.onSurfaceFaint, cs.surfaceContainer),
      ('faint on raised', x.onSurfaceFaint, cs.surfaceContainerHighest!),
      ('accent text on card', cs.accent, cs.surfaceContainer),
      ('accent text on page', cs.accent, cs.surface),
      ('onAction on action', cs.onPrimary, cs.primary),
      ('onAction on action hover', cs.onPrimary, x.primaryHover),
      ('onAccent on accent', cs.onAccent, cs.accent),
      ('ink on accent container', cs.onSurface, cs.accentContainer),
      ('accent on accent container', cs.accent, cs.accentContainer),
      ('accent on accent wash', cs.accent, x.accentWash),
      // Button, chip and nav labels.
      ('filled label', button.onFilledColor, button.filledColor),
      ('filled label hover', button.onFilledColor, button.filledHoverColor),
      ('tonal label', button.onTonalColor, button.tonalColor),
      ('tonal label hover', button.onTonalColor, button.tonalHoverColor),
      ('text button on page', button.textColor, cs.surface),
      ('chip label', chip.labelColor, chip.color),
      ('chip label hover', chip.labelColor, chip.hoverColor),
      ('selected chip', chip.selectedLabelColor, chip.selectedColor),
      ('nav item on bar', nav.itemColor, nav.barColor),
      ('nav item hover', nav.itemColor, nav.itemHoverColor),
      ('current nav item', nav.currentMarkColor, nav.selectedItemBackground),
      // Layout and navigation (the top bar, sidebar, search pill, footer).
      ('nav item on card (the drawer)', nav.itemColor, cs.surfaceContainer),
      (
        'current item on card',
        nav.currentMarkColor,
        nav.selectedItemBackground,
      ),
      ('search placeholder', nav.hintColor, nav.searchColor),
      ('search placeholder on hover', nav.hintColor, nav.searchHoverColor),
      ('key hint', nav.hintColor, nav.hintBackground),
      ('section title on page', nav.sectionTitleColor, cs.surface),
      ('section title on card', nav.sectionTitleColor, cs.surfaceContainer),
      ('section title on hover', nav.sectionTitleColor, nav.itemHoverColor),
      ('ink on search pill', nav.selectedItemColor, nav.searchColor),
      ('ink on card (pager title)', cs.onSurface, card.color),
      ('muted on card (pager caption)', nav.hintColor, card.color),
      ('chip label on page (page header eyebrow)', chip.labelColor, chip.color),
      // The bench.
      ('ink on stage', cs.onSurface, bench.stageColor),
      ('muted on stage', cs.onSurfaceVariant!, bench.stageColor),
      ('ink on panel', cs.onSurface, bench.panelColor),
      ('muted on segmented track', cs.onSurfaceVariant!, segmented.trackColor),
      (
        'chosen label on chosen segment',
        segmented.selectedLabelColor,
        segmented.selectedColor,
      ),
      ('accent on canvas (code links)', cs.accent, cs.surfaceContainerLowest!),
      ('accent on info callout', cs.accent, callout.info.background),
      ('ink on level track', cs.onSurface, slider.trackColor),
      ('ink on level fill', cs.onSurface, slider.fillColor),
      ('muted on level track', cs.onSurfaceVariant!, slider.trackColor),
      // Code and callouts.
      ('code header', code.headerTextColor, code.color),
      ('ink on code', cs.onSurface, code.color),
      ('panel title', panel.titleColor, panel.color),
      ('card ink', cs.onSurface, card.color),
      for (final (name, tone) in [
        ('info', callout.info),
        ('ok', callout.ok),
        ('warn', callout.warn),
        ('danger', callout.danger),
      ]) ...[
        ('$name callout text', tone.foreground, tone.background),
        ('ink on $name callout', cs.onSurface, tone.background),
      ],
      for (final c in StudioSyntaxColors.values) ...[
        ('${c.name} on code', c, code.color),
        ('${c.name} on card', c, cs.surfaceContainer),
      ],
    ];

    // Non-text: the focus ring, the primary pill, the icons of a tone.
    final graphics = <(String, Color, Color)>[
      for (final (name, bg) in [
        ('page', cs.surface),
        ('canvas', cs.surfaceContainerLowest!),
        ('card', cs.surfaceContainer),
        ('raised', cs.surfaceContainerHighest!),
        ('hover', x.hover),
        ('stage', bench.stageColor),
        ('segmented track', segmented.trackColor),
        ('level track', slider.trackColor),
        ('accent container', cs.accentContainer),
      ])
        ('focus ring on $name', cs.accent, bg),
      // A field's border (WCAG 1.4.11): the page, the stage, the panel.
      for (final (name, bg) in [
        ('page', cs.surface),
        ('canvas', cs.surfaceContainerLowest!),
        ('card', cs.surfaceContainer),
        ('raised', cs.surfaceContainerHighest!),
        ('stage', bench.stageColor),
        ('panel', bench.panelColor),
      ])
        ('field border on $name', StudioBorderColors.field, bg),
      ('primary pill on page', cs.primary, cs.surface),
      ('primary pill on card', cs.primary, cs.surfaceContainer),
      ('muted icon on card', cs.onSurfaceVariant!, cs.surfaceContainer),
      ('search icon on pill', nav.hintColor, nav.searchColor),
      ('theme toggle icon on page', nav.hintColor, cs.surface),
      ('breadcrumb separator on page', nav.sectionTitleColor, cs.surface),
      for (final (name, tone) in [
        ('info', callout.info),
        ('ok', callout.ok),
        ('warn', callout.warn),
        ('danger', callout.danger),
      ])
        ('$name icon', tone.foreground, tone.background),
    ];

    for (final dark in [false, true]) {
      Color side(Color c) =>
          dark ? (c as ColorToken).dark : (c as ColorToken).light;
      final mode = dark ? 'dark' : 'light';
      test('every text pair meets 4.5:1 in the $mode theme', () {
        for (final (name, fg, bg) in text) {
          expect(
            ratio(side(fg), side(bg)),
            greaterThanOrEqualTo(4.5),
            reason: name,
          );
        }
      });

      test('focus, the pill and the icons meet 3:1 in the $mode theme', () {
        for (final (name, fg, bg) in graphics) {
          expect(
            ratio(side(fg), side(bg)),
            greaterThanOrEqualTo(3),
            reason: name,
          );
        }
      });
    }

    test('the theme gives fields the field-line border', () async {
      final html = await renderDocument(
        ThorApp(
          theme: StudioTheme.dark(),
          child: const TextField(
            decoration: InputDecoration(labelText: 'Nombre'),
          ),
        ),
      );
      expect(html, contains('var(--t-field-line)'));
      expect(html, isNot(contains('rgb(0,0,0)')));
    });

    test('brand values: cool surfaces and the indigo pill', () {
      expect(StudioSurfaceColors.app.light, const Color(0xFFF6F7FB));
      expect(StudioSurfaceColors.app.dark, const Color(0xFF0B0D17));
      expect(StudioSurfaceColors.panel.dark, const Color(0xFF12141F));
      expect(StudioSurfaceColors.raised.dark, const Color(0xFF1A1D2B));
      expect(StudioSurfaceColors.panel.light, const Color(0xFFFFFFFF));
      expect(StudioActionColors.action.light, const Color(0xFF4F46E5));
      expect(StudioActionColors.action.dark, const Color(0xFF818CF8));
    });

    test('shape and motion tokens', () {
      expect(StudioRadii.card, 28);
      expect(StudioRadii.control, 999);
      expect(StudioRadii.inner, 12);
      expect(StudioDurations.fast, const Duration(milliseconds: 120));
      expect(StudioDurations.base, const Duration(milliseconds: 160));
      expect(StudioDurations.slow, const Duration(milliseconds: 200));
      expect(StudioCurves.enter.css, 'cubic-bezier(0.23, 1, 0.32, 1)');
      expect(StudioMotion.pressScale, 0.97);
    });
  });

  group('highlightCode', () {
    String kinds(String source) => highlightCode(source)
        .where((r) => r.$1 != CodeToken.plain)
        .map((r) => '${r.$1.name}:${r.$2}')
        .join(' ');

    test('keywords, types, numbers, strings and comments', () {
      expect(
        kinds(
          "class A extends ThorState { final n = 0x1F; String s = 'x'; } // c",
        ),
        'keyword:class type:A keyword:extends type:ThorState keyword:final '
        "number:0x1F type:String string:'x' comment:// c",
      );
    });

    test('a comment marker inside a string is string', () {
      expect(kinds("print('// no'); // yes"), "string:'// no' comment:// yes");
    });

    test('escaped quotes and raw strings stay one string', () {
      expect(
        kinds(
          r"'it\'s' r'\d+' "
          '"a \\"b\\""',
        ),
        contains(r"string:'it\'s'"),
      );
      expect(kinds(r"r'\d+'"), r"string:r'\d+'");
      expect(kinds('"a \\"b\\""'), 'string:"a \\"b\\""');
    });

    test('block comments and multiline strings span lines', () {
      expect(kinds('/* a\n b */ x'), 'comment:/* a\n b */');
      expect(kinds("'''a\nb'''"), "string:'''a\nb'''");
    });

    test('the text is kept exactly', () {
      const source = "void main() {\n  print('hi'); // x\n}\n";
      expect(highlightCode(source).map((r) => r.$2).join(), source);
    });

    test('as HTML: escaped, one span per token kind', () {
      expect(
        highlightToHtml("final a = '<b>'; // x"),
        '<span class="studio-tok-keyword">final</span> a = '
        '<span class="studio-tok-string">\'&lt;b&gt;\'</span>; '
        '<span class="studio-tok-comment">// x</span>',
      );
      expect(highlightToHtml('<a>', language: 'html'), '&lt;a&gt;');
      expect(
        highlightToHtml('{"a": 1}', language: 'json'),
        '{<span class="studio-tok-string">"a"</span>: '
        '<span class="studio-tok-number">1</span>}',
      );
    });

    test('annotations and lowercase built-in types', () {
      expect(
        kinds('@override double f(int n, bool b) => n;'),
        'keyword:@override type:double type:int type:bool',
      );
    });

    test('a lowercase identifier is plain', () {
      expect(kinds('count.value++'), isEmpty);
    });
  });
}
