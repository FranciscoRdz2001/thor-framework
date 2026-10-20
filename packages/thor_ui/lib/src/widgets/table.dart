import 'package:thor_style/thor_style.dart';

import '../core/core.dart';
import '../foundation/child_rules.dart';
import '../foundation/element.dart';
import '../foundation/errors.dart';
import '../foundation/layout_hint.dart';
import '../foundation/style_registry.dart';
import '../foundation/transparent.dart';

/// Flutter's `TableCellVerticalAlignment`: where a cell sits in its row.
enum TableCellVerticalAlignment {
  /// At the top of the row.
  top('start'),

  /// Centered in the row.
  middle('center'),

  /// At the bottom of the row.
  bottom('end'),

  /// Text baselines lined up across the row.
  baseline('baseline'),

  /// As tall as the row.
  fill('stretch'),

  /// As tall as the row (Flutter sizes the row by these cells first; the
  /// web sizes every row by its tallest cell anyway).
  intrinsicHeight('stretch');

  const TableCellVerticalAlignment(this.css);

  /// The cell's `align-self`.
  final String css;
}

/// Flutter's `TableColumnWidth`: how wide a column of a [Table] is.
///
/// `// web:` each one is a CSS grid track (`120px`, `minmax(0, 1fr)`,
/// `max-content`, `25%`): the browser sizes the columns, with the same
/// result as Flutter's table layout.
abstract class TableColumnWidth {
  /// Const constructor for subclasses.
  const TableColumnWidth();

  /// The least the track may be (`0`, a length, `max-content`).
  String get minTrack;

  /// The most the track may be (a length, `max-content`, or `Nfr`).
  String get maxTrack;

  /// Whether the column takes a share of the table's width (a flex or a
  /// fraction column): the table then takes the max width, like Flutter's.
  bool get fillsWidth;

  /// The CSS grid track.
  String get track =>
      minTrack == maxTrack ? minTrack : 'minmax($minTrack, $maxTrack)';
}

/// Flutter's `FixedColumnWidth`: [value] logical pixels.
class FixedColumnWidth extends TableColumnWidth {
  /// A column [value] logical pixels wide.
  const FixedColumnWidth(this.value);

  /// Width in logical pixels.
  final double value;

  @override
  String get minTrack => cssPx(value);

  @override
  String get maxTrack => cssPx(value);

  @override
  bool get fillsWidth => false;
}

/// Flutter's `FractionColumnWidth`: [value] of the table's width.
class FractionColumnWidth extends TableColumnWidth {
  /// A column taking [value] (0 to 1) of the table's width.
  const FractionColumnWidth(this.value);

  /// Fraction of the table's width.
  final double value;

  @override
  String get minTrack => '${cssNum(value * 100)}%';

  @override
  String get maxTrack => minTrack;

  @override
  bool get fillsWidth => true;
}

/// Flutter's `FlexColumnWidth`: a share of the width the fixed columns
/// leave.
class FlexColumnWidth extends TableColumnWidth {
  /// A column taking [value] shares of the remaining width.
  const FlexColumnWidth([this.value = 1]);

  /// Its flex factor.
  final double value;

  @override
  String get minTrack => '0';

  @override
  String get maxTrack => '${cssNum(value)}fr';

  @override
  bool get fillsWidth => true;
}

/// Flutter's `IntrinsicColumnWidth`: as wide as its widest cell; with
/// [flex], also a share of the width left over.
class IntrinsicColumnWidth extends TableColumnWidth {
  /// A column as wide as its content.
  const IntrinsicColumnWidth({this.flex});

  /// Share of the remaining width, on top of the content's.
  final double? flex;

  @override
  String get minTrack => 'max-content';

  @override
  String get maxTrack => flex == null ? 'max-content' : '${cssNum(flex!)}fr';

  @override
  bool get fillsWidth => flex != null;
}

/// Flutter's `MaxColumnWidth`: the larger of two widths
/// (`MaxColumnWidth(FixedColumnWidth(120), FlexColumnWidth())`: a flex
/// column never under 120).
class MaxColumnWidth extends TableColumnWidth {
  /// The larger of [a] and [b].
  const MaxColumnWidth(this.a, this.b);

  /// One width.
  final TableColumnWidth a;

  /// The other width.
  final TableColumnWidth b;

  @override
  String get minTrack => _combine(a.minTrack, b.minTrack, 'max', this);

  @override
  String get maxTrack => _combine(a.maxTrack, b.maxTrack, 'max', this);

  @override
  bool get fillsWidth => a.fillsWidth || b.fillsWidth;
}

/// Flutter's `MinColumnWidth`: the smaller of two widths
/// (`MinColumnWidth(FixedColumnWidth(320), FractionColumnWidth(0.5))`).
class MinColumnWidth extends TableColumnWidth {
  /// The smaller of [a] and [b].
  const MinColumnWidth(this.a, this.b);

