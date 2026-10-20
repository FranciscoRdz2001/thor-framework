import 'package:grid/data.dart';
import 'package:grid/grid_state.dart';
import 'package:grid/router.dart';
import 'package:grid/styles.dart';
import 'package:grid/view.dart';
import 'package:test/test.dart';
import 'package:thor_test/thor_test.dart';
import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

void main() {
  final handler = RouteHandler(
    routes: router.routes,
    renderer: WidgetRenderer(
      styles: gridStyles,
      app: (page) => ThorApp(theme: ThemeData(), child: page),
    ),
  );

  Future<ThorTestResponse> get(String path) => handler.client().get(path);

  int rows(String html) => RegExp('data-tk="r').allMatches(html).length;

  test('the first screen renders a window of rows, not all 2,000', () async {
    final response = await get('/');
    expect(response.status, 200);
    final html = response.text;
    expect(rows(html), inInclusiveRange(20, 60));
    expect(html, contains('2000 records'));
  });

  test('the URL view filters and sorts the first screen', () async {
    final html = (await get(
      '/?f=status:isValue:Launched&s=budget:desc&rh=tall',
    )).text;
    expect(html, isNot(contains('2000 records')));
    // Sorted by budget, largest first.
    final budgets = <int>[
      for (final m in RegExp(
        r'\$([0-9,]+)<',
      ).allMatches(html.substring(html.indexOf('data-tk="r'))))
        int.parse(m[1]!.replaceAll(',', '')),
    ].take(10).toList();
    expect(budgets, hasLength(10));
    final sorted = List<int>.of(budgets)..sort((a, b) => b - a);
    expect(budgets, orderedEquals(sorted));
  });

  test('a bad query falls back to the plain view', () async {
    final response = await get('/?f=nope:xx:1&s=zzz&g=name&rh=huge');
    expect(response.status, 200);
    expect(response.text, contains('2000 records'));
  });

  test('grouping renders group headers', () async {
    final html = (await get('/?g=status')).text;
    expect(html, contains('data-tk="gidea"'));
  });

  test('the first screen is an ARIA grid of the whole table', () async {
    final html = (await get('/')).text;
    expect(html, contains('role="grid"'));
    expect(html, contains('aria-rowcount="2001"'));
    expect(html, contains('aria-colcount="13"'));
    expect(RegExp('role="columnheader"').allMatches(html), hasLength(13));
    // Rows know their place in the whole table (the header is row 1).
    expect(html, contains('aria-rowindex="2"'));
    // The primary field names its row; the active cell is selected.
    expect(
      RegExp(r'role="rowheader"[^>]*aria-selected="true"').allMatches(html),
      hasLength(1),
    );
    // The URL column is a real link per row, in a new tab.
    expect(
      html,
      contains(
        'target="_blank" rel="noopener noreferrer" '
        'data-tfa="href:GridState.urlHrefOf"',
      ),
    );
    expect(html, contains('href="https://launch.example.com/'));
    // Row controls are named after their record.
    expect(html, contains('aria-label="Select '));
    // (The row template's other checkbox state keeps the static name; the
    // live rows are named by the binding.)
    final live = html.substring(0, html.indexOf('<template data-tlt'));
    expect(live, isNot(contains('aria-label="Select record"')));
  });

  test('an unsafe URL typed into a cell never becomes a link', () async {
    final s = grid;
    final first = s.rows().first;
    final key = s.rowKey(first);
    s.tapCell('$key.${GridField.url.index}');
    s.startEdit();
    s.draft.text = 'javascript:alert(1)';
    s.commit();
    addTearDown(s.undo);
    final html = (await get('/')).text;
    expect(html, isNot(contains('href="javascript')));
  });

  group('view config', () {
    test('round-trips through the query', () {
      final v = ViewConfig.fromQuery(
        Uri.parse(
          '/?f=name:contains:Aurora&any=1&s=budget:desc&g=owner&h=notes,url'
          '&q=beta&rh=medium',
        ).queryParametersAll,
      );
      expect(v.filters.single.value, 'Aurora');
      expect(v.any, isTrue);
      expect(v.group, isNotNull);
      expect(v.hidden, hasLength(2));
      expect(
        ViewConfig.fromQuery(
          Uri.parse('/${v.toQuery()}').queryParametersAll,
        ).toQuery(),
        v.toQuery(),
      );
    });
  });

  group('state', () {
    test('edits undo and redo', () {
      final s = grid;
      final before = s.rows().first;
      final key = s.rowKey(before);
      final name = s.nameOf(before);
      s.tapCell('$key.0');
      s.startEdit();
      s.draft.text = 'Renamed';
      s.commit();
      expect(s.nameOf(s.rows().first), 'Renamed');
      s.undo();
      expect(s.nameOf(s.rows().first), name);
      s.redo();
      expect(s.nameOf(s.rows().first), 'Renamed');
      s.undo();
    });

    test('aria-selected follows the selection range, row indices the '
        'arranged table', () {
      final s = grid;
      final rows = s.rows();
      final a = s.rowKey(rows[2]), b = s.rowKey(rows[3]);
      s.tapCell('$a.1');
      expect(s.cellSelected(1, s.rows()[2]), isTrue);
      expect(s.cellSelected(2, s.rows()[2]), isFalse);
      expect(s.cellSelected(1, s.rows()[3]), isFalse);
      s.extendDown();
      s.extendRight();
      final now = s.rows();
      expect(s.rowKey(now[3]), b);
      for (final r in [now[2], now[3]]) {
        expect(
          [for (final f in GridField.values) s.cellSelected(f.index, r)],
          [
            false,
            true,
            true,
            ...List.filled(GridField.values.length - 3, false),
          ],
        );
      }
      // Rows whose selection didn't change keep their object (no re-render).
      expect(identical(now[5], s.rows()[5]), isTrue);
      expect(s.ariaRowIndexOf(now[0]), '${now[0].index + 2}');
      expect(s.ariaRowCount(), '2001');
      s.tapCell('${s.rowKey(now[0])}.0');
    });

    test('the window follows the scroll offset', () {
      final s = grid;
      s.scroll.updatePosition(
        pixels: 32.0 * 1000,
        viewportDimension: 640,
        maxScrollExtent: 64000,
      );
      final rows = s.rows();
      expect(rows.length, lessThan(60));
      expect(int.parse(s.numberOf(rows.first)), greaterThan(900));
      expect(s.spaceBefore(), greaterThan(0));
      s.scroll.updatePosition(
        pixels: 0,
        viewportDimension: 640,
        maxScrollExtent: 64000,
      );
    });
  });
}
