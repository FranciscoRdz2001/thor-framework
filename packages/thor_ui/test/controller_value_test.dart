// A TextEditingController whose `value` was set before the page renders (a
// state method that ran on the server, or code at load) shows that text.
@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

Future<String> page(Widget body) => renderDocument(ThorApp(child: body));

void main() {
  initializeThorTests();

  test('value set before the first render is the field\'s text', () async {
    final c = TextEditingController()
      ..value = const TextEditingValue(
        text: 'hello',
        selection: TextSelection.collapsed(offset: 4),
      );
    final html = await page(
      TextField(
        controller: c,
        decoration: const InputDecoration(labelText: 'Name'),
      ),
    );
    expect(html, contains('value="hello"'));
  });

  test('a multiline field puts it inside the textarea', () async {
    final c = TextEditingController()
      ..value = const TextEditingValue(text: 'one\ntwo');
    final html = await page(
      TextField(
        controller: c,
        maxLines: 3,
        decoration: const InputDecoration(labelText: 'Name'),
      ),
    );
    expect(html, contains('one\ntwo'));
  });

  test('a later value replaces the earlier one; the same value twice is '
      'one text', () async {
    final c = TextEditingController(text: 'a')
      ..value = const TextEditingValue(text: 'b')
      ..value = const TextEditingValue(text: 'c');
    final html = await page(
      TextField(
        controller: c,
        decoration: const InputDecoration(labelText: 'Name'),
      ),
    );
    expect(html, contains('value="c"'));
    expect(html, isNot(contains('value="b"')));
  });

  test('TextEditingValue compares and hashes by value', () {
    const a = TextEditingValue(
      text: 'x',
      selection: TextSelection.collapsed(offset: 1),
    );
    const b = TextEditingValue(
      text: 'x',
      selection: TextSelection.collapsed(offset: 1),
    );
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a.copyWith(text: 'y'), isNot(a));
    expect(a.copyWith(), a);
    expect(
      a.copyWith(selection: const TextSelection.collapsed(offset: 0)),
      isNot(a),
    );
  });
}
