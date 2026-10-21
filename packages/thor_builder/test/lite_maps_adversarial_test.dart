import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:test/test.dart';
import 'package:thor_lints/lite.dart';

/// Resolves `lib/s.dart` and translates it.
Future<String> _translate(String source, {bool shortNames = false}) async {
  final units = await resolveSources(
    {'app|lib/s.dart': source},
    (resolver) async {
      final lib = await resolver.libraryFor(AssetId.parse('app|lib/s.dart'));
      final result =
          await lib.session.getResolvedLibraryByElement(lib)
              as ResolvedLibraryResult;
      return [for (final u in result.units) LiteUnit('lib/s.dart', u.unit)];
    },
    rootPackage: 'app',
    readAllSourcesFromFilesystem: true,
  );
  return translateLiteStates(units, shortNames: shortNames);
}

final _node = () {
  try {
    return Process.runSync('node', ['--version']).exitCode == 0;
  } on ProcessException {
    return false;
  }
}();

/// Runs [js] with a stub `thor.def` and returns what [script] (JS, with
/// `S` = the members of the first state) prints as JSON.
Map<String, Object?> _run(
  String js,
  String script, {
  String? tz,
  String pre = '',
}) {
  // The runtime parts the state names (`// thor-lite parts: …`), as the
  // page would load them (no DOM here: only the date parts run in node).
  final parts = RegExp(
    r'^// thor-lite parts: (.*)$',
    multiLine: true,
  ).firstMatch(js)?.group(1)!.split(' ');
  final order = ['json', 'datetime', 'duration', 'time_of_day', 'date_utils'];
  final code = [
    for (final p in order)
      if (parts?.contains(p) ?? false)
        File('../thor_engine/lib/lite/parts/$p.js').readAsStringSync(),
  ].join('\n');
  final program =
      '''
const defs = {};
globalThis.thor = { def: (n, f) => { defs[n] = f; } };
$code
$js
// `n` counts the writes that reached the signal (a real one notifies then).
const signal = (v) => ({ x: v, n: 0, get value() { return this.x; }, set value(y) { this.x = y; this.n++; }, peek() { return this.x; } });
const make = (n) => defs[n]({ key: null, state: (_, v) => signal(v), use: (q) => make(q) });
$pre
const S = make(Object.keys(defs)[0]);
const out = {};
$script
console.log(JSON.stringify(out));
''';
  final r = Process.runSync('node', ['-e', program], environment: {'TZ': ?tz});
  if (r.exitCode != 0) fail('node failed:\n${r.stderr}\n$js');
  return jsonDecode(r.stdout as String) as Map<String, Object?>;
}

/// Translates [lib] (functions `t0`…`t<n-1>` returning strings, called by
/// a state) and checks that it prints what Dart on the web prints: the same
/// code compiled with dart2js, run in node — also with the build's short
/// names.
Future<void> _sameAsWeb(String lib, int n, {String imports = ''}) async {
  final source =
      '''
$imports

import 'package:thor_ui/thor_ui.dart';


$lib
class PState extends ThorState {
${[for (var i = 0; i < n; i++) '  String e$i() => t$i();'].join('\n')}
}
''';
  final js = await _translate(source);
  final short = await _translate(source, shortNames: true);
  expect(short.length, lessThanOrEqualTo(js.length));
  if (!_node) return markTestSkipped('node is not installed');
  final script =
      '''
out.all = [${[for (var i = 0; i < n; i++) 'S.e$i()'].join(', ')}];
''';
  final out = _run(js, script);
  expect(_run(short, script), out);
  final dir = Directory.systemTemp.createTempSync('lite_semantics');
  final probe = File('${dir.path}/probe.dart')
    ..writeAsStringSync('''
import 'dart:convert';
$imports
$lib
void main() => print(jsonEncode([${[for (var i = 0; i < n; i++) 't$i()'].join(', ')}]));
''');
  final compiled = Process.runSync(Platform.resolvedExecutable, [
    'compile',
    'js',
    // The workspace's packages (a probe may import package:collection).
    '--packages=${File('../../.dart_tool/package_config.json').absolute.path}',
    '-O1',
    '--no-source-maps',
    '-o',
    '${dir.path}/probe.js',
    probe.path,
  ]);
  if (compiled.exitCode != 0) fail('dart2js failed:\n${compiled.stdout}');
  final web = Process.runSync('node', [
    '-e',
    "globalThis.self = globalThis; require('${dir.path}/probe.js');",
  ]);
  dir.deleteSync(recursive: true);
  if (web.exitCode != 0) fail('the dart2js probe failed:\n${web.stderr}');
  final expected = jsonDecode(web.stdout as String) as List<Object?>;
  final got = out['all']! as List<Object?>;
  for (var i = 0; i < n; i++) {
    expect(got[i], expected[i], reason: 't$i');
  }
}

