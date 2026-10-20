// The Grid view's browser state: the view (filters, sorts, grouping…),
// the selection and editing, undo/redo, and the window of rows on screen.
import 'dart:math' as math;

import 'package:thor_ui/thor_ui.dart';

import 'data.dart';
import 'view.dart';

/// Height of the header and footer rows (px).
const headerHeight = 34.0;

/// Width of the row number / checkbox column (px).
const numberWidth = 64.0;

/// Rows rendered above and below the viewport.
const _buffer = 8;

/// The viewport height assumed before the page measured it (the server's
/// first screen).
const _assumedViewport = 900.0;

/// How a grid row looks.
enum RowLook { record, checked, hit, checkedHit, group, collapsedGroup }

/// The group menu: none, then the fields that can group.
final groupChoices = <GridField?>[
  null,
  for (final f in GridField.values)
    if (f.groupable) f,
];

/// The editor open on the active cell.
enum EditorKind { none, text, number, date, notes, status, owner, tags }

/// How the selection box looks.
enum OverlayMode { hidden, cell, range }

/// The header checkbox.
enum CheckState { none, some, all }

/// Filter operator families (one operator menu each).
enum OpFamily { text, choice, multi, date, number, check }

OpFamily familyOf(FieldKind k) => switch (k) {
  FieldKind.text || FieldKind.url || FieldKind.longText => OpFamily.text,
  FieldKind.select || FieldKind.person => OpFamily.choice,
  FieldKind.multi => OpFamily.multi,
  FieldKind.date => OpFamily.date,
  FieldKind.checkbox => OpFamily.check,
  _ => OpFamily.number,
};

/// One row on screen: an entry of the arranged table plus what its row
/// shows. Cached: an unchanged row keeps the same object, so the engine
/// skips it.
class RowView {
  RowView(
    this.entry,
    this.index, {
    required this.checked,
    required this.hit,
    this.selected = 0,
  }) : rev = switch (entry) {
         RecordEntry(:final record) => record.rev,
         _ => 0,
       };

  final Entry entry;

  /// Position in the arranged table.
  final int index;
  final bool checked;

  /// Matches the search.
  final bool hit;
  final int rev;

  /// Selected cells: bit `f.index` per selected field.
  final int selected;

  Launch? get record => switch (entry) {
    RecordEntry(:final record) => record,
    _ => null,
  };

  bool same(RowView o) =>
      identical(o.entry.runtimeType, entry.runtimeType) &&
      o.index == index &&
      o.checked == checked &&
      o.hit == hit &&
      o.rev == rev &&
      o.selected == selected &&
      switch ((entry, o.entry)) {
        (final RecordEntry a, final RecordEntry b) =>
          identical(a.record, b.record) && a.number == b.number,
        (final GroupEntry a, final GroupEntry b) =>
          a.count == b.count && a.collapsed == b.collapsed,
        _ => false,
      };
}

sealed class _Change {}

class _FieldChange extends _Change {
  _FieldChange(this.record, this.field, this.before, this.after);

  final Launch record;
  final GridField field;
  final Object? before;
  Object? after;
}

class _RowsChange extends _Change {
  _RowsChange(this.rows, {required this.added});

  /// (position in the table, record).
  final List<(int, Launch)> rows;
  final bool added;
}

class _Step {
  _Step(this.changes);

  final List<_Change> changes;
}

class GridState extends ThorState {
  // ── Data ─────────────────────────────────────────────────────────────
  final List<Launch> _records = seedLaunches();
  // Not `late`: the lite translator rejects it (an eager JS initializer
  // would not be lazy). 0 means "not taken yet"; the first id is taken from
  // the records on first use, as the `late` initializer did.
  int _nextId = 0;

  /// Bumped on every data change (records are plain objects).
  final version = state(0);

  // ── View (in the URL) ────────────────────────────────────────────────
  /// Filter slots: `field:op:value`, or '' for an unused slot.
  final filters = state<List<String>>(List.filled(maxFilters, ''));
  final matchAny = state(false);

  /// Sort slots: `field:asc|desc`, or ''.
  final sorts = state<List<String>>(List.filled(maxSorts, ''));
  final group = state('');
  final hidden = state<List<String>>(const []);
  final search = state('');
  final rowHeight = state('short');
  final collapsed = state<List<String>>(const []);

  // ── Selection, editing ───────────────────────────────────────────────
  final activeKey = state('r1');
  final activeCol = state(0);
  final anchorKey = state('r1');
  final anchorCol = state(0);
  final editing = state('none');
  final checked = state<List<int>>(const []);
  final drawer = state(0);
  final searchPos = state(0);
  final widths = state<List<double>>([
    for (final f in GridField.values) f.width,
  ]);

  // ── Controllers ──────────────────────────────────────────────────────
  final scroll = ScrollController();
  final cellFocus = FocusNode();
  final leadFocus = FocusNode();
  final leadEditorFocus = FocusNode();
  final textFocus = FocusNode();
  final numberFocus = FocusNode();
  final dateFocus = FocusNode();
  final notesFocus = FocusNode();
  final optionFocus = FocusNode();
  final tagsFocus = FocusNode();
  final details = DialogController();
  final draft = TextEditingController();
  final optionQuery = TextEditingController();
  final searchBox = TextEditingController();
  final filterValue0 = TextEditingController();
  final filterValue1 = TextEditingController();
  final filterValue2 = TextEditingController();
  final filterValue3 = TextEditingController();
  final drawerName = TextEditingController();
  final drawerLaunch = TextEditingController();
  final drawerBudget = TextEditingController();
  final drawerProgress = TextEditingController();
  final drawerUrl = TextEditingController();
  final drawerNotes = TextEditingController();
  final drawerFiles = TextEditingController();

  List<TextEditingController> get _filterValues => [
    filterValue0,
    filterValue1,
    filterValue2,
    filterValue3,
  ];

  // ── View config ──────────────────────────────────────────────────────
  /// Sets the view from the URL (server, before rendering).
  void applyView(ViewConfig v) => batch(() {
    filters.value = [
      for (var i = 0; i < maxFilters; i++)
        i < v.filters.length ? v.filters[i].encode() : '',
    ];
    for (var i = 0; i < maxFilters; i++) {
      _filterValues[i].text = i < v.filters.length ? v.filters[i].value : '';
    }
    matchAny.value = v.any;
    sorts.value = [
      for (var i = 0; i < maxSorts; i++)
        i < v.sorts.length ? v.sorts[i].encode() : '',
    ];
    group.value = v.group?.name ?? '';
    hidden.value = [for (final f in v.hidden) f.name];
    search.value = v.search;
    searchBox.text = v.search;
    rowHeight.value = v.rowHeight.name;
  });

