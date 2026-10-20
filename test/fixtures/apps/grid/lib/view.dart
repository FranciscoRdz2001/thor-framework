/// The Grid view's configuration (filters, sorts, grouping, hidden fields,
/// search, row height) and what it does to the records. Pure Dart, shared
/// by the server (the first screen from the URL) and the browser.
library;

import 'data.dart';

/// Filter operators.
enum FilterOp {
  contains('contains'),
  notContains('does not contain'),
  isValue('is'),
  isNot('is not'),
  hasAny('has any of'),
  hasNone('has none of'),
  eq('='),
  neq('≠'),
  gt('>'),
  lt('<'),
  before('is before'),
  after('is after'),
  isChecked('is checked'),
  isUnchecked('is not checked'),
  isEmpty('is empty'),
  isNotEmpty('is not empty');

  const FilterOp(this.label);

  /// Shown text.
  final String label;

  /// Whether it compares against a value.
  bool get takesValue =>
      this != isEmpty &&
      this != isNotEmpty &&
      this != isChecked &&
      this != isUnchecked;
}

/// The operators of a field kind, the default first.
List<FilterOp> opsFor(FieldKind kind) => switch (kind) {
  FieldKind.text || FieldKind.url || FieldKind.longText => const [
    FilterOp.contains,
    FilterOp.notContains,
    FilterOp.isValue,
    FilterOp.isEmpty,
    FilterOp.isNotEmpty,
  ],
  FieldKind.select || FieldKind.person => const [
    FilterOp.isValue,
    FilterOp.isNot,
    FilterOp.isEmpty,
    FilterOp.isNotEmpty,
  ],
  FieldKind.multi => const [
    FilterOp.hasAny,
    FilterOp.hasNone,
    FilterOp.isEmpty,
    FilterOp.isNotEmpty,
  ],
  FieldKind.date => const [
    FilterOp.before,
    FilterOp.after,
    FilterOp.isValue,
    FilterOp.isEmpty,
    FilterOp.isNotEmpty,
  ],
  FieldKind.currency ||
  FieldKind.percent ||
  FieldKind.rating ||
  FieldKind.attachments => const [
    FilterOp.eq,
    FilterOp.neq,
    FilterOp.gt,
    FilterOp.lt,
  ],
  FieldKind.checkbox => const [FilterOp.isChecked, FilterOp.isUnchecked],
};

/// One filter condition.
class Condition {
  const Condition(this.field, this.op, this.value);

  final GridField field;
  final FilterOp op;
  final String value;

  /// `field:op:value` (the URL form).
  String encode() => '${field.name}:${op.name}:$value';

  static Condition? decode(String text) {
    final a = text.indexOf(':');
    final b = a < 0 ? -1 : text.indexOf(':', a + 1);
    if (b < 0) return null;
    final field = _byName(GridField.values, text.substring(0, a));
    final op = _byName(FilterOp.values, text.substring(a + 1, b));
    if (field == null || op == null || !opsFor(field.kind).contains(op)) {
      return null;
    }
    return Condition(field, op, text.substring(b + 1));
  }
}

/// One sort level.
class SortLevel {
  const SortLevel(this.field, {this.descending = false});

  final GridField field;
  final bool descending;

  String encode() => '${field.name}:${descending ? 'desc' : 'asc'}';

  static SortLevel? decode(String text) {
    final parts = text.split(':');
    final field = _byName(GridField.values, parts.first);
    if (field == null) return null;
    return SortLevel(field, descending: parts.length > 1 && parts[1] == 'desc');
  }
}

/// Row heights.
enum RowHeight {
  short('Short', 32),
  medium('Medium', 56),
  tall('Tall', 88),
  extraTall('Extra tall', 128);

  const RowHeight(this.label, this.px);

  final String label;
  final double px;
}

T? _byName<T extends Enum>(List<T> values, String name) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return null;
}

/// Everything the URL carries.
class ViewConfig {
  const ViewConfig({
    this.filters = const [],
    this.any = false,
    this.sorts = const [],
    this.group,
    this.hidden = const {},
    this.search = '',
    this.rowHeight = RowHeight.short,
  });

  final List<Condition> filters;

  /// OR instead of AND.
  final bool any;
  final List<SortLevel> sorts;
  final GridField? group;
  final Set<GridField> hidden;
  final String search;
  final RowHeight rowHeight;

