// Fixture: fields without a label on purpose (focus, state and form behavior).
// ignore_for_file: thor_lints/text_field_without_label
@TestOn('vm')
library;

import 'dart:io';
import 'dart:isolate';

import 'package:test/test.dart';
import 'package:thor_engine/src/js_minify.dart';
import 'package:thor_engine/src/js_rename.dart';
import 'package:thor_ui/html.dart' show css;
import 'package:thor_ui/src/engine/validation_script.dart';
import 'package:thor_ui/src/foundation/style_registry.dart'
    show ModuleSheet, ModuleStyles;
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

Future<String> page(Widget body) => renderDocument(ThorApp(child: body));

/// The `<body>` of [html] without its scripts: the elements a page renders.
String body(String html) => html
    .substring(html.indexOf('<body'))
    .replaceAll(RegExp(r'<script[^>]*>[\s\S]*?</script>'), '');

/// How many `<div>`s the page renders.
int divs(String html) => '<div'.allMatches(body(html)).length;

/// The declarations of the class rule that contains [marker].
String ruleWith(String html, String marker) {
  final rules = RegExp(r'\.[\w-]+\{([^}]*)\}')
      .allMatches(html)
      .map((m) => m[1]!)
      .where((r) => r.contains(marker))
      .toList();
  expect(rules, hasLength(1), reason: 'one rule with "$marker"');
  return rules.single;
}

/// `Center(child: ConstrainedBox(maxWidth:, child:))`: the page-width
/// container of every section of a landing.
Widget centered(Widget child, {double maxWidth = 640}) => Center(
  child: ConstrainedBox(
    constraints: BoxConstraints(maxWidth: maxWidth),
    child: child,
  ),
);

const _row = Row(children: [Text('x')]);

