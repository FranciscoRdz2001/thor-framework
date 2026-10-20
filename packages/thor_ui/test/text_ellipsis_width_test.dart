@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

Future<String> page(Widget body) => renderDocument(ThorApp(child: body));

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

void main() {
  // Flutter gives a Column's children the column's width as their max
  // width, so a one-line Text with an ellipsis truncates at the column's
  // edge. In CSS a start-aligned flex item is fit-content: with
  // `white-space: nowrap` that is the whole line, so the text ran past the
  // column (over its neighbours) and the ellipsis never showed.
  for (final (name, text) in [
    (
      'maxLines: 1',
      const Text(
        'long',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 13.5),
      ),
    ),
    (
      'overflow: ellipsis',
      const Text(
        'long',
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 13.5),
      ),
    ),
  ]) {
    test('a truncated Text ($name) never grows past its parent', () async {
      final html = await page(
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [text],
              ),
            ),
            const Text('hace 5 min'),
          ],
        ),
      );
      final rule = ruleWith(html, 'font-size: 13.5px');
      expect(rule, contains('text-overflow: ellipsis'));
      expect(rule, contains('max-width: 100%'));
    });
  }

  test('a Text that wraps keeps no max-width (it already fits)', () async {
    final html = await page(
      const Column(children: [Text('wraps', style: TextStyle(fontSize: 13.5))]),
    );
    expect(ruleWith(html, 'font-size: 13.5px'), isNot(contains('max-width')));
  });
}
