@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';
import 'package:thor_ui/web.dart';

Future<String> page(Widget body) => renderDocument(ThorApp(child: body));

/// The declarations of the class of the element with [id].
String ruleOf(String html, String id) {
  final cls =
      RegExp('id="$id"[^>]*class="([^" ]+)').firstMatch(html)?[1] ??
      RegExp('class="([^" ]+)"[^>]*id="$id"').firstMatch(html)![1]!;
  return RegExp('\\.$cls\\{([^}]*)\\}').firstMatch(html)![1]!;
}

void main() {
  setUpAll(initializeThorTests);

  group('children of a Column or Row turned into a grid', () {
    Future<String> grid({Widget? child}) => page(
      const Styled(
        style: StyleProps(
          display: Display.grid,
          crossAxisAlignment: CrossAxisAlignment.center,
        ),
        child: Column(
          children: [
            // Fills the cross axis, as a text column of a two-column hero.
            SizedBox(
              width: double.infinity,
              child: Column(
                children: [Semantics(identifier: 'inner', child: Text('x'))],
              ),
            ),
          ],
        ),
      ),
    );

    test('are not stretched: the grid\'s align-items places them', () async {
      final html = await grid();
      final styles = html.substring(html.indexOf('id="thor-styles">'));
      final sheet = styles.substring(0, styles.indexOf('</style>'));
      expect(sheet, contains('align-items: center'));
      expect(sheet, isNot(contains('align-self')));
    });
  });

  group('StyleProps.flex', () {
    test('flex alone is the CSS shorthand: grow, shrink and a zero basis', () {
      expect(const StyleProps(flex: 1).toCss(), containsPair('flex', '1 1 0%'));
    });

    test('an explicit basis or shrink keeps the longhands', () {
      final css = const StyleProps(
        flex: 1,
        flexShrink: 0,
        flexBasis: Length.zero,
      ).toCss();
      expect(css, containsPair('flex-grow', '1'));
      expect(css, containsPair('flex-shrink', '0'));
      expect(css, containsPair('flex-basis', '0'));
      expect(css, isNot(contains('flex')));
    });

    test('flexShrink next to flex only changes the shrink factor', () {
      expect(
        const StyleProps(flex: 2, flexShrink: 0).toCss(),
        containsPair('flex', '2 0 0%'),
      );
    });
  });
}
