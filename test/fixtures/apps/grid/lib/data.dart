/// The "Product launches" table: its fields, its records and the seeded
/// generator that builds the same 2,000 records on the server and in the
/// browser (only the edits live in the page's state).
library;

import 'package:thor_ui/html.dart' show i;

/// How a field stores and shows its value.
enum FieldKind {
  text,
  select,
  multi,
  person,
  date,
  currency,
  percent,
  checkbox,
  rating,
  url,
  longText,
  attachments,
}

/// The table's fields, in their default order. The index is the column.
enum GridField {
  name('Launch', FieldKind.text, 220),
  status('Status', FieldKind.select, 140),
  tags('Platforms', FieldKind.multi, 200),
  owner('Owner', FieldKind.person, 170),
  launch('Launch date', FieldKind.date, 130),
  budget('Budget', FieldKind.currency, 120),
  progress('Progress', FieldKind.percent, 150),
  shipped('Shipped', FieldKind.checkbox, 90),
  rating('Confidence', FieldKind.rating, 130),
  url('Page', FieldKind.url, 200),
  notes('Notes', FieldKind.longText, 260),
  files('Files', FieldKind.attachments, 90);

  const GridField(this.label, this.kind, this.width);

  /// Column header.
  final String label;

  /// Value type.
  final FieldKind kind;

  /// Default width (px).
  final double width;

  /// Whether a column can group rows (a finite set of values).
  bool get groupable =>
      kind == FieldKind.select ||
      kind == FieldKind.person ||
      kind == FieldKind.checkbox ||
      kind == FieldKind.rating;

  /// Whether the footer sums it.
  bool get numeric =>
      kind == FieldKind.currency ||
      kind == FieldKind.percent ||
      kind == FieldKind.rating ||
      kind == FieldKind.attachments;
}

/// Single select options (the first is "empty").
enum Status {
  none(''),
  idea('Idea'),
  planned('Planned'),
  building('Building'),
  beta('Beta'),
  launched('Launched'),
  paused('Paused');

  const Status(this.label);

  /// Shown text.
  final String label;
}

/// Multi select options.
enum Tag {
  web('Web'),
  ios('iOS'),
  android('Android'),
  api('API'),
  growth('Growth'),
  infra('Infra'),
  design('Design'),
  ai('AI');

  const Tag(this.label);

  /// Shown text.
  final String label;
}

/// A tag slot of a cell: a tag, or nothing.
enum TagSlot { none, web, ios, android, api, growth, infra, design, ai }

/// Collaborators (the first is "unassigned").
enum Person {
  none(''),
  ana('Ana Torres'),
  bo('Bo Lindqvist'),
  chen('Chen Wei'),
  dara('Dara Okafor'),
  eli('Eli Navarro'),
  farah('Farah Haddad'),
  gus('Gus Moreau'),
  hana('Hana Sato'),
  ivan('Ivan Petrov');

  const Person(this.label);

  /// Full name.
  final String label;

  /// Two-letter avatar.
  String get initials => this == none
      ? ''
      : label.split(' ').map((p) => p[0]).take(2).join().toUpperCase();
}

/// One launch. Mutable: edits change it and bump [rev].
class Launch {
  Launch({
    required this.id,
    required this.name,
    required this.status,
    required this.tags,
    required this.owner,
    required this.launch,
    required this.budget,
    required this.progress,
    required this.shipped,
    required this.rating,
    required this.url,
    required this.notes,
    required this.files,
  });

  final int id;
  String name;
  Status status;

  /// Bit `i` set = [Tag.values][i].
  int tags;
  Person owner;

  /// Days since 1970-01-01, or null.
  int? launch;

  /// Whole dollars.
  int budget;

  /// 0–100.
  int progress;
  bool shipped;

  /// 0–5.
  int rating;
  String url;
  String notes;
  int files;

  /// Bumped on every edit (row views compare it).
  int rev = 0;

  List<Tag> get tagList => [
    for (final t in Tag.values)
      if (tags & (1 << t.index) != 0) t,
  ];
}

// LCG split in 16-bit halves (exact in dart2js, like test/fixtures/apps/list_engine).
class _Random {
  _Random(this._seed);

  int _seed;

  int next(int max) {
    const m = 2147483648, b = 1103515245;
    final hi = (((_seed >> 16) * b) % m) * 65536 % m;
    final lo = ((_seed & 0xFFFF) * b) % m;
    _seed = (hi + lo + 12345) % m;
    return (_seed >> 8) % max;
  }

  T pick<T>(List<T> list) => list[next(list.length)];
}

