@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

Future<String> page(Widget body) => renderDocument(ThorApp(child: body));

String bodyOf(String html) => html.substring(html.indexOf('<body'));

/// The declarations of the class on the [nth] element [tag].
String cssOf(String html, String tag, {int nth = 0}) {
  final cls = RegExp(
    '<$tag class="([^"]+)"',
  ).allMatches(bodyOf(html)).elementAt(nth)[1]!;
  return RegExp('\\.$cls\\{([^}]*)\\}').firstMatch(html)![1]!;
}

List<String> classesOf(String html, String tag) => [
  for (final m in RegExp('<$tag class="([^"]+)"').allMatches(bodyOf(html)))
    m[1]!,
];

abstract class _RowsMembers extends ThorState {
  @override
  String get $type => 'Rows';

  @override
  List<ThorMember> get $members {
    final s = this as _Rows;
    return [
      ThorMember(
        'sortBy',
        s.sortBy,
        arity: 2,
        call: (a) {
          final x = splitArgs(a, 2);
          return s.sortBy(int.parse(x[0]), x[1] == 'true');
        },
      ),
      ThorMember(
        'toggle',
        s.toggle,
        arity: 2,
        call: (a) {
          final x = splitArgs(a, 2);
          return s.toggle(int.parse(x[0]), x[1] == 'true');
        },
      ),
      ThorMember(
        'selectAll',
        s.selectAll,
        arity: 1,
        call: (a) => s.selectAll(a == 'true'),
      ),
    ];
  }
}

class _Rows extends _RowsMembers {
  void sortBy(int column, bool ascending) {}
  void toggle(int id, bool? selected) {}
  void selectAll(bool? all) {}
}

const _rows = [
  TableRow(children: [Text('a'), Text('b'), Text('c')]),
  TableRow(children: [Text('d'), Text('e'), Text('f')]),
];