  /// Reads `?f=status:isValue:Beta&f=…&any=1&s=budget:desc&g=status&h=notes,url&q=…&rh=tall`.
  factory ViewConfig.fromQuery(Map<String, List<String>> q) {
    String? one(String k) => q[k]?.isEmpty ?? true ? null : q[k]!.first;
    return ViewConfig(
      filters: [
        for (final f in q['f'] ?? const <String>[]) ?Condition.decode(f),
      ].take(maxFilters).toList(),
      any: one('any') == '1',
      sorts: [
        for (final s in q['s'] ?? const <String>[]) ?SortLevel.decode(s),
      ].take(maxSorts).toList(),
      group: switch (_byName(GridField.values, one('g') ?? '')) {
        final g? when g.groupable => g,
        _ => null,
      },
      hidden: {
        for (final h in (one('h') ?? '').split(','))
          if (_byName(GridField.values, h) case final f?
              when f != GridField.name)
            f,
      },
      search: one('q') ?? '',
      rowHeight: _byName(RowHeight.values, one('rh') ?? '') ?? RowHeight.short,
    );
  }

  /// The query string (empty parameters left out), `?` included.
  String toQuery() {
    final params = <String>[
      for (final f in filters) 'f=${Uri.encodeQueryComponent(f.encode())}',
      if (any) 'any=1',
      for (final s in sorts) 's=${Uri.encodeQueryComponent(s.encode())}',
      if (group != null) 'g=${group!.name}',
      if (hidden.isNotEmpty)
        'h=${[for (final f in GridField.values)
          if (hidden.contains(f)) f.name].join(',')}',
      if (search.isNotEmpty) 'q=${Uri.encodeQueryComponent(search)}',
      if (rowHeight != RowHeight.short) 'rh=${rowHeight.name}',
    ];
    return params.isEmpty ? '' : '?${params.join('&')}';
  }
}

/// Most filter conditions and sort levels (their rows are slots).
const maxFilters = 4;
const maxSorts = 3;

/// The cell as text (search, text filters, summaries).
String cellText(Launch r, GridField f) => switch (f) {
  GridField.name => r.name,
  GridField.status => r.status.label,
  GridField.tags => r.tagList.map((t) => t.label).join(', '),
  GridField.owner => r.owner.label,
  GridField.launch => formatDay(r.launch),
  GridField.budget => formatMoney(r.budget),
  GridField.progress => '${r.progress}%',
  GridField.shipped => r.shipped ? 'Yes' : '',
  GridField.rating => r.rating == 0 ? '' : '★' * r.rating,
  GridField.url => r.url,
  GridField.notes => r.notes,
  GridField.files => r.files == 0 ? '' : '${r.files}',
};

/// The cell as a number (numeric filters and sorts), or null.
num? cellNumber(Launch r, GridField f) => switch (f) {
  GridField.budget => r.budget,
  GridField.progress => r.progress,
  GridField.rating => r.rating,
  GridField.files => r.files,
  GridField.launch => r.launch,
  GridField.shipped => r.shipped ? 1 : 0,
  _ => null,
};

bool _isEmpty(Launch r, GridField f) => switch (f) {
  GridField.status => r.status == Status.none,
  GridField.owner => r.owner == Person.none,
  GridField.tags => r.tags == 0,
  GridField.launch => r.launch == null,
  _ => cellText(r, f).isEmpty,
};

