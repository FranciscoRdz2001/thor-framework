@TestOn('vm')
library;

// a `Dialog`/`AlertDialog` that does not block the page.
import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

Future<String> _page(Widget w) => renderDocument(ThorApp(child: w));

String _head(String html) => html.substring(0, html.indexOf('</head>'));

String _body(String html) => html.substring(html.indexOf('<body'));

void main() {
  setUpAll(initializeThorTests);

  group('non-modal dialog (34)', () {
    test('Dialog(modal: false) is an open dialog with no backdrop', () async {
      final html = await _page(
        const Dialog(modal: false, child: Text('Starting')),
      );
      final body = _body(html);
      expect(body, matches(RegExp(r'<dialog[^>]* open')));
      expect(body, isNot(contains('closedby')));
      expect(_head(html), isNot(contains('::backdrop')));
      expect(_head(html), isNot(contains('dialog:modal')));
      expect(_head(html), isNot(contains('overscroll-behavior')));
    });

    test('AlertDialog(modal: false) is open too; modal stays closed', () async {
      final html = await _page(
        const AlertDialog(modal: false, content: Text('Error')),
      );
      final open = _body(html);
      expect(open, matches(RegExp(r'<dialog[^>]* open')));
      expect(open, isNot(contains('closedby')));
      expect(_head(html), isNot(contains('::backdrop')));
      expect(_head(html), isNot(contains('dialog:modal')));
      expect(_head(html), isNot(contains('overscroll-behavior')));
      final modal = _body(
        await _page(const AlertDialog(content: Text('Error'))),
      );
      expect(modal, isNot(matches(RegExp(r'<dialog[^>]* open'))));
      expect(modal, contains('closedby="any"'));
    });
  });
}
