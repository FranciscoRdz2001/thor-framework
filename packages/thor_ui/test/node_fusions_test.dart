@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

Future<String> page(Widget body) => renderDocument(ThorApp(child: body));

/// The `<body>` of [html] without its scripts: the elements a page renders.
String body(String html) => html
    .substring(html.indexOf('<body'))
    .replaceAll(RegExp(r'<script[^>]*>[\s\S]*?</script>'), '');

/// How many `<div>`s the page renders.
int divs(String html) => '<div'.allMatches(body(html)).length;

/// The declarations of the one class rule that contains [marker].
String ruleWith(String html, String marker) {
  final rules = RegExp(r'\.[\w-]+\{([^}]*)\}')
      .allMatches(html)
      .map((m) => m[1]!)
      .where((r) => r.contains(marker))
      .toList();
  expect(rules, hasLength(1), reason: 'one rule with "$marker"');
  return rules.single;
}

const _texts = [Text('a'), Text('b')];

void main() {
  setUpAll(initializeThorTests);

  group('a SizedBox height per breakpoint', () {
    test('folds into the next child\'s margin, per breakpoint', () async {
      final html = await page(
        Column(
          children: [
            const Text('a'),
            SizedBox(heightLength: 40.px.when(expanded: 56.px)),
            const Text('b'),
          ],
        ),
      );
      expect(divs(html), 1, reason: 'the Column only: no empty div');
      expect(html, contains('margin-top: 40px'));
      expect(
        html,
        matches(
          RegExp(r'@media[^{]*min-width: 840px[^{]*\{[^}]*margin-top: 56px'),
        ),
      );
      expect(html, isNot(contains('⟦')));
    });

    test('a fixed one next to it adds up', () async {
      final html = await page(
        Column(
          children: [
            const Text('a'),
            const SizedBox(height: 8),
            SizedBox(heightLength: 40.px.when(expanded: 56.px)),
            const Text('b'),
          ],
        ),
      );
      expect(divs(html), 1);
      expect(html, contains('margin-top: calc(8px + 40px)'));
      expect(html, contains('margin-top: calc(8px + 56px)'));
    });

    test('a width per breakpoint in a Row is a logical margin', () async {
      final html = await page(
        Row(
          children: [
            const Text('a'),
            SizedBox(widthLength: 12.px.when(medium: 24.px)),
            const Text('b'),
          ],
        ),
      );
      expect(divs(html), 1);
      expect(html, contains('margin-inline-start: 12px'));
      expect(html, contains('margin-inline-start: 24px'));
    });

    test(
      'a share of the parent stays a box: a margin % is of the width',
      () async {
        final html = await page(
          const Column(
            children: [
              Text('a'),
              SizedBox(heightLength: Length.percent(10)),
              Text('b'),
            ],
          ),
        );
        expect(divs(html), 2);
        expect(html, contains('height: 10%'));
      },
    );

    test('alone, it is a box whose height changes', () async {
      final html = await page(
        SizedBox(heightLength: 40.px.when(expanded: 56.px)),
      );
      expect(html, contains('height: 40px'));
      expect(html, contains('height: 56px'));
    });
  });

  group('a box around a Wrap', () {
    test('Padding > Wrap is one element', () async {
      final html = await page(
        const Padding(
          padding: EdgeInsets.all(16),
          child: Wrap(spacing: 8, children: _texts),
        ),
      );
      expect(divs(html), 1);
      final rule = ruleWith(html, 'flex-wrap: wrap');
      expect(rule, contains('padding: 16px'));
      expect(rule, contains('column-gap: 8px'));
    });

    test('Container(padding, decoration) > Wrap is one element', () async {
      final html = await page(
        const Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(color: Color(0xffeeeeee)),
          child: Wrap(runSpacing: 4, children: _texts),
        ),
      );
      expect(divs(html), 1);
      final rule = ruleWith(html, 'flex-wrap: wrap');
      expect(rule, contains('padding: 12px'));
      expect(rule, contains('background-color: #eeeeee'));
    });

    test('a fixed width around it: the Wrap no longer fills', () async {
      final html = await page(
        const Center(
          child: Container(
            width: 300,
            padding: EdgeInsets.all(4),
            child: Wrap(children: _texts),
          ),
        ),
      );
      final rule = ruleWith(html, 'flex-wrap: wrap');
      expect(rule, contains('width: 300px'));
    });

    test('an aligned Container keeps its element', () async {
      final html = await page(
        const Container(
          alignment: Alignment.center,
          child: Wrap(children: _texts),
        ),
      );
      expect(divs(html), 2);
    });
  });

  group('Center over a box capped by its own constraints', () {
    Widget section({double maxWidth = 1180}) => Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _texts,
        ),
      ),
    );

    test('in a Column: one element, centered across', () async {
      final html = await page(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [section()],
        ),
      );
      expect(divs(html), 2, reason: 'the page Column and the section');
      final rule = ruleWith(html, 'max-width: 1180px');
      expect(rule, contains('margin-inline: auto'));
      expect(rule, contains('width: 100%'));
      expect(rule, contains('box-sizing: border-box'));
      expect(rule, contains('padding: 0px 14px'));
      expect(rule, isNot(contains('max-width: 100%')));
    });

    test('a max width per breakpoint caps it too', () async {
      final html = await page(
        Column(
          children: [
            Center(
              child: Container(
                constraints: const BoxConstraints(
                  maxWidth: 600,
                ).when(expanded: const BoxConstraints(maxWidth: 1180)),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: _texts,
                ),
              ),
            ),
          ],
        ),
      );
      expect(divs(html), 2);
      expect(ruleWith(html, 'max-width: 600px'), contains('width: 100%'));
    });

    test('a child at its own width keeps its max width', () async {
      final html = await page(
        const Container(
          padding: EdgeInsets.all(1),
          child: Center(
            child: Container(
              constraints: BoxConstraints(maxWidth: 300),
              child: Text('x'),
            ),
          ),
        ),
      );
      expect(divs(html), 2, reason: 'the box and the capped text box');
      final rule = ruleWith(html, 'max-width: 300px');
      expect(rule, contains('margin: auto'));
      expect(rule, isNot(contains('max-width: 100%')));
    });

    test('other constraints keep the Center', () async {
      for (final c in const [
        BoxConstraints(minWidth: 200, maxWidth: 400),
        BoxConstraints(maxWidth: 400, maxHeight: 100),
      ]) {
        final html = await page(
          Column(
            children: [
              Center(
                child: Container(
                  constraints: c,
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _texts,
                  ),
                ),
              ),
            ],
          ),
        );
        expect(divs(html), 3, reason: '$c');
      }
    });

    test('a Semantics(region) above it names the folded element', () async {
      final html = await page(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              role: SemanticsRole.region,
              label: 'Offers',
              child: section(),
            ),
          ],
        ),
      );
      final b = body(html);
      expect(divs(html), 1, reason: 'the page Column; the section is the box');
      expect(b, contains('<section'));
      expect(b, contains('aria-label="Offers"'));
      final rule = ruleWith(html, 'max-width: 1180px');
      expect(rule, contains('margin-inline: auto'));
    });

    test('a Semantics(region) below it too', () async {
      final html = await page(
        const Column(
          children: [
            Center(
              child: Semantics(
                role: SemanticsRole.region,
                child: Container(
                  constraints: BoxConstraints(maxWidth: 900),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _texts,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
      expect(divs(html), 1, reason: 'the page Column; the section is the box');
      expect(body(html), contains('<section'));
      expect(
        ruleWith(html, 'max-width: 900px'),
        contains('margin-inline: auto'),
      );
    });

    test('a wrapper with layout above it keeps the Center', () async {
      final html = await page(
        Column(
          children: [
            Opacity(opacity: 0.5, child: section()),
            Semantics(button: true, child: section(maxWidth: 1000)),
          ],
        ),
      );
      // The button Center is a <button>, not a div.
      expect(divs(html), 4, reason: 'two Centers kept, plus their sections');
      expect(body(html), contains('<button'));
    });
  });
}
