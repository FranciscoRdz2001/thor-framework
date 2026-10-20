@TestOn('vm')
library;

// A button the browser wires natively (`popovertarget`, `commandfor`) is
// enabled without `onPressed`: the wrapper is its action.
import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

void _noop() {}

Future<String> _page(Widget w) => renderHtml(w);

bool _disabled(String html) => RegExp(r'<button[^>]*\sdisabled').hasMatch(html);

void main() {
  setUpAll(initializeThorTests);

  test('a plain button without onPressed is still disabled', () async {
    expect(
      _disabled(
        await _page(const TextButton(onPressed: null, child: Text('x'))),
      ),
      isTrue,
    );
  });

  test('MenuAnchor builder buttons need no onPressed', () async {
    for (final button in <Widget>[
      const TextButton(onPressed: null, child: Text('Menu')),
      const FilledButton(onPressed: null, child: Text('Menu')),
      const OutlinedButton(onPressed: null, child: Text('Menu')),
      const IconButton(
        onPressed: null,
        tooltip: 'Menu',
        icon: Icon(IconData.svg('x', '<path/>')),
      ),
    ]) {
      final html = await _page(
        MenuAnchor(
          menuChildren: [
            const MenuItemButton(onPressed: _noop, child: Text('One')),
          ],
          builder: (context, controller, child) => button,
        ),
      );
      expect(html, contains('popovertarget'));
      expect(_disabled(html), isFalse, reason: '${button.runtimeType}');
    }
  });

  test('MenuAnchor child button needs no onPressed', () async {
    final html = await _page(
      const MenuAnchor(
        menuChildren: [MenuItemButton(onPressed: _noop, child: Text('One'))],
        child: TextButton(onPressed: null, child: Text('Menu')),
      ),
    );
    expect(html, contains('popovertarget'));
    expect(_disabled(html), isFalse);
  });

  test('DialogTrigger and DialogClose buttons need no onPressed', () async {
    final html = await _page(
      const Column(
        children: [
          DialogTrigger(
            id: 'x',
            child: FilledButton(onPressed: null, child: Text('Open')),
          ),
          DialogClose(
            id: 'x',
            child: TextButton(onPressed: null, child: Text('Close')),
          ),
        ],
      ),
    );
    expect(html, contains('commandfor="x" command="show-modal"'));
    expect(html, contains('commandfor="x" command="close"'));
    expect(_disabled(html), isFalse);
  });

  test('stays native: no handler, no script, no onclick', () async {
    final html = await _page(
      const DialogTrigger(
        id: 'x',
        child: FilledButton(onPressed: null, child: Text('Open')),
      ),
    );
    expect(html, isNot(contains('onclick')));
    expect(html, isNot(contains('<script')));
  });

  test('enabled: false disables a trigger on purpose', () async {
    final html = await _page(
      const Column(
        children: [
          DialogTrigger(
            id: 'x',
            enabled: false,
            child: FilledButton(onPressed: _noop, child: Text('Open')),
          ),
          DialogClose(
            id: 'x',
            enabled: false,
            child: TextButton(onPressed: null, child: Text('Close')),
          ),
        ],
      ),
    );
    expect(RegExp(r'<button[^>]*\sdisabled').allMatches(html), hasLength(2));
  });

  test('a submit button in a Form inside DialogClose stays enabled', () async {
    final html = await _page(
      const Form(
        child: DialogClose(
          id: 'x',
          child: FilledButton(
            onPressed: null,
            buttonType: ButtonType.submit,
            child: Text('Save'),
          ),
        ),
      ),
    );
    expect(_disabled(html), isFalse);
    expect(html, contains('command="close"'));
  });
}