void main() {
  setUpAll(initializeThorTests);

  group('Center around a child that fills and caps its width', () {
    test('in a padded box: one element, centered both ways', () async {
      final html = await page(
        Container(padding: const EdgeInsets.all(24), child: centered(_row)),
      );
      expect(divs(html), 2, reason: 'the box and the Row, no Center');
      final rule = ruleWith(html, 'max-width: 640px');
      expect(rule, contains('width: 100%'));
      expect(rule, contains('box-sizing: border-box'));
      // The box may be taller: the Center centered it both ways.
      expect(rule, contains('margin: auto'));
      expect(rule, contains('flex: 0 1 auto'));
    });

    test('in a Column: one element, centered across', () async {
      for (final cross in [
        CrossAxisAlignment.start,
        CrossAxisAlignment.center,
        CrossAxisAlignment.stretch,
      ]) {
        final html = await page(
          Column(
            crossAxisAlignment: cross,
            children: [
              centered(
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [Text('x')],
                ),
                maxWidth: 820,
              ),
            ],
          ),
        );
        expect(divs(html), 2, reason: '$cross');
        final rule = ruleWith(html, 'max-width: 820px');
        expect(rule, contains('margin-inline: auto'));
        expect(rule, contains('width: 100%'));
        // Its height is its content's in a Column: nothing to center.
        expect(rule, isNot(contains('margin: auto')));
      }
    });

    test('a child at its own width: centered by auto margins', () async {
      final html = await page(
        Column(
          children: [
            centered(const Text('lead'), maxWidth: 620),
            const Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [Text('a'), Text('b')],
              ),
            ),
          ],
        ),
      );
      expect(divs(html), 2, reason: 'the Column and the Row');
      final text = ruleWith(html, 'max-width: 620px');
      expect(text, contains('margin-inline: auto'));
      expect(text, isNot(contains('width: 100%')));
      expect(
        ruleWith(html, 'width: fit-content'),
        contains('margin-inline: auto'),
      );
    });

    test('keeps its element where folding would change the layout', () async {
      for (final (name, widget) in <(String, Widget)>[
        // The padding is outside the capped box.
        (
          'padding around',
          Padding(padding: const EdgeInsets.all(8), child: centered(_row)),
        ),
        // A Row doesn't give it the width.
        ('in a Row', Row(children: [Expanded(child: centered(_row))])),
        // Nothing caps the child.
        (
          'no max width',
          const Container(
            padding: EdgeInsets.all(1),
            child: Center(child: _row),
          ),
        ),
        // A min width: the Align positioned that box (a max width alone
        // folds: node_fusions_test.dart).
        (
          'box with a min width',
          const Container(
            padding: EdgeInsets.all(1),
            child: Center(
              child: Container(
                constraints: BoxConstraints(minWidth: 200, maxWidth: 300),
                child: Text('x'),
              ),
            ),
          ),
        ),
        // A component: its element may have margins of its own.
        (
          'component',
          Container(
            padding: const EdgeInsets.all(1),
            child: centered(const _Card()),
          ),
        ),
      ]) {
        final html = await page(widget);
        expect(
          ruleWith(html, 'justify-content: center'),
          contains('display: flex'),
          reason: name,
        );
      }
    });
  });

  group('a Row inside a button', () {
    const arrow = Icon(IconData.svg('arrow', '<path d="M0 0"/>'), size: 16);

    test('is the button: its children, its spacing as the gap', () async {
      final html = await page(
        const FilledButton(
          href: '/contact',
          onPressed: null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 6,
            children: [Text('Start free'), arrow],
          ),
        ),
      );
      final b = body(html);
      expect(b, isNot(contains('<div')));
      expect(b, isNot(contains('<span')), reason: 'the label is its text');
      expect(b, contains('>Start free<svg'));
      final rule = ruleWith(html, 'text-decoration: none');
      expect(rule, contains('gap: 6px'));
      // Like the Row's children, the label doesn't wrap.
      expect(rule, contains('white-space: nowrap'));
    });

    test('a styled label and a box keep their elements', () async {
      final html = await page(
        const TextButton(
          onPressed: null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Yearly', style: TextStyle(fontSize: 13)),
              Container(padding: EdgeInsets.all(2), child: Text('-17%')),
            ],
          ),
        ),
      );
      final b = body(html);
      expect('<div'.allMatches(b), hasLength(1), reason: 'the badge only');
      expect(b, contains('<span'));
      expect(ruleWith(html, 'padding: 10px 12px'), contains('gap: 0'));
    });

    test('keeps its element when it lays out differently', () async {
      for (final row in [
        const Row(children: [Text('a'), arrow]),
        const Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Text('a'), arrow],
        ),
        const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(child: Text('a')),
            arrow,
          ],
        ),
      ]) {
        final html = await page(FilledButton(onPressed: null, child: row));
        expect(body(html), contains('<div'));
      }
    });
  });

  group('theme variables', () {
    Future<String> themed(Widget body) =>
        renderDocument(ThorApp(theme: ThemeData(), child: body));

    test('a text role no rule reads is not published', () async {
      final html = await themed(const Text('x', style: ThemeText.titleLarge));
      expect(html, contains('--t-title-large-size:'));
      expect(html, isNot(contains('--t-headline-large-size:')));
      expect(html, isNot(contains('--t-title-small-line:')));
      // Colors stay: the app's CSS may read them.
      expect(html, contains('--t-error:'));
      expect(html, contains('--t-on-secondary:'));
    });

    test('a breakpoint change of an unread role leaves no rule', () async {
      final base = TextTheme(displayLarge: const TextStyle(fontSize: 48));
      final html = await renderDocument(
        ThorApp(
          theme: ThemeData(
            textTheme: base.when(
              medium: base.copyWith(
                displayLarge: const TextStyle(fontSize: 60),
              ),
            ),
          ),
          child: const Text('x'),
        ),
      );
      expect(html, isNot(contains('--t-display-large-size')));
      expect(html, isNot(contains(':root{}')));
      expect(html, isNot(contains(RegExp(r'@media[^{]*\{(:root)?\{?\}'))));
    });

    test('a role the app stylesheet reads stays', () async {
      final sheet = ModuleSheet.of([
        css('.hero').styles(
          // The case under test: app CSS that reads a theme variable.
          // ignore: thor_lints/avoid_raw_css
          raw: {'font-size': 'var(--t-headline-medium-size)'},
        ),
      ]);
      final html = await themed(
        ModuleStyles(sheet: sheet, child: const Text('x')),
      );
      expect(html, contains('--t-headline-medium-size:'));
      expect(html, isNot(contains('--t-headline-medium-line:')));
    });
  });

  group('a validated field on a page without the engine', () {
    const field = TextFormField(
      name: 'email',
      validators: [Validator.required('Enter your email.')],
    );

    test('shows its own messages: the forms part inline', () async {
      final html = await page(const Form(child: field));
      expect(html, contains('data-msg-valuemissing="Enter your email."'));
      expect(html, contains(validationScript));
      expect(
        html.indexOf(validationScript),
        greaterThan(html.indexOf('data-msg-valuemissing')),
        reason: 'after the fields it looks for',
      );
    });

    test('the engine brings it when the page loads it', () async {
      final html = await page(const Form(child: _WithEngine(field)));
      expect(html, isNot(contains(validationScript)));
    });

    test('is the forms part of the engine, minified', () async {
      final uri = await Isolate.resolvePackageUri(
        Uri.parse('package:thor_engine/lite/parts/forms.js'),
      );
      final source = File.fromUri(uri!).readAsStringSync();
      expect(validationScript, minifyJs(renameLocals(source)));
    });
  });

  group('a button that is a link', () {
    test('has no :disabled rule (an <a> is never disabled)', () async {
      final html = await page(
        const FilledButton(
          href: '/contact',
          onPressed: null,
          child: Text('Contact'),
        ),
      );
      expect(html, contains('<a '));
      expect(html, isNot(contains(':disabled')));
    });

    test('a <button> keeps it', () async {
      final html = await page(
        const FilledButton(onPressed: null, child: Text('Send')),
      );
      expect(html, contains(':disabled'));
    });
  });
}

class _Card extends StatelessWidget implements ThorElementWidget {
  const _Card();

  @override
  Widget build(BuildContext context) => const Container(
    margin: EdgeInsets.all(4),
    child: Row(children: [Text('card')]),
  );
}

/// A widget that asks for the engine (as a date picker does).
class _WithEngine extends StatelessWidget {
  const _WithEngine(this.child);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    ThorStyleRegistry.active(context)?.useEngine();
    return child;
  }
}