  /// One width.
  final TableColumnWidth a;

  /// The other width.
  final TableColumnWidth b;

  @override
  String get minTrack => _combine(a.minTrack, b.minTrack, 'min', this);

  @override
  String get maxTrack => _combine(a.maxTrack, b.maxTrack, 'min', this);

  @override
  bool get fillsWidth => a.fillsWidth || b.fillsWidth;
}

bool _isLength(String t) => t != 'max-content' && !t.endsWith('fr');

double _fr(String t) => double.parse(t.substring(0, t.length - 2));

/// [x] and [y] combined with CSS `max()`/`min()` ([fn]); what CSS can't
/// combine (a flex share with a length as a maximum…) is an error.
String _combine(String x, String y, String fn, TableColumnWidth width) {
  if (x == y) return x;
  if (_isLength(x) && _isLength(y)) {
    if (x == '0') return fn == 'max' ? y : '0';
    if (y == '0') return fn == 'max' ? x : '0';
    return '$fn($x, $y)';
  }
  if (x.endsWith('fr') && y.endsWith('fr')) {
    final a = _fr(x), b = _fr(y);
    return (fn == 'max') == (a >= b) ? x : y;
  }
  // The larger of a flex share and a length is the share (it only
  // grows past its minimum); the larger of content and nothing, content.
  if (fn == 'max' && (x.endsWith('fr') || y.endsWith('fr'))) {
    return x.endsWith('fr') ? x : y;
  }
  if (fn == 'max' && (x == '0' || y == '0')) return x == '0' ? y : x;
  if (fn == 'min' && (x == '0' || y == '0')) return '0';
  throw ArgumentError(
    thorError(
      'THOR-R011',
      '${width.runtimeType} can\'t combine $x and $y as a CSS grid track. '
          'Use widths CSS can compare: two lengths (FixedColumnWidth, '
          'FractionColumnWidth), or a flex and a length in MaxColumnWidth.',
    ),
  );
}

/// Flutter's `TableBorder`: the lines of a [Table], outside and between
/// its rows and columns.
///
/// `// web:` like Flutter, the lines are painted over the cells and take
/// no space (inset shadows), so a border never changes a row's height.
class TableBorder {
  /// The lines of a table; each defaults to none.
  const TableBorder({
    this.top = BorderSide.none,
    this.right = BorderSide.none,
    this.bottom = BorderSide.none,
    this.left = BorderSide.none,
    this.horizontalInside = BorderSide.none,
    this.verticalInside = BorderSide.none,
    this.borderRadius = BorderRadius.zero,
  });

  /// The same line around and inside the table.
  factory TableBorder.all({
    Color color = const Color(0xFF000000),
    double width = 1,
    BorderStyle style = BorderStyle.solid,
    BorderRadius borderRadius = BorderRadius.zero,
  }) {
    final side = BorderSide(color: color, width: width, style: style);
    return TableBorder(
      top: side,
      right: side,
      bottom: side,
      left: side,
      horizontalInside: side,
      verticalInside: side,
      borderRadius: borderRadius,
    );
  }

  /// One line inside, another around.
  factory TableBorder.symmetric({
    BorderSide inside = BorderSide.none,
    BorderSide outside = BorderSide.none,
    BorderRadius borderRadius = BorderRadius.zero,
  }) => TableBorder(
    top: outside,
    right: outside,
    bottom: outside,
    left: outside,
    horizontalInside: inside,
    verticalInside: inside,
    borderRadius: borderRadius,
  );

  /// Above the first row.
  final BorderSide top;

  /// After the last column.
  final BorderSide right;

  /// Below the last row.
  final BorderSide bottom;

  /// Before the first column.
  final BorderSide left;

  /// Between rows.
  final BorderSide horizontalInside;

  /// Between columns.
  final BorderSide verticalInside;

  /// The outer corners.
  final BorderRadius borderRadius;
}

/// An inset shadow painting [side] on one edge (`dx`/`dy` point inwards),
/// or null when it draws nothing.
String? paintedEdge(BorderSide side, {double dx = 0, double dy = 0}) {
  if (side.style == BorderStyle.none || side.width <= 0) return null;
  return 'inset ${cssPx(dx * side.width)} ${cssPx(dy * side.width)} 0 0 '
      '${side.color.css}';
}

/// [border] as inset shadows (top, right, bottom, left): painted inside the
/// box without taking space, like a Flutter `TableRow` decoration.
List<String> paintedBorder(Border? border) => border == null
    ? const []
    : [
        ?paintedEdge(border.top, dy: 1),
        ?paintedEdge(border.right, dx: -1),
        ?paintedEdge(border.bottom, dy: -1),
        ?paintedEdge(border.left, dx: 1),
      ];

