// Keyed list state: create, append, update every tenth row, swap, select, remove, clear.
import 'package:thor_ui/thor_ui.dart';

class Item {
  const Item(this.id, this.label, {this.selected = false});
  final int id;
  final String label;
  final bool selected;
}

const _a = [
  'pretty',
  'large',
  'big',
  'small',
  'tall',
  'short',
  'long',
  'handsome',
  'plain',
  'quaint',
  'clean',
  'elegant',
  'easy',
  'angry',
  'crazy',
  'helpful',
  'mushy',
  'odd',
  'unsightly',
  'adorable',
  'important',
  'inexpensive',
  'cheap',
  'expensive',
  'fancy',
];
const _c = [
  'red',
  'yellow',
  'blue',
  'green',
  'pink',
  'brown',
  'purple',
  'brown',
  'white',
  'black',
  'orange',
];
const _n = [
  'table',
  'chair',
  'house',
  'bbq',
  'desk',
  'car',
  'pony',
  'cookie',
  'sandwich',
  'burger',
  'pizza',
  'mouse',
  'keyboard',
];

var _seed = 1;

// A small LCG, so every run draws the same rows. The product can exceed 2^53
// (dart2js numbers are doubles), so it is split into 16-bit halves: every
// partial result stays exact.
int _rnd(int max) {
  const m = 2147483648, b = 1103515245;
  final hi = (((_seed >> 16) * b) % m) * 65536 % m;
  final lo = ((_seed & 0xFFFF) * b) % m;
  _seed = (hi + lo + 12345) % m;
  return _seed % max;
}

var _nextId = 1;

List<Item> _build(int count) => [
  for (var i = 0; i < count; i++)
    Item(
      _nextId++,
      '${_a[_rnd(_a.length)]} ${_c[_rnd(_c.length)]} ${_n[_rnd(_n.length)]}',
    ),
];

/// The rows and the operations on them.
class ListState extends ThorState {
  final rows = state<List<Item>>(const []);

  String rowKey(Item r) => 'r${r.id}';
  String rowId(Item r) => '${r.id}';
  String rowLabel(Item r) => r.label;
  bool isSelected(Item r) => r.selected;

  void create() => rows.value = _build(1000);
  void createMany() => rows.value = _build(10000);

  // Only the two rows that change get a new item, so only they re-render.
  void select(String key) {
    final id = int.parse(key.substring(1));
    rows.value = [
      for (final r in rows.value)
        r.selected != (r.id == id)
            ? Item(r.id, r.label, selected: r.id == id)
            : r,
    ];
  }

  void append() => rows.value = [...rows.value, ..._build(1000)];
  void update() {
    final r = rows.value;
    rows.value = [
      for (var i = 0; i < r.length; i++)
        i % 10 == 0
            ? Item(r[i].id, '${r[i].label} !!!', selected: r[i].selected)
            : r[i],
    ];
  }

  void swap() {
    final r = [...rows.value];
    if (r.length <= 998) return;
    final t = r[1];
    r[1] = r[998];
    r[998] = t;
    rows.value = r;
  }

  void removeFirst() {
    if (rows.value.isNotEmpty) rows.value = rows.value.sublist(1);
  }

  void clear() => rows.value = const [];

  void remove(String key) => rows.value = [
    for (final r in rows.value)
      if (rowKey(r) != key) r,
  ];
}

final list = ListState();
