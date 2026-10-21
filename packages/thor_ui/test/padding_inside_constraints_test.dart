@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

Future<String> page(Widget body) => renderDocument(ThorApp(child: body));

/// The declarations of the only class rule that contains [marker].
String ruleWith(String html, String marker) {
  final rules = RegExp(r'\.[\w-]+\{([^}]*)\}')
      .allMatches(html)
      .map((m) => m[1]!)
      .where((r) => r.contains(marker))
      .toList();
  expect(rules, hasLength(1), reason: 'one rule with "$marker"');
  return rules.single;
}

const _box = Container(color: Color(0xFF123456), child: Text('x'));

void main() {
  setUpAll(initializeThorTests);

  group('a Padding inside a size constraint counts in the constraint', () {
    test('maxWidth 1180 with horizontal 28 is 1180 wide in total', () async {
      final rule = ruleWith(
        await page(
          const Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 1180),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 28),
                child: _box,
              ),
            ),
          ),
        ),
        'max-width',
      );
      expect(rule, contains('max-width: 1124px'));
      expect(rule, contains('margin: 0px 28px'));
      expect(rule, isNot(contains('1180px')));
    });

    test('a padded Column already measures it inside (border-box)', () async {
      final rule = ruleWith(
        await page(
          const Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 1180),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [Text('x')],
                ),
              ),
            ),
          ),
        ),
        'max-width',
      );
      expect(rule, contains('max-width: 1180px'));
      expect(rule, contains('padding: 0px 28px'));
      expect(rule, contains('box-sizing: border-box'));
    });

    test('a Container child keeps its margin inside the constraint', () async {
      final rule = ruleWith(
        await page(
          const Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 1180),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 28),
                child: Container(color: Color(0xFF123456), child: Text('x')),
              ),
            ),
          ),
        ),
        'max-width',
      );
      expect(rule, contains('max-width: 1124px'));
    });

    test('minHeight loses the vertical padding', () async {
      final html = await page(
        const ConstrainedBox(
          constraints: BoxConstraints(minHeight: 100),
          child: Padding(padding: EdgeInsets.all(10), child: _box),
        ),
      );
      expect(html, contains('min-height: 80px'));
    });

    test('a padded Text with a max size is border-box', () async {
      final rule = ruleWith(
        await page(
          const ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 300, maxHeight: 200),
            child: Padding(padding: EdgeInsets.all(6), child: Text('y')),
          ),
        ),
        'max-width',
      );
      expect(rule, contains('max-width: 300px'));
      expect(rule, contains('padding: 6px'));
      expect(rule, contains('box-sizing: border-box'));
    });

    test('a SizedBox width is its own element: the margin is inside', () async {
      final html = await page(
        const SizedBox(
          width: 200,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: _box,
          ),
        ),
      );
      expect(html, contains('width: 200px'));
      expect(html, contains('margin: 0px 12px'));
    });

    test('a Container margin inside a ConstrainedBox counts too', () async {
      final rule = ruleWith(
        await page(
          const ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 600),
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 20),
              color: Color(0xFF123456),
              child: Text('x'),
            ),
          ),
        ),
        'max-width',
      );
      expect(rule, contains('max-width: 560px'));
    });

    test('a non-pixel constraint becomes a calc()', () async {
      final html = await page(
        const FractionallySizedBox(
          widthFactor: 0.5,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: _box,
          ),
        ),
      );
      expect(html, contains('width: calc(50% - 16px)'));
    });
  });

  group('the padding keeps its outside meaning when it is outside', () {
    test('Padding around the ConstrainedBox is not subtracted', () async {
      final html = await page(
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 28),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 1180),
            child: _box,
          ),
        ),
      );
      expect(html, contains('max-width: 1180px'));
      expect(html, isNot(contains('1124px')));
    });

    test('Container(constraints:, margin:) keeps the margin outside', () async {
      final html = await page(
        const Container(
          constraints: BoxConstraints(maxWidth: 600),
          margin: EdgeInsets.symmetric(horizontal: 20),
          color: Color(0xFF123456),
          child: Text('x'),
        ),
      );
      expect(html, contains('max-width: 600px'));
    });

    test('Container(constraints:, padding:) keeps border-box sizing', () async {
      final rule = ruleWith(
        await page(
          const Container(
            constraints: BoxConstraints(maxWidth: 600),
            padding: EdgeInsets.symmetric(horizontal: 20),
            color: Color(0xFF123456),
            child: Text('x'),
          ),
        ),
        'max-width',
      );
      expect(rule, contains('max-width: 600px'));
      expect(rule, contains('box-sizing: border-box'));
    });
  });
}
