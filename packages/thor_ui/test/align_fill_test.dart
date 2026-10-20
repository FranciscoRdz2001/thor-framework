@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

Future<String> page(Widget body) => renderDocument(ThorApp(child: body));

/// The declarations of the class rule that contains [marker] (every case
/// gives the element under test a unique declaration).
String ruleWith(String html, String marker) {
  final rules = RegExp(r'\.[\w-]+\{([^}]*)\}')
      .allMatches(html)
      .map((m) => m[1]!)
      .where((r) => r.contains(marker))
      .toList();
  expect(rules, hasLength(1), reason: 'one rule with "$marker"');
  return rules.single;
}

/// A child that takes the max width (`width: double.infinity`) and caps it.
Widget capped({double maxWidth = 1180, EdgeInsets? margin}) => Container(
  width: double.infinity,
  margin: margin,
  constraints: BoxConstraints(maxWidth: maxWidth),
  child: const Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [Text('x')],
  ),
);

/// Asserts that the capped child is limited and positioned at [x] (-1 left,
/// 0 centered, 1 right) with auto margins, instead of stretched to the left.
void expectPositioned(String rule, {required double x}) {
  if (x == 0) {
    // Unsafe centering: overflow goes both ways, like Flutter's Center.
    expect(rule, contains('align-self: center'));
  } else {
    expect(rule, contains('margin-left: ${x == -1 ? '0' : 'auto'}'));
    expect(rule, contains('margin-right: ${x == 1 ? '0' : 'auto'}'));
  }
  expect(rule, contains('width: 100%'), reason: 'takes the max width…');
  expect(rule, contains('box-sizing: border-box'));
  expect(rule, isNot(contains('align-self: stretch')), reason: '…not stretch');
  expect(rule, isNot(contains('max-width: none')));
}