bool _matches(Launch r, Condition c) {
  final f = c.field;
  final v = c.value.trim().toLowerCase();
  if (c.op.takesValue && v.isEmpty) return true; // an unfinished condition
  final text = cellText(r, f).toLowerCase();
  num? number() => num.tryParse(v.replaceAll(RegExp(r'[$,%\s]'), ''));
  return switch (c.op) {
    FilterOp.contains => text.contains(v),
    FilterOp.notContains => !text.contains(v),
    FilterOp.isValue when f.kind == FieldKind.date =>
      r.launch == parseIsoDay(v),
    FilterOp.isValue => text == v,
    FilterOp.isNot => text != v,
    FilterOp.hasAny => r.tagList.any((t) => t.label.toLowerCase() == v),
    FilterOp.hasNone => !r.tagList.any((t) => t.label.toLowerCase() == v),
    FilterOp.eq => cellNumber(r, f) == number(),
    FilterOp.neq => cellNumber(r, f) != number(),
    FilterOp.gt => (cellNumber(r, f) ?? 0) > (number() ?? double.infinity),
    FilterOp.lt =>
      (cellNumber(r, f) ?? 0) < (number() ?? double.negativeInfinity),
    FilterOp.before => r.launch != null && r.launch! < (parseIsoDay(v) ?? 0),
    FilterOp.after =>
      r.launch != null && r.launch! > (parseIsoDay(v) ?? 1 << 30),
    FilterOp.isChecked => r.shipped,
    FilterOp.isUnchecked => !r.shipped,
    FilterOp.isEmpty => _isEmpty(r, f),
    FilterOp.isNotEmpty => !_isEmpty(r, f),
  };
}

int _compare(Launch a, Launch b, GridField f) {
  switch (f) {
    case GridField.status:
      return a.status.index.compareTo(b.status.index);
    case GridField.owner:
      return a.owner.label.compareTo(b.owner.label);
    default:
      final x = cellNumber(a, f), y = cellNumber(b, f);
      if (x != null || y != null) {
        return (x ?? -1e12).compareTo(y ?? -1e12);
      }
      return cellText(
        a,
        f,
      ).toLowerCase().compareTo(cellText(b, f).toLowerCase());
  }
}

/// A row of the grid: a record, or the header of a group.
sealed class Entry {
  const Entry();

  String get key;
}

class RecordEntry extends Entry {
  const RecordEntry(this.record, this.number);

  final Launch record;

  /// 1-based position among the shown records.
  final int number;

  @override
  String get key => 'r${record.id}';
}

class GroupEntry extends Entry {
  const GroupEntry(
    this.value,
    this.label,
    this.count, {
    required this.collapsed,
  });

  /// The grouped value (stable key part).
  final String value;
  final String label;
  final int count;
  final bool collapsed;

  @override
  String get key => 'g$value';
}

/// The group value of a record, and its label.
(String, String) groupOf(Launch r, GridField f) => switch (f) {
  GridField.status => (
    r.status.name,
    r.status == Status.none ? 'No status' : r.status.label,
  ),
  GridField.owner => (
    r.owner.name,
    r.owner == Person.none ? 'Unassigned' : r.owner.label,
  ),
  GridField.shipped => (
    r.shipped ? 'yes' : 'no',
    r.shipped ? 'Shipped' : 'Not shipped',
  ),
  GridField.rating => (
    '${r.rating}',
    r.rating == 0 ? 'No rating' : '★' * r.rating,
  ),
  _ => ('', ''),
};

/// Filters, sorts and groups [records]; [collapsed] group values show
/// only their header.
List<Entry> arrange(
  List<Launch> records,
  ViewConfig view, {
  Set<String> collapsed = const {},
}) {
  final active = view.filters;
  final shown = [
    for (final r in records)
      if (active.isEmpty ||
          (view.any
              ? active.any((c) => _matches(r, c))
              : active.every((c) => _matches(r, c))))
        r,
  ];
  final group = view.group;
  if (view.sorts.isNotEmpty || group != null) {
    shown.sort((a, b) {
      if (group != null) {
        final g = _compare(a, b, group);
        if (g != 0) return g;
      }
      for (final s in view.sorts) {
        final c = _compare(a, b, s.field);
        if (c != 0) return s.descending ? -c : c;
      }
      return a.id.compareTo(b.id);
    });
  }
  if (group == null) {
    return [
      for (var i = 0; i < shown.length; i++) RecordEntry(shown[i], i + 1),
    ];
  }
  final out = <Entry>[];
  var n = 0;
  for (var i = 0; i < shown.length;) {
    final (value, label) = groupOf(shown[i], group);
    var j = i;
    while (j < shown.length && groupOf(shown[j], group).$1 == value) {
      j++;
    }
    final isCollapsed = collapsed.contains(value);
    out.add(GroupEntry(value, label, j - i, collapsed: isCollapsed));
    for (var k = i; k < j; k++) {
      n++;
      if (!isCollapsed) out.add(RecordEntry(shown[k], n));
    }
    i = j;
  }
  return out;
}
