import 'package:thor_engine/thor_engine.dart' show bindingId, encodeArg;
import 'package:thor_style/thor_style.dart';

import '../core/core.dart';
import '../engine/watch.dart' show engineAttributes;
import '../foundation/child_rules.dart';
import '../foundation/element.dart';
import '../foundation/layout_hint.dart';
import '../foundation/style_registry.dart';
import '../foundation/theme_tokens.dart';
import '../foundation/widget_state.dart';
import 'basic.dart' show SizedBox;
import 'icon.dart';
import 'selection_controls.dart';
import 'table.dart';
import 'theme.dart';

const _divider = Color.variable(
  CssVariable('--t-outline-variant'),
  fallback: Color(0xFFCAC4D0),
);
const _onSurface = Color.variable(
  CssVariable('--t-on-surface'),
  fallback: Color(0xFF1D1B20),
);
const _primary = Color.variable(
  CssVariable('--t-primary'),
  fallback: Color(0xFF6750A4),
);
const _hover = 'color-mix(in srgb, ${ThemeTokens.onSurface} 8%, transparent)';
const _focusRing = ConditionalCss(CssCondition.focused, {
  'outline': '2px solid ${ThemeTokens.primary}',
  'outline-offset': '-2px',
});

// Flutter's DataTable measures.
const _sortArrowSize = 16.0;
const _sortArrowPadding = 2.0;
const _editIconSize = 18.0;
const _checkboxWidth = 18.0;

const _arrowUpward = IconData.svg(
  'thor-arrow-upward',
  '<path d="M4 12l1.41 1.41L11 7.83V20h2V7.83l5.58 5.59L20 12l-8-8-8 8z"/>',
);
const _edit = IconData.svg(
  'thor-edit',
  '<path d="M3 17.25V21h3.75L17.81 9.94l-3.75-3.75L3 17.25zM20.71 7.04a1 1 0 '
      '0 0 0-1.41l-2.34-2.34a1 1 0 0 0-1.41 0l-1.83 1.83 3.75 3.75 '
      '1.83-1.83z"/>',
);

/// Flutter's `DataColumnSortCallback`: the column tapped and the order it
/// asks for.
typedef DataColumnSortCallback = void Function(int columnIndex, bool ascending);

/// Flutter's `DataColumn`: a column header of a [DataTable].
class DataColumn {
  /// A column labeled [label].
  const DataColumn({
    required this.label,
    this.tooltip,
    this.numeric = false,
    this.onSort,
    this.headingRowAlignment,
    this.columnWidth,
  });

  /// The header's content (usually a `Text`).
  final Widget label;

  /// Shown when the pointer rests on the header (`title`).
  final String? tooltip;

  /// Numbers: right-aligned, the sort arrow before the label.
  final bool numeric;

  /// Called with this column's index and the new order when its header is
  /// tapped: `sortBy(int column, bool ascending)` of a `ThorState`, or a
  /// closure on the server. Null: the column doesn't sort.
  final DataColumnSortCallback? onSort;

  /// Where the header's content sits (default: start, end if [numeric]).
  final MainAxisAlignment? headingRowAlignment;

  /// The column's width (default: as wide as its content; the last column
  /// also takes the width left over).
  final TableColumnWidth? columnWidth;
}

/// Flutter's `DataRow`: one row of a [DataTable].
class DataRow {
  /// A row of [cells].
  const DataRow({
    this.key,
    this.selected = false,
    this.onSelectChanged,
    this.color,
    required this.cells,
  });

  /// A row keyed by its [index].
  DataRow.byIndex({
    int? index,
    this.selected = false,
    this.onSelectChanged,
    this.color,
    required this.cells,
  }) : key = ValueKey<int?>(index);

  /// Identifies the row.
  final Key? key;

  /// Whether the row is selected (its checkbox is checked).
  final bool selected;

  /// Called with the new selection when the row or its checkbox is
  /// tapped: a `ThorState` method (`toggle.withArg(id)`) or a closure on
  /// the server. Rows with it get the checkbox column.
  final ValueChanged<bool?>? onSelectChanged;

  /// The row's color per state (selected, hovered); overrides the table's
  /// `dataRowColor`.
  final WidgetStateProperty<Color?>? color;

