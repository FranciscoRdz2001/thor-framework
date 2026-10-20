@TestOn('vm')
library;

// A modal `<dialog>` locks the page's scroll with one server-written rule,
// only on the pages that have one (rule 4: no client styles, no JS).
import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

const _lock =
    ':root:has(dialog:modal){overflow: hidden; scrollbar-gutter: stable; '
    'overscroll-behavior: none}';

Future<String> _html(Widget w) => renderDocument(ThorApp(child: w));

void main() {
  initializeThorTests();

  test('a page without a modal dialog ships no scroll lock', () async {
    final html = await _html(const Text('hello'));
    expect(html, isNot(contains('dialog:modal')));
  });

  for (final (name, dialog) in <(String, Widget)>[
    ('Drawer', const Drawer(child: Text('x'))),
    ('AlertDialog', const AlertDialog(title: Text('x'))),
    ('Dialog', const Dialog(child: Text('x'))),
    ('ModalBottomSheet', const ModalBottomSheet(child: Text('x'))),
  ]) {
    test('$name locks the document scroll and contains its own', () async {
      final html = await _html(dialog);
      expect(html, contains(_lock));
      expect(html, contains('overscroll-behavior: contain'));
    });
  }

  test('several modal dialogs share the one rule', () async {
    final html = await _html(
      const Column(
        children: [
          Drawer(child: Text('a')),
          AlertDialog(title: Text('b')),
          ModalBottomSheet(child: Text('c')),
        ],
      ),
    );
    expect(RegExp(RegExp.escape(_lock)).allMatches(html), hasLength(1));
  });
}