const _header = '''
import 'dart:async';

import 'package:thor_ui/thor_ui.dart';

''';

void main() {
  cookieTests();
  // Each program runs as Dart on the web (dart2js) and as lite JS: the text
  // must match.
  Future<void> same(String lib, {String imports = ''}) =>
      _sameAsWeb(lib, 1, imports: imports);

  // `MapEntry(:key, :value)` patterns (a Dart 3 idiom over `entries`).
  test('MapEntry(:key, :value) in a for-in over entries', () async {
    await same(r"""
String t0() {
  final m = {'a': 1, 'b': 2};
  var r = '';
  for (final MapEntry(:key, :value) in m.entries) {
    r += '$key=$value;';
  }
  return r;
}
""");
  });

  test('MapEntry(:key, :value) in declarations, switch and if-case', () async {
    await same(r"""
String t0() {
  final m = <String, int>{'a': 1, 'b': 2, 'c': 3};
  final MapEntry(key: k0, value: v0) = m.entries.first;
  final MapEntry(:key, :value) = m.entries.last;
  var r = '$k0$v0 $key$value';
  for (final e in m.entries) {
    switch (e) {
      case MapEntry(key: 'b', :final value):
        r += ' b->$value';
      case MapEntry(:final key, value: > 2):
        r += ' big $key';
      default:
        r += ' other';
    }
    if (e case MapEntry(:final key, :final value) when value.isOdd) {
      r += ' odd$key';
    }
  }
  final names = [for (final MapEntry(:key, :value) in m.entries) '$key$value'];
  return '$r ${names.join(',')}';
}
""");
  });

  test('MapEntry(:key, :value) over a map of lists, nested', () async {
    await same(r"""
Map<String, List<int>> groups() => {'x': [1, 2], 'y': []};
String t0() {
  var r = '';
  for (final MapEntry(:key, :value) in groups().entries) {
    r += '$key${value.length}';
    for (final MapEntry(:key, :value) in {for (final n in value) '$n': n * 2}.entries) {
      r += '[$key:$value]';
    }
  }
  return r;
}
""");
  });

  test('MapEntry(:key, :value) over a sorted list of entries', () async {
    await same(r"""
String t0() {
  final m = {'b': 2, 'a': 1};
  final sorted = m.entries.toList()..sort((x, y) => x.key.compareTo(y.key));
  final MapEntry(key: first, value: one) = sorted.first;
  final MapEntry(:key, :value) = sorted.last;
  var r = '$first$one $key$value';
  if (sorted.last case MapEntry(key: 'b', value: final v) when v > 1) r += ' b$v';
  return r;
}
""");
  });

  test(
    'MapEntry patterns inside records and lists, and a list value',
    () async {
      await same(r"""
String t0() {
  final m = {'a': 1, 'b': 2};
  final list = m.entries.toList();
  final (n, MapEntry(:key, :value)) = (7, list.last);
  var r = '$n$key$value';
  if (list case [MapEntry(key: 'a'), MapEntry(:final value)]) r += ' v$value';
  switch ((list.first, 3)) {
    case (MapEntry(:final key, value: 1), final x):
      r += ' k$key$x';
    default:
  }
  final lists = {'z': [1, 2]}.entries.first;
  final MapEntry(key: zk, value: [z0, ...]) = lists;
  return '$r $zk$z0';
}
""");
    },
  );

  test('MapEntry pattern variables are captured per iteration', () async {
    await same(r"""
String t0() {
  final fs = <String Function()>[];
  for (final MapEntry(:key, :value) in {'a': 1, 'b': 2, 'c': 3}.entries) {
    fs.add(() => '$key$value');
  }
  final gs = [
    for (final MapEntry(:key, :value) in {'x': 1, 'y': 2}.entries) () => key * value,
  ];
  return '${fs.map((f) => f()).join(',')} ${gs.map((g) => g()).join(',')}';
}
""");
  });

  test('a lazy field is read inside closures of a state method', () async {
    final js = await _translate(r"""
import 'package:thor_ui/thor_ui.dart';


class PState extends ThorState {
  final n = state(3);
  var evals = 0;
  late final base = _base();
  int _base() {
    evals++;
    return 100;
  }

  late final byKey = {for (final MapEntry(:key, :value) in {'a': 1, 'b': 2}.entries) key: value + base};
  String go() {
    final xs = [1, 2, 3].map((x) => x + base).toList();
    final fs = <int Function()>[() => base, () => base + 1];
    var r = '$xs ${fs.map((f) => f()).toList()} evals=$evals';
    for (final MapEntry(:key, :value) in byKey.entries) {
      r += ' $key$value';
    }
    return r;
  }
}
""");
    if (!_node) return markTestSkipped('node is not installed');
    expect(
      _run(js, 'out.v = S.go();')['v'],
      '[101, 102, 103] [100, 101] evals=1 a101 b102',
    );
  });

  test(
    'a field initializer that reads a lazy field declared after it',
    () async {
      final js = await _translate(r"""
import 'package:thor_ui/thor_ui.dart';


class PState extends ThorState {
  final n = state(0);
  final doubled2 = state(0);
  late final base = 21;
  late final twice = base * 2;
  String go() {
    n.value = twice;
    return '${n.value} $twice';
  }
}
""");
      if (!_node) return markTestSkipped('node is not installed');
      expect(_run(js, 'out.v = S.go();')['v'], '42 42');
    },
  );

  test(
    'a field initializer may call a static method declared after it',
    () async {
      final js = await _translate(r"""
import 'package:thor_ui/thor_ui.dart';


class PState extends ThorState {
  final sum = _sum();
  final n = state(1);
  static int _sum() => 1;
  int go() => sum + n.value;
}
""");
      if (!_node) return markTestSkipped('node is not installed');
      expect(_run(js, 'out.v = S.go();')['v'], 2);
    },
  );

  // `late final x = …` (the initializer form) in a state and a helper.
  group('late final with an initializer', () {
    const state = r"""
import 'package:thor_ui/thor_ui.dart';


class Table {
  Table(this.n);
  final int n;
  var evals = 0;
  late final squares = _squares();
  List<int> _squares() {
    evals++;
    return [for (var i = 1; i <= n; i++) i * i];
  }
  late final label = 'n=$n';
}

class PState extends ThorState {
  final a = state(2);
  var runs = 0;
  final early = 1;
  late final doubled = _compute();
  late final names = ['x', 'y'].map((s) => s.toUpperCase()).toList();
  late final table = Table(3);
  late final Map<String, int> index = {for (final n in names) n: n.length};
  final after = 0;
  int _compute() {
    runs++;
    return a.value * 2 + bonus;
  }

  final bonus = 10;
  String read() =>
      '$doubled $doubled runs=$runs ${names.join()} ${table.squares} ${table.squares.length} evals=${table.evals} ${table.label} ${index['X']}';
  String fresh() => 'runs=$runs evals=${table.evals}';
  void bump() => a.value = 5;
  int early2() => early + doubled;
}
""";

    for (final short in [false, true]) {
      test(
        'it is computed on first read, once, and sees the later fields',
        () async {
          final js = await _translate(state, shortNames: short);
          if (!_node) return markTestSkipped('node is not installed');
          final out = _run(js, r'''
out.before = S.fresh();
out.first = S.read();
S.bump();
out.second = S.read();
out.early = S.early2();
''');
          expect(out['before'], 'runs=0 evals=0');
          expect(out['first'], '14 14 runs=1 XY [1, 4, 9] 3 evals=1 n=3 1');
          // Cached: a later change of `a` does not recompute it (like Dart).
          expect(out['second'], '14 14 runs=1 XY [1, 4, 9] 3 evals=1 n=3 1');
          expect(out['early'], 15);
        },
      );
    }

    test('an initializer that throws tries again at the next read', () async {
      final js = await _translate(r"""
import 'package:thor_ui/thor_ui.dart';


class PState extends ThorState {
  var tries = 0;
  late final v = _pick();
  int _pick() {
    tries++;
    if (tries < 2) throw StateError('not yet');
    return tries * 10;
  }

  String go() {
    var r = '';
    try { r += '${v}'; } catch (e) { r += 'threw '; }
    return '$r${v} $tries ${v}';
  }
}
""");
      if (!_node) return markTestSkipped('node is not installed');
      expect(_run(js, 'out.v = S.go();')['v'], 'threw 20 2 20');
    });

    test(
      'the other late forms stay rejected, with the fix in the hint',
      () async {
        for (final c in [r'late int x = 3;', r'late final int x;']) {
          final src =
              '''
import 'package:thor_ui/thor_ui.dart';


class PState extends ThorState {
  $c
  void h() {}
}
''';
          await expectLater(
            _translate(src),
            throwsA(
              isA<LiteTranslationException>().having(
                (e) => e.errors.map((x) => '${x.message} ${x.hint}').join('\n'),
                'errors',
                contains('late'),
              ),
            ),
            reason: c,
          );
        }
      },
    );
  });

  test('equality of maps is identity, like Dart', () async {
    await same(r"""
String t0() {
  final a = {'a': 1}, b = {'a': 1};
  final m = <String, Object?>{'x': a};
  return '${a == b} ${a == a} ${identical(a, b)} ${m['x'] == a} ${[a].contains(b)} ${[a].contains(a)} ${{a}.contains(b)} ${[a].indexOf(b)}';
}
""");
  });

  test(
    'a const map is read-only (Dart throws), never written in place',
    () async {
      await same(r"""
const base = {'a': 1};
String t0() {
  final m = base;
  var r = '';
  try { m['b'] = 2; r += 'wrote'; } catch (e) { r += 'threw'; }
  return '$r ${base.length} ${base.keys.join(',')}';
}
""");
    },
  );

  test('a const map cannot be cleared or removed from', () async {
    await same(r"""
const base = {'a': 1, 'b': 2};
String t0() {
  final m = base;
  var r = '';
  try { m.remove('a'); r += 'removed'; } catch (e) { r += 'threw'; }
  try { m.clear(); r += 'cleared'; } catch (e) { r += 'threw'; }
  return '$r ${base.length}';
}
""");
  });

  test(
    'PRE-EXISTING: a map changed while iterating throws ConcurrentModificationError',
    () async {
      await same(r"""
String t0() {
  final m = {'a': 1, 'b': 2, 'c': 3};
  var r = '';
  try {
    for (final k in m.keys) { m.remove(k); r += k; }
  } catch (e) { r += ' threw'; }
  return '$r ${m.length}';
}
""");
    },
  );

  test('PRE-EXISTING: a map grown while iterating entries throws', () async {
    await same(r"""
String t0() {
  final m = {'a': 1};
  var r = '';
  try {
    for (final e in m.entries) { m['${e.key}x'] = 1; r += e.key; if (r.length > 20) break; }
  } catch (e) { r += ' threw'; }
  return r;
}
""");
  });

  test('PRE-EXISTING: forEach that mutates the map throws', () async {
    await same(r"""
String t0() {
  final m = {'a': 1, 'b': 2};
  var r = '';
  var n = 0;
  try { m.forEach((k, v) { m['z$k'] = v; r += k; if (++n > 5) throw 'stop'; }); } catch (e) { r += ' threw'; }
  return '$r ${m.length}';
}
""");
  });

  test(
    'remove then re-insert moves the key to the end; remove returns',
    () async {
      await same(r"""
String t0() {
  final m = {'a': 1, 'b': 2, 'c': 3};
  final r1 = m.remove('a');
  m['a'] = 9;
  m['b'] = 8;
  final r2 = m.remove('zz');
  return '$r1 $r2 ${m.keys.toList()} ${m.values.toList()} ${m.entries.map((e) => '${e.key}${e.value}').toList()}';
}
""");
    },
  );

  test('Map<int, V> and Map<Enum, V> keys', () async {
    await same(r"""
enum E { x, y }
String t0() {
  final m = <int, String>{3: 'c', 1: 'a'};
  m[2] = 'b';
  final e = <E, int>{E.y: 1, E.x: 2};
  final n = <String?, int>{null: 1};
  n['k'] = 2;
  return '${m.keys.toList()} ${m[1]} ${m[9]} ${e.keys.map((k) => k.name).toList()} ${e[E.x]} ${n[null]} ${n.length}';
}
""");
  });

  test('a user fromJson over jsonDecode (typed)', () async {
    await same(r"""
class Sub {
  Sub(this.n);
  final int n;
  factory Sub.fromJson(Map<String, dynamic> j) => Sub(j['n'] as int);
  Map<String, dynamic> toJson() => {'n': n};
}
class Item {
  Item(this.name, this.tags, this.sub, this.extra);
  final String name;
  final List<String> tags;
  final Sub sub;
  final Map<String, int>? extra;
  factory Item.fromJson(Map<String, dynamic> json) => Item(
    json['name'] as String,
    List<String>.from(json['tags'] as List),
    Sub.fromJson(json['sub'] as Map<String, dynamic>),
    json['extra'] == null ? null : Map<String, int>.from(json['extra'] as Map),
  );
  Map<String, dynamic> toJson() => {'name': name, 'tags': tags, 'sub': sub.toJson(), 'extra': extra};
}
String t0() {
  const s = '{"items":[{"name":"a","tags":["x","y"],"sub":{"n":1},"extra":{"b":1,"a":2}},{"name":"b","tags":[],"sub":{"n":2},"extra":null}]}';
  final j = jsonDecode(s) as Map<String, dynamic>;
  final items = (j['items'] as List).map((e) => Item.fromJson(e as Map<String, dynamic>)).toList();
  return '${items.map((i) => '${i.name}${i.tags.join()}${i.sub.n}${i.extra == null ? '-' : i.extra!.keys.join('/')}').join(';')} ${jsonEncode(items)}';
}
""", imports: "import 'dart:convert';");
  });

  test('copies of a decoded map keep the text order (the VM order; dart2js '
      'reorders integer-like keys) and are separate', () async {
    final js = await _translate(r"""
import 'dart:convert';
import 'package:thor_ui/thor_ui.dart';


class PState extends ThorState {
  String e0() {
    final j = jsonDecode('{"10":1,"9":2,"a":3}') as Map<String, dynamic>;
    final a = Map<String, dynamic>.from(j);
    final b = Map<String, dynamic>.of(j);
    final d = {...j};
    final e = Map.of(j)..['9'] = 0;
    a['new'] = 1;
    return '${a.keys.join(',')} ${b.keys.join(',')} ${d.keys.join(',')} ${e.values.join(',')} ${j.length} ${identical(a, j)}';
  }
}
""");
    if (!_node) return markTestSkipped('node is not installed');
    final out = _run(js, 'out.v = S.e0();');
    expect(out['v'], '10,9,a,new 10,9,a 10,9,a 1,0,3 3 false');
  });

  test(
    'map keys: empty, unicode, surrogate pairs in decode and encode',
    () async {
      await same(r"""
String t0() {
  final m = <String, int>{'': 1, '\u00e9': 2, '\u{1F600}': 3, 'a\nb': 4, '\u2028': 5};
  final d = jsonDecode('{"\\ud83d\\ude00":1,"\\u00e9":2,"":3,"\u2028":4}') as Map<String, dynamic>;
  return '${m.keys.map((k) => k.length).join(',')} ${m['\u{1F600}']} ${d.keys.map((k) => k.length).join(',')} ${jsonEncode(m)} ${jsonEncode(d)} ${d['\u{1F600}'] as int}';
}
""", imports: "import 'dart:convert';");
    },
  );

  test('big ints, -0 and exponents through jsonDecode', () async {
    await same(r"""
String t0() {
  final l = jsonDecode('[9007199254740993, 1e2, 1.0, 0.1, 12345678901234567890, 1e400]') as List;
  return l.map((x) => (x as num).toString()).join(',');
}
""", imports: "import 'dart:convert';");
  });

  test('group by with putIfAbsent and Map<String, List>', () async {
    await same(r"""
String t0() {
  final l = ['10', '9', '10', 'a', '9'];
  final g = <String, List<String>>{};
  for (final x in l) { g.putIfAbsent(x, () => []).add(x); }
  return '${g.keys.join(',')} ${g.values.map((v) => v.length).join(',')}';
}
""");
  });

  test('null-aware map operations and spread', () async {
    await same(r"""
String t0() {
  Map<String, int>? n;
  final m = {'b': 1, ...?n, 'a': 2};
  final l = n?['x'];
  final len = n?.length;
  n = {'10': 1};
  final s = {...?n, '9': 2};
  return '${m.keys.join(',')} $l $len ${s.keys.join(',')} ${n.length} ${n['10']}';
}
""");
  });

  test('PRE-EXISTING: null-aware keys.toList on a null map', () async {
    await same(r"""
String t0() {
  Map<String, int>? n;
  final k = n?.keys.toList();
  final v = n?.values.toList();
  return '${k == null} ${v == null}';
}
""");
  });

  test('map in a list of maps: nested mutation and order', () async {
    await same(r"""
String t0() {
  final rows = <Map<String, Object?>>[
    {'b': 1, 'a': 2},
    {'10': 'x', '9': 'y'},
  ];
  rows[0]['c'] = 3;
  rows[1].remove('10');
  rows[1]['10'] = 'z';
  final copy = [for (final r in rows) {...r}];
  copy[0]['a'] = 99;
  return '${rows.map((r) => r.keys.join('/')).join(',')} ${jsonEncode(rows)} ${jsonEncode(copy)}';
}
""", imports: "import 'dart:convert';");
  });

  test('map as a key of an equality-sensitive collection', () async {
    await same(r"""
String t0() {
  final k = {'a': 1};
  final m = <Object, int>{k: 1};
  m[{'a': 1}] = 2;
  return '${m.length} ${m[k]}';
}
""");
  });
}