  /// One cell per column.
  final List<DataCell> cells;
}

/// Flutter's `DataCell`: one cell of a [DataRow].
class DataCell {
  /// A cell showing [child].
  const DataCell(
    this.child, {
    this.placeholder = false,
    this.showEditIcon = false,
    this.onTap,
  });

  /// An empty cell.
  static const empty = DataCell(SizedBox.shrink());

  /// The content (usually a `Text`).
  final Widget child;

  /// [child] is a placeholder ("Enter a name"): drawn fainter.
  final bool placeholder;

  /// Shows a pencil after the content (the cell is editable).
  final bool showEditIcon;

  /// Called when the cell is tapped.
  final VoidCallback? onTap;
}

/// Flutter's `DataTable` (Material 3) → a native `<table>` with `<thead>`,
/// `<th scope=col>` headers, `aria-sort` and a native checkbox per
/// selectable row.
///
/// Sorting and selection call the callbacks: `ThorState` methods run in
/// the browser (a header asks for `onSort(index, ascending)`, a row for
/// `onSelectChanged(!selected)`), closures on the server. What the table
/// shows comes from its arguments, so the page (or a `Watch` around it)
/// renders the sorted and selected rows; a table sorted by the URL (a
/// header label that is a `Link`) needs no JavaScript.
///
/// `// web:` the header checkbox calls [onSelectAll]; without it, it is
/// shown but disabled (the browser can't call every row's method). The
/// [sortColumnIndex] column shows its arrow even without `onSort` (a
/// table sorted by the URL, whose header labels are links).
class DataTable extends StatelessWidget
    implements ThorElementWidget, ThorBuiltIn, LayoutHint {
  /// Creates a data table.
  const DataTable({
    super.key,
    required this.columns,
    this.sortColumnIndex,
    this.sortAscending = true,
    this.onSelectAll,
    this.decoration,
    this.dataRowColor,
    this.dataRowMinHeight,
    this.dataRowMaxHeight,
    this.dataTextStyle,
    this.headingRowColor,
    this.headingRowHeight,
    this.headingTextStyle,
    this.horizontalMargin,
    this.columnSpacing,
    this.showCheckboxColumn = true,
    this.showBottomBorder = false,
    this.dividerThickness,
    this.checkboxHorizontalMargin,
    this.border,
    required this.rows,
  });

  /// The column headers.
  final List<DataColumn> columns;

  /// The column the rows are sorted by (its header shows the arrow).
  final int? sortColumnIndex;

  /// Whether that column is sorted ascending.
  final bool sortAscending;

  /// Called when the header checkbox is tapped (`true`: select all).
  final ValueSetter<bool?>? onSelectAll;

  /// Painted behind the whole table.
  final BoxDecoration? decoration;

  /// A data row's color per state (default: the primary color at 8 % when
  /// selected).
  final WidgetStateProperty<Color?>? dataRowColor;

  /// Least height of a data row (default 48).
  final double? dataRowMinHeight;

  /// Most height of a data row (default 48).
  final double? dataRowMaxHeight;

  /// Text style of the cells (default: `bodyMedium`).
  final TextStyle? dataTextStyle;

  /// The header row's color per state.
  final WidgetStateProperty<Color?>? headingRowColor;

  /// Height of the header row (default 56).
  final double? headingRowHeight;

  /// Text style of the headers (default: `titleSmall`).
  final TextStyle? headingTextStyle;

  /// Space before the first column and after the last (default 24).
  final double? horizontalMargin;

  /// Space between columns (default 56).
  final double? columnSpacing;

  /// Whether selectable rows get a checkbox column (default true).
  final bool showCheckboxColumn;

  /// A line under the last row too (default false).
  final bool showBottomBorder;

  /// Thickness of the lines between rows (default 1).
  final double? dividerThickness;

  /// Space around the checkboxes (default: [horizontalMargin]).
  final double? checkboxHorizontalMargin;

  /// Lines around and inside the table.
  final TableBorder? border;

  /// The data rows.
  final List<DataRow> rows;

  bool get _hasCheckboxes =>
      showCheckboxColumn && rows.any((r) => r.onSelectChanged != null);

  @override
  bool get fillsWidth => true;

  @override
  Widget build(BuildContext context) {
    assert(
      sortColumnIndex == null ||
          (sortColumnIndex! >= 0 && sortColumnIndex! < columns.length),
      'sortColumnIndex must name one of the columns.',
    );
    assert(
      rows.every((r) => r.cells.length == columns.length),
      'Every DataRow of a DataTable must have one cell per column.',
    );
    final margin = horizontalMargin ?? 24;
    final spacing = columnSpacing ?? 56;
    final checkboxes = _hasCheckboxes;
    final boxStart = checkboxHorizontalMargin ?? margin;
    final boxEnd = checkboxHorizontalMargin ?? margin / 2;
    final minHeight = dataRowMinHeight ?? 48;
    final maxHeight = dataRowMaxHeight ?? 48;
    final headHeight = headingRowHeight ?? 56;
    final line = BorderSide(color: _divider, width: dividerThickness ?? 1);

    final widths = [
      if (checkboxes) FixedColumnWidth(boxStart + _checkboxWidth + boxEnd),
      for (var i = 0; i < columns.length; i++)
        columns[i].columnWidth ??
            (i == columns.length - 1
                ? const IntrinsicColumnWidth(flex: 1)
                : const IntrinsicColumnWidth()),
    ];

    EdgeInsets padOf(int i) => EdgeInsets.only(
      left: i == 0 ? (checkboxes ? margin / 2 : margin) : spacing / 2,
      right: i == columns.length - 1 ? margin : spacing / 2,
    );

    final headStyle = {
      ...(headingTextStyle ?? ThemeText.titleSmall).toCss(),
      if (headingTextStyle?.color == null) 'color': _onSurface.css,
    };
    final dataStyle = {
      ...(dataTextStyle ?? ThemeText.bodyMedium).toCss(),
      if (dataTextStyle?.color == null) 'color': _onSurface.css,
    };

    BoxDecoration rowLines({required bool heading, Color? color}) =>
        BoxDecoration(
          color: color,
          border: showBottomBorder
              ? Border(bottom: line)
              : heading
              ? null
              : Border(top: line),
        );

    // The header checkbox: checked when every row is, mixed when some are.
    final selectable = rows.where((r) => r.onSelectChanged != null);
    final selectedCount = selectable.where((r) => r.selected).length;
    final all = selectable.isNotEmpty && selectedCount == selectable.length;
    final some = selectedCount > 0 && !all;

    final head = TableRowSpec(
      decoration: rowLines(
        heading: true,
        color: headingRowColor?.resolve(const {}),
      ),
      cells: [
        if (checkboxes)
          TableCellSpec(
            Checkbox(
              stateLayer: false,
              value: some ? null : all,
              tristate: true,
              onChanged: onSelectAll,
            ),
            tag: 'th',
            alignment: TableCellVerticalAlignment.fill,
            css: _checkboxCell(boxStart, boxEnd, headHeight),
            attributes: const {'scope': 'col'},
          ),
        for (var i = 0; i < columns.length; i++)
          _headerCell(
            columns[i],
            i,
            padding: padOf(i),
            height: headHeight,
            style: headStyle,
          ),
      ],
    );

    final body = [
      for (final row in rows)
        _dataRow(
          row,
          checkboxes: checkboxes,
          lines: rowLines(heading: false),
          boxStart: boxStart,
          boxEnd: boxEnd,
          minHeight: minHeight,
          maxHeight: maxHeight,
          padOf: padOf,
          style: dataStyle,
        ),
    ];

    return tableElement(
      debugName: 'DataTable',
      widths: widths,
      border: border,
      css: {if (decoration != null) ...decoration!.toCss()},
      sections: [
        TableSection('thead', rows: [head]),
        TableSection('tbody', rows: body),
      ],
    );
  }

  CssDeclarations _checkboxCell(double start, double end, double height) => {
    'flex-direction': 'row',
    'align-items': 'center',
    'padding': EdgeInsets.only(left: start, right: end).css,
    'min-height': cssPx(height),
  };

  TableCellSpec _headerCell(
    DataColumn column,
    int index, {
    required EdgeInsets padding,
    required double height,
    required CssDeclarations style,
  }) {
    final sorted = sortColumnIndex == index;
    final sortable = column.onSort != null;
    final justify =
        column.headingRowAlignment ??
        (column.numeric ? MainAxisAlignment.end : MainAxisAlignment.start);
    // web: a column sorted by the URL (its label a link, no onSort) shows
    // its arrow too.
    final arrow = sortable || sorted
        ? _SortArrow(visible: sorted, up: !sorted || sortAscending)
        : null;
    final content = [
      if (arrow != null && column.numeric) arrow,
      column.label,
      if (arrow != null && !column.numeric) arrow,
    ];
    // Flutter: a sorted column flips its order; another starts ascending.
    final ascending = !sorted || !sortAscending;
    return TableCellSpec(
      sortable
          ? _SortButton(
              justify: justify,
              onSort: column.onSort!,
              index: index,
              ascending: ascending,
              children: content,
            )
          : _HeaderRow(justify: justify, children: content),
      tag: 'th',
      alignment: TableCellVerticalAlignment.fill,
      css: {
        ...style,
        'justify-content': 'center',
        'padding': padding.css,
        'height': cssPx(height),
        'box-sizing': 'border-box',
      },
      attributes: {
        'scope': 'col',
        if (sortable || sorted)
          'aria-sort': sorted
              ? (sortAscending ? 'ascending' : 'descending')
              : 'none',
        'title': ?column.tooltip,
      },
    );
  }

  TableRowSpec _dataRow(
    DataRow row, {
    required bool checkboxes,
    required BoxDecoration lines,
    required double boxStart,
    required double boxEnd,
    required double minHeight,
    required double maxHeight,
    required EdgeInsets Function(int) padOf,
    required CssDeclarations style,
  }) {
    final color = row.color ?? dataRowColor;
    Color? resolve(Set<WidgetState> states) => color == null
        ? (states.contains(WidgetState.selected)
              ? _primary.withOpacity(0.08)
              : null)
        : color.resolve(states);
    final base = resolve(const {});
    final selected = resolve(const {WidgetState.selected});
    final hovered = resolve(const {WidgetState.hovered});
    final hoveredSelected = resolve(const {
      WidgetState.hovered,
      WidgetState.selected,
    });
    final tappable = row.onSelectChanged != null;
    return TableRowSpec(
      decoration: BoxDecoration(color: base, border: lines.border),
      css: {if (tappable) 'cursor': 'pointer'},
      // Selected and hovered are conditions of the row's one class: a
      // selected row and the others share it.
      conditions: [
        if (selected != null && selected != base)
          ConditionalCss(const CssCondition.selector('[data-selected]'), {
            'background-color': selected.css,
          }),
        if (tappable)
          ConditionalCss(CssCondition.hover, {
            'background-color': hovered?.css ?? _hover,
          }),
        if (tappable && hoveredSelected != null && hoveredSelected != selected)
          ConditionalCss(const CssCondition.selector('[data-selected]:hover'), {
            'background-color': hoveredSelected.css,
          }),
      ],
      attributes: {
        if (row.selected) 'data-selected': '',
        // web: Flutter's row is an InkWell; with the checkbox column the
        // checkbox is the focus stop, without it the row itself is (the
        // engine clicks a focusable row on Enter / Space).
        if (tappable && !checkboxes) ...{
          'tabindex': '0',
          'aria-selected': '${row.selected}',
        },
        ...engineAttributes({'click': row.onSelectChanged}, arg: !row.selected),
      },
      cells: [
        if (checkboxes)
          TableCellSpec(
            Checkbox(
              stateLayer: false,
              value: row.selected,
              onChanged: row.onSelectChanged,
            ),
            alignment: TableCellVerticalAlignment.fill,
            css: _checkboxCell(boxStart, boxEnd, minHeight),
          ),
        for (var i = 0; i < row.cells.length; i++)
          _cell(
            row.cells[i],
            numeric: columns[i].numeric,
            padding: padOf(i),
            minHeight: minHeight,
            maxHeight: maxHeight,
            style: style,
          ),
      ],
    );
  }

  TableCellSpec _cell(
    DataCell cell, {
    required bool numeric,
    required EdgeInsets padding,
    required double minHeight,
    required double maxHeight,
    required CssDeclarations style,
  }) {
    final tappable = cell.onTap != null;
    return TableCellSpec(
      cell.showEditIcon
          ? _HeaderRow(
              justify: numeric
                  ? MainAxisAlignment.end
                  : MainAxisAlignment.start,
              gap: 8,
              children: [
                cell.child,
                const Icon(_edit, size: _editIconSize),
              ],
            )
          : cell.child,
      alignment: TableCellVerticalAlignment.fill,
      css: {
        ...style,
        if (cell.placeholder)
          'color': 'color-mix(in srgb, currentColor 60%, transparent)',
        'justify-content': 'center',
        'align-items': numeric ? 'flex-end' : 'flex-start',
        if (numeric) 'text-align': 'end',
        'padding': padding.css,
        'min-height': cssPx(minHeight),
        if (maxHeight.isFinite) 'max-height': cssPx(maxHeight),
        'box-sizing': 'border-box',
        if (tappable) 'cursor': 'pointer',
      },
      attributes: {
        // web: an InkWell is a focus stop. The cell keeps role="cell" (a
        // role="button" would break the row's owned cells and the column
        // header association); the engine clicks a focusable cell on
        // Enter / Space.
        if (tappable) 'tabindex': '0',
        ...engineAttributes({'click': cell.onTap}),
      },
    );
  }
}

