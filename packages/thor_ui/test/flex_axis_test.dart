@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

Future<String> page(Widget body) => renderDocument(ThorApp(child: body));

/// The declarations of the class of the element tagged [tag].
String ruleOf(String html, String tag) {
  final cls = RegExp('<$tag[^>]*class="([^" ]+)').firstMatch(html)![1]!;
  return RegExp('\\.$cls\\{([^}]*)\\}').firstMatch(html)![1]!;
}

void main() {
  setUpAll(initializeThorTests);

  test('Expanded in a Row frees the width, keeps the min height', () async {
    final html = await page(
      Row(
        children: [
          Expanded(
            child: FilledButton(onPressed: () {}, child: const Text('Add')),
          ),
        ],
      ),
    );
    final rule = ruleOf(html, 'button');
    expect(rule, contains('min-width: 0'));
    expect(rule, contains('min-height: 40px'), reason: "the button's own");
    expect(rule, isNot(contains('min-height: 0')));
  });

  test('Expanded in a Column frees the height, keeps the min width', () async {
    final html = await page(
      const SizedBox(
        height: 200,
        child: Column(
          children: [
            Expanded(
              child: Semantics(role: SemanticsRole.paragraph, child: Text('x')),
            ),
          ],
        ),
      ),
    );
    final rule = ruleOf(html, 'p');
    expect(rule, contains('min-height: 0'));
    expect(rule, contains('flex: 1 1 0'));
  });

  test('Expanded takes its share by percentage: an auto-height Column keeps '
      'the content', () async {
    // web: `flex-basis: 0%` is 0 when the container's main size is definite
    // (the same share Flutter gives) and `content` when it is not, so a
    // Column that grows with its content (a phone, `FlexLayout`) does not
    // collapse the Expanded to a height of 0.
    final html = await page(
      Column(
        layout: const FlexLayout().when(
          expanded: const FlexLayout(direction: Axis.horizontal),
        ),
        children: const [
          Expanded(
            child: Semantics(role: SemanticsRole.paragraph, child: Text('x')),
          ),
        ],
      ),
    );
    expect(ruleOf(html, 'p'), contains('flex: 1 1 0%'));
  });

  test('an outlined button is as tall as a filled one (40 px)', () async {
    final html = await page(
      OutlinedButton(onPressed: () {}, child: const Text('Details')),
    );
    expect(ruleOf(html, 'button'), contains('padding: 9px 23px'));
  });
}