  ViewConfig _config() => ViewConfig(
    filters: [
      for (final f in filters.value)
        if (f.isNotEmpty) ?Condition.decode(f),
    ],
    any: matchAny.value,
    sorts: [
      for (final s in sorts.value)
        if (s.isNotEmpty) ?SortLevel.decode(s),
    ],
    group: GridField.values.asNameMap()[group.value],
    hidden: {for (final h in hidden.value) ?GridField.values.asNameMap()[h]},
    search: search.value,
    rowHeight: RowHeight.values.asNameMap()[rowHeight.value] ?? RowHeight.short,
  );

  void _syncUrl() => SystemNavigator.routeInformationUpdated(
    uri: Uri.parse('/${_config().toQuery()}'),
    replace: true,
  );

  // ── Arranged table (memoized on the inputs' identity) ────────────────
  List<Object?> _displayKey = const [];
  List<Entry> _displayCache = const [];
  Map<String, int> _indexCache = const {};

  List<Entry> _display() {
    final key = [
      filters.value,
      matchAny.value,
      sorts.value,
      group.value,
      collapsed.value,
      version.value,
    ];
    if (key.length == _displayKey.length &&
        [for (var i = 0; i < key.length; i++) i].every(
          (i) => identical(key[i], _displayKey[i]) || key[i] == _displayKey[i],
        )) {
      return _displayCache;
    }
    _displayKey = key;
    _displayCache = arrange(
      _records,
      _config(),
      collapsed: collapsed.value.toSet(),
    );
    _indexCache = {
      for (var i = 0; i < _displayCache.length; i++) _displayCache[i].key: i,
    };
    return _displayCache;
  }

  int _indexOf(String key) {
    _display();
    return _indexCache[key] ?? -1;
  }

  List<GridField> _visible() {
    final h = hidden.value;
    return [
      for (final f in GridField.values)
        if (!h.contains(f.name)) f,
    ];
  }

  double get _rowPx =>
      (RowHeight.values.asNameMap()[rowHeight.value] ?? RowHeight.short).px;

  // Search matches: (entry index, column), in reading order.
  List<Object?> _searchKey = const [];
  List<(int, GridField)> _matchCache = const [];
  Set<int> _hitIds = const {};

  List<(int, GridField)> _matches() {
    final d = _display();
    final q = search.value.trim().toLowerCase();
    final key = [d, q, hidden.value];
    if (identical(key[0], _searchKey.firstOrNull) &&
        _searchKey.length == 3 &&
        key[1] == _searchKey[1] &&
        identical(key[2], _searchKey[2])) {
      return _matchCache;
    }
    _searchKey = key;
    final out = <(int, GridField)>[];
    final ids = <int>{};
    if (q.isNotEmpty) {
      final fields = _visible();
      for (var i = 0; i < d.length; i++) {
        final e = d[i];
        if (e is! RecordEntry) continue;
        for (final f in fields) {
          if (cellText(e.record, f).toLowerCase().contains(q)) {
            out.add((i, f));
            ids.add(e.record.id);
          }
        }
      }
    }
    _hitIds = ids;
    return _matchCache = out;
  }

  // ── The window of rows ───────────────────────────────────────────────
  Map<String, RowView> _rowCache = {};

  (int, int) _window() {
    final d = _display();
    final h = _rowPx;
    final top = scroll.offset;
    final viewport = scroll.position.viewportDimension;
    final height = viewport > 0 ? viewport : _assumedViewport;
    final first = math.max(0, (top - headerHeight) ~/ h - _buffer);
    final last = math.min(d.length, ((top + height) / h).ceil() + _buffer);
    return (first, math.max(first, last));
  }

  /// The rows on screen (plus a buffer): the list the page renders.
  List<RowView> rows() {
    final d = _display();
    final (first, last) = _window();
    final checkedIds = checked.value.toSet();
    _matches();
    // The selected cells (aria-selected): fields between the range's
    // columns, on the range's rows.
    var top = -1, bottom = -2, mask = 0;
    if (_selectionShown()) {
      final (r0, r1, c0, c1) = _range();
      final visible = _visible();
      (top, bottom) = (r0, r1);
      for (var p = c0; p <= c1 && p < visible.length; p++) {
        mask |= 1 << visible[p].index;
      }
    }
    final next = <String, RowView>{};
    final out = <RowView>[];
    for (var i = first; i < last; i++) {
      final e = d[i];
      final id = e is RecordEntry ? e.record.id : -1;
      final v = RowView(
        e,
        i,
        checked: checkedIds.contains(id),
        hit: _hitIds.contains(id),
        selected: i >= top && i <= bottom ? mask : 0,
      );
      final old = _rowCache[e.key];
      final row = old != null && old.same(v) ? old : v;
      next[e.key] = row;
      out.add(row);
    }
    _rowCache = next;
    return out;
  }

  /// Rows of the grid for assistive technology: the header plus every
  /// arranged row (only a window of them is in the page).
  String ariaRowCount() => '${_display().length + 1}';

  /// Space above the rendered rows (px).
  double spaceBefore() => _window().$1 * _rowPx;

  /// Space below the rendered rows (px).
  double spaceAfter() => (_display().length - _window().$2) * _rowPx;

  /// The row height (px).
  double rowHeightPx() => _rowPx;

  /// A column's width (px).
  double width(int column) => widths.value[column];

  /// Width of the primary column (px).
  double leadWidth() => widths.value[0];

  // ── Row texts and states ─────────────────────────────────────────────
  String rowKey(RowView r) => r.entry.key;

  /// The row's 1-based position in the whole grid (the header is row 1),
  /// right whatever window of rows is in the page.
  String ariaRowIndexOf(RowView r) => '${r.index + 2}';

  /// Whether cell [column] of the row is in the selection.
  bool cellSelected(int column, RowView r) => (r.selected >> column) & 1 == 1;

  /// The record's name, for the controls of its row.
  String _recordName(RowView r) => r.record?.name ?? '';

  /// The active cell as a screen reader should hear it when the selection
  /// moves: the field, the record and the value.
  String activeCellAnnouncement() {
    final r = _recordOf(activeKey.value);
    if (r == null) return '';
    final f = GridField.values[activeCol.value];
    final value = cellText(r, f);
    return '${f.label}, ${r.name}: ${value.isEmpty ? 'empty' : value}';
  }

  /// Name of the row's checkbox.
  String selectLabelOf(RowView r) => 'Select ${_recordName(r)}';

  /// Name of the row's expand button.
  String expandLabelOf(RowView r) => 'Expand ${_recordName(r)}';

  /// The page's full URL (the cell's link).
  String urlHrefOf(RowView r) => r.record?.url ?? '';

  String numberOf(RowView r) => switch (r.entry) {
    RecordEntry(:final number) => '$number',
    _ => '',
  };

