import 'dart:io';
import 'dart:math';

import 'package:test/test.dart';
import 'package:thor_studio/thor_studio.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

final _theme = StudioTheme.light();

Future<String> _render(Widget child) async =>
    bodyOfPage(await renderDocument(ThorApp(theme: _theme, child: child)));

/// The page's stylesheet (where a widget's CSS is), spaces removed.
Future<String> _css(Widget child) async => headOfPage(
  await renderDocument(ThorApp(theme: _theme, child: child)),
).replaceAll(RegExp(r'\s+'), '');

int _count(String html, Pattern pattern) => pattern.allMatches(html).length;

const _source = 'final a = 1;\nfinal b = 2;\nfinal c = 3;';

void main() {
  setUpAll(initializeThorTests);

  group('line ranges and diffs', () {
    test('parse reads a fence-like spec and skips what is not a range', () {
      expect(StudioLineRange.parse('2-4,7'), [
        const StudioLineRange(2, 4),
        const StudioLineRange(7),
      ]);
      expect(StudioLineRange.parse('x, 0, 3 - 5'), [
        const StudioLineRange(3, 5),
      ]);
      expect(const StudioLineRange(2, 4).contains(4), isTrue);
      expect(const StudioLineRange(2, 4).contains(5), isFalse);
    });

    test(
      'added is what the other code does not have, ignoring indentation',
      () {
        expect(StudioCodeDiff.added('a\nb\nc', 'a\n  b\nx\ny\nc'), [
          const StudioLineRange(3, 4),
        ]);
        expect(StudioCodeDiff.added('a\nb', 'a\n\nb'), isEmpty);
      },
    );
  });

  group('StudioCodeBlock', () {
    test('is a <pre> whose text is the exact source', () async {
      final html = await _render(const StudioCodeBlock(_source));
      expect(html, contains('<pre'));
      final pre = RegExp(r'<pre[^>]*>([\s\S]*?)</pre>').firstMatch(html)!;
      final text = pre[1]!.replaceAll(RegExp(r'<[^>]+>'), '');
      expect(text, _source);
    });

    test(
      'keeps the source text with marked lines (one run per mark)',
      () async {
        final html = await _render(
          const StudioCodeBlock(
            _source,
            highlight: [StudioLineRange(2)],
            changed: [StudioLineRange(3)],
          ),
        );
        final pre = RegExp(r'<pre[^>]*>([\s\S]*?)</pre>').firstMatch(html)!;
        expect(pre[1]!.replaceAll(RegExp(r'<[^>]+>'), ''), _source);
        // Three runs: plain, highlighted, changed.
        expect(_count(pre[1]!, '<div '), 2);
      },
    );

    test(
      'the header, the language and the copy strings are parameters',
      () async {
        final html = await _render(
          const StudioCodeBlock(
            _source,
            title: 'main.dart',
            copyLabel: 'Copiar',
            copiedLabel: 'Copiado',
          ),
        );
        expect(html, contains('main.dart'));
        // No language label: the file name is the header.
        expect(html, isNot(contains('>dart<')));
        expect(html, contains('data-studio-copy="Copiado"'));
        expect(html, contains('Copiar</button>'));
        expect(html, contains('type="button"'));
        expect(html, isNot(contains('Copy')));
      },
    );

    test('copyButton: false leaves only selectable text', () async {
      final html = await _render(
        const StudioCodeBlock(_source, copyButton: false),
      );
      expect(html, isNot(contains('<button')));
      expect(html, isNot(contains('data-studio-copy')));
    });

    test(
      'without a copyLabel the button speaks the page\'s language',
      () async {
        final en = await _render(const StudioCodeBlock(_source));
        // The floating button is the icon alone, named by its label.
        expect(en, contains('aria-label="Copy"'));
        expect(en, contains('data-studio-copy="Copied"'));
        final es = bodyOfPage(
          await renderDocument(
            ThorApp(
              theme: _theme,
              locale: const Locale('es'),
              supportedLocales: StudioLocalizations.supportedLocales,
              localizationsDelegates: [StudioLocalizations.delegate],
              child: const StudioCodeBlock(_source),
            ),
          ),
        );
        expect(es, contains('aria-label="Copiar"'));
        expect(es, contains('data-studio-copy="Copiado"'));
      },
    );

    test(
      'the copy button hides itself until the script marks the page',
      () async {
        final doc = await renderDocument(
          ThorApp(
            theme: _theme,
            child: const StudioCodeBlock(_source, copyLabel: 'Copiar'),
          ),
        );
        expect(doc, contains(':root:not([data-studio-js])'));
      },
    );

    test(
      'the copy strip follows the block width (container), not the window',
      () async {
        final css = await _css(
          const StudioCodeBlock(_source, copyLabel: 'Copiar'),
        );
        // The block is a size container; the strip goes at its own 480px.
        expect(css, contains('container-type:inline-size'));
        expect(css, contains('@container(min-width:480px)'));
        // No viewport breakpoint decides it (the `sm` media query).
        final media = RegExp(r'@media[^{]*\{[^{}]*\{[^}]*padding[^}]*\}');
        expect(media.hasMatch(css), isFalse);
      },
    );

    test('the code scrolls inside itself and is keyboard reachable', () async {
      final html = await _render(const StudioCodeBlock(_source));
      expect(html, contains('tabindex="0"'));
      expect(html, contains('role="group"'));
      final css = await _css(const StudioCodeBlock(_source));
      expect(css, contains('overflow-x:auto'));
      expect(css, contains('width:max-content'));
    });

    test('shell, YAML and JSON are colored too', () async {
      final yaml = await _render(
        const StudioCodeBlock(
          '# note\nname: "x"\nport: 8080',
          language: StudioCodeLanguage.yaml,
        ),
      );
      final yamlCss = await _css(
        const StudioCodeBlock(
          '# note\nname: "x"\nport: 8080',
          language: StudioCodeLanguage.yaml,
        ),
      );
      for (final kind in ['comment', 'string', 'number']) {
        expect(yamlCss, contains('var(--t-code-$kind'));
      }
      expect(yaml, contains('# note'));
      final jsonCss = await _css(
        const StudioCodeBlock(
          '{"a": [1, true, null]}',
          language: StudioCodeLanguage.json,
        ),
      );
      expect(jsonCss, contains('var(--t-code-keyword'));
    });
  });

  group('language', () {
    test('the language colors and labels the block', () async {
      const block = StudioCodeBlock(
        '# note\nname: "x"',
        title: 'pubspec.yaml',
        language: StudioCodeLanguage.yaml,
      );
      final html = await _render(block);
      expect(html, contains('pubspec.yaml'));
      expect(await _css(block), contains('var(--t-code-comment'));
    });

    test('a name read at run time maps to the enum', () {
      expect(StudioCodeLanguage.fromName('sh'), StudioCodeLanguage.bash);
      expect(StudioCodeLanguage.fromName('yml'), StudioCodeLanguage.yaml);
      expect(StudioCodeLanguage.fromName('dart'), StudioCodeLanguage.dart);
      expect(StudioCodeLanguage.fromName('klingon'), StudioCodeLanguage.plain);
      expect(StudioCodeLanguage.fromName(null), StudioCodeLanguage.plain);
    });
  });

  group('native selectors, no JavaScript', () {
    test('StudioCodeTabs: one radio per tab, one panel per tab', () async {
      final html = await _render(
        const StudioCodeTabs(
          id: 'tabs',
          tabs: [
            StudioCodeTab(label: 'main.dart', code: 'a'),
            StudioCodeTab(
              label: 'pubspec.yaml',
              code: 'b',
              language: StudioCodeLanguage.yaml,
            ),
          ],
          copyLabel: 'Copiar',
        ),
      );
      expect(_count(html, 'type="radio"'), 2);
      expect(_count(html, 'name="tabs"'), 2);
      expect(_count(html, ' checked'), 1);
      expect(html, contains('role="radiogroup"'));
      expect(html, contains('main.dart'));
      expect(html, contains('pubspec.yaml'));
      expect(html, contains('id="tabs-panel-0"'));
      expect(html, contains('id="tabs-panel-1"'));
      expect(_count(html, 'data-studio-copy'), 2);
    });

    test(
      'a panel is hidden by CSS only while another radio is checked',
      () async {
        final doc = await renderDocument(
          ThorApp(
            theme: _theme,
            child: const StudioCodeTabs(
              id: 'tabs',
              tabs: [
                StudioCodeTab(label: 'a', code: 'a'),
                StudioCodeTab(label: 'b', code: 'b'),
              ],
            ),
          ),
        );
        expect(doc, contains('input[name="tabs"]:checked:not([value="1"])'));
      },
    );

    test(
      'StudioFlutterCompare: Flutter and Thor labels from parameters',
      () async {
        final html = await _render(
          const StudioFlutterCompare(
            id: 'cmp',
            flutterCode: 'setState(() => n++);',
            thorCode: 'n.value++;',
            flutterLabel: 'En Flutter',
            thorLabel: 'En Thor',
            initialIndex: 0,
          ),
        );
        expect(_count(html, 'type="radio"'), 2);
        expect(html, contains('En Flutter'));
        expect(html, contains('En Thor'));
        expect(html, contains('setState(() =&gt; n++);'));
        expect(html, contains('n.value++;'));
        // The first side is the one that is open.
        expect(RegExp(r'value="0"[^>]*checked').hasMatch(html), isTrue);
      },
    );

    test(
      'StudioFlutterCompare marks the lines that differ on each side',
      () async {
        final html = await _render(
          const StudioFlutterCompare(
            flutterCode: 'same();\nonlyFlutter();',
            thorCode: 'same();\nonlyThor();',
          ),
        );
        // One marked band per side (and none for the shared line).
        expect(_count(html, '<div class="t-_run'), 2);
        final plain = await _render(
          const StudioFlutterCompare(
            flutterCode: 'same();\nonlyFlutter();',
            thorCode: 'same();\nonlyThor();',
            markChanges: false,
          ),
        );
        expect(_count(plain, '<div class="t-_run'), 0);
      },
    );

    test('StudioCompareSummary: two lines with their labels', () async {
      final html = await _render(
        const StudioCompareSummary(
          flutter: 'setState(() => n++)',
          thor: 'n.value++',
          flutterLabel: 'En Flutter',
          thorLabel: 'En Thor',
        ),
      );
      expect(html, contains('En Flutter'));
      expect(html, contains('En Thor'));
      expect(html, contains('n.value++'));
      expect(_count(html, '<li'), 2);
    });

    test(
      'StudioLayerDiagram: every layer from the data, with its compare',
      () async {
        const layers = [
          StudioLayer(
            title: 'View',
            kind: 'Widget',
            description: 'Shows the state.',
            flutterCode: 'ViewFlutter();',
            thorCode: 'ViewThor();',
          ),
          StudioLayer(
            title: 'ViewModel',
            description: 'Holds the state.',
            flutterCode: 'VmFlutter();',
            thorCode: 'VmThor();',
          ),
          StudioLayer(
            title: 'Service',
            description: 'Talks to the server.',
            flutterCode: 'ServiceFlutter();',
            thorCode: 'ServiceThor();',
          ),
        ];
        final html = await _render(
          const StudioLayerDiagram(
            id: 'layers',
            layers: layers,
            flutterLabel: 'En Flutter',
            thorLabel: 'En Thor',
            copyLabel: 'Copiar',
          ),
        );
        // 3 layer radios + 3 compares of 2 radios.
        expect(_count(html, 'type="radio"'), 3 + 3 * 2);
        expect(_count(html, 'name="layers"'), 3);
        for (final layer in layers) {
          expect(html, contains(layer.title));
          expect(html, contains(layer.description));
          expect(html, contains(layer.thorCode.replaceAll('();', '')));
        }
        expect(html, contains('Widget'));
        expect(_count(html, 'name="layers-code-'), 6);
        expect(_count(html, '>En Thor<'), 3);
        // The arrows between layers are decoration: two of three.
        expect(_count(html, 'href="#lucide-arrow-right"'), 2);
      },
    );
  });

  group('callouts, steps, cards', () {
    test(
      'StudioCallout is a note named by its title, one icon per tone',
      () async {
        final icons = <String>{};
        // Neutral is a chip's tone: a callout draws it as an info note.
        final tones = StudioTone.values.where((t) => t != StudioTone.neutral);
        for (final tone in tones) {
          final html = await _render(
            StudioCallout(tone: tone, title: 'Ojo', body: 'Texto'),
          );
          expect(html, contains('role="note"'));
          expect(html, contains('aria-label="Ojo"'));
          expect(html, contains('Texto'));
          icons.add(RegExp(r'href="#(lucide-[a-z-]+)"').firstMatch(html)![1]!);
        }
        expect(icons, hasLength(tones.length));
      },
    );

    test('StudioCallout takes widgets as its content', () async {
      final html = await _render(
        const StudioCallout(title: 'T', child: Text('Dentro')),
      );
      expect(html, contains('Dentro'));
    });

    test(
      'StudioSteps is a list; the number is hidden from assistive tech',
      () async {
        final html = await _render(
          const StudioSteps(
            headingLevel: 2,
            steps: [
              StudioStep(title: 'Uno', body: 'Texto'),
              StudioStep(title: 'Dos', code: 'x', codeTitle: 'a.dart'),
            ],
            copyLabel: 'Copiar',
          ),
        );
        expect(html, contains('<ul'));
        expect(_count(html, '<li'), 2);
        expect(html, contains('<h2'));
        expect(html, contains('Uno'));
        expect(html, contains('a.dart'));
        expect(html, contains('aria-hidden="true"'));
      },
    );

    test(
      'StudioSteps.diff marks what a step adds over the previous one',
      () async {
        final html = await _render(
          const StudioSteps.diff(
            steps: [
              StudioStep(title: 'Uno', code: 'a();\nb();'),
              StudioStep(title: 'Dos', code: 'a();\nb();\nc();'),
            ],
          ),
        );
        // Only the second step has a changed line (the third one).
        expect(_count(html, '<div class="t-_run'), 1);
        final plain = await _render(
          const StudioSteps(
            steps: [
              StudioStep(title: 'Uno', code: 'a();\nb();'),
              StudioStep(title: 'Dos', code: 'a();\nb();\nc();'),
            ],
          ),
        );
        expect(_count(plain, '<div class="t-_run'), 0);
      },
    );

    test('StudioLinkCard is one link; external opens a new tab', () async {
      final html = await _render(
        const StudioCardGrid(
          children: [
            StudioLinkCard(title: 'Estado', href: '/estado', description: 'D'),
            StudioLinkCard(
              title: 'GitHub',
              href: 'https://github.com',
              external: true,
            ),
          ],
        ),
      );
      expect(_count(html, '<a '), 2);
      expect(html, contains('href="/estado"'));
      expect(html, contains('target="_blank"'));
      expect(html, contains('Estado'));
      expect(html, contains('lucide-arrow-up-right'));
    });

    test(
      'StudioCardGrid is one column on a phone and [columns] from md up',
      () async {
        final css = await _css(
          const StudioCardGrid(
            columns: 3,
            children: [Text('a'), Text('b'), Text('c')],
          ),
        );
        expect(css, contains('grid-template-columns:repeat(1,minmax(0,1fr))'));
        expect(css, contains('grid-template-columns:repeat(3,minmax(0,1fr))'));
      },
    );
  });

  group('file tree, kbd, table, prose', () {
    test('StudioFileTree is a nested list', () async {
      final html = await _render(
        const StudioFileTree(
          label: 'Proyecto',
          entries: [
            StudioFileEntry(
              'lib/',
              children: [StudioFileEntry('main.dart', note: 'Arranca')],
            ),
            StudioFileEntry('pubspec.yaml'),
          ],
        ),
      );
      expect(_count(html, '<ul'), 2);
      expect(_count(html, '<li'), 3);
      expect(html, contains('aria-label="Proyecto"'));
      expect(html, contains('main.dart'));
      expect(html, contains('Arranca'));
      expect(html, contains('lucide-folder'));
      expect(html, contains('lucide-file'));
    });

    test('StudioKbd is a keyboard key with an optional spoken name', () async {
      final html = await _render(
        const StudioKbd('⌘', semanticLabel: 'Command'),
      );
      expect(html, contains('<kbd'));
      expect(html, contains('aria-label="Command"'));
      expect(html, contains('⌘'));
    });

    test(
      'StudioDataTable is a real table with headers from the parameters',
      () async {
        final html = await _render(
          const StudioDataTable(
            columns: [
              DataColumn(label: Text('Página')),
              DataColumn(label: Text('JS'), numeric: true),
            ],
            rows: [
              DataRow(
                cells: [DataCell(Text('Contador')), DataCell(Text('24.8 KB'))],
              ),
              DataRow(
                cells: [DataCell(Text('Lista')), DataCell(Text('30 KB'))],
              ),
            ],
          ),
        );
        expect(html, contains('<table'));
        expect(_count(html, RegExp(r'<th[ >]')), 2);
        expect(_count(html, RegExp(r'<td[ >]')), 4);
        expect(html, contains('Página'));
        expect(html, contains('30 KB'));
      },
    );

    test('StudioProse writes the markup and styles its tags', () async {
      const markup =
          '<h2 id="uno">Uno</h2><p>Texto con <code>code</code>.</p>'
          '<pre><code><span class="studio-tok-keyword">final</span></code></pre>';
      const prose = StudioProse(markup, anchors: false);
      expect(await _render(prose), contains('<h2 id="uno">Uno</h2>'));
      final css = await _css(prose);
      expect(css, contains('max-width:68ch'));
      expect(css, contains('.studio-tok-keyword'));
      expect(css, contains('var(--t-code-keyword'));
    });

    test('anchors: every h2-h4 with an id gets a link named by the label', () {
      final out = StudioProse.withAnchors(
        '<h2 id="a">A</h2><h3 id="b" class="x">B</h3><h2>No id</h2>'
            '<h4 id="c">C <a href="#c" data-anchor>#</a></h4>',
        'Enlace "a" la sección',
      );
      expect(
        out,
        contains(
          '<a href="#a" data-anchor aria-label="Enlace &quot;a&quot; la '
          'sección"><span aria-hidden="true"><svg',
        ),
      );
      // The heading is named by its text alone, not text + link label.
      expect(
        out,
        contains(
          '<h2 id="a" aria-labelledby="a-title"><span id="a-title">A</span>',
        ),
      );
      expect(out, contains('<span id="b-title">B</span>'));
      expect(out, contains('<a href="#b" data-anchor'));
      expect(_count(out, 'data-anchor'), 3);
      expect(out, contains('<h2>No id</h2>'));
    });

    test('code in a heading is the heading\'s size, in text 0.875em', () async {
      final css = await _css(
        const StudioProse('<h2 id="a">A <code>b</code></h2>'),
      );
      expect(css, contains('h2code'));
      expect(css, contains('font-size:1em'));
      expect(css, contains('font-size:0.875em'));
    });

    test(
      'StudioProse anchors headings, named by the locale or a label',
      () async {
        const markup = '<h2 id="uno">Uno</h2>';
        final plain = await _render(const StudioProse(markup, anchors: false));
        expect(plain, isNot(contains('data-anchor')));
        final byLocale = await _render(const StudioProse(markup));
        expect(byLocale, contains('aria-label="Link to this section"'));
        final withLabel = await _render(
          const StudioProse(markup, anchorLabel: 'Enlace'),
        );
        expect(withLabel, contains('aria-label="Enlace"'));
      },
    );
  });

  group('theming', () {
    test(
      'the code theme overrides like Flutter: a copyWith on the extension',
      () async {
        final base = StudioTheme.light();
        final theme = base.copyWith(
          extensions: [
            const StudioCodeThemeData().copyWith(radius: 4),
            ...base.extensions.where((e) => e is! StudioCodeThemeData),
          ],
        );
        final css = headOfPage(
          await renderDocument(
            ThorApp(theme: theme, child: const StudioCodeBlock(_source)),
          ),
        ).replaceAll(RegExp(r'\s+'), '');
        expect(css, contains('border-radius:4px'));
      },
    );

    test('no content widget paints a literal color', () {
      final literal = RegExp(r'Color\(0x[0-9A-Fa-f]{2}[0-9A-Fa-f]{6}\)');
      final dir = Directory('lib/src/widgets/content');
      for (final file in dir.listSync(recursive: true).whereType<File>()) {
        final source = file.readAsStringSync();
        // A transparent reset is `Colors.transparent`, not a literal.
        expect(literal.allMatches(source), isEmpty, reason: file.path);
      }
    });
  });

  group('contrast of the content colors, light and dark', () {
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

    final code = StudioCodeThemeData.resolve(StudioTheme.light());
    final callout = StudioCalloutThemeData.resolve(StudioTheme.light());
    final cs = StudioTheme.colorScheme(Brightness.light);
    const x = StudioExtraColors.standard;

    final text = <(String, Color, Color)>[
      // Syntax and code text on every band a code line can sit on.
      for (final (band, bg) in [
        ('block', code.color),
        ('highlighted line', code.highlightColor),
        ('changed line', code.changedColor),
        ('card', cs.surfaceContainer),
      ]) ...[
        for (final c in StudioSyntaxColors.values)
          ('${c.name} on $band', c, bg),
        ('ink on $band', cs.onSurface, bg),
      ],
      ('muted header on block', code.headerTextColor, code.color),
      ('muted on hover (copy button)', code.headerTextColor, x.hover),
      // Every callout tone, the Flutter one included.
      for (final (name, tone) in [
        ('info', callout.info),
        ('ok', callout.ok),
        ('warn', callout.warn),
        ('danger', callout.danger),
        ('flutter', callout.flutter),
      ]) ...[
        ('$name title on its tint', tone.foreground, tone.background),
        ('ink body on $name tint', cs.onSurface, tone.background),
      ],
      (
        'ink-soft on card (layer description)',
        x.onSurfaceSoft,
        cs.surfaceContainer,
      ),
      (
        'muted on card (card description)',
        cs.onSurfaceVariant!,
        cs.surfaceContainer,
      ),
      ('accent link on page', cs.accent, cs.surface),
      ('accent link on card', cs.accent, cs.surfaceContainer),
    ];

    final graphics = <(String, Color, Color)>[
      (
        'highlight bar on its line',
        code.highlightBarColor,
        code.highlightColor,
      ),
      ('changed bar on its line', code.changedBarColor, code.changedColor),
      ('tab indicator on block', cs.accent, code.color),
      ('tab indicator on card', cs.accent, cs.surfaceContainer),
      for (final (name, tone) in [('flutter', callout.flutter)])
        ('$name icon', tone.foreground, tone.background),
      ('muted arrow on card', cs.onSurfaceVariant!, cs.surfaceContainer),
    ];

    for (final dark in [false, true]) {
      Color side(Color c) =>
          dark ? (c as ColorToken).dark : (c as ColorToken).light;
      final mode = dark ? 'dark' : 'light';

      test('text meets 4.5:1 in the $mode theme', () {
        for (final (name, fg, bg) in text) {
          expect(
            ratio(side(fg), side(bg)),
            greaterThanOrEqualTo(4.5),
            reason: name,
          );
        }
      });

      test('bars, indicators and icons meet 3:1 in the $mode theme', () {
        for (final (name, fg, bg) in graphics) {
          expect(
            ratio(side(fg), side(bg)),
            greaterThanOrEqualTo(3),
            reason: name,
          );
        }
      });
    }

    test('the Flutter tone is published as CSS variables', () async {
      final head = headOfPage(
        await renderDocument(ThorApp(theme: _theme, child: const Text('x'))),
      );
      for (final name in ['flutter', 'flutter-bg', 'flutter-line']) {
        expect(head, contains('--t-$name:'));
      }
    });
  });
}
