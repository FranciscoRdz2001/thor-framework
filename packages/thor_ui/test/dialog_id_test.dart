// `DialogTrigger(id:)` and `DialogClose(id:)` open and close a dialog by id.
@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

Future<String> _page(Widget body) => renderDocument(ThorApp(child: body));

Widget _button() => FilledButton(onPressed: () {}, child: const Text('Go'));

void main() {
  test('id opens and closes the dialog', () async {
    final byId = await _page(
      Column(
        children: [
          DialogTrigger(id: 'x', child: _button()),
          DialogClose(id: 'x', child: _button()),
        ],
      ),
    );
    expect(byId, contains('commandfor="x" command="show-modal"'));
    expect(byId, contains('commandfor="x" command="close"'));
  });

  test('a trigger needs a dialog, an id or a controller', () {
    expect(
      () => DialogTrigger(child: _button()),
      throwsA(
        isA<AssertionError>().having(
          (e) => '${e.message}',
          'message',
          contains('exactly one of dialog, id or controller'),
        ),
      ),
    );
  });
}