  String nameOf(RowView r) => switch (r.entry) {
    RecordEntry(:final record) => record.name,
    GroupEntry(:final label) => label,
  };

  String groupCountOf(RowView r) => switch (r.entry) {
    GroupEntry(:final count) => '$count ${count == 1 ? 'record' : 'records'}',
    _ => '',
  };

  RowLook lookOf(RowView r) => switch (r.entry) {
    RecordEntry() when r.checked && r.hit => RowLook.checkedHit,
    RecordEntry() when r.checked => RowLook.checked,
    RecordEntry() when r.hit => RowLook.hit,
    RecordEntry() => RowLook.record,
    GroupEntry(:final collapsed) =>
      collapsed ? RowLook.collapsedGroup : RowLook.group,
  };

  bool isChecked(RowView r) => r.checked;

  bool isHit(RowView r) => r.hit;

  Status statusOf(RowView r) => r.record?.status ?? Status.none;

  TagSlot _tag(RowView r, int i) {
    final tags = r.record?.tagList ?? const [];
    return i < tags.length ? TagSlot.values[tags[i].index + 1] : TagSlot.none;
  }

  TagSlot tag0(RowView r) => _tag(r, 0);
  TagSlot tag1(RowView r) => _tag(r, 1);
  TagSlot tag2(RowView r) => _tag(r, 2);

  String moreTagsOf(RowView r) {
    final n = (r.record?.tagList.length ?? 0) - 3;
    return n > 0 ? '+$n' : '';
  }

  Person ownerOf(RowView r) => r.record?.owner ?? Person.none;

  String launchOf(RowView r) => formatDay(r.record?.launch);

  String budgetOf(RowView r) {
    final b = r.record?.budget;
    return b == null ? '' : formatMoney(b);
  }

  /// Progress in 5 % steps (0–20).
  int progressStep(RowView r) => ((r.record?.progress ?? 0) / 5).round();

  String progressOf(RowView r) {
    final p = r.record?.progress;
    return p == null ? '' : '$p%';
  }

  bool shippedOf(RowView r) => r.record?.shipped ?? false;

  int ratingOf(RowView r) => r.record?.rating ?? 0;

  String urlOf(RowView r) =>
      (r.record?.url ?? '').replaceFirst(RegExp('^https?://'), '');

  String notesOf(RowView r) => r.record?.notes ?? '';

  String filesOf(RowView r) {
    final n = r.record?.files ?? 0;
    return n == 0 ? '' : '$n ${n == 1 ? 'file' : 'files'}';
  }

  // ── Selection ────────────────────────────────────────────────────────
  (int, int, int, int) _range() {
    final visible = _visible();
    int pos(int col) {
      final p = visible.indexOf(GridField.values[col]);
      return p < 0 ? 0 : p;
    }

    final a = _indexOf(activeKey.value), b = _indexOf(anchorKey.value);
    final ai = a < 0 ? 0 : a, bi = b < 0 ? ai : b;
    final ac = pos(activeCol.value), bc = pos(anchorCol.value);
    return (
      math.min(ai, bi),
      math.max(ai, bi),
      math.min(ac, bc),
      math.max(ac, bc),
    );
  }

  bool _selectionShown() {
    final i = _indexOf(activeKey.value);
    return i >= 0 && _display()[i] is RecordEntry;
  }

  double _columnsWidth(int fromPos, int toPos) {
    final visible = _visible();
    var w = 0.0;
    for (var p = fromPos; p <= toPos && p < visible.length; p++) {
      w += widths.value[visible[p].index];
    }
    return w;
  }

  /// The box over the primary column.
  OverlayMode leadOverlay() {
    if (!_selectionShown()) return OverlayMode.hidden;
    final (top, bottom, left, _) = _range();
    if (left > 0) return OverlayMode.hidden;
    return top == bottom && _range().$4 == 0
        ? OverlayMode.cell
        : OverlayMode.range;
  }

  /// The box over the other columns.
  OverlayMode cellOverlay() {
    if (!_selectionShown()) return OverlayMode.hidden;
    final (top, bottom, left, right) = _range();
    if (right == 0) return OverlayMode.hidden;
    return top == bottom && left == right
        ? OverlayMode.cell
        : OverlayMode.range;
  }

  double selectionTop() => headerHeight + _range().$1 * _rowPx;

  double selectionHeight() => (_range().$2 - _range().$1 + 1) * _rowPx;

  /// Left of the cell box, after the primary column (px).
  double selectionX() => _columnsWidth(1, math.max(1, _range().$3) - 1);

  double selectionWidth() {
    final (_, _, left, right) = _range();
    return _columnsWidth(math.max(1, left), right);
  }

  void _select(String key, int col, {bool extend = false}) {
    batch(() {
      activeKey.value = key;
      activeCol.value = col;
      if (!extend) {
        anchorKey.value = key;
        anchorCol.value = col;
      }
      editing.value = EditorKind.none.name;
    });
    _focusSelection();
  }

  void _focusSelection() =>
      (activeCol.value == 0 ? leadFocus : cellFocus).requestFocus();

  (String, int) _cellOf(String id) {
    final dot = id.lastIndexOf('.');
    return (id.substring(0, dot), int.parse(id.substring(dot + 1)));
  }

  /// A click on a cell (`r12.3`); with Shift it extends the range. On a
  /// group header it opens or closes the group.
  void tapCell(String id) {
    final (key, col) = _cellOf(id);
    if (key.startsWith('g')) return toggleGroup(key);
    _commitIfEditing();
    _select(key, col, extend: HardwareKeyboard.instance.isShiftPressed);
  }

  /// A double click: select and edit.
  void editCell(String id) {
    final (key, col) = _cellOf(id);
    _select(key, col);
    startEdit();
  }

  void _move(int dRow, int dCol, {bool extend = false}) {
    _commitIfEditing();
    final d = _display();
    if (d.isEmpty) return;
    final visible = _visible();
    var i = math.max(0, _indexOf(activeKey.value));
    var pos = math.max(0, visible.indexOf(GridField.values[activeCol.value]));
    pos = (pos + dCol).clamp(0, visible.length - 1);
    if (dRow != 0) {
      var j = i;
      var steps = dRow.abs();
      while (steps > 0) {
        final n = j + dRow.sign;
        if (n < 0 || n >= d.length) break;
        j = n;
        if (d[j] is RecordEntry) {
          i = j;
          steps--;
        }
      }
    }
    _select(d[i].key, visible[pos].index, extend: extend);
  }

  void up() => _move(-1, 0);
  void down() => _move(1, 0);
  void left() => _move(0, -1);
  void right() => _move(0, 1);
  void pageUp() => _move(-_pageRows(), 0);
  void pageDown() => _move(_pageRows(), 0);
  void extendUp() => _move(-1, 0, extend: true);
  void extendDown() => _move(1, 0, extend: true);
  void extendLeft() => _move(0, -1, extend: true);
  void extendRight() => _move(0, 1, extend: true);

