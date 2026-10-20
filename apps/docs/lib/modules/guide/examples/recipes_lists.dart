// ignore_for_file: public_member_api_docs
// (each example is named by its region; a doc comment would sit outside the
// code the site shows)
// The cookbook: the list recipes (docs/guia/es/ejemplos/crud.md, circulos.md
// and celdas.md). Each example sits between `// region: <id>` and
// `// endregion`: the site shows that code and renders the same widget.
import 'package:thor_ui/thor_ui.dart';

// region: recipe-crud
class Person {
  const Person(this.id, this.name, this.surname);

  final int id;
  final String name;
  final String surname;

  factory Person.fromJson(Map<String, Object?> json) => Person(
    json['id']! as int,
    json['name']! as String,
    json['surname']! as String,
  );

  Map<String, Object?> toJson() => {'id': id, 'name': name, 'surname': surname};
}

class PeopleViewModel extends ThorState {
  final people = state(const [
    Person(1, 'Hans', 'Emil'),
    Person(2, 'Max', 'Mustermann'),
  ]);
  final prefix = state('');
  final selected = state(0);
  final name = TextEditingController();
  final surname = TextEditingController();
  var nextId = 3;

  // The people whose surname starts with the filter, once per change.
  late final visible = derived(
    () => [
      for (final p in people.value)
        if (p.surname.toLowerCase().startsWith(prefix.value.toLowerCase())) p,
    ],
  );

  int idOf(Person p) => p.id;
  String label(Person p) => '${p.surname}, ${p.name}';
  bool isSelected(Person p) => p.id == selected.value;
  bool hasSelection() => selected.value != 0;
  List<Person> rows() => visible.value;

  String shownCount() => '${visible.value.length}';
  String totalCount() => '${people.value.length}';

  void setPrefix(String text) => prefix.value = text;

  void select(int id) => batch(() {
    selected.value = id;
    for (final p in people.value) {
      if (p.id == id) {
        name.text = p.name;
        surname.text = p.surname;
      }
    }
  });

  void create() => batch(() {
    people.value = [...people.value, Person(nextId, name.text, surname.text)];
    selected.value = nextId;
    nextId++;
  });

  void update() => people.value = [
    for (final p in people.value)
      if (p.id == selected.value) Person(p.id, name.text, surname.text) else p,
  ];

  void remove() => batch(() {
    people.value = [
      for (final p in people.value)
        if (p.id != selected.value) p,
    ];
    selected.value = 0;
    name.text = '';
    surname.text = '';
  });
}

final peopleState = PeopleViewModel();

