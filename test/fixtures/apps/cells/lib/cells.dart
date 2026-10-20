// The 7GUIs Cells task (100 x 26), the page `test/e2e/checks/cells_check.mjs`
// drives: editing A1 with 100 dependents.
import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

const _columns = 26;
const _rows = 100;
const _colWidth = 64.0;
const _rowHeight = 28.0;
const _headWidth = 44.0;
const _letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
// Where the selection frame and the editor sit (the selected cell).
const _sx = CssVariable<Length>('--sx');
const _sy = CssVariable<Length>('--sy');

String _name(int index) =>
    '${_letters[index % _columns]}${index ~/ _columns + 1}';

bool _isDigit(String c) => c.compareTo('0') >= 0 && c.compareTo('9') <= 0;
bool _isLetter(String c) {
  final u = c.toUpperCase();
  return u.compareTo('A') >= 0 && u.compareTo('Z') <= 0 && c.length == 1;
}

/// A formula that cannot be computed: its text is what the cell shows.
class SheetError implements Exception {
  const SheetError(this.text);

  final String text;
}

/// The sheet's formulas: numbers, cell references (`A1`), `+ - * /`,
/// parentheses and `SUM`, `AVG`, `MIN`, `MAX`, `COUNT` over lists or ranges
/// (`SUM(A1:A5)`). A cycle or a bad formula is an error text, not a crash.
///
/// [raw] is the text of a cell: the sheet reads only the cells a formula
/// refers to, so a cell's text depends on those cells and nothing else.
class Sheet {
  Sheet(this.raw);

  final String Function(int index) raw;
  final _memo = <int, double>{};
  final _busy = <int>{};

  double number(int i) {
    final known = _memo[i];
    if (known != null) return known;
    final text = raw(i).trim();
    if (text.isEmpty) return 0;
    if (!text.startsWith('=')) {
      final n = double.tryParse(text);
      if (n == null) throw const SheetError('#VALUE');
      return _memo[i] = n;
    }
    if (_busy.contains(i)) throw const SheetError('#CYCLE');
    _busy.add(i);
    try {
      return _memo[i] = _Parser(this, text.substring(1)).parse();
    } finally {
      _busy.remove(i);
    }
  }

  String show(int i) {
    final cell = raw(i);
    final text = cell.trim();
    if (!text.startsWith('=')) return cell;
    try {
      final v = number(i);
      return v == v.roundToDouble()
          ? '${v.round()}'
          : '${(v * 1e6).round() / 1e6}';
    } on SheetError catch (e) {
      return e.text;
    }
  }
}

class _Parser {
  _Parser(this.sheet, this.src);

  final Sheet sheet;
  final String src;
  int p = 0;

  double parse() {
    final v = _sum();
    _skip();
    if (p < src.length) throw const SheetError('#ERROR');
    return v;
  }

  void _skip() {
    while (p < src.length && src[p] == ' ') {
      p++;
    }
  }

  bool _eat(String c) {
    _skip();
    if (p < src.length && src[p] == c) {
      p++;
      return true;
    }
    return false;
  }

  double _sum() {
    var v = _product();
    while (true) {
      if (_eat('+')) {
        v += _product();
      } else if (_eat('-')) {
        v -= _product();
      } else {
        return v;
      }
    }
  }

  double _product() {
    var v = _unary();
    while (true) {
      if (_eat('*')) {
        v *= _unary();
      } else if (_eat('/')) {
        final d = _unary();
        if (d == 0) throw const SheetError('#DIV/0');
        v /= d;
      } else {
        return v;
      }
    }
  }

  double _unary() => _eat('-') ? -_unary() : _atom();

  double _atom() {
    if (_eat('(')) {
      final v = _sum();
      if (!_eat(')')) throw const SheetError('#ERROR');
      return v;
    }
    _skip();
    final start = p;
    while (p < src.length && (_isDigit(src[p]) || src[p] == '.')) {
      p++;
    }
    if (p > start) return double.parse(src.substring(start, p));
    final ref = _ref();
    if (ref >= 0) return sheet.number(ref);
    while (p < src.length && _isLetter(src[p])) {
      p++;
    }
    final fn = src.substring(start, p).toUpperCase();
    if (fn.isEmpty || !_eat('(')) throw const SheetError('#ERROR');
    final values = <double>[];
    if (!_eat(')')) {
      do {
        _argument(values);
      } while (_eat(','));
      if (!_eat(')')) throw const SheetError('#ERROR');
    }
    return _call(fn, values);
  }

