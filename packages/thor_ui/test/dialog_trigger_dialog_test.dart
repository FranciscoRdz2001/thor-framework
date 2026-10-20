// `DialogTrigger(dialog:)` renders the button and its dialog together, with
// an id the page names.
@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

Future<String> _page(Widget body) => renderDocument(ThorApp(child: body));

Widget _button(String label) =>
    FilledButton(onPressed: () {}, child: Text(label));

final _opens = RegExp(r'commandfor="([^"]+)" command="show-modal"');

void main() {
  test('the trigger and its dialog share an automatic id', () async {
    final html = await _page(
      DialogTrigger(
        dialog: AlertDialog(
          title: const Text('Delete?'),
          actions: [DialogClose(child: _button('Cancel'))],
        ),
        child: _button('Delete'),
      ),
    );
    final id = _opens.firstMatch(html)?.group(1);
    expect(id, isNotNull);
    expect(html, contains('<dialog'));
    expect(html, contains('id="$id"'));
    // The dialog's own close button points at it too.
    expect(html, contains('command="close" commandfor="$id"'));
    expect(html.indexOf('show-modal'), lessThan(html.indexOf('<dialog')));
  });

  test('two triggers get two ids, the same on every render', () async {
    Widget page() => Column(
      children: [
        DialogTrigger(
          dialog: const Dialog(child: Text('one')),
          child: _button('A'),
        ),
        DialogTrigger(
          dialog: const ModalBottomSheet(child: Text('two')),
          child: _button('B'),
        ),
      ],
    );
    final first = await _page(page());
    final second = await _page(page());
    expect(first, second);
    final ids = _opens.allMatches(first).map((m) => m.group(1)).toList();
    expect(ids, hasLength(2));
    expect(ids[0], isNot(ids[1]));
    for (final id in ids) {
      expect(first, contains('id="$id"'));
    }
  });

  test('a dialog with its own id keeps it', () async {
    final html = await _page(
      DialogTrigger(
        dialog: const AlertDialog(id: 'confirm', title: Text('Sure?')),
        child: _button('Go'),
      ),
    );
    expect(html, contains('commandfor="confirm" command="show-modal"'));
    expect(html, contains('id="confirm"'));
  });

  test('a dialog nested in the carried one names itself', () async {
    final html = await _page(
      DialogTrigger(
        dialog: AlertDialog(
          content: DialogTrigger(
            dialog: const Dialog(child: Text('inner')),
            child: _button('More'),
          ),
        ),
        child: _button('Open'),
      ),
    );
    final ids = _opens.allMatches(html).map((m) => m.group(1)).toSet();
    expect(ids, hasLength(2));
    for (final id in ids) {
      expect(html, contains('id="$id"'));
    }
  });

  test('only dialogs can be carried', () async {
    await expectLater(
      _page(DialogTrigger(dialog: const Text('no'), child: _button('Go'))),
      throwsA(isA<StateError>()),
    );
  });

  test('exactly one of dialog, id or controller', () {
    expect(
      () => DialogTrigger(
        id: 'x',
        dialog: const Dialog(child: Text('x')),
        child: _button('Go'),
      ),
      throwsA(isA<AssertionError>()),
    );
  });
}