/// The CSS of a row [decoration] whose border is painted, not laid out,
/// plus [extraShadows] (inside lines).
CssDeclarations paintedDecorationCss(
  BoxDecoration? decoration, [
  List<String> extraShadows = const [],
]) {
  final css = <String, String>{
    if (decoration != null)
      ...BoxDecoration(
        color: decoration.color,
        image: decoration.image,
        borderRadius: decoration.borderRadius,
        boxShadow: decoration.boxShadow,
        gradient: decoration.gradient,
        shape: decoration.shape,
      ).toCss(),
  };
  final shadows = [
    ...extraShadows,
    ...paintedBorder(decoration?.border),
    ?css['box-shadow'],
  ];
  if (shadows.isNotEmpty) css['box-shadow'] = shadows.join(', ');
  return css;
}

/// Flutter's `TableRow`: the cells of one row of a [Table].
class TableRow {
  /// A row of [children] cells, painted with [decoration] behind them.
  const TableRow({this.key, this.decoration, this.children = const []});

  /// Identifies the row (kept for parity: rows render in order).
  final Key? key;

  /// Painted behind the row's cells; its border takes no space.
  final BoxDecoration? decoration;

  /// One widget per column.
  final List<Widget> children;
}

/// Flutter's `TableCell`: a cell of a [Table] with its own vertical
/// alignment.
class TableCell extends StatelessWidget implements ThorBuiltIn {
  /// Places [child] in its row by [verticalAlignment] (null: the table's
  /// default).
  const TableCell({super.key, this.verticalAlignment, required this.child});

  /// Where the cell sits in its row.
  final TableCellVerticalAlignment? verticalAlignment;

