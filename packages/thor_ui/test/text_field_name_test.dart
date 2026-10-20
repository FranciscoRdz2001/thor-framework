// The accessible name of the input: the `<label for>` of a labelText, else
// the hintText (also when the labelText is empty) as `aria-label`.
@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

Future<String> _body(Widget w) async =>
    bodyOfPage(await renderDocument(ThorApp(child: w)));

String _control(String html) =>
    RegExp(r'<(?:input|textarea)\b[^>]*>').firstMatch(html)![0]!;

void main() {
  setUpAll(initializeThorTests);

  test('an empty labelText falls back to the hintText name', () async {
    final html = await _body(
      const TextField(
        decoration: InputDecoration(labelText: '', hintText: 'Search'),
      ),
    );
    expect(_control(html), contains('aria-label="Search"'));
  });

  test('labelText is the name, over the hintText', () async {
    final html = await _body(
      const TextField(
        id: 'n',
        decoration: InputDecoration(labelText: 'Name', hintText: 'Ann'),
      ),
    );
    expect(html, matches(RegExp(r'<label[^>]*for="n"[^>]*>Name</label>')));
    expect(_control(html), isNot(contains('aria-label')));
  });
}