  int _pageRows() {
    final vp = scroll.position.viewportDimension;
    return math.max(1, ((vp > 0 ? vp : _assumedViewport) / _rowPx).floor() - 2);
  }

  /// Tab: the next cell, wrapping to the next row.
  void nextCell() {
    final visible = _visible();
    final pos = visible.indexOf(GridField.values[activeCol.value]);
    if (pos < visible.length - 1) return _move(0, 1);
    _move(1, -visible.length);
  }

  /// Shift+Tab.
  void previousCell() {
    final visible = _visible();
    final pos = visible.indexOf(GridField.values[activeCol.value]);
    if (pos > 0) return _move(0, -1);
    _move(-1, visible.length);
  }

  /// Escape: collapse a range (the drawer closes itself: a native modal).
  void escape() => _select(activeKey.value, activeCol.value);

  // ── Editing ──────────────────────────────────────────────────────────
  Launch? _activeRecord() {
    final i = _indexOf(activeKey.value);
    if (i < 0) return null;
    final e = _display()[i];
    return e is RecordEntry ? e.record : null;
  }

  GridField get _activeField => GridField.values[activeCol.value];

  EditorKind editorKind() {
    final k = EditorKind.values.asNameMap()[editing.value] ?? EditorKind.none;
    return activeCol.value == 0 ? EditorKind.none : k;
  }

  bool leadEditing() =>
      activeCol.value == 0 && editing.value == EditorKind.text.name;

  /// Enter / F2 / double click: edit the active cell with its editor.
  void startEdit() {
    final r = _activeRecord();
    if (r == null) return;
    final f = _activeField;
    final kind = switch (f.kind) {
      FieldKind.text || FieldKind.url => EditorKind.text,
      FieldKind.currency ||
      FieldKind.percent ||
      FieldKind.attachments => EditorKind.number,
      FieldKind.date => EditorKind.date,
      FieldKind.longText => EditorKind.notes,
      FieldKind.select => EditorKind.status,
      FieldKind.person => EditorKind.owner,
      FieldKind.multi => EditorKind.tags,
      FieldKind.checkbox || FieldKind.rating => EditorKind.none,
    };
    if (f.kind == FieldKind.checkbox) {
      return _set(r, f, !r.shipped);
    }
    if (f.kind == FieldKind.rating) return _set(r, f, (r.rating + 1) % 6);
    batch(() {
      draft.text = switch (f) {
        GridField.budget => '${r.budget}',
        GridField.progress => '${r.progress}',
        GridField.files => '${r.files}',
        GridField.launch => isoDay(r.launch),
        _ => cellText(r, f),
      };
      optionQuery.clear();
      anchorKey.value = activeKey.value;
      anchorCol.value = activeCol.value;
      editing.value = kind.name;
    });
    (switch (kind) {
      EditorKind.text when f == GridField.name => leadEditorFocus,
      EditorKind.text => textFocus,
      EditorKind.number => numberFocus,
      EditorKind.date => dateFocus,
      EditorKind.notes => notesFocus,
      EditorKind.status || EditorKind.owner => optionFocus,
      _ => tagsFocus,
    }).requestFocus();
  }

  void _commitIfEditing() {
    if (editing.value != EditorKind.none.name) commit();
  }

  /// Saves the draft of a text-like editor and closes it.
  void commit() {
    final r = _activeRecord();
    final kind = EditorKind.values.asNameMap()[editing.value];
    if (r != null) {
      final f = _activeField;
      final text = draft.text.trim();
      switch (kind) {
        case EditorKind.text || EditorKind.notes:
          _set(r, f, draft.text);
        case EditorKind.number:
          final n = int.tryParse(text.replaceAll(RegExp(r'[$,%\s]'), ''));
          if (n != null) {
            _set(
              r,
              f,
              f == GridField.progress ? n.clamp(0, 100) : math.max(0, n),
            );
          }
        case EditorKind.date:
          _set(r, f, parseIsoDay(text));
        default:
          break;
      }
    }
    editing.value = EditorKind.none.name;
    _focusSelection();
  }

  /// Escape in an editor: close without saving.
  void cancel() {
    editing.value = EditorKind.none.name;
    _focusSelection();
  }

  /// Enter in an editor: save and go down.
  void commitDown() {
    commit();
    down();
  }

  /// Tab in an editor: save and go right.
  void commitRight() {
    commit();
    nextCell();
  }

  /// Shift+Tab in an editor.
  void commitLeft() {
    commit();
    previousCell();
  }

  bool _optionShown(String label) {
    final q = optionQuery.text.trim().toLowerCase();
    return q.isEmpty || label.toLowerCase().contains(q);
  }

  bool statusShown(int i) => _optionShown(Status.values[i].label);

  bool ownerShown(int i) => _optionShown(Person.values[i].label);

  void pickStatus(int i) {
    final r = _activeRecord();
    if (r != null) _set(r, GridField.status, Status.values[i]);
    cancel();
  }

  void pickOwner(int i) {
    final r = _activeRecord();
    if (r != null) _set(r, GridField.owner, Person.values[i]);
    cancel();
  }

  /// Enter in the option search: the first match.
  void pickFirst() {
    if (editing.value == EditorKind.status.name) {
      for (var i = 1; i < Status.values.length; i++) {
        if (statusShown(i)) return pickStatus(i);
      }
    } else {
      for (var i = 1; i < Person.values.length; i++) {
        if (ownerShown(i)) return pickOwner(i);
      }
    }
  }

  bool activeHasTag(int i) {
    version.value;
    final r = _activeRecord();
    return r != null && r.tags & (1 << i) != 0;
  }

  void toggleTag(int i) {
    final r = _activeRecord();
    if (r != null) _set(r, GridField.tags, r.tags ^ (1 << i));
  }

  /// A row's Shipped checkbox.
  void setShipped(String key, bool? shipped) {
    final r = _recordOf(key);
    if (r != null) _set(r, GridField.shipped, shipped ?? false);
  }

  /// A click on a star (`r12.3`).
  void rate(String id) {
    final (key, n) = _cellOf(id);
    final r = _recordOf(key);
    if (r != null) _set(r, GridField.rating, r.rating == n ? 0 : n);
  }

