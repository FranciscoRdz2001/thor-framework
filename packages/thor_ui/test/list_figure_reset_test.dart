@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';
import 'package:thor_ui/web.dart' show ListStyleType;

Future<String> page(Widget body) => renderDocument(ThorApp(child: body));

/// The declarations of the class of the first element tagged [tag].
String ruleOf(String html, String tag) {
  final cls = RegExp('<$tag[^>]*class="([^" ]+)').firstMatch(html)![1]!;
  return RegExp('\\.$cls\\{([^}]*)\\}').firstMatch(html)![1]!;
}

void main() {
  setUpAll(initializeThorTests);

  test(
    'a list role draws no markers until listStyleType asks for them',
    () async {
      final plain = await page(
        const Semantics(
          role: SemanticsRole.list,
          child: Column(
            children: [
              Semantics(role: SemanticsRole.listItem, child: Text('a')),
            ],
          ),
        ),
      );
      expect(ruleOf(plain, 'ul'), contains('list-style: none'));

      final marked = await page(
        const Styled(
          style: StyleProps(listStyleType: ListStyleType.disc),
          child: Semantics(
            role: SemanticsRole.list,
            child: Column(
              children: [
                Semantics(role: SemanticsRole.listItem, child: Text('a')),
              ],
            ),
          ),
        ),
      );
      final rule = ruleOf(marked, 'ul');
      // The reset comes first in the class, so the typed value wins.
      expect(
        rule.indexOf('list-style: none'),
        lessThan(rule.indexOf('list-style-type: disc')),
      );
      expect(RegExp('list-style').allMatches(rule), hasLength(2));
    },
  );

  test('an ordered list takes its markers the same way', () async {
    final html = await page(
      const Styled(
        style: StyleProps(listStyleType: ListStyleType.decimal),
        child: Semantics(
          role: SemanticsRole.orderedList,
          child: Column(
            children: [
              Semantics(role: SemanticsRole.listItem, child: Text('a')),
            ],
          ),
        ),
      ),
    );
    expect(ruleOf(html, 'ol'), contains('list-style-type: decimal'));
  });

  test(
    'a figure, a blockquote and a paragraph role drop the browser margins',
    () async {
      for (final (role, tag) in [
        (SemanticsRole.figure, 'figure'),
        (SemanticsRole.blockquote, 'blockquote'),
        (SemanticsRole.paragraph, 'p'),
        (SemanticsRole.preformatted, 'pre'),
      ]) {
        final html = await page(
          Semantics(
            role: role,
            child: const Column(children: [Text('x')]),
          ),
        );
        expect(ruleOf(html, tag), contains('margin: 0'), reason: tag);
      }
    },
  );

  test('justifyItems places the grid items on the inline axis', () {
    expect(
      const StyleProps(
        display: Display.grid,
        justifyItems: CrossAxisAlignment.center,
      ).toCss(),
      containsPair('justify-items', 'center'),
    );
  });
}
