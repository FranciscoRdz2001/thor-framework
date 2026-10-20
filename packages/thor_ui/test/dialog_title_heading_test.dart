@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

Future<String> _page(Widget body) async {
  final html = await renderDocument(ThorApp(child: body));
  return html.substring(html.indexOf('<body'));
}

void main() {
  setUpAll(initializeThorTests);

  test('the AlertDialog title is an h2 the dialog is labelled by', () async {
    final html = await _page(
      const AlertDialog(
        id: 'd',
        title: Text('Delete?'),
        content: Text('Gone for good.'),
      ),
    );
    expect(
      RegExp(r'<h2[^>]*id="d-title"[^>]*>Delete\?</h2>').hasMatch(html),
      isTrue,
      reason: html,
    );
    expect(html, contains('aria-labelledby="d-title"'));
  });

  test(
    'a title wrapped in Semantics(headingLevel:) keeps one heading',
    () async {
      final html = await _page(
        const AlertDialog(
          id: 'd',
          title: Semantics(headingLevel: 3, child: Text('Delete?')),
        ),
      );
      expect('<h2'.allMatches(html), isEmpty, reason: html);
      expect('<h3'.allMatches(html), hasLength(1), reason: html);
      expect(html, contains('id="d-title"'));
    },
  );

  test('no title, no heading', () async {
    final html = await _page(const AlertDialog(id: 'd', content: Text('x')));
    expect(html, isNot(contains('<h2')));
  });
}
