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

  test('headingLevel makes a Text a heading, like Flutter', () async {
    final html = await page(
      const Semantics(headingLevel: 2, child: Text('Pricing')),
    );
    expect(html, contains('<h2 '));
    expect(html, contains('>Pricing</h2>'));
  });

  group('selected and toggled on a button are aria-pressed', () {
    test('Semantics(button: true, selected:)', () async {
      final html = await page(
        const Semantics(button: true, selected: true, child: Text('Anual')),
      );
      expect(html, contains('aria-pressed="true"'));
      expect(html, isNot(contains('aria-selected')));
    });

    test('Semantics(selected:) over a TextButton or an IconButton', () async {
      final html = await page(
        Row(
          children: [
            Semantics(
              selected: false,
              child: TextButton(onPressed: () {}, child: const Text('Mensual')),
            ),
            Semantics(
              selected: true,
              child: IconButton(onPressed: () {}, icon: const Text('*')),
            ),
          ],
        ),
      );
      expect(html, contains('aria-pressed="false"'));
      expect(html, contains('aria-pressed="true"'));
      expect(html, isNot(contains('aria-selected')));
    });

    test('Semantics(toggled:) on a button is aria-pressed, elsewhere a '
        'switch', () async {
      final html = await page(
        Column(
          children: [
            Semantics(
              toggled: true,
              child: TextButton(
                onPressed: () {},
                child: const Text('Negritas'),
              ),
            ),
            const Semantics(toggled: false, child: Text('Wifi')),
          ],
        ),
      );
      expect(html, contains('aria-pressed="true"'));
      expect(html, contains('role="switch"'));
      expect(html, contains('aria-checked="false"'));
    });

    test('selected stays aria-selected where ARIA allows it', () async {
      final html = await page(
        const Semantics(
          role: SemanticsRole.gridCell,
          selected: true,
          child: Text('x'),
        ),
      );
      expect(html, contains('aria-selected="true"'));
      expect(html, isNot(contains('aria-pressed')));
    });
  });

  test('a list: Wrap as <ul>, chips as <li>', () async {
    final html = await page(
      const Semantics(
        role: SemanticsRole.list,
        child: Wrap(
          children: [
            Semantics(
              role: SemanticsRole.listItem,
              child: Chip(label: Text('Iced')),
            ),
          ],
        ),
      ),
    );
    expect(html, contains('<ul '));
    expect(html, contains('<li '));
    final full = await renderDocument(
      const ThorApp(
        child: Semantics(role: SemanticsRole.list, child: Wrap()),
      ),
    );
    expect(full, contains('list-style: none'), reason: 'no bullets');
  });

  test('landmarks and web extras', () async {
    for (final (role, tag) in [
      (SemanticsRole.navigation, 'nav'),
      (SemanticsRole.main, 'main'),
      (SemanticsRole.complementary, 'aside'),
      (SemanticsRole.contentInfo, 'footer'),
      (SemanticsRole.region, 'section'),
      (SemanticsRole.form, 'form'),
      (SemanticsRole.article, 'article'),
      (SemanticsRole.paragraph, 'p'),
    ]) {
      final html = await page(
        Semantics(
          role: role,
          child: const Column(children: [Text('x')]),
        ),
      );
      expect(html, contains('<$tag '), reason: '$role');
    }
  });

  test('a role without its own tag becomes an ARIA role', () async {
    final html = await page(
      const Semantics(role: SemanticsRole.status, child: Text('Saved')),
    );
    expect(html, contains('role="status"'));
  });

  test('a note is a labelled ARIA note', () async {
    final html = await page(
      const Semantics(
        role: SemanticsRole.note,
        label: 'Ojo',
        child: Column(children: [Text('Careful')]),
      ),
    );
    expect(html, contains('role="note"'));
    expect(html, contains('aria-label="Ojo"'));
  });

  test('grid roles, indices and selection map onto ARIA', () async {
    final html = await page(
      const Semantics(
        role: SemanticsRole.grid,
        label: 'Records',
        rowCount: 2001,
        columnCount: 13,
        child: Column(
          children: [
            Semantics(
              role: SemanticsRole.row,
              rowIndex: 1,
              child: Row(
                children: [
                  Semantics(
                    role: SemanticsRole.columnHeader,
                    columnIndex: 2,
                    child: Text('Name'),
                  ),
                ],
              ),
            ),
            Semantics(
              role: SemanticsRole.row,
              rowIndex: 40,
              child: Row(
                children: [
                  Semantics(
                    role: SemanticsRole.rowHeader,
                    columnIndex: 2,
                    selected: true,
                    child: Text('Aurora'),
                  ),
                  Semantics(
                    role: SemanticsRole.gridCell,
                    columnIndex: 3,
                    selected: false,
                    child: Text('Beta'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    expect(
      html,
      contains(
        'role="grid" aria-label="Records" aria-rowcount="2001" '
        'aria-colcount="13"',
      ),
    );
    expect(html, contains('role="row" aria-rowindex="40"'));
    expect(html, contains('role="columnheader" aria-colindex="2"'));
    expect(
      html,
      contains('role="rowheader" aria-selected="true" aria-colindex="2"'),
    );
    expect(
      html,
      contains('role="gridcell" aria-selected="false" aria-colindex="3"'),
    );
    expect(RegExp('<(table|tr|td)').allMatches(html), isEmpty);
  });

  test('button: a native <button> around a thor element', () async {
    final html = await page(
      const Semantics(button: true, child: Container(child: Text('×'))),
    );
    expect(html, contains('<button '));
    expect(html, contains('type="button"'));
  });

  test("a heading's size and weight come from its TextStyle", () async {
    final html = await renderDocument(
      const ThorApp(child: Semantics(headingLevel: 2, child: Text('Title'))),
    );
    final cls = RegExp('<h2 class="([^"]+)"').firstMatch(html)![1]!;
    final rule = RegExp('\\.$cls\\{([^}]*)\\}').firstMatch(html)![1]!;
    expect(rule, contains('font-weight: inherit'));
    expect(rule, contains('font-size: inherit'));
  });

  test('a Gesture around a Semantics button adds no role', () async {
    final html = await page(
      Gesture(
        onTap: () {},
        child: const Semantics(
          button: true,
          child: Container(child: Text('x')),
        ),
      ),
    );
    expect(html, contains('<button '));
    expect(html, isNot(contains('role="button"')));
  });

  test('a drag handle is a separator; a live region is polite', () async {
    final html = await page(
      const Column(
        children: [
          Semantics(
            role: SemanticsRole.dragHandle,
            label: 'Resize Status',
            child: SizedBox(width: 6, height: 32),
          ),
          Semantics(liveRegion: true, child: Text('Status, Quartz: Idea')),
        ],
      ),
    );
    expect(html, contains('role="separator"'));
    expect(html, contains('aria-label="Resize Status"'));
    expect(html, contains('aria-live="polite"'));
    expect(
      await page(const Semantics(child: Text('x'))),
      isNot(contains('aria-live')),
    );
  });

  test(
    'figure, figureCaption, blockquote and label are their element',
    () async {
      final html = await page(
        const Semantics(
          role: SemanticsRole.figure,
          child: Column(
            children: [
              Semantics(role: SemanticsRole.blockquote, child: Text('Quote')),
              Semantics(role: SemanticsRole.figureCaption, child: Text('Cap')),
              Semantics(role: SemanticsRole.label, child: Text('Name')),
            ],
          ),
        ),
      );
      expect(html, contains('<figure'));
      expect(html, contains('<blockquote'));
      expect(html, contains('<figcaption'));
      expect(html, contains('<label'));
    },
  );

  group("Flutter's semantics roles", () {
    Future<String> role(SemanticsRole r, {String? value, bool? checked}) =>
        page(
          Semantics(
            role: r,
            value: value,
            checked: checked,
            child: const SizedBox(width: 8, height: 8),
          ),
        );

    test(
      'spinButton, menuItemCheckbox and menuItemRadio are ARIA roles',
      () async {
        expect(
          await role(SemanticsRole.spinButton, value: 'May 2026'),
          allOf(
            contains('role="spinbutton"'),
            contains('aria-valuetext="May 2026"'),
          ),
        );
        expect(
          await role(SemanticsRole.menuItemCheckbox, checked: true),
          allOf(
            contains('role="menuitemcheckbox"'),
            contains('aria-checked="true"'),
          ),
        );
        expect(
          await role(SemanticsRole.menuItemRadio, checked: false),
          allOf(
            contains('role="menuitemradio"'),
            contains('aria-checked="false"'),
          ),
        );
      },
    );

    test('loadingSpinner is a progress bar without a value', () async {
      final html = await role(SemanticsRole.loadingSpinner);
      expect(html, contains('role="progressbar"'));
      expect(html, isNot(contains('aria-valuenow')));
      expect(html, isNot(contains('aria-valuetext')));
    });

    test(
      'progressBar, slider, listBox and image keep their ARIA role',
      () async {
        expect(
          await role(SemanticsRole.progressBar, value: '40%'),
          allOf(
            contains('role="progressbar"'),
            contains('aria-valuetext="40%"'),
          ),
        );
        expect(await role(SemanticsRole.slider), contains('role="slider"'));
        expect(await role(SemanticsRole.listBox), contains('role="listbox"'));
        expect(await role(SemanticsRole.image), contains('role="img"'));
      },
    );

    test(
      'none and hotKey write no role, the rest of Semantics stays',
      () async {
        for (final r in [SemanticsRole.none, SemanticsRole.hotKey]) {
          final html = await page(
            Semantics(
              role: r,
              label: 'Shortcut',
              child: const SizedBox(width: 8, height: 8),
            ),
          );
          expect(html, isNot(contains('role=')), reason: '$r');
          expect(html, contains('aria-label="Shortcut"'), reason: '$r');
        }
      },
    );

    test("every role of Flutter's SemanticsRole exists", () {
      // dart:ui's SemanticsRole (Flutter 3.44), by name.
      const flutter = [
        'none',
        'tab',
        'tabBar',
        'tabPanel',
        'dialog',
        'alertDialog',
        'table',
        'cell',
        'row',
        'columnHeader',
        'dragHandle',
        'spinButton',
        'comboBox',
        'menuBar',
        'menu',
        'menuItem',
        'menuItemCheckbox',
        'menuItemRadio',
        'list',
        'listItem',
        'form',
        'tooltip',
        'loadingSpinner',
        'progressBar',
        'hotKey',
        'radioGroup',
        'status',
        'alert',
        'complementary',
        'contentInfo',
        'main',
        'navigation',
        'region',
      ];
      final names = SemanticsRole.values.map((r) => r.name).toSet();
      expect(flutter.where((n) => !names.contains(n)), isEmpty);
    });
  });
}
