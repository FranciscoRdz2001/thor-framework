/// `:::bench bench-long-list`: the long lists reference example. A Level sets
/// how many rows the list has (up to 10 000); the list is a `Watch.list` with
/// `virtual: true`, so the page keeps only the rows near the screen.
///
/// The rows live in the state: moving the Level builds a new list there and
/// the browser adds or removes the rows by their key.
library;

import 'package:thor_ui/thor_ui.dart';

import 'bench_example.dart';

/// The row counts the Level steps through.
const _sizes = [100, 500, 1000, 2500, 5000, 10000];

/// The height of one row, in px.
const _extent = 36.0;

/// What the panel controls and the stage reads.
class LongListViewModel extends ThorState {
  /// The index in the row counts.
  final size = state(2);

  /// Every item of the list.
  final items = state<List<int>>(_range(2));

  /// The rows the list draws.
  List<int> rows() => items.value;

  static List<int> _range(int step) => [
    for (var i = 1; i <= _sizes[step]; i++) i,
  ];

  /// The key of a row.
  int keyOf(int n) => n;

  /// The text of a row.
  String label(int n) => 'Item $n';

  /// The number next to the Level's bar.
  String sizeText() => '${_sizes[size.value]}';

  /// The total, spaced by thousands, as the stage's counter shows it.
  String totalText() {
    final n = _sizes[size.value].toString();
    return n.length > 3
        ? '${n.substring(0, n.length - 3)}\u202f${n.substring(n.length - 3)}'
        : n;
  }

  /// The `items` line of the Code view.
  String rowsCode() => '// ${_sizes[size.value]} rows in the state';

  /// What the Level calls.
  void setSize(double value) {
    size.value = value.round();
    items.value = _range(size.value);
  }
}

/// One instance, at the top level: the browser boots with it.
final longList = LongListViewModel();

/// The example: a Level, the stage and its code.
final longListBench = BenchExample(
  title: (t) => t.exUiListTitle,
  description: (t) => t.exUiListDescription,
  stage: const LongListStage(),
  code: BenchCode([
    const BenchCodeLine('Watch.list('),
    BenchCodeLine.live(longList.rowsCode, indent: 1),
    const BenchCodeLine('items.rows,', indent: 1),
    const BenchCodeLine('itemKey: items.keyOf,', indent: 1),
    const BenchCodeLine('itemExtent: 36,', indent: 1),
    const BenchCodeLine('virtual: true,', indent: 1),
    const BenchCodeLine('each: (row) => row.text(items.label),', indent: 1),
    const BenchCodeLine(')'),
  ], appCode: true),
  controls: [
    BenchLevel(
      label: (t) => t.exUiListRows,
      value: longList.size.value,
      max: 5,
      divisions: 5,
      onChanged: longList.setSize,
      valueText: longList.sizeText,
    ),
  ],
);

/// The stage: a box with the list.
class LongListStage extends StatelessWidget {
  /// The stage of the example.
  const LongListStage({super.key});

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    spacing: 12,
    children: [
      Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 2,
        children: [
          Watch(
            longList.totalText,
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
          ),
          const Text(
            'rows in the state; the page keeps only the nearby ones',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: ThemeColor.onSurfaceVariant),
          ),
        ],
      ),
      Watch.list(
        longList.rows,
        itemKey: longList.keyOf,
        itemExtent: _extent,
        virtual: true,
        container: _RowsScroller.new,
        each: _LongListRow.new,
      ),
    ],
  );
}

/// The rows' parent is the scroller: the window of rows is cut by where it
/// is scrolled to.
class _RowsScroller extends StatelessWidget {
  const _RowsScroller(this.rows);

  final List<Widget> rows;

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: 340, height: 288, child: ListView(children: rows));
}

class _LongListRow extends StatelessWidget {
  const _LongListRow(this.row);

  final WatchRow<int, int> row;

  @override
  Widget build(BuildContext context) => Container(
    height: _extent,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    alignment: Alignment.centerLeft,
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: ThemeColor.outline)),
    ),
    child: row.text(longList.label),
  );
}