  /// Delete / Backspace: empty the selected cells.
  void clearCells() {
    final (top, bottom, left, right) = _range();
    final visible = _visible();
    final d = _display();
    final changes = <_Change>[];
    for (var i = top; i <= bottom; i++) {
      final e = d[i];
      if (e is! RecordEntry) continue;
      for (var p = left; p <= right; p++) {
        final f = visible[p];
        final empty = switch (f.kind) {
          FieldKind.select => Status.none,
          FieldKind.person => Person.none,
          FieldKind.multi ||
          FieldKind.currency ||
          FieldKind.percent ||
          FieldKind.rating ||
          FieldKind.attachments => 0,
          FieldKind.checkbox => false,
          FieldKind.date => null,
          _ => '',
        };
        final before = _get(e.record, f);
        if (before == empty) continue;
        _write(e.record, f, empty);
        changes.add(_FieldChange(e.record, f, before, empty));
      }
    }
    _record(changes);
  }

  /// A character typed on the selection: edit the active cell starting
  /// from it (as in a spreadsheet: the text is replaced, an option list is
  /// searched).
  void typeInto(String character) {
    final r = _activeRecord();
    if (r == null || editing.value != EditorKind.none.name) return;
    switch (_activeField.kind) {
      case FieldKind.checkbox || FieldKind.rating:
        return;
      case FieldKind.date || FieldKind.multi:
        return startEdit();
      case FieldKind.select || FieldKind.person:
        startEdit();
        optionQuery.text = character;
      default:
        startEdit();
        draft.text = character;
    }
  }

  // ── Clipboard ────────────────────────────────────────────────────────
  /// ⌘C: the selected cells as tab-separated text (rows by lines), what
  /// spreadsheets copy and paste.
  void copy() {
    final (top, bottom, left, right) = _range();
    final visible = _visible();
    final d = _display();
    final lines = <String>[
      for (var i = top; i <= bottom && i < d.length; i++)
        if (d[i] case RecordEntry(:final record))
          [
            for (var p = left; p <= right; p++)
              tsvCell(cellText(record, visible[p])),
          ].join('\t'),
    ];
    Clipboard.setData(ClipboardData(text: lines.join('\n')));
  }

