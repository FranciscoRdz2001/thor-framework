import 'package:docs/core/content/blocks.dart';
import 'package:docs/core/content/directives.dart';
import 'package:docs/core/content/style_directives.dart';
import 'package:docs/core/i18n/docs_locale.dart';
import 'package:docs/modules/guide/examples/examples.dart';
import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';

void main() {
  setUpAll(initializeThorTests);

  test('a stage example is shown in the resizable frame', () async {
    await prepareExamples(['responsive-card']);
    expect(examples['responsive-card']!.stage, isTrue);
    final html = await renderHtml(const ExampleEmbed('responsive-card'));
    // The reader's hint, the ruler and the corner handle.
    expect(html, contains('Resize the box from its bottom-right corner'));
    expect(html, contains('>240<'));
    expect(html, contains('>640<'));
    expect(html, contains('resize: horizontal'));
    // The card follows its container, not the window.
    expect(html, contains('container-type: inline-size'));
  });

  test('an unknown directive is still left alone', () {
    expect(
      parseStyleDirective(const Directive('nope', '', ''), _NoContext()),
      isNull,
    );
  });

  test('every example of the styles guide renders, with its source', () async {
    const ids = [
      'units',
      'responsive-card',
      'sticky-list',
      'hover-effects',
      'descendants',
      'patterns',
    ];
    await prepareExamples(ids);
    for (final id in ids) {
      final code = exampleCode(id);
      expect(code, isNotNull, reason: id);
      expect(code!.dart, isNotEmpty, reason: id);
      expect(code.html, isNotEmpty, reason: id);
    }
    // Typed values reach the CSS.
    expect(exampleCode('sticky-list')!.css, contains('position: sticky'));
    expect(exampleCode('units')!.css, contains('12vw'));
  });

  test('the code shown for an example is whole: every private value it '
      'uses is declared in it, and html. comes with its import', () async {
    await prepareExamples(examples.keys);
    for (final id in examples.keys.where(
      (id) => !examples[id]!.bare && examples[id]!.bench == null,
    )) {
      final dart = exampleCode(id)!.dart;
      expect(dart, startsWith('import '), reason: id);
      final used = {
        for (final m in RegExp(r'\b(_[a-zA-Z]\w*)\b').allMatches(dart)) m[1]!,
      };
      for (final name in used) {
        expect(
          dart,
          matches(
            RegExp('^(const|final|class|Widget) \\$name\\b', multiLine: true),
          ),
          reason: '$id uses $name without declaring it',
        );
      }
      expect(
        dart.contains('html.'),
        dart.contains("import 'package:thor_ui/html.dart' as html;"),
        reason: id,
      );
    }
    // A shared value is added only where it's used.
    expect(exampleCode('units')!.dart, contains('const _mono = TextStyle('));
    expect(exampleCode('units')!.dart, isNot(contains('const _tint')));
    expect(exampleCode('card')!.dart, isNot(contains('const _ink')));
  });
}

class _NoContext implements DirectiveContext {
  @override
  AppLocalizations get l10n => messagesFor(defaultLocale);
  @override
  List<DocBlock> blocks(String markdown) => const [];
  @override
  String link(String href) => href;
  @override
  void useExample(String id, {bool bench = false}) {}
  @override
  void useLayers(String id) {}
  @override
  String heading(String text) => text;
}