/// A header's label and arrow in a row.
class _HeaderRow extends StatelessWidget
    implements ThorElementWidget, ThorBuiltIn {
  const _HeaderRow({
    required this.justify,
    required this.children,
    this.gap = _sortArrowPadding,
  });

  final MainAxisAlignment justify;
  final double gap;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => thorElement(
    'span',
    css: {
      'display': 'flex',
      'align-items': 'center',
      'justify-content': justify.css,
      'gap': cssPx(gap),
    },
    children: children,
  );
}

/// A sortable header: a button that asks for [index] in [ascending] order.
class _SortButton extends StatelessWidget
    implements ThorElementWidget, ThorBuiltIn {
  const _SortButton({
    required this.justify,
    required this.onSort,
    required this.index,
    required this.ascending,
    required this.children,
  });

  final MainAxisAlignment justify;
  final DataColumnSortCallback onSort;
  final int index;
  final bool ascending;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => thorElement(
    'button',
    debugName: 'DataColumn',
    css: {
      'display': 'flex',
      'align-items': 'center',
      'justify-content': justify.css,
      'gap': cssPx(_sortArrowPadding),
      'width': '100%',
      'margin': '0',
      'padding': '0',
      'border': '0',
      'background': 'none',
      'font': 'inherit',
      'color': 'inherit',
      'text-align': 'inherit',
      'cursor': 'pointer',
    },
    conditions: [
      _focusRing,
      // Hovering an unsorted column shows where its arrow would go.
      const ConditionalCss(
        CssCondition.selector(':hover > [data-sort-arrow]'),
        {'opacity': '0.5'},
      ),
    ],
    attributes: {
      'type': 'button',
      // A ThorState method gets both values from the page.
      ...engineAttributes({
        'click': onSort,
      }, arg: bindingId(encodeArg(index), encodeArg(ascending))),
    },
    children: children,
  );
}

/// Flutter's sort arrow: up for ascending, turned for descending, hidden
/// on columns not sorted (its space kept).
class _SortArrow extends StatelessWidget
    implements ThorElementWidget, ThorBuiltIn {
  const _SortArrow({required this.visible, required this.up});

  final bool visible;
  final bool up;

  @override
  Widget build(BuildContext context) => thorElement(
    'span',
    css: {
      'display': 'inline-flex',
      'flex': 'none',
      'opacity': visible ? '1' : '0',
      'rotate': up ? '0turn' : '0.5turn',
      'transition': 'opacity 150ms, rotate 150ms',
    },
    attributes: const {'data-sort-arrow': '', 'aria-hidden': 'true'},
    children: const [Icon(_arrowUpward, size: _sortArrowSize)],
  );
}