class CrudRecipe extends StatelessWidget {
  const CrudRecipe({super.key});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          TextField(
            onChanged: peopleState.setPrefix,
            decoration: const InputDecoration(labelText: 'Filter prefix'),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12,
            children: [
              Expanded(
                child: Container(
                  height: 180,
                  decoration: BoxDecoration(
                    border: Border.all(color: ThemeColor.outline),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SingleChildScrollView(
                    child: Watch.list(
                      peopleState.rows,
                      itemKey: peopleState.idOf,
                      container: (rows) => Semantics(
                        role: SemanticsRole.list,
                        label: 'People',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: rows,
                        ),
                      ),
                      each: (row) => Semantics(
                        role: SemanticsRole.listItem,
                        child: row.watch(
                          peopleState.isSelected,
                          builder: (on) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            color: on ? ThemeColor.primary : null,
                            // web: a text child makes it a native <button>.
                            child: InkWell(
                              onTap: peopleState.select.withArg(row.key),
                              child: row.text(
                                peopleState.label,
                                style: TextStyle(
                                  color: on ? ThemeColor.onPrimary : null,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 8,
                  children: [
                    TextField(
                      controller: peopleState.name,
                      decoration: const InputDecoration(labelText: 'Name'),
                    ),
                    TextField(
                      controller: peopleState.surname,
                      decoration: const InputDecoration(labelText: 'Surname'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Row(
            spacing: 8,
            children: [
              OutlinedButton(
                onPressed: peopleState.create,
                child: const Text('Create'),
              ),
              Watch(
                peopleState.hasSelection,
                builder: (on) => OutlinedButton(
                  onPressed: on ? peopleState.update : null,
                  child: const Text('Update'),
                ),
              ),
              Watch(
                peopleState.hasSelection,
                builder: (on) => OutlinedButton(
                  onPressed: on ? peopleState.remove : null,
                  child: const Text('Delete'),
                ),
              ),
            ],
          ),
          Row(
            spacing: 4,
            children: [
              Watch(peopleState.shownCount),
              const Text('of'),
              Watch(peopleState.totalCount),
            ],
          ),
        ],
      ),
    );
  }
}
// endregion

// region: recipe-circles
class Dot {
  const Dot(this.id, this.x, this.y, this.d);

  final int id;
  final double x;
  final double y;
  final double d;
}

class CirclesViewModel extends ThorState {
  // The history is a list of snapshots (one string each) and a cursor: undo
  // and redo only move the cursor.
  final snapshots = state(const ['']);
  final cursor = state(0);
  final selected = state(0); // the id of the selected circle; 0 is none
  final preview = state(0.0); // the diameter being dragged; 0 is none
  final dialog = DialogController();
  var nextId = 1;

  late final now = derived(() => parseSnapshot(snapshots.value[cursor.value]));

  List<Dot> parseSnapshot(String text) => text.isEmpty
      ? const []
      : [
          for (final part in text.split(';'))
            Dot(
              int.parse(part.split(',')[0]),
              double.parse(part.split(',')[1]),
              double.parse(part.split(',')[2]),
              double.parse(part.split(',')[3]),
            ),
        ];

  String writeSnapshot(List<Dot> list) =>
      [for (final c in list) '${c.id},${c.x},${c.y},${c.d}'].join(';');

  void push(List<Dot> next) => batch(() {
    snapshots.value = [
      ...snapshots.value.sublist(0, cursor.value + 1),
      writeSnapshot(next),
    ];
    cursor.value = cursor.value + 1;
  });

  // The circle under the point whose centre is nearest to it, or 0.
  int hit(double x, double y) {
    var best = 0;
    var bestDistance = 0.0;
    for (final c in now.value) {
      final dx = x - c.x;
      final dy = y - c.y;
      final distance = dx * dx + dy * dy;
      if (distance <= c.d * c.d / 4 && (best == 0 || distance < bestDistance)) {
        best = c.id;
        bestDistance = distance;
      }
    }
    return best;
  }

  // The pointer went down: a circle under it is selected.
  void down(double x, double y) {
    final id = hit(x, y);
    if (id != 0) selected.value = id;
  }

  // A tap ended: on empty canvas it adds a circle there.
  void up(double x, double y) {
    if (hit(x, y) != 0) return;
    final id = nextId++;
    batch(() {
      push([...now.value, Dot(id, x, y, 30)]);
      selected.value = id;
      preview.value = 0;
    });
  }

  // Right click or long press: the dialog for the selected circle.
  // web: `onLongPress` does not say where it happened, so it acts on the
  // circle a click (or a finger's `onTapDown`) selected.
  void adjust() {
    if (selectedDiameter() == 0) return;
    batch(() {
      preview.value = 0;
      dialog.open();
    });
  }

  void setPreview(double d) => preview.value = d;

  void commit(double d) {
    final id = selected.value;
    final list = now.value;
    batch(() {
      preview.value = 0;
      for (final c in list) {
        if (c.id == id && c.d != d) {
          push([
            for (final o in list)
              if (o.id == id) Dot(o.id, o.x, o.y, d) else o,
          ]);
        }
      }
    });
  }

  void undo() {
    if (cursor.value > 0) cursor.value = cursor.value - 1;
  }

  void redo() {
    if (cursor.value < snapshots.value.length - 1) {
      cursor.value = cursor.value + 1;
    }
  }

  bool cannotUndo() => cursor.value == 0;
  bool cannotRedo() => cursor.value >= snapshots.value.length - 1;
  List<Dot> rows() => now.value;

  String count() => '${now.value.length}';

  // The selected circle's diameter, or the one being dragged; 0 if none.
  double selectedDiameter() {
    for (final c in now.value) {
      if (c.id == selected.value) {
        return preview.value > 0 ? preview.value : c.d;
      }
    }
    return 0;
  }

  String diameterText() => '${selectedDiameter().round()} px';

  // Per circle: its box in pixels.
  int idOf(Dot c) => c.id;
  double diameter(Dot c) =>
      c.id == selected.value && preview.value > 0 ? preview.value : c.d;
  double left(Dot c) => c.x - diameter(c) / 2;
  double top(Dot c) => c.y - diameter(c) / 2;
}

final circlesState = CirclesViewModel();

class CirclesRecipe extends StatelessWidget {
  const CirclesRecipe({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        Row(
          spacing: 8,
          children: [
            Watch(
              circlesState.cannotUndo,
              builder: (disabled) => OutlinedButton(
                onPressed: disabled ? null : circlesState.undo,
                child: const Text('Undo'),
              ),
            ),
            Watch(
              circlesState.cannotRedo,
              builder: (disabled) => OutlinedButton(
                onPressed: disabled ? null : circlesState.redo,
                child: const Text('Redo'),
              ),
            ),
            Watch(circlesState.count),
            const Text('circles'),
          ],
        ),
        Watch.list(
          circlesState.rows,
          itemKey: circlesState.idOf,
          // One element for the whole canvas: the tap says where it fell.
          container: (rows) => Gesture(
            onTapDown: circlesState.down,
            onTapUp: circlesState.up,
            onLongPress: circlesState.adjust,
            child: Semantics(
              label: 'Canvas: tap to add a circle or select one',
              child: Styled(
                style: const StyleProps(position: BoxPosition.relative()),
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 420),
                  height: 280,
                  decoration: BoxDecoration(
                    border: Border.all(color: ThemeColor.outline),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Stack(children: rows),
                ),
              ),
            ),
          ),
          each: (row) {
            final x = row.length(circlesState.left);
            final y = row.length(circlesState.top);
            final d = row.length(circlesState.diameter);
            return row.selected(
              circlesState.selected,
              builder: (on) => Styled(
                style: StyleProps(
                  position: BoxPosition.absolute(left: x, top: y),
                  minWidth: d,
                  minHeight: d,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: on ? ThemeColor.primaryContainer : null,
                    border: Border.all(color: ThemeColor.onSurface),
                  ),
                ),
              ),
            );
          },
        ),
        const Text(
          'Tap the canvas to add a circle or select one. Right-click (or long-press) the selected circle to adjust its diameter.',
        ),
        AlertDialog(
          controller: circlesState.dialog,
          title: const Text('Adjust diameter'),
          content: SizedBox(
            width: 260,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  spacing: 6,
                  children: [
                    const Text('Diameter'),
                    Watch(circlesState.diameterText),
                  ],
                ),
                Slider.watch(
                  circlesState.selectedDiameter,
                  min: 5,
                  max: 100,
                  semanticLabel: 'Diameter',
                  onChanged: circlesState.setPreview,
                  onChangeEnd: circlesState.commit,
                ),
              ],
            ),
          ),
          actions: [const DialogClose(child: TextButton(child: Text('Close')))],
        ),
      ],
    );
  }
}
// endregion

// region: recipe-cells
const _columns = 7;
const _rows = 30;
const _colWidth = 76.0;
const _rowHeight = 28.0;
const _headWidth = 40.0;
const _letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';

String cellName(int index) =>
    '${_letters[index % _columns]}${index ~/ _columns + 1}';

bool isDigit(String c) => c.compareTo('0') >= 0 && c.compareTo('9') <= 0;
bool isLetter(String c) {
  final u = c.toUpperCase();
  return u.compareTo('A') >= 0 && u.compareTo('Z') <= 0 && c.length == 1;
}

// A formula that cannot be computed: its text is what the cell shows.
class SheetError implements Exception {
  const SheetError(this.text);

  final String text;
}

// The formulas: numbers, cell references (`A1`), `+ - * /`, parentheses and
// `SUM`, `AVG`, `MIN`, `MAX`, `COUNT` over lists or ranges (`SUM(A1:A5)`).
// A cycle or a bad formula is an error text, not a crash.
class Sheet {
  Sheet(this.raw) : memo = List<double?>.filled(_columns * _rows, null);

  final List<String> raw;
  final List<double?> memo;
  final busy = <int>{};

  double number(int i) {
    final known = memo[i];
    if (known != null) return known;
    final text = raw[i].trim();
    if (text.isEmpty) return 0;
    if (!text.startsWith('=')) {
      final n = double.tryParse(text);
      if (n == null) throw const SheetError('#VALUE');
      return memo[i] = n;
    }
    if (busy.contains(i)) throw const SheetError('#CYCLE');
    busy.add(i);
    try {
      return memo[i] = _Parser(this, text.substring(1)).parse();
    } finally {
      busy.remove(i);
    }
  }

  String show(int i) {
    final text = raw[i].trim();
    if (!text.startsWith('=')) return raw[i];
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
    final v = sum();
    skip();
    if (p < src.length) throw const SheetError('#ERROR');
    return v;
  }

  void skip() {
    while (p < src.length && src[p] == ' ') {
      p++;
    }
  }

  bool eat(String c) {
    skip();
    if (p < src.length && src[p] == c) {
      p++;
      return true;
    }
    return false;
  }

  double sum() {
    var v = product();
    while (true) {
      if (eat('+')) {
        v += product();
      } else if (eat('-')) {
        v -= product();
      } else {
        return v;
      }
    }
  }

  double product() {
    var v = unary();
    while (true) {
      if (eat('*')) {
        v *= unary();
      } else if (eat('/')) {
        final d = unary();
        if (d == 0) throw const SheetError('#DIV/0');
        v /= d;
      } else {
        return v;
      }
    }
  }

  double unary() => eat('-') ? -unary() : atom();

  double atom() {
    if (eat('(')) {
      final v = sum();
      if (!eat(')')) throw const SheetError('#ERROR');
      return v;
    }
    skip();
    final start = p;
    while (p < src.length && (isDigit(src[p]) || src[p] == '.')) {
      p++;
    }
    if (p > start) return double.parse(src.substring(start, p));
    final ref = cellRef();
    if (ref >= 0) return sheet.number(ref);
    while (p < src.length && isLetter(src[p])) {
      p++;
    }
    final fn = src.substring(start, p).toUpperCase();
    if (fn.isEmpty || !eat('(')) throw const SheetError('#ERROR');
    final values = <double>[];
    if (!eat(')')) {
      do {
        argument(values);
      } while (eat(','));
      if (!eat(')')) throw const SheetError('#ERROR');
    }
    return callFn(fn, values);
  }

  // A cell reference at [p] (`B12`) as an index, or -1 (and [p] unchanged).
  int cellRef() {
    skip();
    final start = p;
    if (p < src.length && isLetter(src[p])) {
      final col = _letters.indexOf(src[p].toUpperCase());
      p++;
      final digits = p;
      while (p < src.length && isDigit(src[p])) {
        p++;
      }
      final row = p > digits ? int.parse(src.substring(digits, p)) : 0;
      if (col < _columns &&
          row >= 1 &&
          row <= _rows &&
          !(p < src.length && isLetter(src[p]))) {
        return (row - 1) * _columns + col;
      }
    }
    p = start;
    return -1;
  }

  void argument(List<double> out) {
    final from = cellRef();
    if (from >= 0 && eat(':')) {
      final to = cellRef();
      if (to < 0) throw const SheetError('#ERROR');
      final c0 = from % _columns, c1 = to % _columns;
      final r0 = from ~/ _columns, r1 = to ~/ _columns;
      for (var r = r0 < r1 ? r0 : r1; r <= (r0 < r1 ? r1 : r0); r++) {
        for (var c = c0 < c1 ? c0 : c1; c <= (c0 < c1 ? c1 : c0); c++) {
          final i = r * _columns + c;
          if (sheet.raw[i].trim().isNotEmpty) out.add(sheet.number(i));
        }
      }
    } else {
      if (from >= 0) {
        out.add(sheet.number(from));
      } else {
        out.add(sum());
      }
    }
  }

  double callFn(String fn, List<double> v) {
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

// The cells are the raw texts; the shown values are computed once per change
// and every cell reads its own.
class CellsViewModel extends ThorState {
  final cells = state(const {
    'A1': '1',
    'A2': '2',
    'A3': '3',
    'A4': '=SUM(A1:A3)',
    'B1': '=A1*2',
  });
  final selected = state(0);
  final editing = state(false);
  final editor = TextEditingController();
  final focus = FocusNode();
  // The selection's frame: the keyboard focus of the grid.
  final frame = FocusNode();

  late final shown = derived(() {
    final raw = List<String>.filled(_columns * _rows, '');
    for (final e in cells.value.entries) {
      final i =
          _letters.indexOf(e.key[0]) +
          (int.parse(e.key.substring(1)) - 1) * _columns;
      raw[i] = e.value;
    }
    final sheet = Sheet(raw);
    return [for (var i = 0; i < raw.length; i++) sheet.show(i)];
  });

  String text(int i) => shown.value[i];
  String raw(int i) => cells.value[cellName(i)] ?? '';
  double left() => _headWidth + (selected.value % _columns) * _colWidth;
  double top() => _rowHeight + (selected.value ~/ _columns) * _rowHeight;
  bool isEditing() => editing.value;
  String selectedName() => cellName(selected.value);

  void select(int i) {
    // The click that ends a double tap arrives after the edit began.
    if (editing.value && selected.value == i) return;
    if (editing.value) commit();
    selected.value = i;
  }

  // Arrow keys move the selection; focusing the frame scrolls it into view.
  void move(int by) => batch(() {
    final next = selected.value + by;
    if (next < 0 || next >= _columns * _rows) return;
    selected.value = next;
    frame.requestFocus();
  });

  void goLeft() {
    if (selected.value % _columns != 0) move(-1);
  }

  void goRight() {
    if (selected.value % _columns != _columns - 1) move(1);
  }

  void goUp() => move(-_columns);
  void goDown() => move(_columns);
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
      next.remove(cellName(selected.value));
    } else {
      next[cellName(selected.value)] = editor.text;
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

  // A cycle, a division by zero and a broken formula: each cell shows its
  // error.
  void loadErrors() =>
      cells.value = {'A1': '=B1', 'B1': '=A1', 'C1': '=1/0', 'D1': '=SUM('};

  void reset() => cells.value = {
    'A1': '1',
    'A2': '2',
    'A3': '3',
    'A4': '=SUM(A1:A3)',
    'B1': '=A1*2',
  };
}

final sheetState = CellsViewModel();

// A cell of the grid: a tap selects it, a double tap edits it.
class SheetCell extends StatelessWidget {
  const SheetCell(this.index, {super.key});

  final int index;

  @override
  Widget build(BuildContext context) => Gesture(
    onTap: sheetState.select.withArg(index),
    onDoubleTap: sheetState.edit.withArg(index),
    semanticButton: false,
    child: Container(
      height: _rowHeight,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Watch(sheetState.text.withArg(index)),
    ),
  );
}

class CellsRecipe extends StatelessWidget {
  const CellsRecipe({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Row(
          spacing: 8,
          children: [
            TextButton(
              onPressed: sheetState.loadErrors,
              child: const Text('Trigger errors'),
            ),
            TextButton(onPressed: sheetState.reset, child: const Text('Reset')),
          ],
        ),
        const Text(
          'Double-click a cell to edit it; Enter commits and Esc cancels. Arrow keys move the selection.',
        ),
        Container(
          height: 300,
          decoration: BoxDecoration(
            border: Border.all(color: ThemeColor.outline),
            borderRadius: BorderRadius.circular(12),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
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
                                color: ThemeColor.surfaceContainer,
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
                                color: ThemeColor.surfaceContainer,
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
    );
  }
}

// The one text field that edits the selected cell, over it.
class _Editor extends StatelessWidget {
  const _Editor();

  @override
  Widget build(BuildContext context) => Watch(
    sheetState.isEditing,
    builder: (on) => on
        ? Positioned(
            leftLength: sheetState.left.px,
            topLength: sheetState.top.px,
            child: Styled(
              style: const StyleProps(zIndex: 2),
              child: SizedBox(
                width: _colWidth,
                height: _rowHeight,
                child: CallbackShortcuts(
                  bindings: {
                    const SingleActivator(LogicalKeyboardKey.escape):
                        sheetState.cancel,
                  },
                  child: Focus(
                    onFocusChange: sheetState.blurred,
                    child: TextField(
                      controller: sheetState.editor,
                      focusNode: sheetState.focus,
                      onSubmitted: sheetState.commitText,
                      decoration: const InputDecoration(
                        labelText: 'Cell formula',
                      ),
                    ),
                  ),
                ),
              ),
            ),
          )
        : const SizedBox.shrink(),
  );
}

// A frame around the selected cell, placed with the same bound lengths as
// the editor.
class _Selection extends StatelessWidget {
  const _Selection();

  @override
  Widget build(BuildContext context) => Positioned(
    leftLength: sheetState.left.px,
    topLength: sheetState.top.px,
    child: Styled(
      style: const StyleProps(ignorePointer: true),
      // The keys are the frame's, not the region's: Enter inside the editor (a
      // sibling) is the editor's to commit.
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.arrowLeft):
              sheetState.goLeft,
          const SingleActivator(LogicalKeyboardKey.arrowRight):
              sheetState.goRight,
          const SingleActivator(LogicalKeyboardKey.arrowUp): sheetState.goUp,
          const SingleActivator(LogicalKeyboardKey.arrowDown):
              sheetState.goDown,
          const SingleActivator(LogicalKeyboardKey.f2): sheetState.editSelected,
          const SingleActivator(LogicalKeyboardKey.enter):
              sheetState.editSelected,
        },
        child: Focus(
          focusNode: sheetState.frame,
          child: Container(
            width: _colWidth,
            height: _rowHeight,
            decoration: BoxDecoration(
              border: Border.all(color: ThemeColor.primary, width: 2),
            ),
          ),
        ),
      ),
    ),
  );
}

// endregion