  /// The cell's content.
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

/// Flutter's `Table` → a native `<table>`.
///
/// `// web:` the columns are a CSS grid on the `<table>` and every row
/// section and row is a subgrid of it: the browser sizes each column from
/// its [TableColumnWidth] across all rows (as Flutter's table layout), and
/// every row keeps a box for its decoration. The table, row group, row
/// and cell roles are explicit, so a changed `display` never drops the
/// table's semantics.
class Table extends StatelessWidget
    implements ThorElementWidget, ThorBuiltIn, LayoutHint {
  /// Creates a table.
  const Table({
    super.key,
    this.children = const [],
    this.columnWidths,
    this.defaultColumnWidth = const FlexColumnWidth(),
    this.textDirection,
    this.border,
    this.defaultVerticalAlignment = TableCellVerticalAlignment.top,
  });

  /// The rows; every row has one widget per column.
  final List<TableRow> children;

  /// Widths of some columns, by index.
  final Map<int, TableColumnWidth>? columnWidths;

  /// Width of the columns [columnWidths] leaves out.
  final TableColumnWidth defaultColumnWidth;

  /// Order of the columns (`rtl`: the first column on the right).
  final TextDirection? textDirection;

  /// The lines around and inside the table.
  final TableBorder? border;

  /// Where cells sit in their row unless a [TableCell] says otherwise.
  final TableCellVerticalAlignment defaultVerticalAlignment;

  int get _columns => children.isEmpty ? 0 : children.first.children.length;

  List<TableColumnWidth> get _widths => [
    for (var i = 0; i < _columns; i++) columnWidths?[i] ?? defaultColumnWidth,
  ];

  @override
  bool get fillsWidth => _widths.any((w) => w.fillsWidth);

  @override
  Widget build(BuildContext context) {
    assert(
      children.every((r) => r.children.length == _columns),
      'Every TableRow of a Table must have the same number of cells.',
    );
    return tableElement(
      debugName: 'Table',
      widths: _widths,
      border: border,
      textDirection: textDirection,
      sections: [
        TableSection(
          'tbody',
          rows: [
            for (final row in children)
              TableRowSpec(
                decoration: row.decoration,
                cells: [
                  for (final cell in row.children)
                    // Also a TableCell an app component builds.
                    if (resolveComponent(cell) case final TableCell c)
                      TableCellSpec(
                        c.child,
                        alignment:
                            c.verticalAlignment ?? defaultVerticalAlignment,
                      )
                    else
                      TableCellSpec(cell, alignment: defaultVerticalAlignment),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

/// A cell to render: its [child], its [alignment] in the row, and the
/// element's extra [css], [attributes] and [tag] (`th` for a header).
class TableCellSpec {
  /// A cell of [child].
  const TableCellSpec(
    this.child, {
    this.alignment = TableCellVerticalAlignment.top,
    this.tag = 'td',
    this.css = const {},
    this.attributes = const {},
  });

  /// The content.
  final Widget child;

  /// Where it sits in its row.
  final TableCellVerticalAlignment alignment;

  /// `td`, or `th` for a column header.
  final String tag;

  /// Extra declarations of the cell element.
  final CssDeclarations css;

  /// Extra attributes of the cell element.
  final Map<String, String> attributes;
}

/// A row to render.
class TableRowSpec {
  /// A row of [cells].
  const TableRowSpec({
    required this.cells,
    this.decoration,
    this.css = const {},
    this.conditions = const [],
    this.attributes = const {},
  });

  /// The cells, one per column.
  final List<TableCellSpec> cells;

  /// Painted behind the row (its border takes no space).
  final BoxDecoration? decoration;

  /// Extra declarations of the row element.
  final CssDeclarations css;

  /// Extra conditions of the row's class (a selected row's color).
  final List<ConditionalCss> conditions;

  /// Extra attributes of the row element.
  final Map<String, String> attributes;
}

/// A `thead` or `tbody` of rows.
class TableSection {
  /// A [tag] section of [rows].
  const TableSection(this.tag, {required this.rows});

  /// `thead` or `tbody`.
  final String tag;

  /// Its rows.
  final List<TableRowSpec> rows;
}

const _subgrid = {
  'display': 'grid',
  'grid-template-columns': 'subgrid',
  'grid-column': '1 / -1',
};

/// The `<table>` of [sections]: a grid of [widths] with a subgrid per
/// section and per row, the [border] painted over it. Shared by [Table]
/// and `DataTable`.
Widget tableElement({
  required String debugName,
  required List<TableColumnWidth> widths,
  required List<TableSection> sections,
  TableBorder? border,
  TextDirection? textDirection,
  CssDeclarations css = const {},
}) {
  final fills = widths.any((w) => w.fillsWidth);
  final inside = border;
  final outer = border == null
      ? const <String>[]
      : [
          ?paintedEdge(border.top, dy: 1),
          ?paintedEdge(border.right, dx: -1),
          ?paintedEdge(border.bottom, dy: -1),
          ?paintedEdge(border.left, dx: 1),
        ];
  final radius = border == null || border.borderRadius == BorderRadius.zero
      ? null
      : border.borderRadius.css;
  var rowIndex = 0;
  return thorElement(
    'table',
    debugName: debugName,
    fillsWidth: fills,
    css: {
      'display': 'grid',
      'grid-template-columns': widths.isEmpty
          ? 'none'
          : widths.map((w) => w.track).join(' '),
      'border-collapse': 'separate',
      'border-spacing': '0',
      if (!fills) 'width': 'fit-content',
      if (outer.isNotEmpty) 'position': 'relative',
      'border-radius': ?radius,
      ...css,
    },
    conditions: [
      // The outer lines go over the rows (a row's color never hides them).
      if (outer.isNotEmpty)
        ConditionalCss(const CssCondition.selector('::after'), {
          'content': '""',
          'position': 'absolute',
          'inset': '0',
          'pointer-events': 'none',
          'border-radius': ?radius,
          'box-shadow': outer.join(', '),
        }),
    ],
    attributes: {
      'role': 'table',
      if (textDirection != null) 'dir': textDirection.name,
    },
    children: [
      for (final section in sections)
        thorElement(
          section.tag,
          css: _subgrid,
          attributes: const {'role': 'rowgroup'},
          children: [
            for (final row in section.rows)
              _row(row, first: rowIndex++ == 0, border: inside),
          ],
        ),
    ],
  );
}

Widget _row(TableRowSpec row, {required bool first, TableBorder? border}) {
  final between = first || border == null
      ? null
      : paintedEdge(border.horizontalInside, dy: 1);
  return thorElement(
    'tr',
    css: {
      ..._subgrid,
      ...paintedDecorationCss(row.decoration, [?between]),
      ...row.css,
    },
    conditions: row.conditions,
    attributes: {'role': 'row', ...row.attributes},
    children: [
      for (var i = 0; i < row.cells.length; i++)
        _cell(
          row.cells[i],
          between: i == 0 || border == null
              ? null
              : paintedEdge(border.verticalInside, dx: 1),
        ),
    ],
  );
}

Widget _cell(TableCellSpec cell, {String? between}) => thorElement(
  cell.tag,
  css: {
    'display': 'flex',
    'flex-direction': 'column',
    'min-width': '0',
    'padding': '0',
    'text-align': 'start',
    'font-weight': 'inherit',
    'align-self': cell.alignment.css,
    'box-shadow': ?between,
    ...cell.css,
  },
  childRules: const ChildRules(all: {'flex': '0 0 auto'}),
  attributes: {
    'role': cell.tag == 'th' ? 'columnheader' : 'cell',
    ...cell.attributes,
  },
  children: [cell.child],
);
