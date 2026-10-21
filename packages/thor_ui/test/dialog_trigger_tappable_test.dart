// `DialogTrigger` / `DialogClose` around something that is not a `<button>`
// (a tappable card): the browser only runs Invoker Commands on a button, so
// the element is announced and focusable like one and the lite engine
// carries the command.
@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

Future<String> _page(Widget body) => renderDocument(ThorApp(child: body));

String _tagWith(String html, String attr) {
  final m = RegExp('<[^>]*$attr[^>]*>').firstMatch(html);
  expect(m, isNotNull, reason: 'no element with $attr in $html');
  return m!.group(0)!;
}

void main() {
  test('a card under a trigger is a focusable role=button', () async {
    final html = await _page(
      const DialogTrigger(
        id: 'x',
        child: InkWell(child: Card(child: Text('a'))),
      ),
    );
    final tag = _tagWith(html, 'commandfor');
    expect(tag, startsWith('<div'));
    expect(tag, contains('commandfor="x" command="show-modal"'));
    expect(tag, contains('role="button"'));
    expect(tag, contains('tabindex="0"'));
  });

  test('a disabled trigger on a card says aria-disabled', () async {
    final html = await _page(
      const DialogTrigger(
        id: 'x',
        enabled: false,
        child: InkWell(child: Card(child: Text('a'))),
      ),
    );
    final tag = _tagWith(html, 'commandfor');
    expect(tag, contains('aria-disabled="true"'));
    expect(tag, isNot(contains(' disabled')));
  });

  test('a real button stays a plain button', () async {
    final html = await _page(
      DialogTrigger(
        id: 'x',
        child: FilledButton(onPressed: () {}, child: const Text('Go')),
      ),
    );
    final tag = _tagWith(html, 'commandfor');
    expect(tag, startsWith('<button'));
    expect(tag, isNot(contains('role=')));
    expect(tag, isNot(contains('tabindex')));
  });

  test('a close wrapper on a column works the same', () async {
    final html = await _page(
      const Drawer(
        id: 'd',
        child: DialogClose(
          child: GestureDetector(
            child: Column(children: [Text('a'), Text('b')]),
          ),
        ),
      ),
    );
    final tag = _tagWith(html, 'command="close"');
    expect(tag, startsWith('<div'));
    expect(tag, contains('commandfor="d"'));
    expect(tag, contains('role="button"'));
  });
}
