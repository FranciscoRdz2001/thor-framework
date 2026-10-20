@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

Future<String> page(Widget body) async {
  final html = await renderDocument(ThorApp(child: body));
  return html.substring(html.indexOf('<body'));
}

void main() {
  setUpAll(initializeThorTests);

  test('value, hint, tooltip, expanded and readOnly are ARIA', () async {
    final html = await page(
      const Semantics(
        value: '50 percent',
        hint: 'Drag to change',
        tooltip: 'Volume',
        expanded: true,
        readOnly: true,
        child: Text('x'),
      ),
    );
    expect(html, isNot(contains('aria-valuetext')));
    expect(html, contains('aria-description="Drag to change. 50 percent"'));
    expect(html, contains('title="Volume"'));
    expect(html, contains('aria-expanded="true"'));
    expect(html, contains('aria-readonly="true"'));
  });

  test('checked over a bare child is a checkbox', () async {
    final html = await page(
      const Semantics(checked: false, child: Text('Agree')),
    );
    expect(html, contains('role="checkbox"'));
    expect(html, contains('aria-checked="false"'));
  });

  test('slider, textField and container give a role to a bare child', () async {
    final html = await page(
      const Column(
        children: [
          Semantics(slider: true, value: '3', child: Text('a')),
          Semantics(textField: true, child: Text('b')),
          Semantics(container: true, label: 'Group', child: Text('c')),
          Semantics(excludeSemantics: true, label: 'Logo', child: Text('d')),
        ],
      ),
    );
    expect(html, contains('role="slider"'));
    expect(html, contains('role="textbox"'));
    expect(html, contains('role="group"'));
    expect(html, contains('role="img"'));
  });

  test('focusable writes tabindex; sortKey and obscured nothing', () async {
    final html = await page(
      const Semantics(
        focusable: true,
        obscured: true,
        explicitChildNodes: true,
        sortKey: OrdinalSortKey(1),
        child: Text('x'),
      ),
    );
    expect(html, contains('tabindex="0"'));
    expect(html, isNot(contains('obscured')));
  });

  test('new roles map to ARIA roles', () async {
    final html = await page(
      const Semantics(role: SemanticsRole.progressBar, child: Text('x')),
    );
    expect(html, contains('role="progressbar"'));
  });

  test('BlockSemantics is aria-modal; MergeSemantics adds nothing', () async {
    final html = await page(
      const Column(
        children: [
          BlockSemantics(child: Text('a')),
          MergeSemantics(child: Text('b')),
        ],
      ),
    );
    expect(html, contains('aria-modal="true"'));
  });

  test('IgnorePointer ignores pointers, AbsorbPointer is inert', () async {
    final html = await page(
      const Column(
        children: [
          IgnorePointer(child: Text('a')),
          IgnorePointer(ignoring: false, child: Text('b')),
          AbsorbPointer(child: Text('c')),
          IgnorePointer(ignoringSemantics: true, child: Text('d')),
        ],
      ),
    );
    final doc = await renderDocument(
      const ThorApp(child: IgnorePointer(child: Text('a'))),
    );
    expect(doc, contains('pointer-events: none'));
    expect(html, contains('inert'));
    expect(html, contains('aria-hidden="true"'));
  });

  test('a role flag never replaces the role of the child', () async {
    final html = await page(
      Column(
        children: [
          Semantics(
            container: true,
            child: TextButton(onPressed: () {}, child: const Text('a')),
          ),
          Semantics(
            excludeSemantics: true,
            label: 'Close',
            child: IconButton(onPressed: () {}, icon: const Icon(Icons.close)),
          ),
          const Semantics(container: true, child: ListTile(title: Text('t'))),
        ],
      ),
    );
    expect(html, isNot(contains('role="group"')));
    expect(html, isNot(contains('role="img"')));
    expect(html, contains('<button'));
  });

  test('checked over a native switch writes no static aria-checked', () async {
    final html = await page(
      Semantics(checked: true, child: Switch(value: true, onChanged: (_) {})),
    );
    expect(html, isNot(contains('aria-checked')));
    expect(html, isNot(contains('role="checkbox"')));
  });

  test('aria-valuetext only with a range role; slider gets valuenow', () async {
    final html = await page(
      const Column(
        children: [
          Semantics(slider: true, value: '3', child: Text('a')),
          Semantics(
            role: SemanticsRole.progressBar,
            value: '9%',
            child: Text('b'),
          ),
          Semantics(excludeSemantics: true, child: Text('c')),
        ],
      ),
    );
    expect(html, contains('aria-valuenow="3"'));
    expect(html, contains('aria-valuetext="3"'));
    expect(html, contains('aria-valuetext="9%"'));
    expect(html, isNot(contains('role="img"')));
  });
}