// ---------------------------------------------------------------------------
// Persisted cookies: `state(cookie:)` with maps.
void cookieTests() {
  const src =
      '''
$_header
class PrefsState extends ThorState {
  final m = state(<String, int>{'z': 0}, cookie: 'm');
  String keys() => m.value.keys.join(',');
  String vals() => m.value.values.join(',');
  void put() { m.value = {...m.value, '10': 1, '9': 2, '__proto__': 3}; }
}
''';

  Map<String, Object?> run(String js, String jar, String script) => _run(
    js,
    script,
    pre:
        '''
const writes = [];
let jar = ${jsonEncode(jar)};
globalThis.document = { get cookie() { return jar; }, set cookie(v) { writes.push(v.split(';')[0]); } };
globalThis.location = { protocol: 'http:' };
const effects = [], frames = [];
globalThis.requestAnimationFrame = (f) => frames.push(f);
thor.effect = (fn) => { effects.push(fn); fn(); };
globalThis.queueMicrotask = (f) => f();
''',
  );

  String enc(String s) => Uri.encodeComponent(s);

  test('a cookie written by the old build (plain object JSON) is read in '
      'the text order', () async {
    final js = await _translate(src);
    if (!_node) return markTestSkipped('node is not installed');
    final out = run(
      js,
      'thor-s.m=${enc('{"10":1,"9":2,"a":3}')}',
      r'out.k = S.keys(); out.v = S.vals();',
    );
    expect(out['k'], '10,9,a');
    expect(out['v'], '1,2,3');
  });

  test('a cookie with __proto__ and constructor keys does not pollute, and '
      'the map keeps them', () async {
    final js = await _translate(src);
    if (!_node) return markTestSkipped('node is not installed');
    final out = run(
      js,
      'thor-s.m=${enc('{"__proto__":1,"constructor":2,"toString":3}')}',
      r'out.k = S.keys(); out.p = Object.getOwnPropertyNames(Object.prototype).includes("polluted");',
    );
    expect(out['k'], '__proto__,constructor,toString');
    expect(out['p'], isFalse);
  });

  for (final (name, cookie) in [
    ('an array', '[1,2]'),
    ('a string', '"x"'),
    ('null', 'null'),
    ('broken JSON', '{"a":'),
    ('a wrong value type', '{"a":"str"}'),
    ('a truncated percent escape', '%7B%22a'),
  ]) {
    test('a cookie that is $name keeps the code value', () async {
      final js = await _translate(src);
      if (!_node) return markTestSkipped('node is not installed');
      final out = run(js, 'thor-s.m=$cookie', r'out.k = S.keys();');
      expect(out['k'], 'z');
    });
  }

  test(
    'writing: the cookie keeps the insertion order, same as jsonEncode',
    () async {
      final js = await _translate(src);
      if (!_node) return markTestSkipped('node is not installed');
      final out = run(js, '', r'''
S.put(); for (const f of effects) f();
frames.splice(0).forEach((f) => f()); // the coalesced write
out.writes = writes;
''');
      final w = (out['writes']! as List).cast<String>();
      expect(
        w.map(Uri.decodeComponent),
        contains('thor-s.m={"z":0,"10":1,"9":2,"__proto__":3}'),
      );
    },
  );

  test(
    'a round trip: what is written is read back with the same order',
    () async {
      final js = await _translate(src);
      if (!_node) return markTestSkipped('node is not installed');
      final out = run(js, '', r'''
S.put(); for (const f of effects) f();
frames.splice(0).forEach((f) => f()); // the coalesced write
const last = writes[writes.length - 1];
out.last = last;
out.k1 = S.keys();
''');
      final last = out['last']! as String;
      final out2 = run(
        js,
        last.replaceFirst(RegExp(r'^'), ''),
        r'out.k = S.keys();',
      );
      expect(out2['k'], out['k1']);
    },
  );

  test(
    'a cookie of 2 KB of nested maps is read; more than 2 KB is ignored',
    () async {
      final js = await _translate(src);
      if (!_node) return markTestSkipped('node is not installed');
      final big = jsonEncode({for (var i = 0; i < 400; i++) 'k$i': i});
      final out = run(js, 'thor-s.m=${enc(big)}', r'out.k = S.keys().length;');
      expect(out['k'], 1);
    },
  );
}