  /// A cell reference at [p] (`B12`) as an index, or -1 (and [p] unchanged).
  int _ref() {
    _skip();
    final start = p;
    if (p < src.length && _isLetter(src[p])) {
      final col = _letters.indexOf(src[p].toUpperCase());
      p++;
      final digits = p;
      while (p < src.length && _isDigit(src[p])) {
        p++;
      }
      final row = p > digits ? int.parse(src.substring(digits, p)) : 0;
      if (row >= 1 && row <= _rows && !(p < src.length && _isLetter(src[p]))) {
        return (row - 1) * _columns + col;
      }
    }
    p = start;
    return -1;
  }

  void _argument(List<double> out) {
    final from = _ref();
    if (from >= 0 && _eat(':')) {
      final to = _ref();
      if (to < 0) throw const SheetError('#ERROR');
      final c0 = from % _columns, c1 = to % _columns;
      final r0 = from ~/ _columns, r1 = to ~/ _columns;
      for (var r = r0 < r1 ? r0 : r1; r <= (r0 < r1 ? r1 : r0); r++) {
        for (var c = c0 < c1 ? c0 : c1; c <= (c0 < c1 ? c1 : c0); c++) {
          final i = r * _columns + c;
          if (sheet.raw(i).trim().isNotEmpty) out.add(sheet.number(i));
        }
      }
    } else {
      if (from >= 0) {
        out.add(sheet.number(from));
      } else {
        out.add(_sum());
      }
    }
  }

  double _call(String fn, List<double> v) {
    if (fn == 'COUNT') return v.length.toDouble();
    if (v.isEmpty) throw const SheetError('#ERROR');
    var total = 0.0, low = v[0], high = v[0];
    for (final x in v) {
      total += x;
      if (x < low) low = x;
      if (x > high) high = x;
    }
    if (fn == 'SUM') return total;
    if (fn == 'AVG') return total / v.length;
    if (fn == 'MIN') return low;
    if (fn == 'MAX') return high;
    throw const SheetError('#NAME');
  }
}

/// Task 7: a 100 x 26 sheet. The cells are the raw texts; each cell computes
/// its own text from the cells its formula reads. `cells.value[name]` reads
/// one entry, so in the browser a cell's text re-runs only when a cell it
/// reads changes: editing A1 re-runs A1 and its dependents, not the 2 600
/// cells.
class CellsViewModel extends ThorState {
  final cells = state(
    const {'A1': '1', 'A2': '2', 'A3': '3', 'A4': '=SUM(A1:A3)', 'B1': '=A1*2'},
    encode: (m) => m,
    decode: (j) => {
      for (final e in (j! as Map).entries) e.key as String: e.value as String,
    },
  );
  final selected = state(0);
  final editing = state(false);
  final editor = TextEditingController();
  final focus = FocusNode();
  final frame =
      FocusNode(); // the selection's frame: keyboard focus of the grid

  String text(int i) => Sheet(raw).show(i);
  String raw(int i) => cells.value[_name(i)] ?? '';
  double left() => _headWidth + (selected.value % _columns) * _colWidth;
  double top() => _rowHeight + (selected.value ~/ _columns) * _rowHeight;
  bool isEditing() => editing.value;
  String selectedName() => _name(selected.value);

  void select(int i) {
    // The click that ends a double tap arrives after the edit began.
    if (editing.value && selected.value == i) return;
    if (editing.value) commit();
    selected.value = i;
  }

  // Arrow keys move the selection; focusing the frame scrolls it into view.
  void _move(int by) => batch(() {
    final next = selected.value + by;
    if (next < 0 || next >= _columns * _rows) return;
    selected.value = next;
    frame.requestFocus();
  });

  void goLeft() {
    if (selected.value % _columns != 0) _move(-1);
  }

  void goRight() {
    if (selected.value % _columns != _columns - 1) _move(1);
  }

  void goUp() => _move(-_columns);
  void goDown() => _move(_columns);
  void editSelected() => edit(selected.value);

  void edit(int i) => batch(() {
    selected.value = i;
    editor.text = raw(i);
    editing.value = true;
    focus.requestFocus();
  });

  void commit() {
    if (!editing.value) return;
    final next = {...cells.value};
    if (editor.text.trim().isEmpty) {
      next.remove(_name(selected.value));
    } else {
      next[_name(selected.value)] = editor.text;
    }
    batch(() {
      cells.value = next;
      editing.value = false;
    });
  }

  void commitText(String text) => commit();
  void cancel() => editing.value = false;
  void blurred(bool focused) {
    if (!focused) commit();
  }

  /// A hundred cells that depend on A1, and a total that depends on them.
  void loadDependents() => cells.value = {
    'A1': '1',
    for (var r = 1; r <= 100; r++) 'B$r': '=A1+$r',
    'C1': '=SUM(B1:B100)',
  };
}

final sheet = CellsViewModel();