const _codenames = [
  'Aurora', 'Beacon', 'Cascade', 'Delta', 'Ember', 'Falcon', 'Glacier', //
  'Harbor', 'Indigo', 'Juniper', 'Kestrel', 'Lumen', 'Meridian', 'Nimbus',
  'Orbit', 'Pioneer', 'Quartz', 'Rivet', 'Summit', 'Tidal', 'Umbra',
  'Vertex', 'Willow', 'Zephyr',
];
const _products = [
  'Checkout', 'Onboarding', 'Search', 'Payments', 'Dashboard', 'Inbox', //
  'Analytics', 'Sync', 'Billing', 'Profiles', 'Notifications', 'Editor',
  'Reports', 'Marketplace', 'Chat', 'Scheduler',
];
const _versions = ['', ' v2', ' v3', ' Lite', ' Pro', ' 2.0', ' Beta'];
const _notes = [
  'Waiting on legal review of the new terms.',
  'Blocked by the payments provider migration.',
  'Needs final copy from marketing.',
  'Load test passed at 3x peak traffic.',
  'Design review scheduled for next sprint.',
  'Rollout behind a feature flag, 10% of users.',
  'Customer interviews show strong demand.',
  'Waiting for app store approval.',
  'Docs and changelog drafted.',
  'Pricing still under discussion.',
  '',
  '',
];

/// Days since the epoch of 2025-01-01.
const _firstDay = 20089;

/// The table: [count] records from a fixed seed (the same on every run).
List<Launch> seedLaunches({int count = 2000, int seed = 42}) {
  final r = _Random(seed);
  return [
    for (var i = 0; i < count; i++)
      () {
        final status = Status.values[1 + r.next(Status.values.length - 1)];
        final progress = switch (status) {
          Status.launched => 100,
          Status.idea => r.next(10),
          _ => 10 + r.next(90),
        };
        var tags = 0;
        for (var t = r.next(4); t > 0; t--) {
          tags |= 1 << r.next(Tag.values.length);
        }
        final name =
            '${r.pick(_codenames)} ${r.pick(_products)}${r.pick(_versions)}';
        return Launch(
          id: i + 1,
          name: name,
          status: status,
          tags: tags,
          owner: Person.values[r.next(Person.values.length)],
          launch: r.next(9) == 0 ? null : _firstDay + r.next(900),
          budget: (5 + r.next(496)) * 1000,
          progress: progress,
          shipped: status == Status.launched || r.next(8) == 0,
          rating: r.next(6),
          url:
              'https://launch.example.com/'
              '${name.toLowerCase().replaceAll(RegExp('[^a-z0-9]+'), '-')}',
          notes: r.pick(_notes),
          files: r.next(13),
        );
      }(),
  ];
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// `Mar 4, 2026` for a day number (UTC, no time zone surprises).
String formatDay(int? day) {
  if (day == null) return '';
  final d = DateTime.utc(1970).add(Duration(days: day));
  return '${_months[d.month - 1]} ${d.day}, ${d.year}';
}

/// `2026-03-04` (a date input's value) for a day number.
String isoDay(int? day) {
  if (day == null) return '';
  final d = DateTime.utc(1970).add(Duration(days: day));
  String two(int n) => n < 10 ? '0$n' : '$n';
  return '${d.year}-${two(d.month)}-${two(d.day)}';
}

/// The day number of `2026-03-04`, or null.
int? parseIsoDay(String text) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(text.trim());
  if (m == null) return null;
  final d = DateTime.utc(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
  return d.difference(DateTime.utc(1970)).inDays;
}

/// A day as [formatDay] writes it (`Mar 3, 2026`), or null.
int? parseDay(String text) {
  final m = RegExp(
    r'^([A-Za-z]{3}) (\d{1,2}), (\d{4})$',
  ).firstMatch(text.trim());
  if (m == null) return null;
  final month = _months.indexWhere(
    (x) => x.toLowerCase() == m[1]!.toLowerCase(),
  );
  if (month < 0) return null;
  final d = DateTime.utc(int.parse(m[3]!), month + 1, int.parse(m[2]!));
  return d.difference(DateTime.utc(1970)).inDays;
}

/// A cell for tab-separated text: quoted (quotes doubled) when it holds a
/// tab, a line break or a quote, like spreadsheets write it.
String tsvCell(String text) => text.contains(RegExp('[\t\n\r"]'))
    ? '"${text.replaceAll('"', '""')}"'
    : text;

/// Tab-separated text (from a spreadsheet or [tsvCell]) as rows
/// of cells. Quoted cells may hold tabs and line breaks; a trailing line
/// break adds no row.
List<List<String>> parseTsv(String text) {
  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var quoted = false;
  var i = 0;
  final src = text.replaceAll('\r\n', '\n');
  while (i < src.length) {
    final c = src[i];
    if (quoted) {
      if (c == '"' && i + 1 < src.length && src[i + 1] == '"') {
        cell.write('"');
        i += 2;
        continue;
      }
      if (c == '"') {
        quoted = false;
      } else {
        cell.write(c);
      }
    } else if (c == '"' && cell.isEmpty) {
      quoted = true;
    } else if (c == '\t') {
      row.add('$cell');
      cell.clear();
    } else if (c == '\n' || c == '\r') {
      row.add('$cell');
      cell.clear();
      rows.add(row);
      row = [];
    } else {
      cell.write(c);
    }
    i++;
  }
  if (cell.isNotEmpty || row.isNotEmpty) rows.add([...row, '$cell']);
  return rows;
}

/// `$120,500`.
String formatMoney(num dollars) {
  final whole = dollars.round().abs().toString();
  final out = StringBuffer(dollars < 0 ? r'-$' : r'$');
  for (var i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) out.write(',');
    out.write(whole[i]);
  }
  return '$out';
}
