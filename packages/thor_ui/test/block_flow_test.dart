@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

// web: Thor's Row and Column are flex boxes (as in Flutter: no margin
// collapsing, no inline boxes). A box that must flow like HTML block content,
// to collapse the margin between its children or to put an inline-level box
// in a line of text, says so with `display`.
Future<String> page(Widget body) => renderDocument(ThorApp(child: body));

String sheet(String html) {
  final s = html.substring(html.indexOf('id="thor-styles">'));
  return s.substring(0, s.indexOf('</style>'));
}

String ruleOf(String html, String id) {
  final cls = RegExp(
    '<[a-z0-9]+ [^>]*class="([^" ]+)"[^>]*id="$id"',
  ).firstMatch(html)![1]!;
  return RegExp('\\.$cls\\{([^}]*)\\}').firstMatch(html)![1]!;
}

void main() {
  setUpAll(initializeThorTests);

  test('a block Column holds an inline-flex Row in its line of text', () async {
    final html = await page(
      const Styled(
        style: StyleProps(display: Display.block),
        child: Column(
          children: [
            Styled(
              style: StyleProps(display: Display.inlineFlex),
              child: Semantics(
                identifier: 'pill',
                child: Row(children: [Text('New')]),
              ),
            ),
            Semantics(identifier: 'after', child: Text('Title')),
          ],
        ),
      ),
    );
    final css = sheet(html);
    expect(css, contains('display: block'));
    expect(ruleOf(html, 'pill'), contains('display: inline-flex'));
    expect(ruleOf(html, 'pill'), isNot(contains('display: flex')));
  });
}