void main() {
  setUpAll(initializeThorTests);

  group('Table', () {
    test('is a native table: rows and cells, with explicit roles', () async {
      final html = bodyOf(await page(const Table(children: _rows)));
      expect('<table'.allMatches(html), hasLength(1));
      expect('<tbody'.allMatches(html), hasLength(1));
      expect('<tr '.allMatches(html), hasLength(2));
      expect('<td '.allMatches(html), hasLength(6));
      expect(html, contains('role="table"'));
      expect(html, contains('role="rowgroup"'));
      expect('role="row"'.allMatches(html), hasLength(2));
      expect('role="cell"'.allMatches(html), hasLength(6));
      // No wrappers: table, row group, rows, cells and the texts.
      expect(RegExp('<[a-z]').allMatches(html).length, 1 + 1 + 1 + 2 + 6 + 6);
    });

    test('same cells share one class; groups and rows are subgrids', () async {
      final html = await page(const Table(children: _rows));
      expect(classesOf(html, 'td').toSet(), hasLength(1));
      expect(cssOf(html, 'tr'), contains('grid-template-columns: subgrid'));
      expect(cssOf(html, 'tbody'), contains('grid-template-columns: subgrid'));
    });

    test('column widths are grid tracks; the default is a flex', () async {
      final html = await page(
        const Table(
          columnWidths: {
            0: FixedColumnWidth(120),
            1: FractionColumnWidth(0.25),
            2: IntrinsicColumnWidth(),
          },
          children: _rows,
        ),
      );
      expect(
        cssOf(html, 'table'),
        contains('grid-template-columns: 120px 25% max-content'),
      );
      final flex = await page(
        const Table(
          defaultColumnWidth: FlexColumnWidth(2),
          columnWidths: {2: IntrinsicColumnWidth(flex: 1)},
          children: _rows,
        ),
      );
      expect(
        cssOf(flex, 'table'),
        contains(
          'grid-template-columns: minmax(0, 2fr) minmax(0, 2fr) '
          'minmax(max-content, 1fr)',
        ),
      );
    });

    test('max and min widths combine as CSS can, or fail clearly', () {
      expect(
        const MaxColumnWidth(FixedColumnWidth(120), FlexColumnWidth()).track,
        'minmax(120px, 1fr)',
      );
      expect(
        const MinColumnWidth(
          FixedColumnWidth(320),
          FractionColumnWidth(0.5),
        ).track,
        'min(320px, 50%)',
      );
      expect(
        const MaxColumnWidth(FlexColumnWidth(), FlexColumnWidth(3)).track,
        'minmax(0, 3fr)',
      );
      expect(
        () => const MinColumnWidth(
          FixedColumnWidth(200),
          FlexColumnWidth(),
        ).track,
        throwsA(
          isA<ArgumentError>().having(
            (e) => '${e.message}',
            'message',
            contains('THOR-R011'),
          ),
        ),
      );
    });

    test('fixed or content columns: only as wide as them', () async {
      const fixed = Table(
        defaultColumnWidth: FixedColumnWidth(80),
        children: _rows,
      );
      expect(fixed.fillsWidth, isFalse);
      expect(cssOf(await page(fixed), 'table'), contains('width: fit-content'));
      const flex = Table(children: _rows);
      expect(flex.fillsWidth, isTrue);
      expect(cssOf(await page(flex), 'table'), isNot(contains('fit-content')));
    });

    test('MinColumnWidth with a fraction fills the width', () async {
      const doc = Table(
        defaultColumnWidth: MinColumnWidth(
          FixedColumnWidth(320),
          FractionColumnWidth(0.5),
        ),
        children: _rows,
      );
      // The 50% needs the available width, not a table sized by its content.
      expect(doc.fillsWidth, isTrue);
      expect(cssOf(await page(doc), 'table'), isNot(contains('fit-content')));
    });

    test('cells sit at the top by default; TableCell overrides', () async {
      final html = await page(
        const Table(
          children: [
            TableRow(
              children: [
                Text('a'),
                TableCell(
                  verticalAlignment: TableCellVerticalAlignment.middle,
                  child: Text('b'),
                ),
              ],
            ),
          ],
        ),
      );
      expect(cssOf(html, 'td'), contains('align-self: start'));
      expect(cssOf(html, 'td', nth: 1), contains('align-self: center'));
    });

    test('borders are painted, never laid out, and only between', () async {
      final html = await page(
        Table(
          border: TableBorder.all(color: const Color(0xFFFF0000)),
          children: _rows,
        ),
      );
      final table = cssOf(html, 'table');
      expect(table, contains('position: relative'));
      expect(table, isNot(contains('border:')));
      // The outer lines go over the rows, from the table's ::after.
      expect(
        html,
        matches(RegExp(r'::after\{[^}]*box-shadow: inset 0px 1px 0 0 #ff0000')),
      );
      // Between rows: from the second row; between cells: not the first.
      expect(cssOf(html, 'tr'), isNot(contains('box-shadow')));
      expect(cssOf(html, 'tr', nth: 1), contains('box-shadow: inset 0px 1px'));
      expect(cssOf(html, 'td'), isNot(contains('box-shadow')));
      expect(cssOf(html, 'td', nth: 1), contains('box-shadow: inset 1px 0px'));
    });

    test('a row decoration\'s border takes no space', () async {
      final html = await page(
        const Table(
          children: [
            TableRow(
              decoration: BoxDecoration(
                color: Color(0xFF00FF00),
                border: Border(bottom: BorderSide(width: 2)),
              ),
              children: [Text('a')],
            ),
          ],
        ),
      );
      final row = cssOf(html, 'tr');
      expect(row, contains('background-color: #00ff00'));
      expect(row, contains('box-shadow: inset 0px -2px 0 0 #000000'));
      expect(row, isNot(contains('border-bottom')));
    });

    test('an empty table renders without columns', () async {
      final html = await page(const Table());
      expect(cssOf(html, 'table'), contains('grid-template-columns: none'));
    });

    test('rows with different cell counts fail in debug', () async {
      await expectLater(
        page(
          const Table(
            children: [
              TableRow(children: [Text('a'), Text('b')]),
              TableRow(children: [Text('c')]),
            ],
          ),
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('DataTable', () {
    const columns = [
      DataColumn(label: Text('Name')),
      DataColumn(label: Text('Price'), numeric: true),
    ];
    const rows = [
      DataRow(cells: [DataCell(Text('Tea')), DataCell(Text('10'))]),
      DataRow(cells: [DataCell(Text('Coffee')), DataCell(Text('12'))]),
    ];

    test('header in <thead> with <th scope=col>, rows in <tbody>', () async {
      final html = bodyOf(
        await page(const DataTable(columns: columns, rows: rows)),
      );
      expect(html, contains('<thead'));
      expect('<th '.allMatches(html), hasLength(2));
      expect('scope="col"'.allMatches(html), hasLength(2));
      expect('role="columnheader"'.allMatches(html), hasLength(2));
      expect('<td '.allMatches(html), hasLength(4));
      // Nothing selectable or sortable: no checkboxes, buttons or aria-sort.
      expect(html, isNot(contains('type="checkbox"')));
      expect(html, isNot(contains('<button')));
      expect(html, isNot(contains('aria-sort')));
    });

    test(
      'Flutter measures: 56 header, 48 rows, 24 margins, 56 apart',
      () async {
        final html = await page(const DataTable(columns: columns, rows: rows));
        expect(cssOf(html, 'th'), contains('height: 56px'));
        expect(cssOf(html, 'th'), contains('padding: 0px 28px 0px 24px'));
        expect(
          cssOf(html, 'th', nth: 1),
          contains('padding: 0px 24px 0px 28px'),
        );
        final cell = cssOf(html, 'td');
        expect(cell, contains('min-height: 48px'));
        expect(cell, contains('max-height: 48px'));
        // Content columns; the last one takes what's left.
        expect(
          cssOf(html, 'table'),
          contains(
            'grid-template-columns: max-content minmax(max-content, 1fr)',
          ),
        );
      },
    );

    test('numeric columns align to the end', () async {
      final html = await page(const DataTable(columns: columns, rows: rows));
      final price = cssOf(html, 'td', nth: 1);
      expect(price, contains('align-items: flex-end'));
      expect(price, contains('text-align: end'));
      expect(cssOf(html, 'td'), contains('align-items: flex-start'));
    });

    test('lines are painted above each data row, like Flutter', () async {
      final html = await page(const DataTable(columns: columns, rows: rows));
      final trs = classesOf(html, 'tr');
      expect(trs, hasLength(3));
      expect(cssOf(html, 'tr'), isNot(contains('box-shadow')));
      expect(cssOf(html, 'tr', nth: 1), contains('box-shadow: inset 0px 1px'));
      expect(trs[1], trs[2]);
      final bottom = await page(
        const DataTable(columns: columns, rows: rows, showBottomBorder: true),
      );
      expect(cssOf(bottom, 'tr'), contains('box-shadow: inset 0px -1px'));
      expect(
        cssOf(bottom, 'tr', nth: 2),
        contains('box-shadow: inset 0px -1px'),
      );
    });

    test('sorting: aria-sort, the arrow, and the order a tap asks', () async {
      final state = _Rows();
      final html = bodyOf(
        await page(
          DataTable(
            sortColumnIndex: 1,
            sortAscending: false,
            columns: [
              DataColumn(label: const Text('Name'), onSort: state.sortBy),
              DataColumn(
                label: const Text('Price'),
                numeric: true,
                onSort: state.sortBy,
              ),
            ],
            rows: rows,
          ),
        ),
      );
      expect(html, contains('aria-sort="none"'));
      expect(html, contains('aria-sort="descending"'));
      // Another column starts ascending; the sorted one flips.
      expect(html, contains('data-tx="0~true"'));
      expect(html, contains('data-tx="1~true"'));
      expect('type="button"'.allMatches(html), hasLength(2));
      // Numeric: the arrow comes before the label.
      final price = html.substring(html.indexOf('aria-sort="descending"'));
      expect(
        price.indexOf('data-sort-arrow'),
        lessThan(price.indexOf('Price')),
      );
    });

    test('a column sorted by the URL shows its arrow, no button', () async {
      final html = bodyOf(
        await page(
          const DataTable(
            sortColumnIndex: 0,
            columns: [
              DataColumn(
                label: Link(href: RouteUrl('/?sort=name'), child: Text('Name')),
              ),
              DataColumn(label: Text('Price')),
            ],
            rows: rows,
          ),
        ),
      );
      expect(html, contains('aria-sort="ascending"'));
      expect('data-sort-arrow'.allMatches(html), hasLength(1));
      expect(html, isNot(contains('<button')));
    });

    test('an unsorted arrow is hidden and keeps its space', () async {
      final state = _Rows();
      final html = await page(
        DataTable(
          sortColumnIndex: 0,
          columns: [
            DataColumn(label: const Text('Name'), onSort: state.sortBy),
            DataColumn(label: const Text('Price'), onSort: state.sortBy),
          ],
          rows: rows,
        ),
      );
      final arrows = RegExp(
        r'<span class="([^"]+)" data-sort-arrow',
      ).allMatches(bodyOf(html)).map((m) => m[1]!).toList();
      expect(arrows, hasLength(2));
      String rule(String cls) =>
          RegExp('\\.$cls\\{([^}]*)\\}').firstMatch(html)![1]!;
      expect(rule(arrows[0]), contains('opacity: 1'));
      expect(rule(arrows[1]), contains('opacity: 0'));
    });

    test('selectable rows: checkboxes, the tap, one class', () async {
      final state = _Rows();
      final html = await page(
        DataTable(
          onSelectAll: state.selectAll,
          columns: columns,
          rows: [
            DataRow(
              selected: true,
              onSelectChanged: state.toggle.withArg(1),
              cells: const [DataCell(Text('Tea')), DataCell(Text('10'))],
            ),
            DataRow(
              onSelectChanged: state.toggle.withArg(2),
              cells: const [DataCell(Text('Coffee')), DataCell(Text('12'))],
            ),
          ],
        ),
      );
      final body = bodyOf(html);
      expect('type="checkbox"'.allMatches(body), hasLength(3));
      // The header: some rows selected → mixed.
      expect(body, contains('aria-checked="mixed"'));
      // A row tap asks for the opposite of its selection.
      expect(body, contains('data-tx="1~false"'));
      expect(body, contains('data-tx="2~true"'));
      expect(body, contains('data-selected'));
      final trs = classesOf(html, 'tr');
      expect(trs[1], trs[2]);
      expect(html, matches(RegExp(r'\[data-selected\]\{background-color:')));
      // The checkbox column: margin + 18 + margin / 2.
      expect(cssOf(html, 'table'), contains('grid-template-columns: 54px'));
    });

    test('without onSelectAll the header checkbox is disabled', () async {
      final state = _Rows();
      final html = bodyOf(
        await page(
          DataTable(
            columns: columns,
            rows: [
              DataRow(
                onSelectChanged: state.toggle.withArg(1),
                cells: const [DataCell(Text('Tea')), DataCell(Text('10'))],
              ),
            ],
          ),
        ),
      );
      final header = html.substring(0, html.indexOf('</thead>'));
      expect(header, contains('disabled'));
    });

    test('showCheckboxColumn: false hides the checkboxes', () async {
      final state = _Rows();
      final html = bodyOf(
        await page(
          DataTable(
            showCheckboxColumn: false,
            columns: columns,
            rows: [
              DataRow(
                onSelectChanged: state.toggle.withArg(1),
                cells: const [DataCell(Text('Tea')), DataCell(Text('10'))],
              ),
            ],
          ),
        ),
      );
      expect(html, isNot(contains('type="checkbox"')));
      expect(html, contains('data-tx="1~true"'));
    });

    test('showCheckboxColumn: false makes the row a keyboard stop', () async {
      final state = _Rows();
      final html = bodyOf(
        await page(
          DataTable(
            showCheckboxColumn: false,
            columns: columns,
            rows: [
              DataRow(
                selected: true,
                onSelectChanged: state.toggle.withArg(1),
                cells: const [DataCell(Text('Tea')), DataCell(Text('10'))],
              ),
            ],
          ),
        ),
      );
      expect(html, contains('tabindex="0" aria-selected="true"'));
      // With the checkbox column the checkbox is the stop, not the row.
      final withBoxes = bodyOf(
        await page(
          DataTable(
            columns: columns,
            rows: [
              DataRow(
                onSelectChanged: state.toggle.withArg(1),
                cells: const [DataCell(Text('Tea')), DataCell(Text('10'))],
              ),
            ],
          ),
        ),
      );
      expect(withBoxes, isNot(contains('tabindex')));
    });

    test('a DataCell with onTap is a focusable cell', () async {
      final state = _Rows();
      final html = bodyOf(
        await page(
          DataTable(
            columns: columns,
            rows: [
              DataRow(
                cells: [
                  DataCell(
                    const Text('Tea'),
                    onTap: state.selectAll.withArg(true),
                  ),
                  const DataCell(Text('10')),
                ],
              ),
            ],
          ),
        ),
      );
      expect('role="cell" tabindex="0"'.allMatches(html), hasLength(1));
      expect(html, isNot(contains('role="button"')));
    });

    test('a row with the wrong number of cells fails in debug', () async {
      await expectLater(
        page(
          const DataTable(
            columns: columns,
            rows: [
              DataRow(cells: [DataCell(Text('Tea'))]),
            ],
          ),
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('placeholder text is fainter; the edit icon follows', () async {
      final html = await page(
        const DataTable(
          columns: [DataColumn(label: Text('Name'))],
          rows: [
            DataRow(
              cells: [
                DataCell(
                  Text('Enter a name'),
                  placeholder: true,
                  showEditIcon: true,
                ),
              ],
            ),
          ],
        ),
      );
      expect(
        cssOf(html, 'td'),
        contains('color-mix(in srgb, currentColor 60%'),
      );
      expect(html, contains('thor-edit'));
    });
  });
}