  /// ⌘V: tab-separated text into the cells from the selection's corner (a
  /// single value fills the whole selected range), one undo step.
  Future<void> paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.isEmpty) return;
    pasteTsv(text);
  }

  /// Writes [text] (tab-separated) into the grid at the selection.
  void pasteTsv(String text) {
    final table = parseTsv(text);
    if (table.isEmpty) return;
    _commitIfEditing();
    final (top, bottom, left, right) = _range();
    final visible = _visible();
    final d = _display();
    final single = table.length == 1 && table[0].length == 1;
    // Records from the corner down (group headers are skipped).
    final records = <int>[
      for (var i = top; i < d.length; i++)
        if (d[i] is RecordEntry) i,
    ];
    final rows = single
        ? records.where((i) => i <= bottom).length
        : math.min(table.length, records.length);
    final cols = single
        ? right - left + 1
        : math.min(
            table.map((r) => r.length).reduce(math.max),
            visible.length - left,
          );
    final changes = <_Change>[];
    for (var y = 0; y < rows; y++) {
      final record = (d[records[y]] as RecordEntry).record;
      final line = single ? table[0] : table[y];
      for (var x = 0; x < cols; x++) {
        final raw = single ? line[0] : (x < line.length ? line[x] : null);
        if (raw == null) continue;
        final f = visible[left + x];
        final (ok, value) = _parseCell(f, raw);
        final before = _get(record, f);
        if (!ok || before == value) continue;
        _write(record, f, value);
        changes.add(_FieldChange(record, f, before, value));
      }
    }
    _record(changes);
    if (rows == 0 || cols == 0) return;
    // The pasted block becomes the selection.
    batch(() {
      anchorKey.value = d[records[0]].key;
      anchorCol.value = visible[left].index;
      activeKey.value = d[records[rows - 1]].key;
      activeCol.value = visible[left + cols - 1].index;
    });
    _focusSelection();
  }

  /// A pasted cell's text as [f]'s value: `(false, null)` when it doesn't
  /// fit (the cell keeps its value).
  (bool, Object?) _parseCell(GridField f, String raw) {
    final t = raw.trim();
    int? number() => int.tryParse(t.replaceAll(RegExp(r'[$,%\s]'), ''));
    T? byLabel<T extends Enum>(List<T> values, String Function(T) label) {
      for (final v in values) {
        if (label(v).toLowerCase() == t.toLowerCase()) return v;
      }
      return null;
    }

    switch (f.kind) {
      case FieldKind.text || FieldKind.url || FieldKind.longText:
        return (true, raw);
      case FieldKind.select:
        final s = byLabel(Status.values, (s) => s.label);
        return (s != null, s);
      case FieldKind.person:
        final p = byLabel(Person.values, (p) => p.label);
        return (p != null, p);
      case FieldKind.multi:
        var tags = 0;
        for (final part in t.split(',')) {
          final name = part.trim().toLowerCase();
          if (name.isEmpty) continue;
          final tag = Tag.values
              .where((g) => g.label.toLowerCase() == name)
              .firstOrNull;
          if (tag == null) return (false, null);
          tags |= 1 << tag.index;
        }
        return (true, tags);
      case FieldKind.date:
        if (t.isEmpty) return (true, null);
        final day = parseIsoDay(t) ?? parseDay(t);
        return (day != null, day);
      case FieldKind.currency || FieldKind.attachments:
        if (t.isEmpty) return (true, 0);
        final n = number();
        return (n != null, n == null ? null : math.max(0, n));
      case FieldKind.percent:
        if (t.isEmpty) return (true, 0);
        final n = number();
        return (n != null, n?.clamp(0, 100));
      case FieldKind.checkbox:
        return (
          true,
          const {
            'yes',
            'true',
            'checked',
            '1',
            'x',
            '✓',
          }.contains(t.toLowerCase()),
        );
      case FieldKind.rating:
        if (t.isEmpty) return (true, 0);
        if (RegExp(r'^★+$').hasMatch(t)) return (true, math.min(5, t.length));
        final n = int.tryParse(t);
        return (n != null && n >= 0 && n <= 5, n);
    }
  }

  // ── Data changes, undo / redo ────────────────────────────────────────
  final List<_Step> _undo = [];
  final List<_Step> _redo = [];

  Launch? _recordOf(String key) {
    final id = int.tryParse(key.substring(1));
    for (final r in _records) {
      if (r.id == id) return r;
    }
    return null;
  }

  Object? _get(Launch r, GridField f) => switch (f) {
    GridField.name => r.name,
    GridField.status => r.status,
    GridField.tags => r.tags,
    GridField.owner => r.owner,
    GridField.launch => r.launch,
    GridField.budget => r.budget,
    GridField.progress => r.progress,
    GridField.shipped => r.shipped,
    GridField.rating => r.rating,
    GridField.url => r.url,
    GridField.notes => r.notes,
    GridField.files => r.files,
  };

  void _write(Launch r, GridField f, Object? v) {
    switch (f) {
      case GridField.name:
        r.name = v! as String;
      case GridField.status:
        r.status = v! as Status;
      case GridField.tags:
        r.tags = v! as int;
      case GridField.owner:
        r.owner = v! as Person;
      case GridField.launch:
        r.launch = v as int?;
      case GridField.budget:
        r.budget = v! as int;
      case GridField.progress:
        r.progress = v! as int;
      case GridField.shipped:
        r.shipped = v! as bool;
      case GridField.rating:
        r.rating = v! as int;
      case GridField.url:
        r.url = v! as String;
      case GridField.notes:
        r.notes = v! as String;
      case GridField.files:
        r.files = v! as int;
    }
    r.rev++;
  }

  /// One edit (typing in the drawer coalesces into one undo step per
  /// field).
  void _set(Launch r, GridField f, Object? v, {bool coalesce = false}) {
    final before = _get(r, f);
    if (before == v) return;
    _write(r, f, v);
    final last = _undo.lastOrNull?.changes.singleOrNull;
    if (coalesce &&
        last is _FieldChange &&
        identical(last.record, r) &&
        last.field == f) {
      last.after = v;
      _redo.clear();
      _changed();
      return;
    }
    _record([_FieldChange(r, f, before, v)]);
  }

  void _record(List<_Change> changes) {
    if (changes.isEmpty) return;
    _undo.add(_Step(changes));
    if (_undo.length > 200) _undo.removeAt(0);
    _redo.clear();
    _changed();
  }

  void _changed() {
    version.value++;
    _syncDrawer();
  }

  void _apply(_Step step, {required bool forward}) {
    for (final c in forward ? step.changes : step.changes.reversed) {
      switch (c) {
        case _FieldChange():
          _write(c.record, c.field, forward ? c.after : c.before);
        case _RowsChange(:final rows, :final added):
          final insert = added == forward;
          if (insert) {
            for (final (i, r) in rows) {
              _records.insert(math.min(i, _records.length), r);
            }
          } else {
            for (final (_, r) in rows) {
              _records.remove(r);
            }
          }
      }
    }
    _changed();
  }

  void undo() {
    if (editing.value != EditorKind.none.name) return cancel();
    final step = _undo.isEmpty ? null : _undo.removeLast();
    if (step == null) return;
    _apply(step, forward: false);
    _redo.add(step);
  }

  void redo() {
    final step = _redo.isEmpty ? null : _redo.removeLast();
    if (step == null) return;
    _apply(step, forward: true);
    _undo.add(step);
  }

  bool canUndo() {
    version.value;
    return _undo.isNotEmpty;
  }

  bool canRedo() {
    version.value;
    return _redo.isNotEmpty;
  }

  int _takeId() {
    if (_nextId == 0) _nextId = _records.length + 1;
    return _nextId++;
  }

  /// "+ Add record": a new row at the end, its name in edit.
  void addRow() {
    final r = Launch(
      id: _takeId(),
      name: '',
      status: Status.none,
      tags: 0,
      owner: Person.none,
      launch: null,
      budget: 0,
      progress: 0,
      shipped: false,
      rating: 0,
      url: '',
      notes: '',
      files: 0,
    );
    _records.add(r);
    _record([
      _RowsChange([(_records.length - 1, r)], added: true),
    ]);
    final d = _display();
    final i = d.indexWhere((e) => e is RecordEntry && identical(e.record, r));
    if (i < 0) return; // filtered out
    _select(d[i].key, 0);
    scroll.jumpTo(headerHeight + i * _rowPx);
    startEdit();
  }

  // ── Row checkboxes and bulk actions ──────────────────────────────────
  /// A row's checkbox.
  void setChecked(String key, bool? on) {
    final id = int.tryParse(key.substring(1));
    if (id == null) return;
    final set = checked.value.toSet();
    (on ?? false) ? set.add(id) : set.remove(id);
    checked.value = set.toList();
  }

  CheckState allChecked() {
    final n = checked.value.length;
    if (n == 0) return CheckState.none;
    final shown = _display().whereType<RecordEntry>().length;
    return n >= shown ? CheckState.all : CheckState.some;
  }

  /// The header checkbox: none checked → all; otherwise none (whatever
  /// the box's own next value).
  void setAllChecked(bool? on) {
    checked.value = allChecked() == CheckState.none
        ? [
            for (final e in _display())
              if (e is RecordEntry) e.record.id,
          ]
        : const [];
  }

  bool hasChecked() => checked.value.isNotEmpty;

  String checkedLabel() {
    final n = checked.value.length;
    return '$n ${n == 1 ? 'record' : 'records'} selected';
  }

  void clearChecked() => checked.value = const [];

  void bulkDelete() {
    final ids = checked.value.toSet();
    final rows = [
      for (var i = 0; i < _records.length; i++)
        if (ids.contains(_records[i].id)) (i, _records[i]),
    ];
    for (final (_, r) in rows) {
      _records.remove(r);
    }
    checked.value = const [];
    _record([_RowsChange(rows, added: false)]);
  }

  void bulkStatus(int i) {
    final ids = checked.value.toSet();
    final changes = <_Change>[];
    for (final r in _records) {
      if (!ids.contains(r.id) || r.status == Status.values[i]) continue;
      changes.add(
        _FieldChange(r, GridField.status, r.status, Status.values[i]),
      );
      _write(r, GridField.status, Status.values[i]);
    }
    _record(changes);
  }

  // ── Groups ───────────────────────────────────────────────────────────
  /// A click on a group header toggles it (records ignore it).
  void toggleGroup(String key) {
    if (!key.startsWith('g')) return;
    final value = key.substring(1);
    final set = collapsed.value.toSet();
    set.contains(value) ? set.remove(value) : set.add(value);
    collapsed.value = set.toList();
  }

  void collapseAll() => collapsed.value = [
    for (final e in _display())
      if (e is GroupEntry) e.value,
  ];

  void expandAll() => collapsed.value = const [];

  // ── Columns ──────────────────────────────────────────────────────────
  /// Width of the column being dragged, before clamping and rounding (so
  /// the edge stays under the pointer after hitting a limit).
  final Map<int, double> _dragging = {};

  /// A header edge moved by [dx] px (every frame of the drag, or an arrow
  /// key): the column follows live.
  void resize(int column, double dx, double dy) {
    final raw = (_dragging[column] ?? widths.value[column]) + dx;
    _dragging[column] = raw;
    final w = raw.clamp(60, 640).roundToDouble();
    if (w == widths.value[column]) return;
    widths.value = [
      for (var i = 0; i < widths.value.length; i++)
        i == column ? w : widths.value[i],
    ];
  }

  /// The drag ended (the width is already set).
  void endResize(int column, double dx, double dy) => _dragging.remove(column);

  bool isHidden(int column) =>
      hidden.value.contains(GridField.values[column].name);

  bool isShown(int column) => !isHidden(column);

  void setShown(int column, bool shown) {
    final name = GridField.values[column].name;
    if (column == 0) return;
    hidden.value = [
      for (final h in hidden.value)
        if (h != name) h,
      if (!shown) name,
    ];
    if (!shown && activeCol.value == column) _move(0, -1);
    _syncUrl();
  }

  void showAll() {
    hidden.value = const [];
    _syncUrl();
  }

  // ── Toolbar: filters ─────────────────────────────────────────────────
  Condition? _condition(int slot) => Condition.decode(filters.value[slot]);

  bool filterActive(int slot) => filters.value[slot].isNotEmpty;

  GridField filterField(int slot) => _condition(slot)?.field ?? GridField.name;

  OpFamily filterFamily(int slot) => familyOf(filterField(slot).kind);

  /// The operator's position in its family's menu.
  int filterOp(int slot) {
    final c = _condition(slot);
    if (c == null) return 0;
    return math.max(0, opsFor(c.field.kind).indexOf(c.op));
  }

  bool filterTakesValue(int slot) => _condition(slot)?.op.takesValue ?? true;

  void _setFilter(int slot, String value) {
    filters.value = [
      for (var i = 0; i < maxFilters; i++) i == slot ? value : filters.value[i],
    ];
    _afterViewChange();
  }

  void addFilter() {
    final slot = filters.value.indexOf('');
    if (slot < 0) return;
    _filterValues[slot].clear();
    _setFilter(
      slot,
      const Condition(GridField.name, FilterOp.contains, '').encode(),
    );
  }

  void removeFilter(int slot) {
    _filterValues[slot].clear();
    _setFilter(slot, '');
  }

  void setFilterField(int slot, String? name) {
    final f = GridField.values.asNameMap()[name] ?? GridField.name;
    _filterValues[slot].clear();
    _setFilter(slot, Condition(f, opsFor(f.kind).first, '').encode());
  }

  void setFilterOp(int slot, String? name) {
    final c = _condition(slot);
    final op = FilterOp.values.asNameMap()[name];
    if (c == null || op == null) return;
    _setFilter(slot, Condition(c.field, op, c.value).encode());
  }

  void setFilterValue(int slot, String value) {
    final c = _condition(slot);
    if (c == null) return;
    _setFilter(slot, Condition(c.field, c.op, value).encode());
  }

  void setMatchAny(String? value) {
    matchAny.value = value == 'or';
    _afterViewChange();
  }

  bool anyMode() => matchAny.value;

  String filterLabel() {
    final n = filters.value.where((f) => f.isNotEmpty).length;
    return n == 0 ? 'Filter' : 'Filtered by $n ${n == 1 ? 'field' : 'fields'}';
  }

  bool isFiltered() => filters.value.any((f) => f.isNotEmpty);

  // ── Toolbar: sorts ───────────────────────────────────────────────────
  bool sortActive(int slot) => sorts.value[slot].isNotEmpty;

  GridField sortField(int slot) =>
      SortLevel.decode(sorts.value[slot])?.field ?? GridField.name;

  bool sortDescending(int slot) =>
      SortLevel.decode(sorts.value[slot])?.descending ?? false;

  void _setSorts(List<String> next) {
    final used = [
      for (final s in next)
        if (s.isNotEmpty) s,
    ];
    sorts.value = [
      for (var i = 0; i < maxSorts; i++) i < used.length ? used[i] : '',
    ];
    _afterViewChange();
  }

  void addSort() {
    final used = {
      for (var i = 0; i < maxSorts; i++)
        if (sortActive(i)) sortField(i),
    };
    final field = GridField.values.firstWhere(
      (f) => !used.contains(f),
      orElse: () => GridField.name,
    );
    final slot = sorts.value.indexOf('');
    if (slot < 0) return;
    _setSorts([
      for (var i = 0; i < maxSorts; i++)
        i == slot ? SortLevel(field).encode() : sorts.value[i],
    ]);
  }

  void removeSort(int slot) => _setSorts([
    for (var i = 0; i < maxSorts; i++)
      if (i != slot) sorts.value[i],
  ]);

  void setSortField(int slot, String? name) {
    final f = GridField.values.asNameMap()[name];
    if (f == null) return;
    _setSorts([
      for (var i = 0; i < maxSorts; i++)
        i == slot
            ? SortLevel(f, descending: sortDescending(slot)).encode()
            : sorts.value[i],
    ]);
  }

  void setSortDirection(int slot, String? direction) => _setSorts([
    for (var i = 0; i < maxSorts; i++)
      i == slot
          ? SortLevel(sortField(slot), descending: direction == 'desc').encode()
          : sorts.value[i],
  ]);

  /// Moves a sort level one place up (the reorder).
  void moveSortUp(int slot) {
    if (slot == 0) return;
    final next = [...sorts.value];
    final t = next[slot - 1];
    next[slot - 1] = next[slot];
    next[slot] = t;
    _setSorts(next);
  }

  String sortLabel() {
    final n = sorts.value.where((s) => s.isNotEmpty).length;
    return n == 0 ? 'Sort' : 'Sorted by $n ${n == 1 ? 'field' : 'fields'}';
  }

  bool isSorted() => sorts.value.any((s) => s.isNotEmpty);

  // ── Toolbar: group, row height, hidden ───────────────────────────────
  void setGroup(String? name) {
    final f = GridField.values.asNameMap()[name];
    batch(() {
      group.value = f != null && f.groupable ? f.name : '';
      collapsed.value = const [];
    });
    _afterViewChange();
  }

  String groupLabel() => switch (GridField.values.asNameMap()[group.value]) {
    final f? => 'Grouped by ${f.label.toLowerCase()}',
    null => 'Group',
  };

  bool isGrouped() => group.value.isNotEmpty;

  /// The group field's place in [groupChoices].
  int groupIndex() => math.max(
    0,
    groupChoices.indexOf(GridField.values.asNameMap()[group.value]),
  );

  bool isRowHeight(RowHeight h) => rowHeight.value == h.name;

  void setRowHeight(String name) {
    rowHeight.value = name;
    _syncUrl();
  }

  String hiddenLabel() {
    final n = hidden.value.length;
    return n == 0 ? 'Hide fields' : '$n hidden ${n == 1 ? 'field' : 'fields'}';
  }

  bool hasHidden() => hidden.value.isNotEmpty;

  void _afterViewChange() {
    scroll.jumpTo(0);
    _syncUrl();
  }

  // ── Search ───────────────────────────────────────────────────────────
  void setSearch(String text) {
    batch(() {
      search.value = text;
      searchPos.value = 0;
    });
    _syncUrl();
    if (_matches().isNotEmpty) _goToMatch();
  }

  void clearSearch() {
    searchBox.clear();
    setSearch('');
  }

  void nextMatch() {
    final n = _matches().length;
    if (n == 0) return;
    searchPos.value = (searchPos.value + 1) % n;
    _goToMatch();
  }

  void previousMatch() {
    final n = _matches().length;
    if (n == 0) return;
    searchPos.value = (searchPos.value - 1 + n) % n;
    _goToMatch();
  }

  void _goToMatch() {
    final m = _matches();
    final (i, f) = m[searchPos.value.clamp(0, m.length - 1)];
    batch(() {
      activeKey.value = anchorKey.value = _display()[i].key;
      activeCol.value = anchorCol.value = f.index;
      editing.value = EditorKind.none.name;
    });
    final top = headerHeight + i * _rowPx;
    final vp = scroll.position.viewportDimension;
    if (top < scroll.offset + headerHeight ||
        top >
            scroll.offset +
                (vp > 0 ? vp : _assumedViewport) -
                3 * headerHeight) {
      scroll.jumpTo(math.max(0, top - 3 * headerHeight));
    }
  }

  String searchCount() {
    if (search.value.trim().isEmpty) return '';
    final n = _matches().length;
    if (n == 0) return 'No results';
    return '${searchPos.value.clamp(0, n - 1) + 1} of $n';
  }

  bool isSearching() => search.value.trim().isNotEmpty;

  // ── Footer ───────────────────────────────────────────────────────────
  String recordCount() {
    final n =
        _display().whereType<RecordEntry>().length +
        _display()
            .whereType<GroupEntry>()
            .where((g) => g.collapsed)
            .fold(0, (a, g) => a + g.count);
    return '$n ${n == 1 ? 'record' : 'records'}';
  }

  /// The footer summary of a column.
  String summary(int column) {
    final f = GridField.values[column];
    final records = [
      for (final e in _display())
        if (e is RecordEntry) e.record,
    ];
    if (records.isEmpty) return '';
    switch (f.kind) {
      case FieldKind.currency:
        return 'Sum ${formatMoney(records.fold<int>(0, (a, r) => a + r.budget))}';
      case FieldKind.percent:
        final avg =
            records.fold<int>(0, (a, r) => a + r.progress) / records.length;
        return 'Avg ${avg.round()}%';
      case FieldKind.rating:
        final avg =
            records.fold<int>(0, (a, r) => a + r.rating) / records.length;
        return 'Avg ${avg.toStringAsFixed(1)}';
      case FieldKind.attachments:
        return 'Sum ${records.fold<int>(0, (a, r) => a + r.files)}';
      case FieldKind.checkbox:
        final n = records.where((r) => r.shipped).length;
        return '${(100 * n / records.length).round()}% checked';
      case FieldKind.select || FieldKind.person || FieldKind.date:
        final filled = records
            .where(
              (r) =>
                  !(_get(r, f) == Status.none ||
                      _get(r, f) == Person.none ||
                      _get(r, f) == null),
            )
            .length;
        return '$filled filled';
      default:
        return '';
    }
  }

  // ── Expanded record (drawer) ─────────────────────────────────────────
  Launch? _drawerRecord() {
    version.value;
    final id = drawer.value;
    if (id == 0) return null;
    for (final r in _records) {
      if (r.id == id) return r;
    }
    return null;
  }

  void expand(String key) {
    final r = _recordOf(key);
    if (r == null) return;
    drawer.value = r.id;
    _syncDrawer();
    details.open();
  }

  /// Space: the active record in the drawer (or toggle a checkbox cell).
  void space() {
    final r = _activeRecord();
    if (r == null) return;
    if (_activeField == GridField.shipped) {
      return _set(r, GridField.shipped, !r.shipped);
    }
    expand('r${r.id}');
  }

  /// The drawer's close button (Esc and the backdrop close it natively);
  /// the focus goes back where it was.
  void closeDrawer() => details.close();

  bool drawerOpen() => details.isOpen;

  void _syncDrawer() {
    final r = _drawerRecord();
    if (r == null) return;
    batch(() {
      drawerName.text = r.name;
      drawerLaunch.text = isoDay(r.launch);
      drawerBudget.text = '${r.budget}';
      drawerProgress.text = '${r.progress}';
      drawerUrl.text = r.url;
      drawerNotes.text = r.notes;
      drawerFiles.text = '${r.files}';
    });
  }

  String drawerTitle() {
    final r = _drawerRecord();
    return r == null ? '' : (r.name.isEmpty ? 'Unnamed record' : r.name);
  }

  bool drawerStatusIs(int i) => _drawerRecord()?.status.index == i;

  bool drawerOwnerIs(int i) => _drawerRecord()?.owner.index == i;

  bool drawerHasTag(int i) => (_drawerRecord()?.tags ?? 0) & (1 << i) != 0;

  bool drawerShipped() => _drawerRecord()?.shipped ?? false;

  int drawerRating() => _drawerRecord()?.rating ?? 0;

  void _drawerSet(GridField f, Object? v) {
    final r = _drawerRecord();
    if (r != null) _set(r, f, v, coalesce: true);
  }

  void drawerSetName(String v) => _drawerSet(GridField.name, v);
  void drawerSetUrl(String v) => _drawerSet(GridField.url, v);
  void drawerSetNotes(String v) => _drawerSet(GridField.notes, v);
  void drawerSetLaunch(String v) =>
      _drawerSet(GridField.launch, parseIsoDay(v));

  void drawerSetBudget(String v) {
    final n = int.tryParse(v.trim());
    if (n != null) _drawerSet(GridField.budget, math.max(0, n));
  }

  void drawerSetProgress(String v) {
    final n = int.tryParse(v.trim());
    if (n != null) _drawerSet(GridField.progress, n.clamp(0, 100));
  }

  void drawerSetFiles(String v) {
    final n = int.tryParse(v.trim());
    if (n != null) _drawerSet(GridField.files, math.max(0, n));
  }

  void drawerSetStatus(int i) => _drawerSet(
    GridField.status,
    drawerStatusIs(i) ? Status.none : Status.values[i],
  );

  void drawerSetOwner(int i) => _drawerSet(
    GridField.owner,
    drawerOwnerIs(i) ? Person.none : Person.values[i],
  );

  void drawerToggleTag(int i) {
    final r = _drawerRecord();
    if (r != null) _drawerSet(GridField.tags, r.tags ^ (1 << i));
  }

  void drawerSetShipped(bool? shipped) {
    final r = _drawerRecord();
    if (r != null) _set(r, GridField.shipped, shipped ?? false);
  }

  void drawerRate(int n) {
    final r = _drawerRecord();
    if (r != null) _set(r, GridField.rating, r.rating == n ? 0 : n);
  }
}

/// The page's grid.
final grid = GridState();
