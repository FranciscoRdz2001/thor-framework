// What a markdown page becomes: blocks (data), and how each block looks on
// the page (the `thor_studio` widget that draws it).
import 'package:docs/core/content/blocks.dart';
import 'package:docs/core/content/blocks_view.dart';
import 'package:docs/core/content/code.dart';
import 'package:docs/core/content/library.dart';
import 'package:docs/modules/guide/examples/examples.dart';
import 'package:docs/modules/guide/examples/layers/layer_set.dart';
import 'package:docs/modules/guide/examples/layers/layer_sets.dart';
import 'package:test/test.dart';
import 'package:thor_studio/thor_studio.dart';
import 'package:thor_test/thor_test.dart';
import 'package:thor_ui/thor_ui.dart' show Localizations, Locale;

List<DocBlock> _blocks(String markdown) =>
    renderMarkdown('# T\n\n$markdown', source: 'x', fileDir: 'guia/es').blocks;

/// The page's blocks drawn as HTML, like the page does (in Spanish: the
/// studio's own strings come from its delegate).
Future<String> _html(String markdown) => renderHtml(
  Localizations(
    locale: const Locale('es'),
    delegates: [StudioLocalizations.delegate],
    child: DocBlocks(_blocks(markdown)),
  ),
);

void main() {
  setUpAll(initializeThorTests);

  group('code fences', () {
    test('a fence is a block with its language; code stays as written', () {
      final [dart, shell] = _blocks(
        "```dart\nfinal a = '<b>';\n```\n\n```bash\nls <dir>\n```\n",
      ).cast<CodeBlockData>();
      expect(dart.language, 'dart');
      expect(dart.code, "final a = '<b>';");
      expect(shell.language, 'bash');
      expect(shell.code, 'ls <dir>');
    });

    test('a first comment names the file and leaves the code', () {
      final code =
          _blocks(
                '```dart\n// lib/a.dart — the state\nfinal a = 1;\nfinal b = 2;\n```\n',
              ).single
              as CodeBlockData;
      expect(code.title, 'lib/a.dart — the state');
      expect(code.code, 'final a = 1;\nfinal b = 2;');
    });

    test('a fence has no title when its first line names no file', () {
      final code =
          _blocks('```dart\n// just a comment\nfinal a = 1;\n```\n').single
              as CodeBlockData;
      expect(code.title, isNull);
    });

    test('{2-4} marks lines, +{5} marks added ones; they count the fence as '
        'written, even after the file name', () {
      final plain =
          _blocks('```dart {2-4,7}\na\nb\nc\nd\ne\nf\ng\n```\n').single
              as CodeBlockData;
      expect(plain.highlight.map((r) => '$r'), ['2-4', '7']);
      final named =
          _blocks('```dart {3} +{4-5}\n// lib/a.dart\na\nb\nc\nd\n```\n').single
              as CodeBlockData;
      expect(named.title, 'lib/a.dart');
      // Line 3 of the fence is `b`: line 2 of what is shown.
      expect(named.highlight.map((r) => '$r'), ['2']);
      expect(named.changed.map((r) => '$r'), ['3-4']);
    });

    test('a block is a StudioCodeBlock with the copy button; a shell block '
        'is a Terminal', () async {
      final html = await _html(
        '```dart\nfinal a = 1;\n```\n\n```bash\nls\n```',
      );
      expect(html, contains('data-studio-code'));
      expect(html, contains('Copiar'));
      expect(html, contains('Terminal'));
      expect(html, isNot(contains('tok-')));
    });

    test('codeBlockOf is the same one', () {
      final b = codeBlockOf('// pubspec.yaml\nname: a', 'yaml');
      expect(b.title, 'pubspec.yaml');
      expect(b.language, 'yaml');
    });
  });

  group('prose', () {
    test('no newlines between blocks; soft breaks keep theirs', () {
      final blocks = _blocks(
        'one `a`\n[b](#b)\n\n- x\n- y\n\n```\nl1\nl2\n```\n',
      );
      expect(
        (blocks.first as ProseBlock).html,
        '<p>one <code>a</code>\n<a href="#b">b</a></p><ul><li>x</li><li>y</li></ul>',
      );
      expect((blocks.last as CodeBlockData).code, 'l1\nl2');
    });

    test('a task list box is named by its text', () {
      expect(
        (_blocks('- [ ] Do it\n- [x] Done\n').single as ProseBlock).html,
        contains('<li class="task-list-item"><label><input type="checkbox">'),
      );
    });

    test('prose is a StudioProse with anchors on its headings', () async {
      final html = await _html('## Uno\n\nTexto.\n');
      expect(html, contains('<h2 id="uno" aria-labelledby="uno-title">'));
      expect(html, contains('data-anchor'));
      expect(html, contains('Enlace a esta sección'));
    });

    test('a section heading opens more room than a paragraph', () {
      final blocks = _blocks('Texto.\n\n```dart\na\n```\n\n## Sección\n\nMás.');
      expect(
        [for (final b in blocks.whereType<ProseBlock>()) b.leading],
        [16, 56],
      );
    });
  });

  group('callouts', () {
    test('a directive is a callout with its tone and title', () {
      final callout =
          _blocks(':::warning\nCareful with **this**.\n:::\n').single
              as CalloutBlock;
      expect(callout.tone, StudioTone.warning);
      expect(callout.title, 'Importante');
      expect(
        (callout.children.single as ProseBlock).html,
        contains('<strong>this</strong>'),
      );
      final titled =
          _blocks(':::note Mi título\nTexto\n:::').single as CalloutBlock;
      expect(titled.title, 'Mi título');
    });

    test('a callout holds lists, code and a table, once, in both spellings', () {
      for (final md in [
        ':::note\nAntes:\n\n- uno\n- dos con `x`\n\n```dart\nfinal a = 1;\n```\n\n| a | b |\n| - | - |\n| 1 | 2 |\n:::',
        '> **Nota:** Antes:\n>\n> - uno\n> - dos con `x`\n>\n> ```dart\n> final a = 1;\n> ```\n>\n> | a | b |\n> | - | - |\n> | 1 | 2 |',
      ]) {
        final blocks = _blocks(md);
        expect(blocks, hasLength(1), reason: md);
        final callout = blocks.single as CalloutBlock;
        expect(callout.tone, StudioTone.note, reason: md);
        expect(callout.title, 'Nota', reason: md);
        expect(callout.children.whereType<CodeBlockData>(), hasLength(1));
        final html = callout.children
            .whereType<ProseBlock>()
            .map((b) => b.html)
            .join();
        expect(html, contains('<li>dos con <code>x</code></li>'), reason: md);
        expect(html, contains('<table'), reason: md);
      }
    });

    test('a callout at the very end of a file, closed or not', () {
      for (final md in [
        ':::tip\nÚltimo.\n:::',
        ':::tip\nÚltimo.',
        '> **Consejo:** Último.',
      ]) {
        final blocks = _blocks('Antes.\n\n$md');
        expect(blocks.first, isA<ProseBlock>(), reason: md);
        final callout = blocks.last as CalloutBlock;
        expect(callout.tone, StudioTone.tip, reason: md);
        expect(
          (callout.children.single as ProseBlock).html,
          contains('Último.'),
        );
      }
    });

    test('a quote with a label is the same callout', () {
      for (final (label, tone) in [
        ('Ojo', StudioTone.warning),
        ('Nota', StudioTone.note),
        ('Consejo', StudioTone.tip),
        ('Cuidado', StudioTone.danger),
        ('Diferencia con Flutter', StudioTone.flutter),
        ('Importante', StudioTone.warning),
      ]) {
        final blocks = _blocks(
          '> **$label:** First line.\n>\n> Second `code`.\n\nAfter.',
        );
        final callout = blocks.first as CalloutBlock;
        expect(callout.tone, tone, reason: label);
        // An alias shows as its tone's own label.
        expect(
          callout.title,
          label == 'Ojo' ? 'Importante' : label,
          reason: label,
        );
        expect(
          (callout.children.single as ProseBlock).html,
          contains('<p>First line.</p>'),
        );
        expect((blocks.last as ProseBlock).html, '<p>After.</p>');
      }
      // A quote without the label stays a quote; so does one in code.
      expect(
        (_blocks('> Plain quote.').single as ProseBlock).html,
        contains('<blockquote>'),
      );
      expect(
        _blocks('```md\n> **Ojo:** in code\n```').single,
        isA<CodeBlockData>(),
      );
    });

    test('the labels are the ARB\'s: a callout is a labelled note', () async {
      final html = await _html(
        '> **Ojo:** Cuidado.\n\n:::flutter Diferencias\nTexto\n:::',
      );
      expect(html, contains('role="note"'));
      expect(html, contains('aria-label="Importante"'));
      expect(html, isNot(contains('aria-label="Ojo"')));
      expect(html, contains('aria-label="Diferencias"'));
    });
  });

  group('steps, tabs, cards and files', () {
    test('steps: a step per ###, listed in the contents', () async {
      final page = renderMarkdown(
        '# T\n\n:::steps\n### One\nA.\n### Two\nB.\n:::\n',
        source: 'x',
      );
      final steps = page.blocks.single as StepsBlock;
      expect([for (final s in steps.steps) s.title], ['One', 'Two']);
      expect(steps.diff, isFalse);
      expect([for (final h in page.toc) h.href], ['#one', '#two']);
      expect(steps.steps.first.id, 'one');
      final html = await _html(':::steps\n### One\nA.\n### Two\nB.\n:::');
      expect(html, contains('id="one"'));
      expect(html, contains('One'));
      expect(html, contains('<li'));
    });

    test('steps diff: each step\'s last code is what is compared', () async {
      const md =
          ':::steps diff\n### One\n```dart\na\n```\n### Two\nMore.\n```dart\na\nb\n```\n:::';
      final steps = _blocks(md).single as StepsBlock;
      expect(steps.diff, isTrue);
      expect(steps.steps.last.code!.code, 'a\nb');
      expect(steps.steps.last.children.single, isA<ProseBlock>());
      // The second step's `b` is the line it adds.
      expect(await _html(md), contains('data-studio-code'));
    });

    test('tabs: code only → code tabs; text → the site\'s tabs', () async {
      final tabs =
          _blocks(
                ':::tabs\n@tab A\n```bash\none\n```\n@tab B\n```bash\ntwo\n```\n:::',
              ).single
              as TabsBlock;
      expect([for (final t in tabs.tabs) t.label], ['A', 'B']);
      final code = await _html(
        ':::tabs\n@tab A\n```bash\none\n```\n@tab B\n```bash\ntwo\n```\n:::',
      );
      expect(code, contains('role="radiogroup"'));
      expect(code, contains('data-studio-code'));
      final mixed = await _html(
        ':::tabs\n@tab A\nuno\n@tab B\n```bash\ntwo\n```\n:::',
      );
      expect(mixed, contains('role="radiogroup"'));
      expect(mixed, contains('uno'));
      expect(mixed, contains('data-studio-code'));
    });

    test('cards link like the rest of the guide', () async {
      const md =
          ':::cards\n- [Routes](navegacion.md) — load and actions\n:::\n';
      final card = (_blocks(md).single as CardsBlock).cards.single;
      expect(card.href, '/fundamentos/navegacion');
      expect(card.description, 'load and actions');
      final html = await _html(md);
      expect(html, contains('href="/es/fundamentos/navegacion"'));
      expect(html, contains('load and actions'));
    });

    test('a file tree nests folders and keeps notes', () async {
      const md = ':::files\nlib/\n  main.dart   the entry\n:::\n';
      final tree = _blocks(md).single as FilesBlock;
      expect(tree.entries.single.name, 'lib/');
      expect(tree.entries.single.children.single.name, 'main.dart');
      expect(tree.entries.single.children.single.note, 'the entry');
      final html = await _html(md);
      expect(html, contains('main.dart'));
      expect(html, contains('the entry'));
      expect(html, contains('<ul'));
    });

    test('a ladder: a rung per ###, the first open and the first and last '
        'tagged', () async {
      const md =
          ':::ladder\n### One\nFirst `a`.\n### Two\nMiddle.\n### Three\nLast.\n:::';
      final ladder = _blocks(md).single as LadderBlock;
      expect(ladder.rungs, hasLength(3));
      final html = await _html(md);
      expect(RegExp('<details').allMatches(html), hasLength(3));
      expect(RegExp('<details[^>]* open').allMatches(html), hasLength(1));
      expect(html, contains('first'));
      expect(html, contains('last resort'));
      expect(html, isNot(contains('<h3')));
    });

    test(
      'tokens: one card per color, with the Dart name and CSS variable',
      () async {
        const md =
            ':::tokens\n- on-primary #FFFFFF — text\n- nope\n- primary #6750A4\n:::';
        expect((_blocks(md).single as TokensBlock).tokens, hasLength(2));
        final html = await _html(md);
        expect(html, contains('ThemeColor.onPrimary'));
        expect(html, contains('var(--t-on-primary)'));
        expect(html, contains('#6750a4'));
      },
    );
  });

  group('Flutter and Thor', () {
    const pair =
        ':::flutter\nIntro text.\n@flutter\n```dart\nsetState(() => n++);\n```\n@thor\n```dart\nn.value++;\n```\n:::';

    test(':::flutter with @flutter and @thor is a pair, and the text before '
        'it stays', () async {
      final compare = _blocks(pair).single as CompareBlock;
      expect(compare.flutter.code, 'setState(() => n++);');
      expect(compare.thor.code, 'n.value++;');
      expect(compare.intro.single, isA<ProseBlock>());
      final html = await _html(pair);
      expect(html, contains('>Flutter<'));
      expect(html, contains('>Thor<'));
      expect(html, contains('setState'));
      expect(html, contains('n.value++'));
      expect(html, contains('Intro text.'));
    });

    test(':::compare takes two code blocks, the first is Flutter\'s', () {
      final compare =
          _blocks(':::compare\n```dart\na\n```\n```dart\nb\n```\n:::').single
              as CompareBlock;
      expect([compare.flutter.code, compare.thor.code], ['a', 'b']);
    });

    test('the one-line form is a summary and needs no closing', () async {
      const md =
          ':::flutter Flutter: `setState(() => n++)` · Thor: `n.value++`\n\nTexto después.';
      final blocks = _blocks(md);
      final summary = blocks.first as CompareSummaryBlock;
      expect(summary.flutter, '`setState(() => n++)`');
      expect(summary.thor, '`n.value++`');
      expect((blocks.last as ProseBlock).html, contains('Texto después.'));
      final html = await _html(md);
      expect(html, contains('<ul'));
      expect(html, contains('n.value++'));
    });

    test('a :::flutter with only text is the note about what differs', () {
      final callout =
          _blocks(':::flutter Diferencias\nTexto\n:::').single as CalloutBlock;
      expect(callout.tone, StudioTone.flutter);
      expect(callout.title, 'Diferencias');
    });
  });

  group('examples, benches and layers', () {
    test('an example leaves a block and is listed; code fences are safe', () {
      final page = renderMarkdown(
        '# T\n\n:::example accordion\n:::\n\n```text\n:::note\n```\n',
        source: 'x',
      );
      expect(page.examples, ['accordion']);
      expect(page.benches, isEmpty);
      expect(page.blocks.first, isA<ExampleBlock>());
      expect(page.blocks.whereType<CalloutBlock>(), isEmpty);
    });

    test(':::bench and :::layers are listed apart', () {
      final page = renderMarkdown(
        '# T\n\n:::bench bench-row-align\n:::\n\n:::layers orders\n:::\n',
        source: 'x',
      );
      expect(page.examples, ['bench-row-align']);
      expect(page.benches, ['bench-row-align']);
      expect(page.layers, ['orders']);
    });

    test('every example, bench and layer set a guide names exists', () {
      final ids = <String>{};
      final benches = <String>{};
      final layers = <String>{};
      for (final g in allGuides) {
        final page = loadGuide(g, 'es')?.page;
        if (page == null) continue;
        ids.addAll(page.examples);
        benches.addAll(page.benches);
        layers.addAll(page.layers);
      }
      expect(ids, isNotEmpty);
      for (final id in ids) {
        expect(examples, contains(id), reason: id);
      }
      for (final id in benches) {
        expect(examples[id]?.bench, isNotNull, reason: ':::bench $id');
      }
      for (final id in layers) {
        expect(layerSets, contains(id), reason: ':::layers $id');
      }
    });

    test('every example of the guide renders, with its source', () async {
      final ids = {
        for (final g in allGuides) ...?loadGuide(g, 'es')?.page.examples,
      };
      await prepareExamples(ids);
      // A demo shows its own code, an illustration and a bench none.
      for (final id in ids.where(
        (id) => !examples[id]!.bare && examples[id]!.bench == null,
      )) {
        final code = exampleCode(id)!;
        expect(code.dart, isNotEmpty, reason: id);
        expect(code.html, startsWith('<'), reason: id);
        expect(code.css, contains('{'), reason: id);
        expect(code.html, isNot(contains('data-thor')), reason: id);
      }
    });

    test('an example is a bench with its Demo / Code toggle and its code in '
        'three tabs', () async {
      await prepareExamples(['accordion']);
      final html = await renderHtml(const ExampleEmbed('accordion'));
      expect(html, contains('name="ex-accordion-view"'));
      expect(html, contains('Generated HTML'));
      expect(html, contains('Generated CSS'));
      expect(html, contains('accordion.dart'));
    });

    test(
      'a layer set is a diagram with every layer and both languages',
      () async {
        final set = layerSets['orders']!;
        expect(
          [for (final l in set.layers) l.title],
          [
            'View',
            'ViewModel',
            'Repository',
            'Service',
            'Injection',
            'Navigation',
            'Tests',
          ],
        );
        final html = await renderHtml(LayersView(set));
        for (final layer in set.layers) {
          expect(html, contains(layer.title));
        }
        expect(html, contains('In Flutter'));
        expect(html, contains('ThorHttpClient'));
        expect(html, contains('GoRoute'));
        expect(html, contains('ContextKey'));
      },
    );
  });
}