void main() {
  setUpAll(initializeThorTests);

  group('a filling child with a max width', () {
    test('is centered by Align(topCenter), like Flutter', () async {
      final html = await page(
        Align(alignment: Alignment.topCenter, child: capped()),
      );
      final rule = ruleWith(html, 'max-width: 1180px');
      expectPositioned(rule, x: 0);
    });

    test('follows every keyword Alignment (physical x, no RTL flip)', () async {
      const all = [
        Alignment.topLeft,
        Alignment.topCenter,
        Alignment.topRight,
        Alignment.centerLeft,
        Alignment.center,
        Alignment.centerRight,
        Alignment.bottomLeft,
        Alignment.bottomCenter,
        Alignment.bottomRight,
      ];
      for (final a in all) {
        final html = await page(Align(alignment: a, child: capped()));
        final rule = ruleWith(html, 'max-width: 1180px');
        expectPositioned(rule, x: a.x);
        expect(
          ruleWith(html, 'justify-content: ${a.flexJustify}'),
          isNot(contains('max-width: 1180px')),
          reason: 'the Align positions it vertically: $a',
        );
      }
    });

    test('a fractional alignment still limits it and offsets it', () async {
      final html = await page(
        Align(alignment: const Alignment(0.5, 0), child: capped()),
      );
      final rule = ruleWith(html, 'max-width: 1180px');
      expectPositioned(rule, x: -1);
      expect(rule, contains('left: 75%'));
      expect(rule, contains('translate: -75% -50%'));
    });

    test('Center and Container(alignment:) with padding center it', () async {
      final center = await page(Center(child: capped(maxWidth: 640)));
      expectPositioned(ruleWith(center, 'max-width: 640px'), x: 0);

      final box = await page(
        Container(
          alignment: Alignment.topCenter,
          padding: const EdgeInsets.all(24),
          child: capped(maxWidth: 641),
        ),
      );
      expectPositioned(ruleWith(box, 'max-width: 641px'), x: 0);
      expect(ruleWith(box, 'padding: 24px'), isNot(contains('max-width')));
    });

    test('nested Align: the inner one fills, the capped one centers', () async {
      final html = await page(
        Center(
          child: Align(alignment: Alignment.topRight, child: capped()),
        ),
      );
      expectPositioned(ruleWith(html, 'max-width: 1180px'), x: 1);
      // The inner Align (no max width) keeps stretching across the outer one.
      final inner = ruleWith(html, 'justify-content: flex-start');
      expect(inner, contains('align-self: stretch'));
      expect(inner, contains('margin-left: 0'));
    });

    test('Center inside a Row, a Column and a Stack', () async {
      for (final parent in <Widget Function(Widget)>[
        (c) => Row(children: [Expanded(child: c)]),
        (c) => Column(children: [Expanded(child: c)]),
        (c) => Stack(children: [c]),
      ]) {
        final html = await page(parent(Center(child: capped())));
        expectPositioned(ruleWith(html, 'max-width: 1180px'), x: 0);
      }
    });

    test('a ConstrainedBox around a stretched Column centers it', () async {
      final html = await page(
        const Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 500),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [Text('x')],
            ),
          ),
        ),
      );
      expectPositioned(ruleWith(html, 'max-width: 500px'), x: 0);
    });

    test('a responsive max width (.when) is capped too', () async {
      final html = await page(
        Center(
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints().when(
              medium: const BoxConstraints(maxWidth: 900),
            ),
            child: const Text('x'),
          ),
        ),
      );
      final rule = ruleWith(html, 'box-sizing: border-box; width: 100%');
      expect(rule, contains('align-self: center'));
      expect(html, contains('max-width: 900px'));
    });

    test('a vertical-only margin keeps it centered', () async {
      final html = await page(
        Center(child: capped(margin: const EdgeInsets.only(bottom: 16))),
      );
      final rule = ruleWith(html, 'max-width: 1180px');
      expect(rule, contains('margin-bottom: 16px'));
      expect(rule, isNot(contains('margin:')), reason: 'no shorthand reset');
      expectPositioned(rule, x: 0);
    });
  });

  // Flutter's margin is a padding around the capped box, so the
  // box is centered with the margin on each side; thor stretched it and the
  // margin pushed it to the start (x = 16).
  group('a capped child with a horizontal margin', () {
    const margin = EdgeInsets.symmetric(horizontal: 16);
    Widget box({EdgeInsetsGeometry? m = margin}) => Container(
      constraints: const BoxConstraints(maxWidth: 1088),
      margin: m,
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [Text('x')],
      ),
    );

    /// Centered by its parent and as wide as it may be inside its margins.
    void expectCentered(String rule, {String width = 'calc(100% - 32px)'}) {
      expect(rule, contains('width: $width'));
      expect(rule, contains('box-sizing: border-box'));
      expect(rule, isNot(contains('align-self: stretch')));
      expect(rule, isNot(contains('margin-left: 0')));
      expect(rule, isNot(contains('margin-inline: auto')));
    }

    test('in a centered Column', () async {
      final html = await page(Column(children: [box()]));
      final rule = ruleWith(html, 'max-width: 1088px');
      expectCentered(rule);
      expect(rule, contains('margin: 0px 16px'));
      expect(ruleWith(html, 'align-items: center'), isNot(contains('1088')));
    });

    test('in a Column ending its children', () async {
      final html = await page(
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [box()]),
      );
      expectCentered(ruleWith(html, 'max-width: 1088px'));
    });

    test('under a Center (no element of its own in a Column)', () async {
      final html = await page(Column(children: [Center(child: box())]));
      expect(html, isNot(contains('data-thor="Center"')));
      final rule = ruleWith(html, 'max-width: 1088px');
      expectCentered(rule);
      expect(rule, contains('align-self: center'));
    });

    test('under a Center or a top-center Align that keeps its box', () async {
      for (final align in [
        (Widget c) => Center(child: c),
        (Widget c) => Align(alignment: Alignment.topCenter, child: c),
      ]) {
        final html = await page(align(box(m: const EdgeInsets.all(16))));
        final rule = ruleWith(html, 'max-width: 1088px');
        expectCentered(rule);
        expect(rule, contains('align-self: center'));
        expect(rule, contains('margin: 16px'));
      }
    });

    test('an uneven or directional margin takes out its sum', () async {
      for (final (m, width) in [
        (
          const EdgeInsets.only(left: 24, right: 8, top: 4),
          'calc(100% - 32px)',
        ),
        (const EdgeInsets.only(left: 10), 'calc(100% - 10px)'),
        (
          const EdgeInsetsDirectional.only(start: 12, end: 4),
          'calc(100% - 16px)',
        ),
      ]) {
        final html = await page(Column(children: [box(m: m)]));
        expectCentered(ruleWith(html, 'max-width: 1088px'), width: width);
      }
    });

    test('a Container that takes the max width (width: infinity)', () async {
      final html = await page(
        Center(child: capped(maxWidth: 1180, margin: const EdgeInsets.all(16))),
      );
      final rule = ruleWith(html, 'max-width: 1180px');
      expectCentered(rule);
      expect(rule, contains('margin: 16px'));
    });

    test('a child that does not fill keeps its own width', () async {
      final html = await page(
        const Column(
          children: [
            Container(
              constraints: BoxConstraints(maxWidth: 1087),
              margin: margin,
              child: Text('x'),
            ),
          ],
        ),
      );
      final rule = ruleWith(html, 'max-width: 1087px');
      expect(rule, isNot(contains('; width:')));
      expect(rule, contains('margin: 0px 16px'));
    });
  });

  group('unchanged (fail-closed: no width it could overflow with)', () {
    test('an Align to one side keeps stretch: its auto margins', () async {
      final html = await page(
        Align(
          alignment: Alignment.topRight,
          child: capped(margin: const EdgeInsets.all(16)),
        ),
      );
      final rule = ruleWith(html, 'max-width: 1180px');
      expect(rule, contains('align-self: stretch'));
      expect(rule, contains('margin: 16px'));
      expect(rule, isNot(contains('calc(')));
    });

    test('a margin per breakpoint keeps stretch', () async {
      final html = await page(
        Column(
          children: [
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 1086),
              margin: const EdgeInsets.all(
                8,
              ).when(medium: const EdgeInsets.all(16)),
            ),
          ],
        ),
      );
      final rule = ruleWith(html, 'max-width: 1086px');
      expect(rule, contains('align-self: stretch'));
      expect(html, isNot(contains('calc(')));
    });

    test('a filling child without a max width still stretches', () async {
      final html = await page(
        const Center(
          child: Container(width: double.infinity, color: Color(0xFF123456)),
        ),
      );
      final rule = ruleWith(html, 'background-color');
      expect(rule, contains('align-self: stretch'));
      expect(rule, contains('margin-left: 0'));
      expect(rule, contains('margin-right: 0'));
      expect(rule, contains('max-width: none'));
    });

    test('a min width alone still stretches', () async {
      final html = await page(
        const Center(
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(minWidth: 200),
          ),
        ),
      );
      final rule = ruleWith(html, 'min-width: 200px');
      expect(rule, contains('align-self: stretch'));
      expect(rule, contains('max-width: none'));
    });

    test('an explicit width with a max width is centered as before', () async {
      final html = await page(
        const Center(
          child: Container(
            width: 600,
            constraints: BoxConstraints(maxWidth: 400),
          ),
        ),
      );
      final rule = ruleWith(html, 'max-width: 400px');
      expect(rule, contains('width: 600px'), reason: 'its own width wins');
      expect(rule, contains('align-self: center'));
      expect(rule, isNot(contains('margin-left')));
    });

    // A centered Column positions it (below); one aligned to the start
    // stretches it, as Flutter places it at the start.
    test('a max width in a start Column keeps stretch', () async {
      final html = await page(
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 700),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [Text('x')],
              ),
            ),
          ],
        ),
      );
      final rule = ruleWith(html, 'max-width: 700px');
      expect(rule, contains('align-self: stretch'));
      expect(rule, isNot(contains('width: 100%')));
    });
  });

  group('a fixed width around a Row', () {
    // Flutter: Center > Container(width: 440, child: Row) is 440 wide and
    // centered; the Row fills the Container, not the Center.
    for (final (name, box) in [
      (
        'Container',
        const Container(width: 437, child: Row(children: [Text('a')])),
      ),
      (
        'SizedBox',
        const SizedBox(width: 437, child: Row(children: [Text('a')])),
      ),
    ]) {
      test('$name is centered by Center, not stretched', () async {
        final html = await page(Center(child: box));
        final rule = ruleWith(html, 'width: 437px');
        expect(rule, isNot(contains('align-self: stretch')));
        expect(rule, isNot(contains('max-width: none')));
        expect(rule, contains('align-self: center'));
      });
    }
  });

  // A capped child of a centered Column sat at the start.
  group('a capped child of a Column', () {
    Widget column(CrossAxisAlignment cross) => Column(
      crossAxisAlignment: cross,
      children: const [
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 820),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [Text('long text that fills the width')],
          ),
        ),
      ],
    );

    for (final cross in [CrossAxisAlignment.center, CrossAxisAlignment.end]) {
      test('is as wide as it may be and follows $cross', () async {
        final rule = ruleWith(await page(column(cross)), 'max-width: 820px');
        expect(rule, contains('width: 100%'));
        expect(rule, contains('box-sizing: border-box'));
        expect(rule, isNot(contains('align-self: stretch')));
      });
    }

    for (final cross in [
      CrossAxisAlignment.start,
      CrossAxisAlignment.stretch,
    ]) {
      test('stays stretched to the start with $cross', () async {
        final rule = ruleWith(await page(column(cross)), 'max-width: 820px');
        expect(rule, contains('align-self: stretch'));
        expect(rule, isNot(contains('width: 100%')));
      });
    }

    test('a Row keeps its rules', () async {
      final html = await page(
        const Row(
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 821),
              child: Row(children: [Text('x')]),
            ),
          ],
        ),
      );
      expect(
        ruleWith(html, 'max-width: 821px'),
        isNot(contains('width: 100%')),
      );
    });
  });
}
