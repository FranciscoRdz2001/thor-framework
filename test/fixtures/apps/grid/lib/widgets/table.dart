// The grid: sticky header, footer and primary column, a virtualized
// window of rows, the selection box and the cell editors.
import 'dart:math' as math;

import 'package:thor_ui/thor_ui.dart';

import '../data.dart';
import '../grid_state.dart';
import '../icons.dart';
import '../ui.dart';

/// Width of the primary column: its own width, at most 45 % of a phone.
final leadWidth = Length.min([
  const Length.variable(CssVariable('--w0')),
  45.vw,
]);

Length _var(String name) => Length.variable(CssVariable(name));

/// Min and max width from a column's variable.
StyleProps _columnWidth(int column) =>
    StyleProps(minWidth: _var('--w$column'), maxWidth: _var('--w$column'));

const _rowHeightVar = Length.variable(CssVariable('--row-h'));
const _selectionTop = Length.variable(CssVariable('--sel-top'));

const _rowHeight = StyleProps(
  minHeight: _rowHeightVar,
  maxHeight: _rowHeightVar,
);

const _rightLine = BoxDecoration(
  border: Border(right: BorderSide(color: line)),
);

class GridTable extends StatelessWidget implements ThorElementWidget {
  const GridTable({super.key});

  static final _keys = <ShortcutActivator, void Function()>{
    const SingleActivator(LogicalKeyboardKey.arrowUp): grid.up,
    const SingleActivator(LogicalKeyboardKey.arrowDown): grid.down,
    const SingleActivator(LogicalKeyboardKey.arrowLeft): grid.left,
    const SingleActivator(LogicalKeyboardKey.arrowRight): grid.right,
    const SingleActivator(LogicalKeyboardKey.arrowUp, shift: true):
        grid.extendUp,
    const SingleActivator(LogicalKeyboardKey.arrowDown, shift: true):
        grid.extendDown,
    const SingleActivator(LogicalKeyboardKey.arrowLeft, shift: true):
        grid.extendLeft,
    const SingleActivator(LogicalKeyboardKey.arrowRight, shift: true):
        grid.extendRight,
    const SingleActivator(LogicalKeyboardKey.pageUp): grid.pageUp,
    const SingleActivator(LogicalKeyboardKey.pageDown): grid.pageDown,
    const SingleActivator(LogicalKeyboardKey.tab): grid.nextCell,
    const SingleActivator(LogicalKeyboardKey.tab, shift: true):
        grid.previousCell,
    const SingleActivator(LogicalKeyboardKey.enter): grid.startEdit,
    const SingleActivator(LogicalKeyboardKey.f2): grid.startEdit,
    const SingleActivator(LogicalKeyboardKey.escape): grid.escape,
    const SingleActivator(LogicalKeyboardKey.space): grid.space,
    const SingleActivator(LogicalKeyboardKey.delete): grid.clearCells,
    const SingleActivator(LogicalKeyboardKey.backspace): grid.clearCells,
    const SingleActivator(LogicalKeyboardKey.keyZ, meta: true): grid.undo,
    const SingleActivator(LogicalKeyboardKey.keyZ, control: true): grid.undo,
    const SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true):
        grid.redo,
    const SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true):
        grid.redo,
    const SingleActivator(LogicalKeyboardKey.keyY, control: true): grid.redo,
    const SingleActivator(LogicalKeyboardKey.keyC, meta: true): grid.copy,
    const SingleActivator(LogicalKeyboardKey.keyC, control: true): grid.copy,
    const SingleActivator(LogicalKeyboardKey.keyV, meta: true): grid.paste,
    const SingleActivator(LogicalKeyboardKey.keyV, control: true): grid.paste,
  };

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: _keys,
    // Typing on the selection starts editing with that character.
    onCharacter: grid.typeInto,
    child: WatchVariables(
      {
        for (final f in GridField.values)
          CssVariable('--w${f.index}'): grid.width.withArg(f.index),
        const CssVariable('--row-h'): grid.rowHeightPx,
        const CssVariable('--before'): grid.spaceBefore,
        const CssVariable('--after'): grid.spaceAfter,
        const CssVariable('--sel-top'): grid.selectionTop,
        const CssVariable('--sel-h'): grid.selectionHeight,
        const CssVariable('--sel-x'): grid.selectionX,
        const CssVariable('--sel-w'): grid.selectionWidth,
      },
      child: Styled(
        classes: const ['grid-root'],
        child: Semantics(
          role: SemanticsRole.region,
          label: 'Launches, grid view',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // One marker per column: the app's stylesheet hides a
              // column's cells while its marker has the class.
              for (final f in GridField.values.skip(1))
                Watch(
                  grid.isHidden.withArg(f.index),
                  builder: (hidden) => Styled(
                    classes: [if (hidden) 'gh${f.index}'],
                    child: const SizedBox.shrink(),
                  ),
                ),
              Expanded(
                child: SingleChildScrollView(
                  controller: grid.scroll,
                  child: const Styled(
                    style: StyleProps(
                      position: BoxPosition.relative(),
                      minWidth: Length.percent(100),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _LeadLayer(),
                        _CellOverlay(),
                        _ActiveCellAnnouncer(),
                        _Editor(),
                        _AriaGrid(),
                        _AddRow(),
                        _Footer(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// The header and the rows: an ARIA grid (roles, row and column
/// indices, selected cells) whose rows know their place in the whole table,
/// though only a window of them is in the page.
class _AriaGrid extends StatelessWidget implements ThorElementWidget {
  const _AriaGrid();

  @override
  Widget build(BuildContext context) => WatchAttributes(
    {AttributeName.ariaOf(AriaAttribute.rowcount): grid.ariaRowCount},
    child: Semantics(
      role: SemanticsRole.grid,
      label: 'Launches',
      columnCount: GridField.values.length + 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Semantics(
            role: SemanticsRole.row,
            rowIndex: 1,
            child: _Header(),
          ),
          const Styled(
            style: StyleProps(
              minHeight: Length.variable(CssVariable('--before')),
            ),
            child: SizedBox(width: 1),
          ),
          Watch.list(
            grid.rows,
            itemKey: grid.rowKey,
            container: (rows) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: rows,
            ),
            each: _ariaRow,
          ),
          const Styled(
            style: StyleProps(
              minHeight: Length.variable(CssVariable('--after')),
            ),
            child: SizedBox(width: 1),
          ),
        ],
      ),
    ),
  );
}

/// A row of the grid, with its 1-based index in the whole table.
Widget _ariaRow(WatchRow<RowView, String> row) => Semantics(
  role: SemanticsRole.row,
  child: row.attribute(
    AttributeName.ariaOf(AriaAttribute.rowindex),
    grid.ariaRowIndexOf,
    child: _row(row),
  ),
);

/// The ARIA column of field [column] (1 is the row number column).
int _ariaColumn(int column) => column + 2;

/// [child] as the grid cell of field [column] (the primary field names its
/// row); selected with the selection.
Widget _ariaCell(WatchRow<RowView, String> row, int column, Widget child) =>
    Semantics(
      role: column == 0 ? SemanticsRole.rowHeader : SemanticsRole.gridCell,
      columnIndex: _ariaColumn(column),
      child: row.attribute(
        AttributeName.ariaOf(AriaAttribute.selected),
        grid.cellSelected.withArg(column),
        child: child,
      ),
    );

/// [child] as the header of column [column] (1 is the row numbers).
Widget _ariaHeader(int column, Widget child) => Semantics(
  role: SemanticsRole.columnHeader,
  columnIndex: column,
  child: child,
);

/// Sticky on the left while the grid scrolls sideways.
Widget _stickyLeft(Widget child, {int z = 1}) => Styled(
  style: StyleProps(
    position: const BoxPosition.sticky(left: Length.zero),
    zIndex: z,
  ),
  child: child,
);

/// A cell of column [column]: its width, hidden with its column.
Widget _column(int column, Widget child) =>
    Styled(classes: ['gc$column'], style: _columnWidth(column), child: child);

// ── Rows ─────────────────────────────────────────────────────────────────

Color? _tint(RowLook look) => switch (look) {
  RowLook.checked || RowLook.checkedHit => blueTint,
  RowLook.hit => hitTint,
  RowLook.group || RowLook.collapsedGroup => chrome,
  RowLook.record => surface,
};

bool _isGroup(RowLook look) =>
    look == RowLook.group || look == RowLook.collapsedGroup;

Widget _row(WatchRow<RowView, String> row) => row.watch(
  grid.lookOf,
  builder: (RowLook look) => HoverGroup(
    child: Styled(
      style: _rowHeight,
      child: Container(
        decoration: BoxDecoration(
          color: _tint(look),
          border: const Border(bottom: BorderSide(color: line)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _lead(row, look),
            for (final f in GridField.values.skip(1))
              Offstage(
                offstage: _isGroup(look),
                child: _ariaCell(row, f.index, _cell(row, f)),
              ),
          ],
        ),
      ),
    ),
  ),
);

Widget _lead(WatchRow<RowView, String> row, RowLook look) {
  final group = _isGroup(look);
  return _stickyLeft(
    Container(
      decoration: BoxDecoration(
        color: _tint(look),
        border: const Border(right: BorderSide(color: line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            role: SemanticsRole.gridCell,
            columnIndex: 1,
            child: SizedBox(
              width: numberWidth,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Offstage(offstage: group, child: _rowCheck(row)),
                  Offstage(
                    offstage: group,
                    child: Styled(
                      style: const StyleProps(
                        opacity: 0,
                      ).when(groupHover: const StyleProps(opacity: 1)),
                      child: Gesture(
                        onTap: grid.expand.withArg(row.key),
                        semanticButton: false,
                        child: Semantics(
                          button: true,
                          label: 'Expand record',
                          child: row.attribute(
                            AttributeName.ariaOf(AriaAttribute.label),
                            grid.expandLabelOf,
                            child: Icon(expandIcon, size: 14, color: blue),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Offstage(
                    offstage: !group,
                    child: Transform.rotate(
                      angle: look == RowLook.collapsedGroup ? -math.pi / 2 : 0,
                      child: Icon(chevronDown, size: 16, color: muted),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _ariaCell(
            row,
            0,
            Styled(
              style: StyleProps(minWidth: leadWidth, maxWidth: leadWidth),
              child: Gesture(
                onTap: grid.tapCell.withArg('${row.key}.0'),
                onDoubleTap: grid.editCell.withArg('${row.key}.0'),
                semanticButton: false,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  alignment: Alignment.centerLeft,
                  child: Row(
                    spacing: 8,
                    children: [
                      Expanded(
                        child: row.text(
                          grid.nameOf,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: group
                              ? const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: ink,
                                )
                              : const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: ink,
                                ),
                        ),
                      ),
                      Offstage(
                        offstage: !group,
                        child: row.text(grid.groupCountOf, style: smallMuted),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// The row number, replaced by a checkbox on hover or when checked.
Widget _rowCheck(WatchRow<RowView, String> row) => row.watch(
  grid.isChecked,
  builder: (bool on) => Stack(
    alignment: Alignment.center,
    children: [
      // Under the checkbox: clicks go through to it.
      Styled(
        style: StyleProps(
          opacity: on ? 0 : 1,
          ignorePointer: true,
        ).when(groupHover: const StyleProps(opacity: 0)),
        child: row.text(grid.numberOf, style: smallMuted),
      ),
      Styled(
        style: StyleProps(
          opacity: on ? 1 : 0,
        ).when(groupHover: const StyleProps(opacity: 1)),
        child: row.attribute(
          AttributeName.ariaOf(AriaAttribute.label),
          grid.selectLabelOf,
          child: Checkbox(
            value: on,
            onChanged: grid.setChecked.withArg(row.key),
            activeColor: blue,
            stateLayer: false,
          ),
        ),
      ),
    ],
  ),
);

Widget _cell(WatchRow<RowView, String> row, GridField f) {
  final id = '${row.key}.${f.index}';
  return Gesture(
    onTap: grid.tapCell.withArg(id),
    onDoubleTap: grid.editCell.withArg(id),
    semanticButton: false,
    child: _column(
      f.index,
      Styled(
        style: const StyleProps(
          overflowX: Overflow.hidden,
          overflowY: Overflow.hidden,
        ),
        child: Container(
          decoration: _rightLine,
          alignment: f.numeric ? Alignment.centerRight : Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: _content(row, f),
        ),
      ),
    ),
  );
}

Widget _content(WatchRow<RowView, String> row, GridField f) => switch (f) {
  GridField.name => row.text(grid.nameOf, style: small),
  GridField.status => row.watch(grid.statusOf, builder: statusPill),
  GridField.tags => Row(
    spacing: 4,
    children: [
      row.watch(grid.tag0, builder: tagPill),
      row.watch(grid.tag1, builder: tagPill),
      row.watch(grid.tag2, builder: tagPill),
      row.text(grid.moreTagsOf, style: smallMuted),
    ],
  ),
  GridField.owner => row.watch(grid.ownerOf, builder: personChip),
  GridField.launch => row.text(
    grid.launchOf,
    style: small,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
  ),
  GridField.budget => row.text(grid.budgetOf, style: small),
  GridField.progress => Row(
    spacing: 6,
    children: [
      Expanded(
        child: Container(
          height: 6,
          alignment: Alignment.centerLeft,
          decoration: const BoxDecoration(
            color: Color(0xFFE9EBEF),
            borderRadius: BorderRadius.all(Radius.circular(3)),
          ),
          child: row.watch(
            grid.progressStep,
            count: 21,
            builder: (int step) => FractionallySizedBox(
              widthFactor: step / 20,
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  color: step == 20
                      ? const Color(0xFF20C933)
                      : const Color(0xFF2D7FF9),
                  borderRadius: const BorderRadius.all(Radius.circular(3)),
                ),
              ),
            ),
          ),
        ),
      ),
      SizedBox(
        width: 36,
        child: row.text(
          grid.progressOf,
          style: smallMuted,
          textAlign: TextAlign.right,
        ),
      ),
    ],
  ),
  GridField.shipped => row.watch(
    grid.shippedOf,
    builder: (bool on) => Checkbox(
      value: on,
      onChanged: grid.setShipped.withArg(row.key),
      activeColor: blue,
      stateLayer: false,
      semanticLabel: 'Shipped',
    ),
  ),
  GridField.rating => row.watch(
    grid.ratingOf,
    count: 6,
    builder: (int n) => Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 1,
      children: stars(n, (i) => grid.rate.withArg('${row.key}.$i')),
    ),
  ),
  // A real link to the page, in a new tab: its address per row.
  GridField.url => Link(
    href: const RouteUrl(''),
    newTab: true,
    child: row.attribute(
      AttributeName.href,
      grid.urlHrefOf,
      child: row.text(
        grid.urlOf,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 13,
          color: blue,
          decoration: TextDecoration.underline,
        ),
      ),
    ),
  ),
  GridField.notes => row.text(
    grid.notesOf,
    maxLines: 4,
    overflow: TextOverflow.ellipsis,
    style: small,
  ),
  GridField.files => Row(
    mainAxisSize: MainAxisSize.min,
    spacing: 4,
    children: [
      Icon(clipIcon, size: 13, color: faint),
      row.text(grid.filesOf, style: small),
    ],
  ),
};

// ── Header, footer, add row ──────────────────────────────────────────────

class _Header extends StatelessWidget implements ThorElementWidget {
  const _Header();

  Widget _title(GridField f) => Container(
    height: headerHeight,
    padding: const EdgeInsets.only(left: 8),
    decoration: _rightLine,
    child: Row(
      spacing: 6,
      children: [
        Icon(fieldIcons[f.kind.name]!, size: 14, color: muted),
        Expanded(
          child: Text(
            f.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: label,
          ),
        ),
        // The column's edge: drag (or arrow keys) to resize, live.
        Gesture(
          onDragUpdate: grid.resize.withArg(f.index),
          onDragEnd: grid.endResize.withArg(f.index),
          drag: const Drag(axis: Axis.horizontal),
          semanticButton: false,
          child: Semantics(
            role: SemanticsRole.dragHandle,
            label: 'Resize ${f.label}',
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeColumn,
              child: Container(
                width: 6,
                height: headerHeight,
                color: const Color(0x00000000).when(hover: blue),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Styled(
    style: const StyleProps(
      position: BoxPosition.sticky(top: Length.zero),
      zIndex: 4,
    ),
    child: Container(
      decoration: const BoxDecoration(
        color: chrome,
        border: Border(bottom: BorderSide(color: line)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _stickyLeft(
            Container(
              color: chrome,
              child: Row(
                children: [
                  _ariaHeader(
                    1,
                    SizedBox(
                      width: numberWidth,
                      height: headerHeight,
                      child: Center(
                        child: Watch(
                          grid.allChecked,
                          builder: (CheckState s) => Checkbox(
                            tristate: true,
                            value: switch (s) {
                              CheckState.none => false,
                              CheckState.some => null,
                              CheckState.all => true,
                            },
                            onChanged: grid.setAllChecked,
                            activeColor: blue,
                            stateLayer: false,
                            semanticLabel: 'Select all records',
                          ),
                        ),
                      ),
                    ),
                  ),
                  _ariaHeader(
                    _ariaColumn(0),
                    Styled(
                      style: StyleProps(
                        minWidth: leadWidth,
                        maxWidth: leadWidth,
                      ),
                      child: _title(GridField.name),
                    ),
                  ),
                ],
              ),
            ),
            z: 5,
          ),
          for (final f in GridField.values.skip(1))
            _ariaHeader(_ariaColumn(f.index), _column(f.index, _title(f))),
        ],
      ),
    ),
  );
}

class _Footer extends StatelessWidget implements ThorElementWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) => Styled(
    style: const StyleProps(
      position: BoxPosition.sticky(bottom: Length.zero),
      zIndex: 4,
    ),
    child: Container(
      height: headerHeight,
      decoration: const BoxDecoration(
        color: chrome,
        border: Border(top: BorderSide(color: line)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _stickyLeft(
            Container(
              padding: const EdgeInsets.only(left: 12),
              alignment: Alignment.centerLeft,
              decoration: const BoxDecoration(
                color: chrome,
                border: Border(right: BorderSide(color: line)),
              ),
              child: Styled(
                style: StyleProps(
                  minWidth: 64.px + leadWidth - 12.px,
                  maxWidth: 64.px + leadWidth - 12.px,
                ),
                child: Watch(grid.recordCount, style: smallMuted),
              ),
            ),
            z: 5,
          ),
          for (final f in GridField.values.skip(1))
            _column(
              f.index,
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                alignment: Alignment.centerRight,
                decoration: _rightLine,
                child: Watch(
                  grid.summary.withArg(f.index),
                  builder: (String s) => Text(
                    s,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: smallMuted,
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class _AddRow extends StatelessWidget implements ThorElementWidget {
  const _AddRow();

  @override
  Widget build(BuildContext context) => _stickyLeft(
    Gesture(
      onTap: grid.addRow,
      semanticButton: false,
      child: Semantics(
        button: true,
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          color: surface.when(hover: chrome),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 6,
            children: [
              Icon(plusIcon, size: 14, color: muted),
              const Text('Add record', style: smallMuted),
            ],
          ),
        ),
      ),
    ),
  );
}

// ── Selection and editors ────────────────────────────────────────────────

BoxDecoration _box(OverlayMode mode) => BoxDecoration(
  color: mode == OverlayMode.range ? const Color(0x1A166EE1) : null,
  border: Border.all(color: blue, width: 2),
  borderRadius: const BorderRadius.all(Radius.circular(2)),
);

const _noOutline = BorderSide(color: Color(0x00000000), width: 0);

/// The layer that stays over the primary column (sticky left): its
/// selection box and its name editor.
class _LeadLayer extends StatelessWidget implements ThorElementWidget {
  const _LeadLayer();

  @override
  Widget build(BuildContext context) => _stickyLeft(
    SizedBox(
      height: 0,
      width: 0,
      child: Column(
        children: [
          Watch(
            grid.leadOverlay,
            builder: (OverlayMode mode) => Focus(
              focusNode: grid.leadFocus,
              skipTraversal: true,
              child: Styled(
                style: StyleProps(
                  position: const BoxPosition.absolute(
                    top: _selectionTop,
                    left: Length.px(numberWidth),
                  ),
                  minWidth: leadWidth,
                  maxWidth: leadWidth,
                  minHeight: _var('--sel-h'),
                  maxHeight: _var('--sel-h'),
                  scrollMargin: const EdgeInsets.symmetric(
                    vertical: headerHeight,
                  ),
                  ignorePointer: true,
                  outline: _noOutline,
                ),
                child: Offstage(
                  offstage: mode == OverlayMode.hidden,
                  child: Container(decoration: _box(mode)),
                ),
              ),
            ),
          ),
          Watch(
            grid.leadEditing,
            builder: (bool on) => Styled(
              style: StyleProps(
                position: const BoxPosition.absolute(
                  top: _selectionTop,
                  left: Length.px(numberWidth),
                ),
                minWidth: leadWidth,
                maxWidth: leadWidth,
              ),
              child: Offstage(
                offstage: !on,
                child: CallbackShortcuts(
                  bindings: _editorKeys,
                  child: Container(
                    decoration: BoxDecoration(
                      color: surface,
                      border: Border.all(color: blue, width: 2),
                    ),
                    child: _field(grid.leadEditorFocus),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
    z: 3,
  );
}

/// Save / cancel / move, in every editor.
final _editorKeys = <ShortcutActivator, void Function()>{
  const SingleActivator(LogicalKeyboardKey.enter): grid.commitDown,
  const SingleActivator(LogicalKeyboardKey.escape): grid.cancel,
  const SingleActivator(LogicalKeyboardKey.tab): grid.commitRight,
  const SingleActivator(LogicalKeyboardKey.tab, shift: true): grid.commitLeft,
};

const _dense = InputDecoration(
  border: InputBorder.none,
  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
);

Widget _field(
  FocusNode focus, {
  TextInputType type = TextInputType.text,
  HtmlAttributes? attributes,
  int lines = 1,
  TextEditingController? controller,
  String? hint,
}) => TextField(
  controller: controller ?? grid.draft,
  focusNode: focus,
  keyboardType: type,
  maxLines: lines,
  style: small,
  decoration: hint == null ? _dense : _dense.copyWith(hintText: hint),
  inputAttributes: attributes,
);

/// What a screen reader hears as the selection moves: the focus stays on
/// the selection box, so the active cell is read from a live region.
class _ActiveCellAnnouncer extends StatelessWidget
    implements ThorElementWidget {
  const _ActiveCellAnnouncer();

  @override
  Widget build(BuildContext context) => Styled(
    style: const StyleProps(
      position: BoxPosition.absolute(top: Length.px(0), left: Length.px(0)),
      minWidth: Length.px(1),
      maxWidth: Length.px(1),
      maxHeight: Length.px(1),
      overflowX: Overflow.hidden,
      overflowY: Overflow.hidden,
      ignorePointer: true,
    ),
    child: Opacity(
      opacity: 0,
      child: Semantics(
        liveRegion: true,
        child: Watch(grid.activeCellAnnouncement),
      ),
    ),
  );
}

/// The box over the other columns.
class _CellOverlay extends StatelessWidget implements ThorElementWidget {
  const _CellOverlay();

  @override
  Widget build(BuildContext context) => Watch(
    grid.cellOverlay,
    builder: (OverlayMode mode) => Focus(
      focusNode: grid.cellFocus,
      skipTraversal: true,
      child: Styled(
        style: StyleProps(
          position: BoxPosition.absolute(
            top: _selectionTop,
            left: 64.px + leadWidth + _var('--sel-x'),
          ),
          minWidth: _var('--sel-w'),
          maxWidth: _var('--sel-w'),
          minHeight: _var('--sel-h'),
          maxHeight: _var('--sel-h'),
          zIndex: 2,
          scrollMargin: const EdgeInsets.fromLTRB(
            numberWidth + 220,
            headerHeight,
            0,
            headerHeight,
          ),
          ignorePointer: true,
          outline: _noOutline,
        ),
        child: Offstage(
          offstage: mode == OverlayMode.hidden,
          child: Container(decoration: _box(mode)),
        ),
      ),
    ),
  );
}

/// The editor of the active cell: every kind is in the page, the state
/// shows one.
class _Editor extends StatelessWidget implements ThorElementWidget {
  const _Editor();

  @override
  Widget build(BuildContext context) => Watch(
    grid.editorKind,
    builder: (EditorKind k) => Styled(
      style: StyleProps(
        position: BoxPosition.absolute(
          top: _selectionTop,
          left: 64.px + leadWidth + _var('--sel-x'),
        ),
        minWidth: Length.max([_var('--sel-w'), 220.px]),
        zIndex: 3,
      ),
      child: Offstage(
        offstage: k == EditorKind.none,
        child: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.escape): grid.cancel,
            const SingleActivator(LogicalKeyboardKey.tab): grid.commitRight,
            const SingleActivator(LogicalKeyboardKey.tab, shift: true):
                grid.commitLeft,
          },
          child: Container(
            decoration: BoxDecoration(
              color: surface,
              border: Border.all(color: blue, width: 2),
              borderRadius: const BorderRadius.all(Radius.circular(4)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _only(
                  k,
                  EditorKind.text,
                  _commitOnEnter(_field(grid.textFocus)),
                ),
                _only(
                  k,
                  EditorKind.number,
                  _commitOnEnter(
                    _field(grid.numberFocus, type: TextInputType.number),
                  ),
                ),
                _only(
                  k,
                  EditorKind.date,
                  _commitOnEnter(
                    _field(
                      grid.dateFocus,
                      attributes: HtmlAttributes.custom({'type': 'date'}),
                    ),
                  ),
                ),
                _only(
                  k,
                  EditorKind.notes,
                  CallbackShortcuts(
                    bindings: {
                      const SingleActivator(
                        LogicalKeyboardKey.enter,
                        meta: true,
                      ): grid.commitDown,
                      const SingleActivator(
                        LogicalKeyboardKey.enter,
                        control: true,
                      ): grid.commitDown,
                    },
                    child: _field(grid.notesFocus, lines: 5),
                  ),
                ),
                Offstage(
                  offstage: k != EditorKind.status && k != EditorKind.owner,
                  child: CallbackShortcuts(
                    bindings: {
                      const SingleActivator(LogicalKeyboardKey.enter):
                          grid.pickFirst,
                    },
                    child: _field(
                      grid.optionFocus,
                      controller: grid.optionQuery,
                      hint: 'Find an option',
                    ),
                  ),
                ),
                _only(
                  k,
                  EditorKind.status,
                  _options([
                    for (var i = 1; i < Status.values.length; i++)
                      Watch(
                        grid.statusShown.withArg(i),
                        builder: (bool on) => Offstage(
                          offstage: !on,
                          child: menuItem(
                            Row(children: [statusPill(Status.values[i])]),
                            onTap: grid.pickStatus.withArg(i),
                          ),
                        ),
                      ),
                  ]),
                ),
                _only(
                  k,
                  EditorKind.owner,
                  _options([
                    for (var i = 1; i < Person.values.length; i++)
                      Watch(
                        grid.ownerShown.withArg(i),
                        builder: (bool on) => Offstage(
                          offstage: !on,
                          child: menuItem(
                            personChip(Person.values[i]),
                            onTap: grid.pickOwner.withArg(i),
                          ),
                        ),
                      ),
                  ]),
                ),
                _only(
                  k,
                  EditorKind.tags,
                  Focus(
                    focusNode: grid.tagsFocus,
                    skipTraversal: true,
                    child: CallbackShortcuts(
                      bindings: {
                        const SingleActivator(LogicalKeyboardKey.enter):
                            grid.cancel,
                      },
                      child: _options([
                        for (final t in Tag.values)
                          Watch(
                            grid.activeHasTag.withArg(t.index),
                            builder: (bool on) => menuItem(
                              Row(
                                spacing: 8,
                                children: [
                                  checkBox(on, size: 14),
                                  tagPill(TagSlot.values[t.index + 1]),
                                ],
                              ),
                              onTap: grid.toggleTag.withArg(t.index),
                            ),
                          ),
                      ]),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

Widget _only(EditorKind k, EditorKind kind, Widget child) =>
    Offstage(offstage: k != kind, child: child);

Widget _commitOnEnter(Widget child) => CallbackShortcuts(
  bindings: {const SingleActivator(LogicalKeyboardKey.enter): grid.commitDown},
  child: child,
);

Widget _options(List<Widget> items) => Container(
  padding: const EdgeInsets.all(4),
  constraints: const BoxConstraints(maxHeight: 280),
  child: SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: items,
    ),
  ),
);