/// A cell of the grid: a tap selects it, a double tap edits it.
class SheetCell extends StatelessWidget implements ThorElementWidget {
  const SheetCell(this.index, {super.key});

  final int index;

  @override
  Widget build(BuildContext context) => Gesture(
    onTap: sheet.select.withArg(index),
    onDoubleTap: sheet.edit.withArg(index),
    semanticButton: false,
    child: Container(
      height: _rowHeight,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Watch(sheet.text.withArg(index)),
    ),
  );
}

class CellsPage extends ThorPage<void> {
  const CellsPage();

  @override
  PageMeta meta(PageState<void> state) => const PageMeta(title: 'Cells');

  @override
  Widget build(BuildContext context, PageState<void> state) => Semantics(
    role: SemanticsRole.main,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        const Semantics(
          headingLevel: 1,
          child: Text('Cells', style: TextStyle(fontSize: 24)),
        ),
        Row(
          spacing: 12,
          children: [
            TextButton(
              onPressed: sheet.loadDependents,
              child: const Text('Load 100 dependents of A1'),
            ),
            const Text('Double-click a cell to edit it; Enter commits.'),
          ],
        ),
        Container(
          height: 480,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF9CA3AF)),
          ),
          child: SingleChildScrollView(
            child: WatchVariables(
              {_sx: sheet.left, _sy: sheet.top},
              child: Styled(
                style: const StyleProps(position: BoxPosition.relative()),
                child: Stack(
                  children: [
                    Table(
                      defaultColumnWidth: const FixedColumnWidth(_colWidth),
                      columnWidths: const {0: FixedColumnWidth(_headWidth)},
                      children: [
                        TableRow(
                          children: [
                            const SizedBox(height: _rowHeight),
                            for (var c = 0; c < _columns; c++)
                              Container(
                                height: _rowHeight,
                                alignment: Alignment.center,
                                color: const Color(0xFFF3F4F6),
                                child: Text(_letters[c]),
                              ),
                          ],
                        ),
                        for (var r = 0; r < _rows; r++)
                          TableRow(
                            children: [
                              Container(
                                height: _rowHeight,
                                alignment: Alignment.center,
                                color: const Color(0xFFF3F4F6),
                                child: Text('${r + 1}'),
                              ),
                              for (var c = 0; c < _columns; c++)
                                SheetCell(r * _columns + c),
                            ],
                          ),
                      ],
                    ),
                    const _Selection(),
                    const _Editor(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

/// The one text field that edits the selected cell, over it.
class _Editor extends StatelessWidget implements ThorElementWidget {
  const _Editor();

  @override
  Widget build(BuildContext context) => Watch(
    sheet.isEditing,
    builder: (on) => on
        ? Styled(
            style: const StyleProps(
              position: BoxPosition.absolute(
                left: Length.variable(_sx),
                top: Length.variable(_sy),
              ),
              zIndex: 2,
            ),
            child: SizedBox(
              width: _colWidth,
              height: _rowHeight,
              child: CallbackShortcuts(
                bindings: {
                  const SingleActivator(LogicalKeyboardKey.escape):
                      sheet.cancel,
                },
                child: Focus(
                  onFocusChange: sheet.blurred,
                  child: TextField(
                    controller: sheet.editor,
                    focusNode: sheet.focus,
                    onSubmitted: sheet.commitText,
                    decoration: const InputDecoration(
                      labelText: 'Cell formula',
                    ),
                  ),
                ),
              ),
            ),
          )
        : const SizedBox.shrink(),
  );
}

/// A frame around the selected cell, placed with the same variables as the
/// editor.
class _Selection extends StatelessWidget implements ThorElementWidget {
  const _Selection();

  @override
  Widget build(BuildContext context) => Styled(
    style: const StyleProps(
      position: BoxPosition.absolute(
        left: Length.variable(_sx),
        top: Length.variable(_sy),
      ),
      ignorePointer: true,
    ),
    // The keys are the frame's, not the region's: Enter inside the editor
    // (a sibling) is the editor's to commit.
    child: CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): sheet.goLeft,
        const SingleActivator(LogicalKeyboardKey.arrowRight): sheet.goRight,
        const SingleActivator(LogicalKeyboardKey.arrowUp): sheet.goUp,
        const SingleActivator(LogicalKeyboardKey.arrowDown): sheet.goDown,
        const SingleActivator(LogicalKeyboardKey.f2): sheet.editSelected,
        const SingleActivator(LogicalKeyboardKey.enter): sheet.editSelected,
      },
      child: Focus(
        focusNode: sheet.frame,
        child: Container(
          width: _colWidth,
          height: _rowHeight,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF2563EB), width: 2),
          ),
        ),
      ),
    ),
  );
}
