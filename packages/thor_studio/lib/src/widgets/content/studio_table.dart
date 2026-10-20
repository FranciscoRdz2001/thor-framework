import 'package:thor_ui/thor_ui.dart';

import '../../theme/component_themes/studio_code_theme.dart';

/// A data table in the studio's frame: Flutter's `DataTable` ([columns] of
/// `DataColumn`, [rows] of `DataRow` and `DataCell`) in a rounded card.
///
/// ```dart
/// StudioDataTable(
///   columns: const [
///     DataColumn(label: Text('Page')),
///     DataColumn(label: Text('JS (gzip)'), numeric: true),
///   ],
///   rows: const [
///     DataRow(cells: [DataCell(Text('Without a ThorState')), DataCell(Text('0 KB'))]),
///     DataRow(cells: [DataCell(Text('A counter')), DataCell(StudioKbd('K'))]),
///   ],
/// )
/// ```
///
/// It is a real `<table>` (thor_ui's `DataTable`: header cells, rows, cells),
/// so a screen reader reads it as a table, and it scrolls inside its own
/// rounded frame when it is wider than the page, never the page itself. The
/// colors are `StudioCodeThemeData`'s surface and hairlines; the text styles
/// are the theme's (`labelMedium` for the header, `bodyMedium` for the
/// cells).
///
/// `// web:` it is the read-only table a documentation page needs, so there
/// is no checkbox column, and the row height is free to grow with wrapped
/// text (`dataRowMaxHeight` 400). Sorting (`sortColumnIndex`) and the other
/// `DataTable` parameters are the framework's.
class StudioDataTable extends StatelessWidget implements ThorElementWidget {
  /// A table with [columns] as headers and [rows] of cells.
  const StudioDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.sortColumnIndex,
    this.sortAscending = true,
  });

  /// The headers.
  final List<DataColumn> columns;

  /// The rows: one `DataCell` per column.
  final List<DataRow> rows;

  /// The column the rows are sorted by (its header shows the arrow).
  final int? sortColumnIndex;

  /// Whether that column is sorted ascending.
  final bool sortAscending;

  @override
  Widget build(BuildContext context) {
    assert(
      rows.every((r) => r.cells.length == columns.length),
      'Every row of a StudioDataTable needs one cell per column',
    );
    final theme = StudioCodeThemeData.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: theme.color,
        border: Border.all(color: theme.borderColor),
        borderRadius: BorderRadius.circular(theme.radius),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        // At least the frame's width, so a short table fills its frame.
        child: Styled(
          style: const StyleProps(minWidth: Length.percent(100)),
          child: DataTable(
            showCheckboxColumn: false,
            horizontalMargin: 16,
            columnSpacing: 32,
            headingRowHeight: 44,
            dataRowMinHeight: 44,
            dataRowMaxHeight: 400,
            sortColumnIndex: sortColumnIndex,
            sortAscending: sortAscending,
            headingTextStyle: text.labelMedium.copyWith(
              color: theme.headerTextColor,
            ),
            dataTextStyle: text.bodyMedium.copyWith(color: scheme.onSurface),
            columns: columns,
            rows: rows,
          ),
        ),
      ),
    );
  }
}
