import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:test/test.dart';
import 'package:thor_engine/src/lite_bundle.dart';
import 'package:thor_lints/lite.dart';

/// Resolves `lib/s.dart` and translates it.
Future<String> _translate(
  String source, {
  bool shortNames = false,
  bool? checks,
}) async {
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
  return translateLiteStates(units, shortNames: shortNames, checks: checks);
}

Future<List<String>> _errors(String source) async {
  try {
    await _translate(source);
  } on LiteTranslationException catch (e) {
    return [for (final x in e.errors) '$x'];
  }
  fail('expected lite errors');
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
  String head = '',
}) {
  // The runtime parts the state names (`// thor-lite parts: …`), as the
  // page would load them (no DOM here: only the date parts run in node).
  final parts = RegExp(
    r'^// thor-lite parts: (.*)$',
    multiLine: true,
  ).firstMatch(js)?.group(1)!.split(' ');
  final order = [
    'json',
    'local_storage',
    'datetime',
    'duration',
    'time_of_day',
    'date_utils',
  ];
  final code = [
    for (final p in order)
      if (parts?.contains(p) ?? false)
        File('../thor_engine/lib/lite/parts/$p.js').readAsStringSync(),
  ].join('\n');
  final program =
      '''
const defs = {};
$head
globalThis.thor = { def: (n, f) => { defs[n] = f; } };
$code
$js
// `n` counts the writes that reached the signal (a real one notifies then).
const signal = (v) => ({ x: v, n: 0, get value() { return this.x; }, set value(y) { this.x = y; this.n++; }, peek() { return this.x; }, key(k) { return this.x?.get?.(k); } });
const make = (n) => defs[n]({ key: null, state: (n, v, d) => { (globalThis.decoders ||= {})[n] = d; return signal(v); }, use: (q) => make(q) });
$pre
const S = make(Object.keys(defs)[0]);
const out = {};
$script
// A script with awaits leaves its promise in `__done`.
Promise.resolve(globalThis.__done).then(() => console.log(JSON.stringify(out)));
''';
  final r = Process.runSync('node', ['-e', program], environment: {'TZ': ?tz});
  if (r.exitCode != 0) fail('node failed:\n${r.stderr}\n$js');
  return jsonDecode(r.stdout as String) as Map<String, Object?>;
}

/// What a page's window offers the navigation helpers: listeners (`fire`),
/// timers (`flush`).
const _browserStubs = r'''
globalThis.location = { href: 'https://a.test/' };
const on = {}, timers = [];
globalThis.addEventListener = (t, f) => { (on[t] ||= []).push(f); };
globalThis.removeEventListener = (t, f) => { on[t] = (on[t] || []).filter((g) => g !== f); };
globalThis.setTimeout = (f) => { timers.push(f); return timers.length; };
globalThis.clearTimeout = (i) => { timers[i - 1] = () => {}; };
globalThis.fire = (t) => (on[t] || []).slice().forEach((f) => f());
globalThis.flush = () => timers.splice(0).forEach((f) => f());
''';

/// Translates [lib] (functions `t0`…`t<n-1>` returning strings, called by
/// a state) and checks that it prints what Dart on the web prints: the same
/// code compiled with dart2js, run in node — also with the build's short
/// names.
///
/// The Dart VM is the third oracle: the server renders with it, so a value
/// the page first shows (VM) and then updates (lite) must not change for no
/// reason. Every index where the VM and the web differ must be listed in
/// [vmDiffers] with the decision (`web: …` = accepted as web semantics, the
/// lite follows dart2js; a stale entry, where they agree, fails). A
/// difference not listed fails the test.
Future<void> _sameAsWeb(
  String lib,
  int n, {
  String imports = '',
  Map<int, String> vmDiffers = const {},
  bool checked = false,
}) async {
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
  // A `checked` snippet exercises what only `thor dev` checks (`!`, `as`,
  // indexes): the release build (short names) drops those checks.
  if (!checked) expect(_run(short, script), out);
  final (:web, :vm) = _probe(lib, n, imports);
  final got = out['all']! as List<Object?>;
  final unexpected = <String>[];
  for (var i = 0; i < n; i++) {
    expect(got[i], web[i], reason: 't$i (lite vs dart2js)');
    final differs = vm[i] != web[i];
    if (differs && !vmDiffers.containsKey(i)) {
      unexpected.add('t$i\n  VM:  ${vm[i]}\n  web: ${web[i]}');
    } else if (!differs && vmDiffers.containsKey(i)) {
      unexpected.add('t$i is listed in vmDiffers but the VM agrees: drop it');
    }
  }
  expect(
    unexpected,
    isEmpty,
    reason:
        'the VM (server) and the web (lite) differ: fix it or list the index '
        'in vmDiffers with the decision',
  );
}

/// Runs `t0()`…`t<n-1>()` of [lib] with dart2js (-O1, in node) and in the
/// Dart VM; each returns the JSON list they print.
({List<Object?> web, List<Object?> vm}) _probe(
  String lib,
  int n,
  String imports,
) {
  final dir = Directory.systemTemp.createTempSync('lite_semantics');
  final probe = File('${dir.path}/probe.dart')
    ..writeAsStringSync('''
import 'dart:convert';
$imports
$lib
void main() => print(jsonEncode([${[for (var i = 0; i < n; i++) 't$i()'].join(', ')}]));
''');
  // The workspace's packages (a probe may import package:collection).
  final packages = File('../../.dart_tool/package_config.json').absolute.path;
  try {
    final compiled = Process.runSync(Platform.resolvedExecutable, [
      'compile',
      'js',
      '--packages=$packages',
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
    if (web.exitCode != 0) fail('the dart2js probe failed:\n${web.stderr}');
    final vm = Process.runSync(Platform.resolvedExecutable, [
      '--packages=$packages',
      probe.path,
    ]);
    if (vm.exitCode != 0) fail('the VM probe failed:\n${vm.stderr}');
    return (
      web: jsonDecode(web.stdout as String) as List<Object?>,
      vm: jsonDecode(vm.stdout as String) as List<Object?>,
    );
  } finally {
    dir.deleteSync(recursive: true);
  }
}

/// The known VM/web differences (the server renders with the VM, the lite
/// runs as JS) and their decision. Every one is "web": the lite follows
/// dart2js, the semantics of Dart on the web, and does not emulate the VM.
///
/// - Numbers: JS has one number type, so an integral double is an `int`
///   (`'\${4 / 2}'` is `2.0` in the VM and `2` on the web; `3.0` matches an
///   `int` pattern; `jsonEncode(2.0)` is `2`). Decision: accept as web. The
///   alternative (tagging doubles) costs bytes in every arithmetic
///   expression and no framework on JS does it (Kotlin/JS documents the same
///   `Double.toString`: `2.0` prints `2`). Write `toStringAsFixed`,
///   `NumberFormat` or an `int` when the text must be identical.
/// - JSON messages: the text of a `FormatException` from `jsonDecode` is
///   the browser's (`JSON.parse`), not the VM's. Decision: accept as web;
///   do not show that message to a user (its `toString` is engine text in
///   dart2js too).
const _numbers = 'web: an integral double is an int in JS';
const _jsonMessages = 'web: the FormatException text is JSON.parse\'s';

/// - RangeError texts: the VM says `RangeError (length): Invalid value: Not
///   in inclusive range 0..2: 99` for an index that dart2js says `RangeError
///   (index): Index out of range: index should be less than 3: 99`. The
///   type is the same (`on RangeError` catches both); the lite (`thor dev`
///   only) follows dart2js. Decision: accept as web; never show it.
const _rangeMessages = 'web: RangeError text of dart2js';

const _header = '''
import 'dart:async';

import 'package:thor_ui/thor_ui.dart';

''';

void main() {
  test('the VM as the third oracle: doubles print as ints (decision: web), '
      'the rest of the arithmetic agrees', () async {
    const lib = r'''
String t0() => '${4 / 2}';
String t1() => (4 / 2).toString();
String t2() => [1.0, 2.5, 3].join(',');
String t3() => '${10 ~/ 4} ${-7 % 3} ${-7 ~/ 2} ${7.5 % 2} ${(2.5).round()} ${(-2.5).round()}';
String t4() => '${0.1 + 0.2} ${1 / 3} ${100 * 1.1} ${1e15} ${1e-7} ${double.infinity}';
String t5() => '${(4 / 2).toInt()} ${(4 / 2) == 2} ${2.0 is int} ${(3 / 2).floor()} ${4.0.toStringAsFixed(1)}';
String t6() => '${5 / 2 * 2} ${2 * 1.5} ${(10 / 4).ceil()} ${1 / 4 + 0.75}';
''';
    await _sameAsWeb(
      lib,
      7,
      // t0/t1/t2/t4/t5/t6 print an integral double: `2.0` in the VM, `2` on
      // the web. By design the lite engine prints what the web prints.
      vmDiffers: {
        0: _numbers,
        1: _numbers,
        2: _numbers,
        4: _numbers,
        5: _numbers,
        6: _numbers,
      },
    );
  });

  test('the VM oracle fails on a difference that is not listed, and on a stale '
      'entry', () async {
    const lib = "String t0() => '\${4 / 2}';";
    await expectLater(_sameAsWeb(lib, 1), throwsA(isA<TestFailure>()));
    await expectLater(
      _sameAsWeb("String t0() => 'a';", 1, vmDiffers: {0: 'stale'}),
      throwsA(isA<TestFailure>()),
    );
  });

  test(
    'thor dev checks `!`, `as` and indexes like Dart; release drops them',
    () async {
      const lib = r'''
int? maybe(bool b) => b ? 1 : null;
Object? id(Object? o) => o;
String tryIt(void Function() f) {
  try {
    f();
    return 'ok';
  } on StateError catch (e) {
    return 'state: ${e.toString()}';
  } on RangeError catch (e) {
    return 'range: ${e.toString()}';
  } on Error catch (e) {
    return 'error';
  }
}
String t0() {
  final String? s = id(null) as String?;
  return [tryIt(() => s!.length), tryIt(() => id('x')! == 'x')].join('|');
}
String t1() {
  final l = <String?>['a', null];
  final m = <String, String>{'a': 'b'};
  return [
    tryIt(() => l[1]!.length),
    tryIt(() => [for (final x in l) x!].length),
    tryIt(() => [if (l.isNotEmpty) l[1]!].length),
    tryIt(() => m['zz']!.length),
    tryIt(() => m['a']!.length),
    tryIt(() => maybe(false)! + 1),
  ].join('|');
}
String t2() {
  List<int>? n = id(null) as List<int>?;
  final ok = <int>[1];
  List<int>? k = ok;
  return [
    tryIt(() => n!..add(2)),
    tryIt(() => k!..add(2)),
    ok.join(','),
  ].join('|');
}
String t3() {
  final Object o = 'text';
  final Object? z = id(null);
  return [
    tryIt(() => o as int),
    tryIt(() => z as String),
    tryIt(() => z as String?),
    tryIt(() => o as String),
    tryIt(() => o as num),
    tryIt(() => o as List<int>),
    tryIt(() => (id([1]) as List<int>).length),
  ].join('|');
}
String t4() {
  final l = [1, 2, 3];
  final i = id(99) as int;
  return [
    tryIt(() => l[i]),
    tryIt(() => l[-1]),
    tryIt(() => l[i] = 5),
    tryIt(() => l[i] += 1),
    tryIt(() => 'abc'[i]),
    tryIt(() => l[2]),
    tryIt(() => l[1] = 9),
    l.join(','),
  ].join('|');
}
String t5() {
  final l = [1, 2, 3];
  final e = <int>[];
  final one = [7];
  final i = id(9) as int;
  return [
    tryIt(() => l.single),
    tryIt(() => e.single),
    tryIt(() => one.single),
    tryIt(() => l.sublist(1, i)),
    tryIt(() => l.sublist(3, 1)),
    tryIt(() => l.sublist(i)),
    tryIt(() => l.sublist(1, 2)),
    tryIt(() => e.reduce((a, b) => a + b)),
    tryIt(() => l.reduce((a, b) => a + b)),
    tryIt(() => e.removeLast()),
    tryIt(() => l.removeAt(i)),
    tryIt(() => l.removeAt(0)),
  ].join('|');
}
''';
      await _sameAsWeb(
        lib,
        6,
        checked: true,
        vmDiffers: {4: _rangeMessages, 5: _rangeMessages},
      );
      // Release (short names, like the build): the same code without checks.
      final source =
          '''
import 'package:thor_ui/thor_ui.dart';


$lib
class PState extends ThorState {
${[for (var i = 0; i < 6; i++) '  String e$i() => t$i();'].join('\n')}
}
''';
      final dev = await _translate(source);
      for (final helper in [
        r'$nn(',
        r'$cast(',
        r'$at(',
        r'$ix(',
        r'$single(',
      ]) {
        expect(dev, contains(helper), reason: helper);
      }
      final release = await _translate(source, shortNames: true);
      for (final helper in [r'$nn', r'$cast', r'$at', r'$ix', r'$single']) {
        expect(release, isNot(contains(helper)), reason: helper);
      }
      // Only the checks go: the same program, smaller.
      expect(release.length, lessThan(dev.length));
    },
  );

  test('the checks throw Dart\'s errors: `on StateError` and `on RangeError` '
      'catch them, the texts are Dart\'s', () async {
    final js = await _translate('''
$_header
class CState extends ThorState {
  final n = state(0);

  String nul() {
    String? s;
    return s!;
  }

  String cast() {
    final Object o = 'x';
    return '\${o as int}';
  }

  String idx() => '\${[1, 2][5]}';
  String red() => '\${<int>[].reduce((a, b) => a + b)}';
  String caught() {
    try {
      return '\${<int>[].reduce((a, b) => a + b)}';
    } on StateError catch (e) {
      return e.toString();
    }
  }
}
''');
    if (!_node) return markTestSkipped('node is not installed');
    final out = _run(js, '''
const t = (f) => { try { return String(f()); } catch (e) { return [e.constructor.name, e.\$t, String(e)]; } };
out.nul = t(() => S.nul());
out.cast = t(() => S.cast());
out.idx = t(() => S.idx());
out.red = t(() => S.red());
out.caught = S.caught();
''');
    expect(out['nul'], [
      r'$X',
      'TypeError',
      'Null check operator used on a null value',
    ]);
    expect(out['cast'], [
      r'$X',
      'TypeError',
      "type 'String' is not a subtype of type 'int' in type cast",
    ]);
    expect(out['idx'], [
      r'$X',
      'RangeError',
      'RangeError (index): Index out of range: index should be less than 2: 5',
    ]);
    expect(out['red'], [r'$X', 'StateError', 'Bad state: No element']);
    expect(out['caught'], 'Bad state: No element');
  });

  test('nulls print as null: interpolation, toString, join, unset locals '
      'and parameters', () async {
    const lib = r'''
class P {
  P(this.name, [this.nick]);
  final String? name;
  String? nick;
  int? age;
}
String? maybe(bool b) => b ? 'x' : null;
Object? id(Object? o) => o;
String opt({String? a, int? b, String c = 'c'}) => '$a $b $c';
String pos(String? a, [int? b]) => '$a $b';
String t0() {
  String? e;
  int? n;
  double? d;
  bool? f;
  List<int>? l;
  return '$e $n $d $f $l ${e}${n}';
}
String t1() {
  String? s = maybe(false);
  return [
    s.toString(),
    'a${s.toString()}',
    maybe(true).toString(),
    3.toString(),
    (id(null) as int?).toString(),
  ].join('|');
}
String t2() {
  final p = P(null);
  final q = P('n', 'k')..age = 4;
  return [
    [p.name].join(','),
    [p.name, q.name].join(','),
    [p.nick, p.age, q.age].join('-'),
    <String?>[null, 'a', null].join(),
    [1, null, 2].join('+'),
  ].join('|');
}
String t3() {
  final nested = <List<int>>[[1, 5], [], [2]];
  return [
    nested.join(','),
    nested.join(),
    <Object?>[[1, null], 'a', {1, 2}].join(';'),
    [<String>['a'], <String>['b']].join(' '),
    '$nested',
  ].join('|');
}
String t4() => [
  opt(),
  opt(a: 'A'),
  opt(b: 3, c: 'x'),
  pos(null),
  pos('p', 2),
  '${P(null).name} ${P(null).nick} ${P(null).age}',
].join('|');
String t5() {
  String? a;
  String? b = null;
  String? c;
  if (maybe(true) != null) c = 'set';
  final l = [a, b, c];
  return '${l.map((x) => '$x').join(',')} ${a ?? 'dflt'} ${a?.length} ${c?.length}';
}
String t6() {
  String? r;
  for (var i = 0; i < 2; i++) {
    String? cur;
    if (i == 1) cur = 'one';
    r = '${r ?? 'start'}:$cur';
  }
  return r!;
}
String t7() {
  String? n;
  final l = <String?>[
    if (maybe(false) == null) n,
    for (final x in [1, 2]) x.isEven ? null : 'odd',
  ]..add(null);
  final Set<String?> set = {n, 'a'};
  return '$l ${l.join('/')} ${l.map((x) => '$x').join(',')} $set ${set.join('|')}';
}
''';
    await _sameAsWeb(lib, 8);
  });

  test('a counter: signals, texts, finite states and actions', () async {
    final js = await _translate('''
$_header
class CounterState extends ThorState {
  final count = state(0);

  String label() => '\${count.value}';
  bool isZero() => count.value == 0;
  void inc() => count.value++;
  void reset() => count.value = 0;
}

final counter = CounterState();
''');
    expect(js, contains("thor.def('CounterState', (\$) => {"));
    expect(js, contains(r"const count = $.state('count', 0);"));
    expect(js, contains('const label = () => `\${count.value}`;'));
    expect(js, contains('const isZero = () => count.value === 0;'));
    expect(js, contains('count: () => count.value,'));
    expect(js, contains(r'$s: { count },'));
    // The top-level instance is the page's, not the runtime's.
    expect(js, isNot(contains('CounterState()')));
  });

  test(
    "a dart:core exception's toString() is its text, not the object",
    () async {
      final js = await _translate('''
$_header
class ErrState extends ThorState {
  final n = state(0);

  String bad() {
    try {
      throw StateError('no');
    } on StateError catch (e) {
      return e.toString();
    }
  }
}
''');
      if (!_node) return markTestSkipped('node is not installed');
      expect(_run(js, 'out.bad = S.bad();'), {'bad': 'Bad state: no'});
    },
  );

  test('toggle() of a bool and the set operations of a set field', () async {
    final js = await _translate('''
$_header
class PickState extends ThorState {
  final open = state(false);
  final picked = state(<String>{});
  final ids = state(<int>{1});

  void flip() => open.toggle();
  bool isOpen() => open.value;
  void pick(String id) => picked.toggle(id);
  void add(String id) => picked.add(id);
  void drop(String id) => picked.remove(id);
  bool has(String id) => picked.contains(id);
  String label() => '\${picked.length}\${picked.isEmpty}\${picked.isNotEmpty}';
  void reset() => picked.clear();
}
''');
    if (!_node) return markTestSkipped('node is not installed');
    final out = _run(js, r'''
S.flip(); out.open1 = S.isOpen(); S.flip(); out.open2 = S.isOpen();
S.pick('a'); out.a = S.has('a'); S.pick('b'); S.pick('a');
out.b = [S.has('a'), S.has('b')];
S.add('b'); S.add('c'); S.drop('zz'); S.drop('c');
out.label = S.label();
S.reset(); out.after = S.label();
// Every real change replaced the set (n counts the writes that reached the
// signal); a no-op (add of a member, drop of a stranger, clear of an empty
// set) wrote nothing.
out.decoded = [...globalThis.decoders.picked(['x', 'y', 'x'])];
out.decodedType = globalThis.decoders.picked(['x']) instanceof Set;
out.ints = [...globalThis.decoders.ids([2, 1])];
''');
    expect(out['open1'], true);
    expect(out['open2'], false);
    expect(out['a'], true);
    expect(out['b'], [false, true]);
    expect(out['label'], '1falsetrue');
    expect(out['after'], '0truefalse');
    expect(out['decoded'], ['x', 'y']);
    expect(out['decodedType'], true);
    expect(out['ints'], [2, 1]);
  });

  test('a set of objects needs decode; the others say how', () async {
    final errors = await _errors('''
$_header
class PickState extends ThorState {
  final days = state(<DateTime>{});
  void pick(DateTime d) => days.add(d);
}
''');
    expect(errors.join('\n'), contains('is a set of DateTime'));
    expect(errors.join('\n'), contains('encode:'));
  });

  test('a multi-argument value splits like splitArgs (escapes in every '
      'part but the last, typed parts parsed)', () async {
    final js = await _translate('''
$_header
enum Role { admin, guest }

class GridState extends ThorState {
  final log = state('');

  void cell(String a, Role role, String rest) =>
      log.value = '\$a|\${role.name}|\$rest';
  void two(int row, String label) => log.value = '\$row|\$label';
}
''');
    if (!_node) return markTestSkipped('node is not installed');
    final out = _run(js, r'''
S.cell('a%7Eb%25~guest~x~y%7E');
out.cell = S.log();
S.two('7~a~b');
out.two = S.log();
''');
    expect(out['cell'], 'a~b%|guest|x~y%7E');
    expect(out['two'], '7|a~b');
  });

  test('confirm() asks the page\'s dialog and toast() its snack bar', () async {
    final js = await _translate('''
$_header
class AskState extends ThorState {
  final orders = state(<int>[1, 2, 3]);

  Future<void> remove(int id) async {
    if (!await confirm('Delete?', message: 'Sure', confirmLabel: 'Yes')) return;
    orders.value = [
      for (final o in orders.value)
        if (o != id) o,
    ];
    toast('Deleted', kind: ToastKind.success, duration: const Duration(seconds: 2));
  }

  Future<bool> plain() => confirm('Plain');
  void hi() => toast('Hi');
  void bad() => toast('Bad', kind: ToastKind.error);
  String count() => orders.value.join(',');
}
''');
    expect(js, contains(r'$confirm('));
    expect(js, contains(r'$toast('));
    if (!_node) return markTestSkipped('node is not installed');
    final out = _run(js, r'''
const calls = [];
let answer = true;
globalThis.document = {
  thorConfirm: (t, m, o, n) => { calls.push(['confirm', t, m, o, n]); return Promise.resolve(answer); },
  thorToast: (m, k, d) => calls.push(['toast', m, k, d]),
};
globalThis.__done = (async () => {
  answer = false;
  await S.remove(2);
  out.declined = S.count();
  out.callsDeclined = calls.splice(0);
  answer = true;
  await S.remove(2);
  out.accepted = S.count();
  out.callsAccepted = calls.splice(0);
  await S.plain(); S.hi(); S.bad();
  out.defaults = calls.splice(0);
  // The page has no dialog and no snack bar (a bug): a no, never a yes.
  delete document.thorConfirm; delete document.thorToast;
  const errors = [];
  console.error = (m) => errors.push(m);
  out.missing = await S.plain();
  S.hi();
  out.errors = errors;
})();
''');
    expect(out['declined'], '1,2,3');
    expect(out['callsDeclined'], [
      ['confirm', 'Delete?', 'Sure', 'Yes', null],
    ]);
    expect(out['accepted'], '1,3');
    expect(out['callsAccepted'], [
      ['confirm', 'Delete?', 'Sure', 'Yes', null],
      ['toast', 'Deleted', 'success', 2000],
    ]);
    expect(out['defaults'], [
      ['confirm', 'Plain', null, null, null],
      ['toast', 'Hi', 'info', null],
      ['toast', 'Bad', 'error', null],
    ]);
    expect(out['missing'], false);
    expect(out['errors'], hasLength(2));
    expect((out['errors']! as List).first, contains('THOR-S031'));
  });

  test('PageNavigator.go: the next page as a document, only relative or '
      'http(s)', () async {
    final js = await _translate('''
$_header
class NavState extends ThorState {
  final at = state('');

  void open(String to) => PageNavigator.go(to);
  void swap(String to) => PageNavigator.go(to, replace: true);
  String tryGo(String to) {
    try {
      PageNavigator.go(to);
      return 'ok';
    } on ArgumentError catch (e) {
      return e.toString();
    }
  }
}
''');
    expect(js, contains(r'$go(to, false)'));
    expect(js, contains(r'$go(to, true)'));
    if (!_node) return markTestSkipped('node is not installed');
    final out = _run(js, r'''
const log = [];
globalThis.location = { assign: (u) => log.push('assign ' + u), replace: (u) => log.push('replace ' + u) };
S.open('/article/a?x=1:2'); S.swap('https://example.test/'); S.open('');
out.log = log;
out.js = S.tryGo('java\tscript:alert(1)');
out.data = S.tryGo('DATA:text/html,x');
out.rel = S.tryGo('a/b:c');
''');
    expect(out['log'], [
      'assign /article/a?x=1:2',
      'replace https://example.test/',
      'assign ',
      'assign a/b:c',
    ]);
    // The same error Dart throws (THOR-S008), catchable as ArgumentError.
    expect(
      out['js'],
      startsWith('Invalid argument (location): Only a relative'),
    );
    expect(out['js'], contains('THOR-S008'));
    expect(out['data'], contains('THOR-S008'));
    expect(out['rel'], 'ok');
  });

  test('PageNavigator.go(flash:) leaves the cookie a server flash rides '
      'in', () async {
    final js = await _translate('''
$_header
class FlashNavState extends ThorState {
  final at = state('');

  void saved() => PageNavigator.go('/orders', flash: 'Saved', flashKind: ToastKind.success);
  void note(String m) => PageNavigator.go('/n', replace: true, flash: m);
  void plain() => PageNavigator.go('/p');
}
''');
    expect(js, contains(r"$go('/orders', false, false, 'Saved', "));
    expect(js, contains(r"$go('/n', true, false, m, 'info')"));
    if (!_node) return markTestSkipped('node is not installed');
    final out = _run(js, r'''
const log = [];
globalThis.location = { protocol: 'http:', assign: (u) => log.push('assign ' + u), replace: (u) => log.push('replace ' + u) };
const jar = [];
globalThis.document = { set cookie(v) { jar.push(v); }, get cookie() { return ''; } };
S.saved(); S.note('x'.repeat(400)); S.note('  '); S.plain();
out.log = log;
out.jar = jar;
''');
    expect(out['log'], [
      'assign /orders',
      'replace /n',
      'replace /n',
      'assign /p',
    ]);
    expect(out['jar'], [
      'thor-flash=success%3ASaved; Path=/; Max-Age=120; SameSite=Lax',
      'thor-flash=info%3A${'x' * 300}; Path=/; Max-Age=120; SameSite=Lax',
    ]);
  });

  test('PageNavigator.pop / canPop / reload: back, honest and with a '
      'fallback', () async {
    final js = await _translate('''
$_header
class BackState extends ThorState {
  final at = state('');

  void close() => PageNavigator.pop();
  void closeTo(String to) => PageNavigator.pop(fallback: to);
  void again() => PageNavigator.reload();
  bool can() => PageNavigator.canPop();
}
''');
    expect(js, contains(r"$goBack('/')"));
    expect(js, contains(r'$goBack(to)'));
    expect(js, contains(r'$canPop()'));
    expect(js, contains(r'$reload()'));
    if (!_node) return markTestSkipped('node is not installed');
    final out = _run(js, head: _browserStubs, r'''
const log = [];
let nav, st = null, ref = '';
globalThis.navigation = undefined;
globalThis.document = { get referrer() { return ref; } };
globalThis.history = { get state() { return st; }, length: 2, back: () => log.push('back') };
globalThis.location = { origin: 'https://a.test', assign: (u) => log.push('assign ' + u), replace: (u) => log.push('replace ' + u), reload: () => log.push('reload') };
// No Navigation API: an external or empty referrer cannot go back.
out.none = S.can();
S.close(); S.closeTo('/home');
ref = 'https://b.test/x'; out.other = S.can();
ref = 'https://a.test.evil/x'; out.lookalike = S.can();
ref = 'https://a.test/list'; out.same = S.can();
S.close();
ref = ''; st = 'thor'; out.pushed = S.can();
S.closeTo('/home');
// The Navigation API wins when the browser has it.
globalThis.navigation = { canGoBack: false }; ref = 'https://a.test/x'; out.navNo = S.can();
globalThis.navigation = { canGoBack: true }; ref = ''; st = null; out.navYes = S.can();
S.close();
// An unsafe fallback is refused even when it is not needed.
try { S.closeTo('javascript:alert(1)'); out.bad = 'ok'; } catch (e) { out.bad = String(e); }
S.again();
out.log = log;
''');
    expect(out['none'], isFalse);
    expect(out['other'], isFalse);
    expect(out['lookalike'], isFalse);
    expect(out['same'], isTrue);
    expect(out['pushed'], isTrue);
    expect(out['navNo'], isFalse);
    expect(out['navYes'], isTrue);
    expect(out['bad'], contains('THOR-S008'));
    expect(out['log'], [
      'assign /',
      'assign /home',
      'back',
      'back',
      'back',
      'reload',
    ]);
  });

  test('PageNavigator.canPop / pop without the Navigation API: a new tab, a '
      'hash entry, a first entry (adversarial)', () async {
    final js = await _translate('''
$_header
class BackState extends ThorState {
  void close() => PageNavigator.pop(fallback: '/home');
  bool can() => PageNavigator.canPop();
}
''');
    if (!_node) return markTestSkipped('node is not installed');
    final out = _run(js, head: _browserStubs, r'''
const log = [];
let st = null, ref = '', len = 1;
globalThis.navigation = undefined;
globalThis.document = { get referrer() { return ref; } };
globalThis.history = { get state() { return st; }, get length() { return len; }, back: () => log.push('back'), replaceState: (v) => { st = v; } };
globalThis.location = { origin: 'https://a.test', href: 'https://a.test/', assign: (u) => log.push('assign ' + u), replace() {}, reload() {} };
// A new tab from a same-origin link: a referrer, but nothing before it.
ref = 'https://a.test/list'; len = 1;
out.newTab = S.can();
S.close(); flush();
out.newTabLog = log.splice(0);
// A direct open, then a hash entry: back goes to the first hash.
ref = ''; len = 2; out.hashBefore = S.can();
location.href = 'https://a.test/#a'; fire('hashchange'); out.hashAfter = S.can();
// Back to the first entry: its URL is the document's own, nothing to claim.
st = null; location.href = 'https://a.test/'; fire('hashchange'); out.hashFirst = S.can();
ref = 'https://a.test/list';
// canPop was a guess and back did nothing (the first entry of a tab with a
// forward entry): the fallback loads.
S.close(); flush();
out.firstLog = log.splice(0);
// Back that leaves the document does not load the fallback.
S.close(); fire('pagehide'); flush();
out.leftLog = log.splice(0);
// Back within the document (a hash entry) does not load it either.
S.close(); fire('popstate'); flush();
out.hashLog = log.splice(0);
''');
    expect(out['newTab'], isFalse);
    expect(out['newTabLog'], ['assign /home']);
    expect(out['hashBefore'], isFalse);
    expect(out['hashAfter'], isTrue);
    expect(out['hashFirst'], isFalse);
    expect(out['firstLog'], ['back', 'assign /home']);
    expect(out['leftLog'], ['back']);
    expect(out['hashLog'], ['back']);
  });

  test('state(encode:, decode:): thor dev puts the codec on the signal, '
      'release does not', () async {
    const source =
        '''
$_header
enum Panel { tree, list }

class PanelState extends ThorState {
  final panel = state<Panel>(
    Panel.tree,
    encode: (p) => p.name,
    decode: (j) => Panel.values.byName(j! as String),
  );
  final other = state(1);
}
''';
    final dev = await _translate(source, checks: true);
    expect(dev, contains('Object.assign(\$.state('));
    expect(dev, contains('enc: (p) => p.name, dec: (j) =>'));
    expect(dev.split('Object.assign(').length, 2, reason: 'only the codec');
    final release = await _translate(source, checks: false);
    expect(release, isNot(contains('Object.assign(\$.state(')));
    expect(release, isNot(contains('enc:')));
  });

  test('state(cookie:): starts from a valid cookie, writes it on change, '
      'starts the state at load', () async {
    final js = await _translate('''
$_header
class PrefsState extends ThorState {
  final big = state(false, cookie: 'big');
  final tags = state(<String>['a'], cookie: 'tags');
  final lap = state<Duration>(
    Duration.zero,
    encode: (d) => d.inSeconds,
    decode: (j) => Duration(seconds: j! as int),
    cookie: 'lap',
  );

  String label() => '\${big.value} \${tags.value.join(',')} \${lap.value.inSeconds}';
  void toggle() => big.value = !big.value;
}
''');
    expect(js, contains("cookies: ['big', 'tags', 'lap']"));
    expect(js, contains(r"$persist($.state('big', false), 'big', null,"));
    if (!_node) return markTestSkipped('node is not installed');
    // The helper runs its effect through thor.effect: a stub that runs now
    // and again on every write (enough to see the writes).
    final out = _run(
      js,
      r'''
// The stub reruns every field's effect: only this field's writes count.
const big = () => writes.filter((x) => x.startsWith('thor-s.big='));
out.start = S.label();
// A burst of changes: nothing is written inside it, one write per frame.
for (let i = 0; i < 9; i++) { S.toggle(); for (const f of effects) f(); }
out.before = writes.length;
frames.splice(0).forEach((f) => f());
out.writes = big();
// A hide flushes without waiting for the frame; the frame then has nothing.
S.toggle(); for (const f of effects) f();
out.hiddenBefore = big().length;
listeners.pagehide.forEach((f) => f());
out.afterHide = big();
frames.splice(0).forEach((f) => f());
out.final = big().length;
''',
      pre: r'''
const writes = [];
let jar = 'x=1; thor-s.big=true; thor-s.tags=' + encodeURIComponent('["b",3]') + '; thor-s.lap=90';
globalThis.document = { get cookie() { return jar; }, set cookie(v) { writes.push(v.split(';')[0]); } };
globalThis.location = { protocol: 'http:' };
const effects = [], frames = [], listeners = {};
globalThis.requestAnimationFrame = (f) => frames.push(f);
globalThis.addEventListener = (t, f) => (listeners[t] ||= []).push(f);
globalThis.document.addEventListener = () => {};
thor.effect = (fn) => { effects.push(fn); fn(); };
// No bindings here: the value applies at once (in the page, after they
// took the server's markup).
globalThis.queueMicrotask = (f) => f();
''',
    );
    expect(out['start'], 'true a 90'); // tags: ["b",3] is not a List<String>
    // Nine toggles from `true`: the burst ends on `false`, written once.
    expect(out['before'], 0);
    expect(out['writes'], ['thor-s.big=false']);
    expect(out['hiddenBefore'], 1);
    expect(out['afterHide'], ['thor-s.big=false', 'thor-s.big=true']);
    expect(out['final'], 2);
  });

  test('state(cookie:): adversarial writes (hidden, throwing, back to start, '
      'bfcache)', () async {
    final js = await _translate('''
$_header
class PrefsState extends ThorState {
  final big = state(false, cookie: 'big');
  final lap = state<Duration>(
    Duration.zero,
    encode: (d) => d.inSeconds,
    decode: (j) => Duration(seconds: j! as int),
    cookie: 'lap',
  );

  void toggle() => big.value = !big.value;
  void tick(int s) => lap.value = Duration(seconds: s);
}
''');
    if (!_node) return markTestSkipped('node is not installed');
    final out = _run(
      js,
      r'''
const run = () => { for (const f of effects) f(); };
const n = () => writes.length;
// Hidden from the start: no frame will come, so the write is immediate.
vis = 'hidden';
S.toggle(); run();
out.hidden = writes.splice(0).filter((x) => x.startsWith('thor-s.big='));
out.hiddenFrames = frames.length;
vis = 'visible';
// A field written back to its start inside one frame: one write, consistent.
S.toggle(); run(); S.toggle(); run();
out.beforeFrame = n();
writes.length = 0;
frames.splice(0).forEach((f) => f());
out.back = writes.splice(0).filter((x) => x.startsWith('thor-s.big='));
// A failing write does not lose the other field's.
throwOn = 'thor-s.big=';
S.toggle(); S.tick(7); run();
try { frames.splice(0).forEach((f) => f()); } catch (e) { out.threw = String(e); }
throwOn = '';
out.lap = writes.splice(0).filter((x) => x.startsWith('thor-s.lap='));
frames.length = 0;
// bfcache: pagehide flushes, pageshow, and the next changes still coalesce.
S.tick(8); run();
listeners.pagehide.forEach((f) => f());
writes.length = 0; frames.length = 0;
for (let i = 0; i < 5; i++) { S.tick(20 + i); run(); }
out.afterShow = n();
out.afterShowLap = writes.length;
frames.splice(0).forEach((f) => f());
out.afterFrame = writes.filter((x) => x.startsWith('thor-s.lap='));
''',
      pre: r'''
const writes = [];
let vis = 'visible', throwOn = '';
let jar = 'x=1';
globalThis.document = {
  get cookie() { return jar; },
  set cookie(v) { const w = v.split(';')[0]; if (throwOn && w.startsWith(throwOn)) throw new Error('blocked'); writes.push(w); },
  get visibilityState() { return vis; },
  addEventListener() {},
};
globalThis.location = { protocol: 'http:' };
const effects = [], frames = [], listeners = {};
globalThis.requestAnimationFrame = (f) => frames.push(f);
globalThis.addEventListener = (t, f) => (listeners[t] ||= []).push(f);
globalThis.reportError = () => {};
thor.effect = (fn) => { effects.push(fn); fn(); };
globalThis.queueMicrotask = (f) => f();
''',
    );
    expect(out['hidden'], ['thor-s.big=true']);
    expect(out['hiddenFrames'], 0);
    expect(out['beforeFrame'], 0);
    expect(out['back'], ['thor-s.big=true'], reason: 'the value at the frame');
    expect(out['threw'], isNull);
    expect(out['lap'], ['thor-s.lap=7']);
    expect(out['afterShow'], 0);
    expect(out['afterFrame'], ['thor-s.lap=24']);
  });

  test(
    'state(local:): starts from a valid stored value, writes it once per '
    'frame, follows other tabs, starts the state when one is stored',
    () async {
      final js = await _translate('''
$_header
class DraftState extends ThorState {
  final big = state(false, local: 'big');
  final tags = state(<String>['a'], local: 'tags');
  final lap = state<Duration>(
    Duration.zero,
    encode: (d) => d.inSeconds,
    decode: (j) => Duration(seconds: j! as int),
    local: 'lap',
  );

  String label() => '\${big.value} \${tags.value.join(',')} \${lap.value.inSeconds}';
  void toggle() => big.value = !big.value;
  void tick(int s) => lap.value = Duration(seconds: s);
}
''');
      expect(
        js,
        contains(r"eager: $local.has('DraftState', 'big', 'tags', 'lap')"),
      );
      expect(js, contains(r"$local($.state('big', false), 'big', null,"));
      expect(js, contains('// thor-lite parts: duration json local_storage'));
      expect(js, isNot(contains(r'$persist')));
      if (!_node) return markTestSkipped('node is not installed');
      final out = _run(
        js,
        r'''
const run = () => { for (const f of effects) f(); };
out.has = thor.local.has('DraftState', 'big');
out.hasNot = thor.local.has('DraftState', 'nope');
out.start = S.label();
// A burst of changes: nothing is written inside it, one write per frame.
for (let i = 0; i < 9; i++) { S.toggle(); run(); }
out.before = writes.length;
frames.splice(0).forEach((f) => f());
// The stub reruns every field's effect: tags (stored as another type) is
// written then too; only these fields' writes count.
out.writes = writes.splice(0).filter((x) => x.startsWith('thor-s.big='));
// Another tab stores a value: the field takes it and does not write it back.
fire({ key: 'thor-s.lap', newValue: '42', storageArea: store });
out.fromTab = S.label();
run(); frames.splice(0).forEach((f) => f());
out.echo = writes.splice(0).filter((x) => !x.startsWith('thor-s.tags='));
// One of another type, a removal and another storage are ignored.
fire({ key: 'thor-s.big', newValue: '"yes"', storageArea: store });
fire({ key: 'thor-s.big', newValue: null, storageArea: store });
fire({ key: 'thor-s.big', newValue: 'true', storageArea: {} });
out.ignored = S.label();
// A hidden page writes at once (no frames there).
vis = 'hidden';
S.tick(7); run();
out.hidden = writes.splice(0).filter((x) => x.startsWith('thor-s.lap='));
out.hiddenFrames = frames.length;
''',
        head: r'''
const writes = [];
const data = new Map([['thor-s.big', 'true'], ['thor-s.tags', '["b",3]'], ['thor-s.lap', '90']]);
const store = { getItem: (k) => (data.has(k) ? data.get(k) : null), setItem: (k, v) => { writes.push(`${k}=${v}`); data.set(k, v); } };
let vis = 'visible';
const effects = [], frames = [], listeners = {};
globalThis.localStorage = store;
globalThis.document = { get visibilityState() { return vis; }, addEventListener() {} };
globalThis.requestAnimationFrame = (f) => frames.push(f);
globalThis.addEventListener = (t, f) => (listeners[t] ||= []).push(f);
// Another tab's write: the shared storage changes, then the event.
const fire = (e) => {
  if (e.storageArea === store) e.newValue == null ? data.delete(e.key) : data.set(e.key, e.newValue);
  listeners.storage.forEach((f) => f(e));
};
''',
        pre: r'''
thor.effect = (fn) => { effects.push(fn); fn(); };
globalThis.queueMicrotask = (f) => f();
''',
      );
      expect(out['has'], isTrue);
      expect(out['hasNot'], isFalse);
      expect(out['start'], 'true a 90'); // tags: ["b",3] is not a List<String>
      expect(out['before'], 0);
      // Nine toggles from `true` end on `false`: one write, with that value.
      expect(out['writes'], ['thor-s.big=false']);
      expect(out['fromTab'], 'false a 42');
      expect(out['echo'], isEmpty);
      expect(out['ignored'], 'false a 42');
      expect(out['hidden'], ['thor-s.lap=7']);
      expect(out['hiddenFrames'], 0);
    },
  );

  test('state(local:): blocked storage keeps the value in memory, never '
      'throws', () async {
    final js = await _translate('''
$_header
class DraftState extends ThorState {
  final text = state('', local: 'draft');

  String label() => text.value;
  void type(String t) => text.value = t;
}
''');
    if (!_node) return markTestSkipped('node is not installed');
    for (final blocked in [
      // The getter throws (SecurityError: storage blocked for the site).
      r"Object.defineProperty(globalThis, 'localStorage', { get() { throw new Error('SecurityError'); } });",
      // Every call throws (a sandboxed frame, a full quota).
      r"globalThis.localStorage = { getItem() { throw new Error('SecurityError'); }, setItem() { throw new Error('QuotaExceededError'); } };",
    ]) {
      final out = _run(
        js,
        r'''
out.has = thor.local.has('DraftState', 'draft');
out.start = S.label();
S.type('hola'); for (const f of effects) f();
frames.splice(0).forEach((f) => f());
out.after = S.label();
out.errors = errors;
''',
        head:
            '''
$blocked
const effects = [], frames = [], errors = [];
globalThis.document = { visibilityState: 'visible', addEventListener() {} };
globalThis.requestAnimationFrame = (f) => frames.push(f);
globalThis.reportError = (e) => errors.push(String(e));
''',
        pre: r'''
thor.effect = (fn) => { effects.push(fn); fn(); };
globalThis.queueMicrotask = (f) => f();
''',
      );
      expect(out['has'], isFalse, reason: blocked);
      expect(out['start'], '');
      expect(out['after'], 'hola');
      expect(out['errors'], isEmpty);
    }
  });

  test('state(local:): a state that ends and starts again leaves one '
      'listener of the other tabs, its own', () async {
    final js = await _translate('''
$_header
class DraftState extends ThorState {
  final text = state('', local: 'draft');

  String label() => text.value;
}
''');
    if (!_node) return markTestSkipped('node is not installed');
    final out = _run(
      js,
      r'''
// The state ends (the part `lifecycle` stops its effects) and starts
// again, three times.
const runs = [S];
for (let i = 0; i < 3; i++) {
  effects.forEach((e) => (e.dead = 1));
  runs.push(make('DraftState'));
}
fire({ key: 'thor-s.draft', newValue: '"tab"', storageArea: store });
out.labels = runs.map((s) => s.label());
// The ended ones were dropped: one listener reads the value, not four.
out.reads = reads;
''',
      head: r'''
const data = new Map();
let reads = 0;
const store = { getItem: (k) => (data.has(k) ? data.get(k) : null), setItem: (k, v) => data.set(k, v) };
const listeners = {};
globalThis.localStorage = store;
globalThis.document = { visibilityState: 'visible', addEventListener() {} };
globalThis.requestAnimationFrame = () => {};
globalThis.addEventListener = (t, f) => (listeners[t] ||= []).push(f);
const fire = (e) => {
  data.set(e.key, e.newValue);
  listeners.storage.forEach((f) => f(e));
};
''',
      pre: r'''
const effects = [];
thor.effect = (fn) => { const e = {}; effects.push(e); fn(); return e; };
const parse = thor.parse;
thor.parse = (s) => { reads++; return parse(s); };
globalThis.queueMicrotask = (f) => f();
''',
    );
    expect(out['labels'], ['', '', '', 'tab']);
    expect(out['reads'], 1);
  });

  test('state(localScope:): one local field per value of another field, '
      'started when any is stored', () async {
    final js = await _translate('''
$_header
class CartState extends ThorState {
  final store = state('shop-a');
  final items = state(<String>[], local: 'cart', localScope: store);

  String label() => items.value.join(',');
  void add(String s) => items.value = [...items.value, s];
}

class OtherCartState extends ThorState {
  final store = state('shop-b');
  final items = state(<String>[], local: 'cart', localScope: store);

  String label() => items.value.join(',');
}

class NoScopeState extends ThorState {
  final store = state('');
  final items = state(<String>[], local: 'cart', localScope: store);

  String label() => items.value.join(',');
  void add(String s) => items.value = [...items.value, s];
}
''');
    expect(js, contains(r"eager: $local.has('CartState', 'cart:*')"));
    expect(js, contains(r"$local($.state('items', []), 'cart', null, "));
    expect(js, contains(', store)'));
    if (!_node) return markTestSkipped('node is not installed');
    final out = _run(
      js,
      r'''
const run = () => { for (const f of effects) f(); };
const b = make('OtherCartState'), n = make('NoScopeState');
out.has = thor.local.has('CartState', 'cart:*');
out.hasNot = thor.local.has('CartState', 'other:*');
out.a = S.label();
out.b = b.label();
out.empty = n.label();
S.add('w'); n.add('lost'); run();
frames.splice(0).forEach((f) => f());
out.writes = writes.splice(0);
// Another tab stores the cart of shop-b: only that field takes it.
fire({ key: 'thor-s.cart:shop-b', newValue: '["q"]', storageArea: store });
out.afterTab = [S.label(), b.label()];
''',
      head: r'''
const writes = [];
const data = new Map([['thor-s.cart:shop-a', '["x"]'], ['thor-s.cart:shop-b', '["y","z"]'], ['thor-s.other', '1']]);
const store = {
  get length() { return data.size; },
  key: (i) => [...data.keys()][i],
  getItem: (k) => (data.has(k) ? data.get(k) : null),
  setItem: (k, v) => { writes.push(`${k}=${v}`); data.set(k, v); },
};
const effects = [], frames = [], listeners = {};
globalThis.localStorage = store;
globalThis.document = { visibilityState: 'visible', addEventListener() {} };
globalThis.requestAnimationFrame = (f) => frames.push(f);
globalThis.addEventListener = (t, f) => (listeners[t] ||= []).push(f);
const fire = (e) => {
  data.set(e.key, e.newValue);
  listeners.storage.forEach((f) => f(e));
};
''',
      pre: r'''
thor.effect = (fn) => { effects.push(fn); fn(); };
globalThis.queueMicrotask = (f) => f();
''',
    );
    expect(out['has'], isTrue);
    expect(out['hasNot'], isFalse);
    expect(out['a'], 'x');
    expect(out['b'], 'y,z');
    expect(out['empty'], '', reason: 'an empty scope keeps nothing stored');
    // The stub reruns every field's effect: only the cart of shop-a is a
    // real change; an empty scope never reaches the storage.
    expect(
      (out['writes']! as List).where((w) => (w as String).contains('cart')),
      ['thor-s.cart:shop-a=["x","w"]'],
    );
    expect(out['afterTab'], ['x,w', 'q']);
  });

  test('state(localScope:) needs local: and a field made before it', () async {
    final errors = await _errors('''
$_header
class BadState extends ThorState {
  final a = state('x');
  final b = state(false, localScope: a);
  final c = state(false, local: 'c', localScope: later);
  final later = state('y');
  final d = state(false, local: 'd', localScope: 'literal');
}
''');
    final text = errors.join('\n');
    expect(text, contains('state(localScope:) needs local:'));
    expect(text, contains('takes a `state(...)` field of the same class'));
    expect(errors.where((e) => e.contains('THOR-S009')).length, 3);
  });

  test('state(local:) needs a literal name, a type lite can check and only '
      'one place', () async {
    final errors = await _errors('''
$_header
class BadState extends ThorState {
  static const name = 'side';
  final a = state(false, local: name);
  final b = state(false, local: 'a b');
  final c = state(Duration.zero, local: 'lap');
  final d = state(false, cookie: 'x', local: 'y');
}
''');
    final text = errors.join('\n');
    expect(text, contains('state(local:) takes a string literal'));
    expect(errors.where((e) => e.contains('THOR-S009')).length, 3);
    expect(text, contains('A persisted Duration needs encode/decode'));
    expect(text, contains('not both'));
  });

  test(
    'state(cookie:) needs a literal name and a type lite can check',
    () async {
      final errors = await _errors('''
$_header
class BadState extends ThorState {
  static const name = 'side';
  final a = state(false, cookie: name);
  final b = state(false, cookie: 'a b');
  final c = state(Duration.zero, cookie: 'lap');
}
''');
      expect(errors.join('\n'), contains('THOR-S009'));
      expect(errors.where((e) => e.contains('THOR-S009')).length, 2);
      expect(
        errors.join('\n'),
        contains('A persisted Duration needs encode/decode'),
      );
    },
  );

  test('Dart-on-the-web number semantics', () async {
    final js = await _translate('''
$_header
class MathState extends ThorState {
  final n = state(-7);

  int mod() => n.value % 3;
  int div() => n.value ~/ 2;
  double half() => n.value / 2;
  int shr() => 4294967295 >> 4;
  int and() => -1 & 0xFF;
  int round() => (-2.5).round();
  String text() => '\${n.value}|\${1.5}|\${true}|\${null}';
  int parse(String s) => int.parse(s) + 1;
}
''');
    if (!_node) return markTestSkipped('node is not installed');
    final out = _run(js, '''
out.mod = S.mod(); out.div = S.div(); out.half = S.half(); out.shr = S.shr();
out.and = S.and(); out.round = S.round(); out.text = S.text(); out.parse = S.parse('41');
''');
    expect(out, {
      'mod': 2, // Dart: always non-negative.
      'div': -3, // truncates toward zero.
      'half': -3.5,
      'shr': 268435455,
      'and': 255,
      'round': -3, // half away from zero.
      'text': '-7|1.5|true|null',
      'parse': 42,
    });
  });

  test('page arguments are parsed like the Dart members do', () async {
    final js = await _translate('''
$_header
enum Tab { home, cart }

class ArgState extends ThorState {
  final log = state('');

  void add(int n) => log.value = '\${log.value}+\$n';
  void pick(Tab t) => log.value = '\${log.value}|\$t';
  void flag(bool on) => log.value = '\${log.value}|\$on';
  void move(int id, double dx) => log.value = '\${log.value}|\${id + dx}';
  String label() => log.value;
}
''');
    expect(
      js,
      contains(
        r'add: (a) => add((typeof a === '
        "'string'"
        r' ? $int(a) : a))',
      ),
    );
    if (!_node) return markTestSkipped('node is not installed');
    final out = _run(js, '''
S.add('2'); S.add(3); S.pick('cart'); S.flag('true'); S.move('4~0.5');
out.log = S.label();
''');
    expect(out['log'], '+2+3|Tab.cart|true|4.5');
  });

  test('GestureDetector details arrive as objects with their fields', () async {
    final js = await _translate('''
$_header
class DetailsState extends ThorState {
  final log = state('');

  void down(TapDownDetails d) => log.value = '\${log.value}|d\${d.localPosition.dx},\${d.localPosition.dy}';
  void up(TapUpDetails d) => log.value = '\${log.value}|u\${d.localPosition.dx}';
  void pan(DragUpdateDetails d) => log.value = '\${log.value}|p\${d.delta.dx},\${d.delta.dy}';
  void end(DragEndDetails d) => log.value = '\${log.value}|e\${d.velocity.pixelsPerSecond.dx},\${d.localPosition.dy},\${d.globalPosition.dx}';
  String label() => log.value;
}
''');
    if (!_node) return markTestSkipped('node is not installed');
    final out = _run(js, '''
S.down('3.5~4'); S.up('7~8'); S.pan('-1~2'); S.end('250~-3~4~5~104~205');
out.log = S.label();
''');
    expect(out['log'], '|d3.5,4|u7|p-1,2|e250,5,104');
  });

  test('a Set parameter holds the one value the page sends', () async {
    final js = await _translate('''
$_header
enum Tab { home, cart }

class SetState extends ThorState {
  final log = state('');

  void pick(Set<Tab> t) => log.value = '\${log.value}|\${t.isEmpty ? '-' : t.first.name}';
  void ids(Set<int> n) => log.value = '\${log.value}|\${n.length}';
  String label() => log.value;
}
''');
    if (!_node) return markTestSkipped('node is not installed');
    final out = _run(js, '''
S.pick('cart'); S.pick(''); S.ids('3'); S.ids('');
S.ids('3\\u001f4\\u001f5');
out.log = S.label();
''');
    expect(out['log'], '|cart|-|1|0|3');
  });

  test(
    'library code: classes, top-level state, collections, closures',
    () async {
      final js = await _translate('''
$_header
class Item {
  const Item(this.id, this.label, {this.done = false});
  final int id;
  final String label;
  final bool done;

  Item toggled() => Item(id, label, done: !done);
  String get tag => done ? 'x' : 'o';
  @override
  String toString() => '\$tag\$id';
}

const _names = ['a', 'b', 'c'];
var _next = 1;

List<Item> _make(int n) => [for (var i = 0; i < n; i++) Item(_next++, _names[i % 3])];

class ListState extends ThorState {
  final items = state<List<Item>>(const []);
  final counts = state(const <String, int>{});

  void fill() => items.value = _make(4);
  void toggle(int id) => items.value = [
    for (final i in items.value) i.id == id ? i.toggled() : i,
  ];
  void drop() => items.value = [...items.value]..removeWhere((i) => i.id.isEven);
  void count() => counts.value = {
    for (final i in items.value) i.label: (counts.value[i.label] ?? 0) + 1,
  };
  String all() => items.value.map((i) => '\$i').join(',');
  String labels() => items.value.where((i) => !i.done).map((i) => i.label).toList().join();
  int firstDone() => items.value.indexWhere((i) => i.done);
  String kind(int n) => switch (n) { 0 => 'zero', 1 || 2 => 'few', _ => 'many' };
  bool same() => identical(const <int>[], const <int>[]);
  String map() => counts.value.keys.join() + '\${counts.value['a']}\${counts.value['zz']}';
}
''');
      if (!_node) return markTestSkipped('node is not installed');
      final out = _run(js, '''
S.fill(); S.toggle('2'); out.all = S.all(); out.labels = S.labels(); out.firstDone = S.firstDone();
S.count(); out.map = S.map(); S.drop(); out.dropped = S.all();
out.kinds = [S.kind('0'), S.kind('2'), S.kind('9')].join(''); out.same = S.same();
''');
      expect(out, {
        'all': 'o1,x2,o3,o4',
        'labels': 'aca',
        'firstDone': 1,
        'map': 'abc1null',
        'dropped': 'o1,o3',
        'kinds': 'zerofewmany',
        'same': true, // const collections are canonical, like Dart.
      });
    },
  );

  test('a state reading another state lists it in uses', () async {
    final js = await _translate('''
$_header
class A extends ThorState {
  final n = state(1);
  void inc() => n.value++;
}

class B extends ThorState {
  String twice() => '\${a.n.value * 2}';
  void bump() => a.inc();
}

final a = A();
final b = B();
''');
    expect(js, contains("}, { uses: ['A'] });"));
    expect(js, contains(r"$.use('A').$s.n.value * 2"));
  });

  test('DateTime, Duration, TimeOfDay, DateUtils: the same text as the Dart VM', () async {
    // A zone with daylight saving: local-time math must follow it.
    const tz = 'America/New_York';
    const cases = [
      r'DateTime(2026, 9, 25)',
      r'DateTime.utc(2026, 2, 30, 25, 61, 61, 1001, 1500)',
      r'DateTime(5, 3, 1)',
      r'DateTime.utc(-5, 1, 1).toIso8601String()',
      r'DateTime.utc(12345, 1, 1).toIso8601String()',
      r'DateTime.utc(2026, 1, 1, 0, 0, 0, 0, -1)',
      r"DateTime.parse('2026-09-25')",
      r"DateTime.parse('2026-09-25T10:20:30.1234567Z')",
      r"DateTime.parse('20260925T1020+0530')",
      r"DateTime.parse('2026-13-45 25:00')",
      r"DateTime.parse('2026-03-08T02:30')",
      r"DateTime.tryParse('nope')",
      r"DateTime.parse('2026-09-25T10:20:30,5-03:00').toIso8601String()",
      r'[for (var d = 20; d < 27; d++) DateTime(2026, 9, d).weekday].join()',
      r'DateTime(2026, 11, 1, 1, 30).hour',
      r'DateTime(2026, 3, 8).add(const Duration(hours: 24))',
      r'DateTime(2026, 3, 9).difference(DateTime(2026, 3, 8))',
      r'DateTime.utc(2026).subtract(const Duration(microseconds: 1))',
      r'DateTime.utc(2026, 1, 1, 0, 0, 0, 999, 999).add(const Duration(microseconds: 2)).microsecond',
      r'DateTime(2026).isBefore(DateTime(2026, 1, 1, 0, 0, 0, 0, 1))',
      r'DateTime(2027).isAfter(DateTime(2026))',
      r'DateTime.utc(2026).isAtSameMomentAs(DateTime.utc(2026).toLocal())',
      r'DateTime.utc(2026) == DateTime.utc(2026).toLocal()',
      r'DateTime.utc(2026) == DateTime.utc(2026).toLocal().toUtc()',
      r'DateTime(2026).compareTo(DateTime(2025))',
      r'DateTime(2026, 1, 31).copyWith(month: 14)',
      r'DateTime(2026, 7, 4, 12).copyWith(isUtc: true)',
      r'DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)',
      r'DateTime.fromMicrosecondsSinceEpoch(-1, isUtc: true)',
      r'DateTime(2026, 7, 1).timeZoneOffset',
      r'DateTime(2026, 1, 1).timeZoneOffset.inHours',
      r'DateTime(2026, 1, 1).millisecondsSinceEpoch',
      r'DateTime.utc(2026, 1, 1, 0, 0, 0, 1, 2).microsecondsSinceEpoch',
      r'const Duration(days: 1, hours: -3, minutes: 90, seconds: 5, milliseconds: 6, microseconds: 7)',
      r'-const Duration(minutes: 1, microseconds: 5)',
      r'const Duration(minutes: -1, seconds: 1).inMinutes',
      r'const Duration(hours: -25).inDays',
      r'(-const Duration(seconds: 3)).abs()',
      r'const Duration(seconds: 3) * 2.5',
      r'const Duration(seconds: -3) * 0.5',
      r'const Duration(minutes: 7) ~/ 4',
      r'const Duration(minutes: 1) + const Duration(seconds: 1) - const Duration(milliseconds: 1)',
      r'const Duration(minutes: 1) > const Duration(seconds: 59)',
      r'const Duration(minutes: 1) == const Duration(seconds: 60)',
      r'Duration.zero.isNegative',
      r'const Duration(days: 400).inHours',
      r'const TimeOfDay(hour: 0, minute: 5).hourOfPeriod',
      r'const TimeOfDay(hour: 12, minute: 5).period == DayPeriod.pm',
      r'const TimeOfDay(hour: 13, minute: 5).periodOffset',
      r'const TimeOfDay(hour: 9, minute: 5).replacing(hour: 13)',
      r'const TimeOfDay(hour: 9, minute: 5).isBefore(const TimeOfDay(hour: 9, minute: 6))',
      r'TimeOfDay.fromDateTime(DateTime(2026, 1, 1, 23, 59)) == const TimeOfDay(hour: 23, minute: 59)',
      r'DayPeriod.pm.name',
      r'DayPeriod.am',
      r'DateUtils.dateOnly(DateTime(2026, 9, 25, 13))',
      r'DateUtils.isSameDay(DateTime(2026, 9, 25, 1), DateTime(2026, 9, 25, 23))',
      r'DateUtils.isSameMonth(null, DateTime(2026))',
      r'DateUtils.monthDelta(DateTime(2025, 11), DateTime(2026, 2))',
      r'DateUtils.addMonthsToMonthDate(DateTime(2026, 1, 31), 1)',
      r'DateUtils.addDaysToDate(DateTime(2026, 3, 7), 2)',
      r'DateUtils.getDaysInMonth(2024, 2)',
      r"([DateTime(2027), DateTime(2025), DateTime(2026)]..sort()).map((d) => d.year).join(',')",
    ];
    final js = await _translate('''
$_header
class DateState extends ThorState {
${[for (var i = 0; i < cases.length; i++) "  String e$i() => '\${${cases[i]}}';"].join('\n')}
}
''');
    expect(
      js,
      contains('// thor-lite parts: date_utils datetime duration time_of_day'),
    );
    if (!_node) return markTestSkipped('node is not installed');
    final out = _run(js, '''
out.all = [${[for (var i = 0; i < cases.length; i++) 'S.e$i()'].join(', ')}];
''', tz: tz);
    // The same expressions in the Dart VM, in the same time zone.
    final dir = Directory.systemTemp.createTempSync('lite_dates');
    final probe = File('${dir.path}/probe.dart')
      ..writeAsStringSync('''
import 'dart:convert';
import 'package:thor_ui/thor_ui.dart';
void main() => print(jsonEncode([${[for (final c in cases) "'\${$c}'"].join(', ')}]));
''');
    final vm = Process.runSync(
      Platform.resolvedExecutable,
      [
        '--packages=${Directory.current.parent.parent.path}/.dart_tool/package_config.json',
        probe.path,
      ],
      environment: {'TZ': tz},
    );
    dir.deleteSync(recursive: true);
    if (vm.exitCode != 0) fail('dart failed:\n${vm.stderr}');
    final expected = jsonDecode(vm.stdout as String) as List<Object?>;
    final got = out['all']! as List<Object?>;
    expect(got, hasLength(cases.length));
    for (var i = 0; i < cases.length; i++) {
      expect(got[i], expected[i], reason: cases[i]);
    }
  });

  test('controllers: fields, members, eager with a ScrollController', () async {
    final js = await _translate('''
$_header
class FormState extends ThorState {
  final name = TextEditingController(text: 'Ana');
  final box = FocusNode();
  final sheet = DialogController();
  final list = ScrollController(initialScrollOffset: 40);

  String hello() => sheet.isOpen && box.hasFocus ? name.text : '\${list.position.pixels}';
  void reset() {
    name.text = '';
    name.clear();
    box.requestFocus();
    sheet.close();
    list.jumpTo(list.offset + 1);
  }
}
''');
    expect(
      js,
      contains(
        '// thor-lite parts: controllers dialog_controller focus_node '
        'scroll_controller text_controller',
      ),
    );
    expect(js, contains(r'const $p = $.p;'));
    expect(js, contains(r"const name = $C.text(`${$p}.name`, 'Ana');"));
    expect(js, contains(r'const list = $C.scroll(`${$p}.list`, 40);'));
    expect(js, contains(r'const sheet = $C.dialog(`${$p}.sheet`);'));
    expect(js, contains("name.text = '';"));
    expect(js, contains('list.jumpTo(list.offset + 1);'));
    expect(js, contains('}, { eager: true });'));
    // A static site keeps only the states a page names: each top-level
    // item is marked, and the parts behind helpers without an item of their
    // own go with the state that uses them (thor_engine's lite_site).
    expect(js, contains('\n  // @item\n'));
    expect(
      js,
      contains(
        '// @parts dialog_controller focus_node scroll_controller '
        'text_controller',
      ),
    );
    expect(js, contains('// thor-lite helper-parts: '));
  });

  test(
    'static methods of a state are local functions, never members',
    () async {
      final js = await _translate('''
$_header
class GalleryState extends ThorState {
  final on = state(true);

  String summary() => 'a: \${_yesNo(on.value)} b: \${GalleryState._yesNo(!on.value)}';
  static String _yesNo(bool v) => v ? 'sí' : 'no';
  static String shout(String s) => s.toUpperCase();
}
''');
      expect(js, contains('const _yesNo = (v) => v ? '));
      expect(js, contains(r'${_yesNo(on.value)}'));
      expect(js, contains(r'${_yesNo(!on.value)}'));
      // Not callable from the page.
      expect(js, isNot(contains('shout: ')));
      final errors = await _errors('''
$_header
class GalleryState extends ThorState {
  static int get zero => 0;
  int one() => zero + 1;
}
''');
      expect(errors, [
        contains('Static getters and setters in a ThorState are not supported'),
      ]);
    },
  );

  test('AnimationController: status as the enum, members, eager', () async {
    final js = await _translate('''
$_header
class MotionState extends ThorState {
  final reveal = AnimationController(
    duration: const Duration(milliseconds: 350),
    reverseDuration: const Duration(milliseconds: 220),
  );
  final spin = AnimationController(duration: const Duration(seconds: 1), upperBound: 2);

  String label() => switch (reveal.status) {
    AnimationStatus.dismissed => 'hidden',
    AnimationStatus.completed => 'shown',
    _ => 'moving',
  };
  bool busy() => spin.isAnimating || reveal.isForwardOrCompleted;
  void go() {
    reveal.forward(from: 0);
    spin.repeat(reverse: true, count: 2);
    spin.repeat(min: 0.5, max: 1.5, period: const Duration(milliseconds: 80));
    spin.value = 1.5;
    spin.duration = const Duration(milliseconds: 500);
  }
  void halt() => spin.stop();
}
''');
    expect(
      js,
      contains('// thor-lite parts: animation_controller controllers duration'),
    );
    expect(js, contains(r'const reveal = $C.anim(`${$p}.reveal`, undefined, '));
    expect(js, contains(r'const spin = $C.anim(`${$p}.spin`, undefined, $c'));
    expect(js, contains(', undefined, undefined, undefined, 2);'));
    expect(js, contains(r'$AnimationStatus$values[reveal.status]'));
    expect(js, contains('spin.isAnimating || reveal.isForwardOrCompleted'));
    expect(js, contains('reveal.forward(0);'));
    expect(
      js,
      contains('spin.repeat(undefined, undefined, true, undefined, 2);'),
    );
    expect(js, contains('spin.repeat(0.5, 1.5, undefined, '));
    expect(js, contains('spin.value = 1.5;'));
    expect(js, contains('spin.duration = '));
    expect(js, contains('}, { eager: true });'));
  });

  test('AnimationController: what lite does not run is a build error', () async {
    final errors = await _errors('''
$_header
class MotionState extends ThorState {
  final reveal = AnimationController(duration: const Duration(milliseconds: 350));
  var loose = AnimationController();

  void listen() => reveal.addStatusListener((s) {});
  bool moving() => reveal.status.isAnimating;
}
''');
    expect(errors, [
      contains(
        'Controller field MotionState.loose: create it in a `final` field',
      ),
      contains(
        '`.addStatusListener()` of AnimationController is not in the lite subset.',
      ),
      contains('`.isAnimating` on AnimationStatus is not in the lite subset.'),
    ]);
  });

  test(
    'batch, untracked, Timer, String * int, date signals set by value',
    () async {
      final js = await _translate('''
$_header
class TickState extends ThorState {
  final shown = state(false);
  final ticks = state(0);
  final day = state(DateTime.utc(2026, 9, 25));
  final wait = state(const Duration(seconds: 1));
  Timer? _hide;
  Timer? _every;

  String stars(int n) => '\${'★' * n}\${'☆' * (3 - n)}';
  void show() => batch(() {
    shown.value = true;
    _hide?.cancel();
    _hide = Timer(const Duration(seconds: 3), () => shown.value = false);
  });
  bool active() => _hide?.isActive ?? false;
  void start() => _every = Timer.periodic(const Duration(milliseconds: 100), (t) {
    ticks.value = t.tick;
    if (t.tick == 3) t.cancel();
  });
  int peek() => untracked(() => ticks.value);
  void sameDay() => day.value = DateTime.utc(2026, 9, 25);
  void nextDay() => day.value = day.value.add(const Duration(days: 1));
  void longer() => wait.value += const Duration(seconds: 1);
  String sum() {
    var d = const Duration(seconds: 1);
    d += const Duration(seconds: 2);
    d *= 2;
    return '\$d';
  }
}
''');
      expect(js, contains("'★'.repeat(Math.max(0, n))"));
      expect(js, contains('thor.batch(() => {'));
      expect(js, contains(r'_hide = new $Timer($c'));
      expect(js, contains(r'$sset(day, '));
      expect(js, contains('// thor-lite parts: datetime duration'));
      if (!_node) return markTestSkipped('node is not installed');
      final out = _run(js, '''
thor.batch = (f) => f();
thor.untracked = (f) => f();
// Timers by hand: [callback, ms, periodic], run in order.
const q = [];
globalThis.setTimeout = (f, ms) => q.push([f, ms, false]);
globalThis.setInterval = (f, ms) => q.push([f, ms, true]);
globalThis.clearTimeout = globalThis.clearInterval = (h) => (q[h - 1] = null);
out.stars = [S.stars(0), S.stars(2), S.stars(5)];
S.show();
S.show(); // cancels the first timer
out.pending = q.filter(Boolean).map((t) => t[1]);
out.active = S.active();
q[1][0]();
out.shownAfter = S.shown();
out.activeAfter = S.active();
S.start();
const tick = q.length;
for (let i = 0; i < 5 && q[tick - 1]; i++) q[tick - 1][0]();
out.ticks = S.ticks();
out.peek = S.peek();
const d = S.\$s.day;
S.sameDay();
out.sameDayWrites = d.n;
S.nextDay();
out.nextDayWrites = d.n;
out.day = `\${S.day()}`;
S.longer();
out.wait = `\${S.wait()}`;
out.sum = S.sum();
''');
      expect(out, {
        'stars': ['☆☆☆', '★★☆', '★★★★★'],
        'pending': [3000],
        'active': true,
        'shownAfter': false,
        'activeAfter': false,
        'ticks': 3, // the callback cancelled it at 3
        'peek': 3,
        'sameDayWrites': 0, // an equal DateTime: Dart's `==`, no write
        'nextDayWrites': 1,
        'day': '2026-09-26 00:00:00.000Z',
        'wait': '0:00:02.000000',
        'sum': '0:00:06.000000', // compound Duration operators
      });
    },
  );

  test(
    'enums with members, classes with a base, patterns, sets, maps, '
    'StringBuffer, RegExp, Uri, dart:math, ?.: the same text as the Dart VM',
    () async {
      // Plain Dart the state calls (`t<i>()`); the VM runs the same code.
      const lib = r'''
enum Kind { text, number, check }

enum Field {
  name('Name', Kind.text, 200),
  budget('Budget', Kind.number, 120),
  done('Done', Kind.check, 90);

  const Field(this.label, this.kind, this.width);
  final String label;
  final Kind kind;
  final double width;
  bool get numeric => kind == Kind.number;
  bool isFirst() => this == name;
  String describe(int n) => '$label×$n';
}

sealed class Shape {
  const Shape(this.id);
  final int id;
  double get area;
  @override
  String toString() => '${runtimeType == Square ? 'sq' : 'ci'}#$id';
}

class Square extends Shape {
  const Square(super.id, this.side);
  final double side;
  @override
  double get area => side * side;
}

class Circle extends Shape {
  Circle(int id, {required this.r}) : super(id);
  final double r;
  @override
  double get area => 3 * r * r;
}

String byName<T extends Enum>(List<T> values, String n) {
  for (final v in values) {
    if (v.name == n) return '${v.name}/${v.index}';
  }
  return '-';
}

(int, String) pair(int n) => (n * 2, 'n$n');

String t0() => [
  for (final f in Field.values) '$f:${f.label}:${f.kind.name}:${f.numeric}:${f.isFirst()}:${f.describe(f.index)}',
].join(',');
String t1() => '${Field.values.byName('budget').width}|${Field.values.asNameMap()['done']?.label}|${Field.values.asNameMap()['zz']}|${byName(Kind.values, 'check')}';
String t2() {
  final shapes = <Shape>[const Square(1, 2), Circle(2, r: 1.5), const Square(3, 0.5)];
  final squares = shapes.whereType<Square>().map((s) => s.side).join('+');
  final text = [
    for (final s in shapes)
      switch (s) {
        Square(side: final d) when d > 1 => 'big$d',
        Square(:final side) => 'small$side',
        Circle(r: > 1) => 'wide',
        Circle() => 'ci',
      },
  ].join(',');
  return '$shapes $squares $text ${shapes.map((s) => s.area).join(';')} ${shapes[0] is Square} ${shapes[1] is! Circle}';
}
String t3() {
  final (a, b) = pair(3);
  var (x, y) = (1, 2);
  (x, y) = (y, x);
  final out = <String>[];
  for (final (n, s) in [pair(1), pair(2)]) {
    out.add('$n$s');
  }
  final Object? o = pair(4);
  if (o case (final int m, final String t) when m > 5) out.add('case$m$t');
  final int? maybe = null;
  if (maybe case final v?) out.add('never$v');
  String kind(Object? v) => switch (v) {
    null => 'null',
    int() || double() when v is num && v < 0 => 'neg',
    int n => 'int$n',
    String s when s.isEmpty => 'empty',
    String(:final length) => 'str$length',
    _ => 'other',
  };
  var loops = 0;
  for (var i = 0; i < 5; i++) {
    switch (i) {
      case int n when n.isEven:
        loops += 10;
        if (n == 2) break;
        loops += 1;
      case _:
        loops += 100;
    }
  }
  return '$a$b $x$y ${out.join()} ${[null, -1, 7, '', 'abc', true].map(kind).join(',')} $loops';
}
String t4() {
  final s = {3, 1, 2};
  final added = s.add(2);
  final addedNew = s.add(5);
  final removed = s.remove(1);
  final evens = {for (final x in [1, 2, 3, 4, 4]) if (x.isEven) x};
  final kinds = {Kind.text, Kind.text, Kind.check};
  return '${s.toList()} $added $addedNew $removed ${s.contains(3)} ${s.length} ${evens.toList()} ${[3, 1, 3].toSet().toList()} ${s.union(evens).toList()} ${s.intersection({3, 9}).toList()} ${kinds.length} ${s.where((x) => x > 2).toList()} ${<int>{}.isEmpty}';
}
String t5() {
  final m = <int, String>{2: 'b', 1: 'a'};
  m[3] = 'c';
  final r = m.remove(2);
  final gone = m.remove(9);
  final byKind = <Kind, int>{};
  for (final f in Field.values) {
    byKind[f.kind] = (byKind[f.kind] ?? 0) + 1;
  }
  final got = m.putIfAbsent(7, () => 'g');
  final kept = m.putIfAbsent(7, () => 'x');
  final order = <String>[];
  m.forEach((k, v) => order.add('$k=$v'));
  return '${m.keys.toList()} ${m.values.toList()} ${m[1]} ${m[9]} $r $gone ${m.length} ${m.containsKey(3)} ${byKind[Kind.number]} $got$kept ${order.join('&')} ${m.entries.map((e) => e.key).toList()}';
}
String t6() {
  final b = StringBuffer('x');
  b.write(1);
  b.write(null);
  b.write(Kind.text);
  b.writeln('!');
  final empty = StringBuffer();
  final e1 = empty.isEmpty;
  empty.write('');
  b.writeAll([1, 2, 3], '-');
  final len = b.length;
  final s = '$b';
  b.clear();
  return '$s|$len|$e1|${empty.isEmpty}|${b.isEmpty}|${b.toString()}';
}
String t7() {
  final re = RegExp(r'^(\d+)-(\w+)?(!)?$');
  final m = re.firstMatch('12-ab');
  final ci = RegExp('HELLO', caseSensitive: false);
  final all = RegExp(r'\d').allMatches('a1b22c').map((x) => x[0]).join();
  return '${m?[1]} ${m?[2]} ${m?[3]} ${m?.group(0)} ${re.hasMatch('x')} ${ci.hasMatch('say hello')} $all '
      '${'a.b.c'.replaceAll('.', r'$&')} ${'a1b2'.replaceAll(RegExp(r'\d'), r'<$0>')} ${'aaa'.replaceFirst('a', 'b')} '
      '${'x1y2'.replaceFirst(RegExp(r'\d'), '#')} ${'Hello'.contains(RegExp('ll'))} ${RegExp(r'(\d)(\d)?').firstMatch('5')?.groupCount}';
}
String t8() => [
  Uri.encodeQueryComponent("a b&c=d/é!*'()~._-"),
  Uri.decodeQueryComponent('a+b%26c%3Dd'),
  Uri.encodeComponent("a b&c/é!*'()"),
].join('|');
String t9() {
  final l = [3, 9, 4];
  return '${math.max(2, 5)} ${math.min(2.5, -1)} ${l.reduce(math.max)} ${math.sqrt(16)} ${math.pow(2, 10)} ${(math.pi * 100).round()}';
}
String t10() {
  List<int>? none;
  final some = <int>[4, 5];
  String? s;
  int? n;
  Map<String, int>? m;
  return '${none?.isEmpty} ${some.isEmpty} ${s?.length} ${n?.clamp(0, 5)} ${(n ?? 9).clamp(0, 5)} ${none?.length} ${m?['a']} ${some.firstOrNull} ${none?.firstOrNull}';
}
String t11() {
  final Object? a = DateTime.utc(2026, 1, 2);
  final Object? b = DateTime.utc(2026, 1, 2);
  final Object? c = 3;
  return '${a == b} ${a == c} ${c == 3} ${identical(a, b)}';
}
''';
      await _sameAsWeb(
        lib,
        12,
        imports: "import 'dart:math' as math;",
        vmDiffers: {1: _numbers, 2: _numbers, 9: _numbers},
      );
    },
  );

  test('try/catch/finally, throw, rethrow, jsonDecode, map and list patterns: '
      'the same text as dart2js', () async {
    const lib = r'''
class Oops implements Exception {
  Oops(this.n);
  final int n;
  @override
  String toString() => 'Oops$n';
}

String kind(Object? Function() f) {
  try {
    f();
    return 'ok';
  } on RangeError {
    return 'range';
  } on ArgumentError {
    return 'arg';
  } on StateError {
    return 'state';
  } on FormatException {
    return 'format';
  } on Exception {
    return 'exc';
  } on String catch (s) {
    return 'str:$s';
  } on Error {
    return 'error';
  } catch (_) {
    return 'other';
  }
}

String t0() => [
  kind(() => throw StateError('s')),
  kind(() => throw ArgumentError('a')),
  kind(() => throw RangeError('r')),
  kind(() => throw const FormatException('f')),
  kind(() => throw Exception('e')),
  kind(() => throw Oops(3)),
  kind(() => throw 'boom'),
  kind(() => throw UnsupportedError('u')),
  kind(() => int.parse('x')),
  kind(() => <int>[].first),
  kind(() => null),
].join('|');

String t1() {
  final out = <String>[];
  for (final e in <Object>[
    StateError('s'),
    ArgumentError('a'),
    ArgumentError(),
    RangeError('r'),
    const FormatException('f'),
    const FormatException(),
    Exception('e'),
    UnsupportedError('u'),
  ]) {
    try {
      throw e;
    } on StateError catch (x) {
      out.add('$x');
    } on ArgumentError catch (x) {
      out.add('$x');
    } on FormatException catch (x) {
      out.add('$x');
    } on Exception catch (x) {
      out.add('$x');
    } on UnsupportedError catch (x) {
      out.add('$x');
    }
  }
  return out.join('|');
}

String t2() {
  final log = <String>[];
  int f(int n) {
    try {
      if (n > 1) throw StateError('big');
      return n;
    } finally {
      log.add('fin$n');
    }
  }

  String g() {
    try {
      try {
        throw const FormatException('inner');
      } on FormatException {
        log.add('caught');
        rethrow;
      } finally {
        log.add('inner-fin');
      }
    } on FormatException catch (e, s) {
      return 'outer:$e';
    }
  }

  var r = f(1);
  try {
    r += f(2);
  } on StateError catch (e) {
    log.add('$e');
  }
  return '$r ${g()} ${log.join(',')}';
}

String t3() {
  final out = <String>[];
  for (final s in ['{"a": 1}', 'nope', '[1, 2]', '', '"x"', '{"a": [1, {"b": null}]}']) {
    try {
      final Object? v = jsonDecode(s);
      out.add(v is Map ? 'map' : v is List ? 'list' : v is String ? 'str:$v' : 'x');
    } on FormatException catch (e) {
      out.add('$e');
    }
  }
  return out.join('|');
}

String m(Object? v) => switch (v) {
  {'bar': final String name, 'value': final num value} => 'bar $name $value',
  {'count': final int n} => 'count $n',
  [] => 'empty',
  [final int a] => 'one $a',
  {'k': [_, final String s, ...]} => 'nested $s',
  [final a, ..., final int z] => 'ends ${a is int} $z',
  _ => 'other',
};

String t4() => [
  for (final s in [
    '{"bar": "x", "value": 2.5}',
    '{"bar": "x", "value": "no"}',
    '{"count": 3}',
    '{"count": 3.0}',
    '{"count": 3.5}',
    '{"count": 1, "extra": true}',
    '[]',
    '[7]',
    '[1, 2, 3]',
    '["a", 2, 9]',
    '["a", 2, "z"]',
    '{"k": [1, "s", 2]}',
    '{"k": [1, 2]}',
    'null',
    '"str"',
  ])
    m(jsonDecode(s)),
  m((1, 2)),
  m((count: 5)),
  m(<String, int>{'count': 4}),
  m(<int, String>{1: 'x'}),
  m({1, 2}),
  m(Oops(1)),
].join('|');

String t5() {
  String h(List<int> l) => switch (l) {
    [] => 'e',
    [final x] => 'one$x',
    [final x, ...final rest] => '$x+${rest.length}:${rest.join()}',
  };
  String k(Map<String, int> m) => switch (m) {
    {'a': final a, 'b': final b} => 'ab${a + b}',
    {'a': final a} => 'a$a',
    _ => 'none',
  };
  final got = <String>[];
  final Map<int, String> byId = {1: 'x', 2: 'y'};
  if (byId case {2: final y}) got.add(y);
  final [first, ..., last] = [4, 5, 6];
  return '${[<int>[], [5], [1, 2, 3]].map(h).join(',')} '
      '${[<String, int>{'a': 1, 'b': 2}, {'a': 5}, {'b': 1}, <String, int>{}].map(k).join(',')} '
      '${got.join()} $first$last';
}
''';
    await _sameAsWeb(
      lib,
      6,
      imports: "import 'dart:convert';",
      vmDiffers: {3: _jsonMessages, 4: _numbers},
    );
  });

  test(
    'constructs outside the subset are build errors with file:line',
    () async {
      final errors = await _errors('''
$_header
class Bad extends ThorState {
  final when = state(0);

  Set<DateTime> days() => {DateTime(2026)};
  String list() => '\${<Object>[1, 2]}';
  Iterable<int> gen() sync* {}
  void risky() {
    try {} on TypeError catch (_) {}
  }
  void later() => Timer.run(() {});
  int head(Object o) => switch (o) { <int>[final a] => a, _ => 0 };
}
''');
      expect(errors, hasLength(6));
      expect(errors.every((e) => e.startsWith('lib/s.dart:')), isTrue);
      expect(
        errors.join('\n'),
        allOf([
          contains('Sets of DateTime compare by value'),
          contains('Interpolating a List<Object>'),
          contains('Generators (sync*, async*)'),
          contains('Catching TypeError is not in the lite subset'),
          contains('Timer.run is not in the lite subset'),
          contains('A list pattern with an element type'),
        ]),
      );
      expect(errors.first, startsWith('lib/s.dart:'));
    },
  );

  test('package:collection helpers: the same text as dart2js', () async {
    const lib = r'''
class Item {
  const Item(this.name, this.n);
  final String name;
  final int n;
}

const items = [Item('b', 2), Item('a', 2), Item('c', 1)];

String t0() => [
  '${[3, 9, 12].firstWhereOrNull((x) => x > 8)}',
  '${[3, 9, 12].firstWhereOrNull((x) => x > 80)}',
  '${[3, 9, 12].lastWhereOrNull((x) => x > 8)}',
  '${<int?>[null, 1].firstWhereOrNull((x) => x == null)}',
].join('|');

String t1() => [
  items.sortedBy<num>((i) => i.n).map((i) => i.name).join(),
  items.sortedBy((i) => i.name).map((i) => i.name).join(),
  items.sorted((a, b) => b.n.compareTo(a.n)).map((i) => i.name).join(),
  items.map((i) => i.name).join(),
].join('|');

String t2() {
  final byN = items.groupListsBy((i) => i.n);
  final byName = groupBy(items, (Item i) => i.name.toUpperCase());
  return [
    for (final e in byN.entries) '${e.key}:${e.value.map((i) => i.name).join()}',
    byName.keys.join(),
    '${byN[3] == null}',
  ].join('|');
}

String t3() {
  final seen = <String>[];
  [4, 5].forEachIndexed((i, x) => seen.add('$i=$x'));
  return [
    [1, 2, 3].sum,
    [1.5, 2].sum,
    <int>[].sum,
    [4, 9, 2].max,
    [4, 9, 2].min,
    [1.5, 0.5].max,
    ['a', 'b'].mapIndexed((i, s) => '$i$s').join(),
    [5, 6, 7].whereIndexed((i, x) => i.isEven).join(),
    seen.join(),
    [1, 2].map((x) => x * 2).firstWhereOrNull((x) => x > 2),
  ].join('|');
}

String t4() {
  try {
    return '${<int>[].max}';
  } on StateError catch (e) {
    return '$e';
  }
}
''';
    await _sameAsWeb(
      lib,
      5,
      imports: "import 'package:collection/collection.dart';",
    );
  });

  test('jsonEncode: the same text as dart2js', () async {
    const lib = r'''
class Tag {
  const Tag(this.name, this.at);
  final String name;
  final int at;
  Map<String, Object?> toJson() => {'name': name, 'at': at};
}

String t0() => jsonEncode({
  'a': [1, 2.5, null, true, false],
  'b': 'x"y\n< >',
  'c': <String, Object?>{},
  'd': [<int>[], 'é'],
});

String t1() => jsonEncode([const Tag('x', 1), const Tag('y', 2)]);

String t2() => jsonEncode({'tags': [const Tag('z', 3)], 'n': 2.0});

String t3() {
  final back = jsonDecode(jsonEncode({'k': [1, 2]})) as Map<String, Object?>;
  return (back['k']! as List).join(',');
}

String t4() {
  final out = <String>[];
  for (final v in <Object?>[double.nan, double.infinity, 'ok', null]) {
    try {
      out.add(jsonEncode(v));
    } catch (e) {
      out.add('error');
    }
  }
  return out.join(',');
}
''';
    await _sameAsWeb(
      lib,
      5,
      imports: "import 'dart:convert';",
      vmDiffers: {2: _numbers},
    );
  });

  test('Map<String, V> keeps insertion order and takes any string key: '
      'the same as dart2js', () async {
    const lib = r"""
String show(Map<String, Object?> m) =>
    '${m.keys.join(',')}|${m.values.join(',')}|${m.length}';

String t0() {
  final m = {'10': 1, '9': 2, 'a': 3};
  final out = [show(m)];
  m.remove('9');
  m['9'] = 4;
  m['-1'] = 5;
  m['01'] = 6;
  out.add(show(m));
  final es = m.entries.map((e) => '${e.key}=${e.value}').join(',');
  final fe = <String>[];
  m.forEach((k, v) => fe.add('$k$v'));
  return '${out.join('#')}#$es#${fe.join(',')}';
}

String t1() {
  final m = <String, int>{};
  for (final k in ['__proto__', 'constructor', 'toString', 'hasOwnProperty', 'valueOf', 'a']) {
    m[k] = k.length;
  }
  m['__proto__'] = 99;
  final out = <String>[
    '${m.length}',
    m.keys.join(','),
    '${m['__proto__']} ${m['constructor']} ${m['toString']}',
    '${m.containsKey('__proto__')} ${m.containsKey('nope')} ${m['nope']}',
    '${m.remove('__proto__')} ${m.remove('__proto__')} ${m.length}',
    '${m.putIfAbsent('__proto__', () => 7)} ${m.putIfAbsent('__proto__', () => 8)}',
  ];
  final lit = {'__proto__': 1, 'x': 2};
  out.add('${lit.length} ${lit['__proto__']} ${lit.keys.join(',')}');
  return out.join('|');
}

String t2() {
  final m = <String, int>{};
  return '${m.isEmpty} ${m.isNotEmpty} ${m.length} ${m['x']} ${m.remove('x')} '
      '${m.keys.toList()} ${m.values.toList()} ${m.containsKey('')} '
      '${(m..[''] = 1).length} ${m['']}';
}

String t3() {
  final m = <String, int>{};
  for (var i = 9999; i >= 0; i--) {
    m['$i'] = i;
  }
  var sum = 0;
  m.forEach((k, v) => sum += v);
  final keys = m.keys.toList();
  return '${m.length} $sum ${keys.first} ${keys[1]} ${keys.last} ${m['5000']}';
}

String t4() {
  final inner = {'2': 'b', '1': 'a'};
  final m = <String, Object?>{
    'z': inner,
    '3': [
      {'9': 1, '8': [inner, {'k': 'v'}]},
    ],
  };
  final l = (m['3']! as List).first as Map<String, Object?>;
  final deep = (l['8']! as List).first as Map<String, String>;
  final on = true;
  final spread = {
    '10': 0,
    ...{'9': 1, '8': 2},
    if (on) '7': 3,
    for (var i = 6; i > 4; i--) '$i': i,
  };
  return '${m.keys.join(',')} ${l.keys.join(',')} ${deep.keys.join(',')} '
      '${spread.keys.join(',')} ${spread.values.join(',')}';
}

String t5() {
  final m = {for (var i = 0; i < 12; i++) '${i * 7 % 12}': i};
  for (final k in m.keys.toList()) {
    if (int.parse(k) % 3 == 0) m.remove(k);
  }
  final copy = Map<String, int>.of(m)..addAll({'50': 1, '4': 9});
  final g = <String, int>{'q': 1}..addAll(copy);
  return '${m.keys.join(',')} ${copy.keys.join(',')} ${g.keys.join(',')} '
      '${copy.containsValue(9)} ${copy.containsValue(-1)} ${Map<String, int>.from(g).length}';
}

String t6() {
  final m = {'10': 1, '9': 2};
  m.clear();
  m['b'] = 1;
  m['1'] = 2;
  return '${m.keys.join(',')} ${jsonEncode(m)} ${jsonEncode({'10': [1], '9': {'2': 1, '1': 2}})}';
}
""";
    await _sameAsWeb(lib, 7, imports: "import 'dart:convert';");
  });

  test('jsonDecode: objects come back as insertion-ordered maps', () async {
    final js = await _translate("""
import 'dart:convert';
$_header
class JsonState extends ThorState {
  String keys(String s) => (jsonDecode(s) as Map<String, Object?>).keys.join(',');
  String deep(String s) {
    final m = jsonDecode(s) as Map<String, Object?>;
    final l = (m['list']! as List).first as Map<String, Object?>;
    return '\${m.keys.join(',')}|\${l.keys.join(',')}|\${m.length}|\${m['__proto__'] as int}';
  }
  String back(String s) => jsonEncode(jsonDecode(s));
  String isMap(String s) => '\${jsonDecode(s) is Map}';
}
""");
    if (!_node) return markTestSkipped('node is not installed');
    final out = _run(js, r'''
out.keys = S.keys('{"10":1,"9":2,"a":3}');
out.deep = S.deep('{"list":[{"3":0,"2":1}],"__proto__":5,"1":0}');
out.back = S.back('{"10":[{"3":1,"2":{"b":1,"1":2}}],"9":null}');
out.isMap = [S.isMap('{"1":1}'), S.isMap('[1]'), S.isMap('"x"')].join();
''');
    expect(out['keys'], '10,9,a');
    expect(out['deep'], 'list,__proto__,1|3,2|3|5');
    expect(out['back'], '{"10":[{"3":1,"2":{"b":1,"1":2}}],"9":null}');
    expect(out['isMap'], 'true,false,false');
  });

  for (final minify in [false, true]) {
    test(
      'a map state through #thor-state and a persisted cookie keeps its '
      'order and any string key (${minify ? 'minified' : 'as written'})',
      () async {
        final js = await _translate('''
$_header
class MapsState extends ThorState {
  final counts = state<Map<String, int>>({'x': 0}, cookie: 'counts');
  final nested = state<Map<String, List<Map<String, int>>>>({});

  String keys() => counts.value.keys.join(',');
  String all() => '\${counts.value.keys.join(',')}|\${counts.value.values.join(',')}|\${counts.value.length}|\${counts.value['__proto__']}';
  int total() {
    var t = 0;
    for (final v in counts.value.values) {
      t += v;
    }
    return t;
  }
  String deep() {
    final l = nested.value['10']!.first;
    return '\${nested.value.keys.join(',')}|\${l.keys.join(',')}';
  }
  void bump(String? k) => counts.value = {...counts.value, k!: (counts.value[k] ?? 0) + 1};
}
''');
        if (!_node) return markTestSkipped('node is not installed');
        final runtime = File(
          '../thor_engine/lib/lite/runtime.js',
        ).readAsStringSync();
        final bundle = liteBundle(
          runtime: runtime,
          parts: {
            for (final p in ['json', 'map_keys'])
              p: File('../thor_engine/lib/lite/parts/$p.js').readAsStringSync(),
          },
          stateJs: js,
          minify: minify,
        );
        String run(String stateText, String jar, String script) {
          final program =
              '''
globalThis.window = globalThis;
const listeners = {}, writes = [];
let jar = ${jsonEncode(jar)};
const root = { addEventListener(t, f) { listeners[t] = f; }, querySelectorAll: () => [] };
globalThis.document = {
  documentElement: root,
  get cookie() { return jar; },
  set cookie(v) { writes.push(decodeURIComponent(v.split(';')[0].split('=').slice(1).join('='))); },
  querySelectorAll: () => [],
  getElementById: (id) => (id === 'thor-state' ? { textContent: ${jsonEncode(stateText)} } : null),
  dispatchEvent() {}, createElement: () => ({}),
};
globalThis.location = { protocol: 'http:' };
globalThis.requestAnimationFrame = (f) => setTimeout(f, 0);
globalThis.CustomEvent = class {};
const el = (a) => ({ getAttribute: (n) => a[n] ?? null, hasAttribute: (n) => n in a, closest(sel) { return sel.split(',').some((s) => s.slice(1, -1) in a) ? this : null; }, parentElement: null, isConnected: true });
const click = (spec, tx) => { const t = el({ 'data-t-on': spec, 'data-tx': tx }); listeners.click({ type: 'click', target: t, preventDefault() {}, stopPropagation() {} }); };
const step = () => new Promise((r) => setTimeout(r, 0));
$bundle
(async () => {
  await step();
  const out = {};
  const S = thor.use('MapsState').m ?? thor.use('MapsState');
  $script
  console.log(JSON.stringify(out));
})();
''';
          final r = Process.runSync('node', ['-e', program]);
          if (r.exitCode != 0) fail('node failed:\n${r.stderr}');
          return (r.stdout as String).trim();
        }

        // The server's JSON (from the VM, in insertion order) into a Map, and
        // the change back out to the cookie, still in order.
        final fromState =
            jsonDecode(
                  run(
                    '{"MapsState.counts":{"10":1,"9":2,"__proto__":3,"a":4},'
                        '"MapsState.nested":{"10":[{"3":1,"2":2}],"9":[]}}',
                    '',
                    r'''
out.all = S.all();
out.total = S.total();
out.deep = S.deep();
click('click:MapsState.bump', '9');
await step();
out.after = S.all();
out.writes = writes;
''',
                  ),
                )
                as Map<String, Object?>;
        expect(fromState['all'], '10,9,__proto__,a|1,2,3,4|4|3');
        expect(fromState['total'], 10);
        expect(fromState['deep'], '10,9|3,2');
        expect(fromState['after'], '10,9,__proto__,a|1,3,3,4|4|3');
        expect(fromState['writes'], ['{"10":1,"9":3,"__proto__":3,"a":4}']);

        // A cookie from a previous visit starts the state before any event.
        final fromCookie =
            jsonDecode(
                  run(
                    '{}',
                    'thor-s.counts=${Uri.encodeComponent('{"10":1,"9":2,"__proto__":3}')}',
                    r'''
out.all = S.all();
''',
                  ),
                )
                as Map<String, Object?>;
        expect(fromCookie['all'], '10,9,__proto__|1,2,3|3|3');

        // A cookie that is not a Map<String, int> is ignored: the value in
        // the code.
        final bad =
            jsonDecode(
                  run(
                    '{}',
                    'thor-s.counts=${Uri.encodeComponent('{"a":"no"}')}',
                    'out.all = S.all();',
                  ),
                )
                as Map<String, Object?>;
        expect(bad['all'], 'x|0|1|null');
      },
    );
  }

  test(
    'the part json ships with the code that has maps, and only then',
    () async {
      final plain = await _translate('''
$_header
class PlainState extends ThorState {
  final n = state(0);
  String label() => '\${n.value}';
}
''');
      expect(plain, isNot(contains('json')));
      for (final body in [
        'final m = state(<String, int>{});',
        "final l = state(<int>[], cookie: 'l');",
        'String s(String x) => jsonEncode([x]);',
        "String s(String x) => '\${jsonDecode(x) is List}';",
      ]) {
        final js = await _translate('''
import 'dart:convert';
$_header
class HasState extends ThorState {
  $body
}
''');
        expect(
          js,
          contains(RegExp(r'// thor-lite parts: .*\bjson\b')),
          reason: body,
        );
      }
    },
  );

  test(
    'Future.delayed waits in the browser, with or without a value',
    () async {
      final js = await _translate('''
$_header
class WaitState extends ThorState {
  final status = state('idle');

  Future<void> run() async {
    status.value = 'waiting';
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final n = await Future.delayed(Duration.zero, () => 41 + 1);
    status.value = 'done \$n';
  }
}
''');
      expect(js, contains('setTimeout'));
      if (!_node) return markTestSkipped('node is not installed');
      final out = _run(js, '''
const done = S.run();
out.before = S.\$s.status.value;
const log = console.log;
console.log = () => done.then(() => {
  out.after = S.\$s.status.value;
  log(JSON.stringify(out));
});
''');
      expect(out, {'before': 'waiting', 'after': 'done 42'});
    },
  );

  test('the build report names each construct and the way out', () {
    final e = LiteTranslationException(const []);
    expect(e.report, contains('THOR-B012'));
    // The lightest way out first: the server, where any package runs.
    expect(e.report, contains('query(fn)'));
    expect(e.report, contains('command(fn)'));
    expect(e.report, isNot(contains('engine: dart')));
    expect(e.report, isNot(contains('--engine')));
  });

  test('a state that extends ThorState translates like the old form', () async {
    const body = r'''
  final count = state(0);
  String label() => '${count.value}';
  bool isZero() => count.value == 0;
  void inc() => count.value++;
}

final counter = CounterState();
''';
    final old = await _translate(
      "import 'package:thor_ui/thor_ui.dart';\n\n"
      'class CounterState extends ThorState {\n$body',
    );
    final current = await _translate(
      "import 'package:thor_ui/thor_ui.dart';\n"
      'class CounterState extends ThorState {\n$body',
    );
    expect(current, contains("thor.def('CounterState'"));
    expect(current, old);
  });

  // Keyed instances (`TileState(key: 't1')`) need a constructor
  // that forwards the key; the lite engine gives each instance its key.
  test('a constructor that only forwards the key translates', () async {
    final js = await _translate(r"""
import 'package:thor_ui/thor_ui.dart';
class TileState extends ThorState {
  TileState({super.key});
  final n = state(0);
  String label() => '${n.value}';
  void inc() => n.value++;
}

final left = TileState(key: 'left');
final right = TileState(key: 'right');
""");
    expect(js, contains("thor.def('TileState'"));
    if (!_node) return markTestSkipped('node is not installed');
    final out = _run(js, 'S.inc(); S.inc(); out.label = S.label();');
    expect(out['label'], '2');
  });

  test('a constructor that does more than forward the key fails', () async {
    final errors = await _errors(r"""
import 'package:thor_ui/thor_ui.dart';
class TileState extends ThorState {
  TileState({super.key, int start = 0}) {
    n.value = start;
  }
  final n = state(0);
}
""");
    expect(errors.single, contains('Constructors in a ThorState'));
  });

  group('adversarial', () {
    const common = r'''
int hits = 0;
Object? id(Object? o) => o;
List<int>? gl = [10, 20, 30];
List<int>? f() { hits++; return gl; }
int g() { hits++; return 1; }
class Box {
  List<int> list = [1, 2, 3];
  int get idx { hits++; return 1; }
  List<int> get lst { hits++; return list; }
}
int? mi(bool b) => b ? 4 : null;
bool? mb(bool b) => b ? true : null;
class P { P? next; int? v; P(this.next, this.v); }
enum Color { red, green }
abstract class Shape { int area() => 0; }
abstract class Named { String get name; }
enum Fancy implements Shape { a, b; @override int area() => 1; }
class Circle implements Shape, Named { @override int area() => 3; @override String get name => 'c'; }
class Box2 { }
class Base { }
class Sq extends Base { }
class Gen<T> { final T v; Gen(this.v); }
class Item { String? name; String? tag; int? n; List<int>? kids; }
String opt({String? a, int? b}) => '${a}/${b}';
class NullTag { String? a; int? b; NullTag(); factory NullTag.nothing() => NullTag(); }
extension ObjTag on Object? { String tag() => 'x'; }
extension StrOrEmpty on String? { String orEmpty() => this ?? ''; }
String tryIt(void Function() f) {
  try { f(); return 'ok'; } on Error catch (e) { return 'E'; }
}
''';

    /// Numbers the bodies `t0…` (a body is a block or an expression).
    String fns(List<String> bodies) => [
      common,
      for (var i = 0; i < bodies.length; i++)
        'String t$i() ${bodies[i].startsWith('{') ? bodies[i] : '=> ${bodies[i]};'}',
    ].join('\n');

    Future<void> run(
      List<String> bodies, {
      Map<int, String> vm = const {},
      bool checked = true,
      String imports = '',
    }) => _sameAsWeb(
      fns(bodies),
      bodies.length,
      checked: checked,
      vmDiffers: vm,
      imports: imports,
    );

    test(
      'each operand of a check is evaluated exactly once',
      () => run([
        r"{ hits = 0; final a = f()!; return '${a.length} $hits'; }",
        r"{ hits = 0; final l = [5, 6, 7]; final v = l[g()]; return '$v $hits'; }",
        r"{ hits = 0; final String? a = id(null) as String?; final v = (a ?? 'z')!; return '$v $hits'; }",
        r"{ hits = 0; final l = <List<int>?>[[1, 2]]; final v = l[g() - 1]![g()]; return '$v $hits'; }",
        r"{ hits = 0; final b = Box(); b.list[g()] += 1; return '${b.list} $hits'; }",
        r"{ hits = 0; final l = [1, 2, 3]; l..[g()] = 9..[0] = 4; return '$l $hits'; }",
        r"{ hits = 0; f()![g()] = 5; final r = '$gl $hits'; gl = [10, 20, 30]; return r; }",
        r"{ hits = 0; final b = Box(); b.list[b.idx]++; return '${b.list} $hits'; }",
        r"{ hits = 0; final b = Box(); final v = b.lst[b.idx]; return '$v $hits'; }",
        r"{ hits = 0; final b = Box(); final l = b.lst..[g()] = 7; return '$l $hits'; }",
        r"{ hits = 0; final l = [1, 2, 3]; var i = 0; l[i++] += 10; return '$l $i'; }",
        r"{ hits = 0; final l = <int?>[null, 2]; l[g() - 1] ??= 5; return '$l $hits'; }",
      ]),
    );

    test(
      'a getter receiver of an indexed assignment is evaluated once',
      () => run([
        r"{ hits = 0; final b = Box(); b.lst[g()] += 1; return '${b.list} $hits'; }",
        r"{ hits = 0; final b = Box(); b.lst[g()] = 5; return '${b.list} $hits'; }",
        r"{ hits = 0; final b = Box(); b.lst[g()]++; return '${b.list} $hits'; }",
        r"{ hits = 0; final b = Box(); b.lst[g()] ??= 3; return '${b.list} $hits'; }",
        r"{ hits = 0; final b = Box(); b.lst[1] = 8; return '${b.list} $hits'; }",
      ]),
    );

    test(
      'precedence and syntax of the checked forms parse and behave',
      () => run(
        [
          r"'${mi(true)! + 1} ${mi(true)! * 2 + mi(true)!} ${1 - mi(true)!}'",
          r"'${-mi(true)!} ${!mb(true)!} ${!(mb(true)!)}'",
          r"{ final Object o = 7; return '${(o as num) + 1} ${o as int} ${(o as int).isEven}'; }",
          r"{ final l = [1, 2]; return '${(id(l) as List<int>)[0]} ${(id(l) as List<int>)[1] + 1}'; }",
          r"{ final p = P(P(null, 3), 2); return '${p.next!.v! + p.v!} ${p.next!.next?.v}'; }",
          r'{ final P? p = id(null) as P?; return tryIt(() => p!.next!.v!); }',
          r'{ final f = (int? x) => x! + 1; return tryIt(() => f(null)) + tryIt(() => f(2)); }',
          r"{ final n = mi(true); return '${n!}${n}${[if (n! > 3) n]}${[for (final i in [1, 2]) if (mi(true)! > i) i]}'; }",
          r"{ final n = mi(true); return n! > 3 ? 'big' : 'small'; }",
          r"{ final l = <int?>[3, 4]; final i = mi(true)! - 3; return '${l[i]!}${l[i]! + l[i - 1]!}'; }",
          r"{ final b = mb(true); return b! ? 'y' : 'n'; }",
          r"{ final b = mb(true); return b! && !b ? 'y' : 'n'; }",
          r"{ int? a = mi(true); a = a! + a; return '$a'; }",
          r"{ final x = mi(true); return '${x!.toString()}${x!.isEven}${x!.abs()}'; }",
          r"{ final l = [1, 2, 3]; return '${l[0]++} ${l[1]--} ${++l[2]} $l'; }",
          r"{ final x = mi(true); return '${x! ~/ 2} ${x! % 3} ${x! ^ 1} ${x! << 1} ${x! is int}'; }",
          r"{ final x = mi(true); return '${x!.compareTo(3)}${-x!.abs()}${- -x!}'; }",
          r"{ final x = mi(true); return '${x! - -x!} ${x!-x!} ${x!/2}'; }",
          r"{ final x = mi(true); final y = mi(false); return '${y == null ? 0 : y!} ${x! > 2 && y == null}'; }",
        ],
        vm: {17: 'web: 2.0 is 2'},
      ),
    );

    test(
      'an out-of-range assignment through a non-plain receiver throws',
      () => run([
        r"{ final b = Box(); return tryIt(() => b.lst[9] = 1) + '${b.list}'; }",
        r"{ final List<int>? n = [1]; return tryIt(() => n![9] = 1) + '${n}'; }",
        r"{ return tryIt(() => f()![-1] = 1) + '$gl'; }",
        r"{ final l = <List<int>>[[1]]; return tryIt(() => l[0][5] = 1) + '$l'; }",
        r"{ final l = <List<int>>[[1]]; return tryIt(() => l[0][5] += 1) + '$l'; }",
        r"{ final l = <List<int>>[[1]]; return tryIt(() => (id(l[0]) as List<int>)[5] = 1) + '$l'; }",
        r"{ final Object o = [1]; return tryIt(() => (o as List<int>)[3]++) + '${o as List<int>}'; }",
      ]),
    );

    test(
      'insert, substring, codeUnitAt, take and skip out of range throw like dart2js',
      () => run([
        r"{ final l = [1, 2, 3]; return tryIt(() => l.insert(9, 1)) + '$l'; }",
        r'{ final l = [1, 2, 3]; return tryIt(() => l.elementAt(9)) ; }',
        r"{ final s = 'abc'; return tryIt(() => s.substring(5)); }",
        r"{ final s = 'abc'; return tryIt(() => s.substring(2, 1)); }",
        r"{ final s = 'abc'; return tryIt(() => s.codeUnitAt(9)); }",
        r'{ final l = [1, 2, 3]; return tryIt(() => l.take(-1).toList()); }',
        r'{ final l = [1, 2, 3]; return tryIt(() => l.skip(-1).toList()); }',
        r'{ final l = [1, 2, 3]; return tryIt(() => l.first.compareTo(1)) + tryIt(() => <int>[].last.compareTo(1)); }',
        r'{ final l = <int>[]; return tryIt(() => l.firstWhere((x) => x > 1)); }',
      ]),
    );

    test(
      'as: primitives, nulls, enums, dates and inherited classes',
      () => run(
        [
          r"{ final Object o = 5; return [tryIt(() => o as int), tryIt(() => o as num), tryIt(() => o as String), tryIt(() => o as Object), tryIt(() => o as dynamic), tryIt(() => o as Object?)].join(','); }",
          r"{ final Object? n = id(null); return [tryIt(() => n as Object?), tryIt(() => n as int?), tryIt(() => n as dynamic), tryIt(() => n as Object), tryIt(() => n as int), tryIt(() => n as String?), tryIt(() => n as List<int>?), tryIt(() => n as Map<String, dynamic>?)].join(','); }",
          r"{ final Object x = 2.5; final Object y = 3.0; return [tryIt(() => x as int), tryIt(() => y as int), tryIt(() => x as double), tryIt(() => x as num)].join(','); }",
          r"{ final Object i = 2; return [tryIt(() => i as double), tryIt(() => i as num)].join(','); }",
          r"{ final Object s = <int>{1}; return [tryIt(() => s as Set<int>), tryIt(() => s as Set), tryIt(() => s as Iterable), tryIt(() => s as List)].join(','); }",
          r"{ final Object e = Color.red; final Object s = 'red'; return [tryIt(() => e as Color), tryIt(() => e as String), tryIt(() => s as Color), tryIt(() => e as Enum), tryIt(() => e as Object)].join(','); }",
          r"{ final Object c = Sq(); return [tryIt(() => c as Sq), tryIt(() => c as Base), tryIt(() => c as Circle)].join(','); }",
          r"{ final Object d = DateTime(2020); final Object du = const Duration(seconds: 1); return [tryIt(() => d as DateTime), tryIt(() => d as Duration), tryIt(() => du as Duration), tryIt(() => du as DateTime)].join(','); }",
          r"{ final Object sb = StringBuffer(); return [tryIt(() => sb as StringBuffer), tryIt(() => sb as String), tryIt(() => sb as Object)].join(','); }",
          r"{ int? a = mi(true); double? d = a?.toDouble(); return '${(d as num).toInt()} ${(a as num) + 1} ${(a as int?)! + 1} ${(mi(false) as int?) ?? 7}'; }",
        ],
        vm: {2: 'web: 3.0 is an int in JS', 3: 'web: an int is a double in JS'},
      ),
    );

    test(
      'as to an interface an app class implements must not throw on a valid program',
      () => run([
        r"{ final Object e = Fancy.a; return [tryIt(() => e as Fancy), tryIt(() => e as Shape), tryIt(() => e as Color)].join(','); }",
        r"{ final Object c = Circle(); return [tryIt(() => c as Circle), tryIt(() => c as Shape), tryIt(() => c as Named), tryIt(() => c as Box)].join(','); }",
      ]),
    );

    test('as with type arguments or a record: dev checks only the outer type '
        '(accepted, documented)', () async {
      // By design: the lite has no reified generics (a JS array does not know
      // it is a `List<int>`) and a record is a plain array; testing the
      // arguments would cost a walk over every element on every cast. So
      // `as` verifies the outer type, the same as release (which checks
      // nothing). dart2js checks the arguments: those are the `web=` cells
      // that differ. The exact lite outputs are pinned here.
      final bodies = [
        r"{ final Object m = <String, int>{'a': 1}; return [tryIt(() => m as Map<String, int>), tryIt(() => m as Map<String, dynamic>), tryIt(() => m as Map), tryIt(() => m as List), tryIt(() => m as Map<int, int>)].join(','); }",
        r"{ final Object l = <int>[1]; return [tryIt(() => l as List<int>), tryIt(() => l as List<num>), tryIt(() => l as List), tryIt(() => l as List<dynamic>), tryIt(() => l as Iterable<int>), tryIt(() => l as List<String>), tryIt(() => l as Set<int>)].join(','); }",
        r"{ final List<dynamic> d = [1, 'a']; return [tryIt(() => d as List<int>), tryIt(() => d as List<Object>)].join(','); }",
        r"{ final Object c = Gen<int>(1); return [tryIt(() => c as Gen<int>), tryIt(() => c as Gen<String>), tryIt(() => c as Gen)].join(','); }",
        r"{ final Object r = (1, 'a'); final Object f = () => 1; return [tryIt(() => r as (int, String)), tryIt(() => r as (String, int)), tryIt(() => f as Function), tryIt(() => f as int Function()), tryIt(() => f as int)].join(','); }",
      ];
      final src =
          """
import 'package:thor_ui/thor_ui.dart';


${fns(bodies)}
class PState extends ThorState {
${[for (var i = 0; i < bodies.length; i++) '  String e$i() => t$i();'].join('\n')}
}
""";
      if (!_node) return markTestSkipped('node is not installed');
      final out = _run(
        await _translate(src, checks: true),
        'out.all = [${[for (var i = 0; i < bodies.length; i++) 'S.e$i()'].join(', ')}];',
      );
      expect(out['all'], [
        // E: the outer type is wrong. dart2js also throws on `Map<int, int>`.
        'ok,ok,ok,E,ok',
        // dart2js also throws on `List<String>` (an int list).
        'ok,ok,ok,ok,ok,ok,E',
        // dart2js throws on both (a `List<dynamic>` holding an int and a String).
        'ok,ok',
        // dart2js throws on `Gen<String>`.
        'ok,ok,ok',
        // dart2js also throws on `(String, int)`.
        'ok,ok,ok,ok,E',
      ]);
    });

    test(
      'an unnamed extension translates (it has no name to mangle)',
      () async {
        const src =
            _header +
            r"""
extension on String {
  String twice() => '$this$this';
  int get double2 => length * 2;
}
class XState extends ThorState {
  String x() => 'ab'.twice() + 'abc'.double2.toString();
}
""";
        final js = await _translate(src);
        final short = await _translate(src, shortNames: true);
        if (!_node) return markTestSkipped('node is not installed');
        expect(_run(js, 'out.x = S.x();')['x'], 'abab6');
        expect(_run(short, 'out.x = S.x();')['x'], 'abab6');
      },
    );

    test(
      'catching the dev checks: on RangeError, StateError, Error, Exception, rethrow, finally',
      () => run([
        r"{ final l = [1]; try { l[9]; return 'no'; } on RangeError catch (e) { return 'range'; } }",
        r"{ final l = [1]; try { l[9]; return 'no'; } on ArgumentError catch (e) { return 'arg'; } }",
        r"{ final l = [1]; try { l[9]; return 'no'; } on StateError catch (e) { return 'state'; } on Error catch (e) { return 'error'; } }",
        r"{ final l = [1]; try { try { l[9]; return 'no'; } on Exception catch (e) { return 'exc'; } } on Error catch (e) { return 'outer-error'; } }",
        r"{ final n = mi(false); try { n!; return 'no'; } on StateError catch (e) { return 'state'; } on Exception catch (e) { return 'exc'; } on Error catch (e) { return 'error'; } }",
        r"{ final n = mi(false); try { n!; return 'no'; } on RangeError catch (e) { return 'range'; } catch (e) { return 'other'; } }",
        r"{ final l = <int>[]; try { l.single; return 'no'; } on RangeError catch (e) { return 'range'; } on StateError catch (e) { return 'state'; } }",
        r"{ final l = <int>[]; try { l.removeLast(); return 'no'; } on StateError catch (e) { return 'state'; } on RangeError catch (e) { return 'range'; } }",
        r"{ final l = <int>[]; try { l.reduce((a, b) => a + b); return 'no'; } on StateError catch (e) { return 'state'; } }",
        r"{ final l = [1]; var s = ''; try { try { l[9]; } on RangeError { s += 'a'; rethrow; } finally { s += 'f'; } } on RangeError { s += 'b'; } return s; }",
        r"{ final n = mi(false); var s = ''; try { try { n!; } on StateError { s += 'x'; } finally { s += 'f'; } } on Error { s += 'e'; } return s; }",
        r"{ final l = [1]; try { l[9]; return 'no'; } catch (e, s) { return 'caught'; } }",
        r"{ final Object o = 'x'; try { o as int; return 'no'; } on Error catch (e) { return 'error'; } }",
        r"{ final Object o = 'x'; try { o as int; return 'no'; } on Exception catch (e) { return 'exc'; } catch (e) { return 'other'; } }",
      ], vm: {}),
    );

    test(
      'null-shorting through a bang is not a null check',
      () => run([
        r'{ final String? s = id(null) as String?; return tryIt(() => s?.length); }',
        r"{ final P? p = id(null) as P?; return tryIt(() => '${p?.next!.v}'); }",
        r'{ final P? p = id(null) as P?; return tryIt(() => p?.next!.v); }',
        r'{ final P? p = P(null, 1); return tryIt(() => p?.next!.v); }',
        r'{ final P? p = P(P(null, 5), 1); return tryIt(() => p?.next!.v!); }',
        r'{ final P? p = id(null) as P?; return tryIt(() => p?.next!); }',
        r'{ final List<int>? l = id(null) as List<int>?; return tryIt(() => l?[0]!); }',
        r'{ final List<int>? l = id(null) as List<int>?; return tryIt(() => l?.first); }',
        r'{ final List<int>? l = id(null) as List<int>?; return tryIt(() => l?[0]); }',
        r'{ final List<int>? l = [1]; return tryIt(() => l?[5]); }',
        r'{ final P p = P(null, 1); return tryIt(() => p.next?.next!.v); }',
        r'{ final P? p = id(null) as P?; return tryIt(() => (p?.v)!); }',
      ]),
    );

    test(
      'nulls print null in interpolation, toString, join and buffers',
      () => run(
        [
          r"{ final String? s = id(null) as String?; return '${s}|$s|a${null}b|${s.toString()}|${s?.length}|${s ?? 'd'}'; }",
          r"{ final int? n = id(null) as int?; final bool? b = id(null) as bool?; final double? d = id(null) as double?; return '$n|$b|$d|${n.toString()}|${b.toString()}|${d.toString()}|${n?.toString()}'; }",
          r"{ final l = <String?>['a', null, 'b']; return '${l.join(',')}|$l|${l.toString()}|${l.join()}|${l.first}|${l[1]}'; }",
          r"{ final l = <List<String?>>[['a', null], [null], []]; return '${l.join(';')}|$l|${l.map((x) => x.join('-')).join('/')}'; }",
          r"{ final l = <int?>[1, null, 3]; return '${l.join(',')}|$l|${l.where((x) => x != null).join(',')}'; }",
          r"{ final s = <String?>{'a', null}; return '${s.join('-')}|$s|${s.toList()}'; }",
          r"{ final m = <String, String?>{'a': null, 'b': 'x'}; return '${m['a']}|${m['zz']}|${m.values.join(',')}|${m.entries.map((e) => '${e.key}=${e.value}').join(',')}'; }",
          r"{ final sb = StringBuffer(); final String? s = id(null) as String?; sb.write(null); sb.write(s); sb.writeAll([1, 'x'], ','); sb.writeln(null); sb.write(1.5); sb.writeCharCode(65); return sb.toString(); }",
          r"{ final Color? c = id(null) as Color?; final cs = <Color?>[Color.red, null]; return '$c|${cs.join(',')}|$cs|${cs.first}'; }",
          r"{ final ns = <List<int>?>[[1, 2], null]; return '$ns|${ns.join('/')}|${[[1, 2], [3]].join(';')}|${[[1, 2], [3]]}'; }",
          r"{ final ss = <Set<int>>[{1, 2}, {3}]; return '$ss|${ss.join(';')}'; }",
          r"{ final o = Item(); return '${o.name}|${o.tag}|${o.n}|${o.kids}|${o.name.toString()}|${o.name ?? 'x'}|${o.name?.length}|${[o.name]}|${[o.name].join(',')}'; }",
          r"{ return '${opt()}|${opt(a: 'x')}|${opt(b: 3)}|${[opt()]}|${opt().length}'; }",
          r"{ final f = (String? s) => '$s|${s.toString()}'; return f(null) + f('a'); }",
          r"{ final l = List<String?>.filled(2, null); final g = List<String?>.generate(2, (i) => i == 0 ? null : 'x'); return '$l|${l.join(',')}|$g|${g.join(',')}'; }",
          r"{ final m = <String, int>{'a': 1}; return '${m['zz']}|${m['a']}|${m['zz']?.isEven}|${[m['zz']]}|${[m['zz']].join(',')}'; }",
          r"{ final Item? o = id(null) as Item?; return '${o?.name}|${o?.n}|${o?.kids}'; }",
          r"{ final s = <int?>[null]; return '${s.map((x) => x).join(',')}|${s.map((x) => x).toList()}|${s.reversed.join(',')}|${s.take(1).join(',')}|${s.toSet().join(',')}'; }",
          r"{ int? late1; String? late2; return '${late1}|${late2}|${[late1]}|${[late2]}'; }",
          r"{ int? k; if (mi(true)! > 9) k = 1; return '$k|${k ?? -1}'; }",
          r"{ final l = [1, 2, 3]; final e = <int>[]; return '${l.join(', ')}|${e.join(',')}|${[e]}|${[<int>[]].join(',')}'; }",
          r"{ final x = NullTag(); return '${x.a}|${x.b}|${null.tag()}|${(id(null) as String?).orEmpty()}|${NullTag.nothing().a}'; }",
        ],
        vm: {},
        checked: false,
      ),
    );

    test(
      'toString of a nullable enum prints null',
      () => run([
        r'{ final Color? c = id(null) as Color?; return c.toString(); }',
        r'{ final Color? c = Color.red; return c.toString(); }',
      ], checked: false),
    );

    test(
      'StringBuffer.writeAll prints null elements as null',
      () => run([
        r"{ final sb = StringBuffer(); sb.writeAll([null, 1, 'x'], ','); return sb.toString(); }",
        r"{ final sb = StringBuffer(); final l = <String?>[null, 'a']; sb.writeAll(l); return sb.toString(); }",
      ], checked: false),
    );

    test(
      'checked forms in statements, closures, calls and patterns',
      () => run([
        r"{ final List<int>? x = [1, 2]; var s = 0; for (final e in x!) { s += e; } var i = 0; while (x!.length > i) { i++; } return '$s $i'; }",
        r"{ final int? x = mi(true); var y = 1; y += x!; y *= x!; int? z; z ??= x!; return '$y $z ${switch (x!) { 4 => 'four', _ => 'other' }}'; }",
        r"{ final int? x = mi(true); switch (x!) { case 4: return 'four'; default: return 'other'; } }",
        r"{ final void Function(int)? cb = (int v) {}; final int Function()? g2 = () => 3; return '${g2!()} ${g2!() + 1}' + tryIt(() => cb!(1)); }",
        r'{ final void Function()? cb = id(null) as void Function()?; return tryIt(() => cb!()); }',
        r"{ final Object o = [1, 2]; if (o is List && o.isNotEmpty) { return '${(o as List<int>)[0]} ${(o as List<int>)[1]}'; } return 'no'; }",
        r'{ final P p = P(P(null, 1), null); return tryIt(() => p.v!) + tryIt(() => p.next!.v!) + tryIt(() => p.next!.next!.v!); }',
        r'{ final l = <int?>[1, null]; return tryIt(() => l[0]! + 1) + tryIt(() => l[1]! + 1) + tryIt(() => l[2]! + 1); }',
        r"{ final m = <String, List<int>>{'a': [1]}; return tryIt(() => m['a']![0]) + tryIt(() => m['a']![3]) + tryIt(() => m['b']![0]); }",
        r"{ final b = Box(); b.list.add(4); return '${b.list[3]} ${b.list.last} ${b.list.first} ${b.list.length}' + tryIt(() => b.list[4]); }",
        r"{ final l = [1, 2, 3]; var s = ''; for (var i = 0; i <= 3; i++) { try { s += '${l[i]}'; } on RangeError { s += '!'; } } return s; }",
        r'{ final l = <int>[]; return tryIt(() => l.first) + tryIt(() => l.last) + tryIt(() => l.removeAt(0)) + tryIt(() => l.sublist(0, 0)) + tryIt(() => l.sublist(1)); }',
        r'{ final l = [3, 1, 2]; final i = l.indexOf(9); return tryIt(() => l[i]) + tryIt(() => l[l.length]) + tryIt(() => l[l.length - 1]); }',
        r"{ final s = 'abc'; final i = s.indexOf('z'); return tryIt(() => s[i]) + tryIt(() => s[3]) + '${s[2]}'; }",
        r"{ final l = [1, 2, 3]; final r = l.map((x) => l[x - 1]).toList(); final q = [for (var i = 0; i < 3; i++) l[i]]; return '$r $q'; }",
        r"{ var l = <int>[1, 2, 3]; final n = l.length; l = [for (var i = 0; i < n; i++) if (l[i].isOdd) l[i]]; return '$l'; }",
      ]),
    );

    test(
      'checks with short names still parse and behave like the readable dev build',
      () async {
        final bodies = [
          r"'${mi(true)! + 1} ${-mi(true)!} ${!mb(true)!} ${(id([1, 2]) as List<int>)[1]}'",
          r"{ final l = [1, 2, 3]; l[1] += 5; l..[0] = 9; return '$l ${l[2]} ${tryIt(() => l[7])} ${tryIt(() => mi(false)!)}'; }",
          r"{ final n = mi(true); return '${[if (n! > 3) n]} ${[for (final i in [1, 2]) l2[i]]}'; }",
        ];
        final src =
            """
import 'package:thor_ui/thor_ui.dart';


${fns(bodies)}
List<int> l2 = [0, 5, 6];
class PState extends ThorState {
${[for (var i = 0; i < bodies.length; i++) '  String e$i() => t$i();'].join('\n')}
}
""";
        final script =
            'out.all = [${[for (var i = 0; i < bodies.length; i++) 'S.e$i()'].join(', ')}];';
        final readable = _run(await _translate(src, checks: true), script);
        final short = _run(
          await _translate(src, shortNames: true, checks: true),
          script,
        );
        expect(short, readable);
      },
    );

    test(
      'number semantics: what agrees between VM, web and lite',
      () => run(
        [
          r"{ return '${(1e21).toStringAsFixed(2)} ${(1.005).toStringAsFixed(2)} ${(2.5).toStringAsFixed(0)} ${(0.5).toStringAsFixed(0)} ${(1234.5678).toStringAsFixed(3)} ${(1e-10).toStringAsFixed(3)} ${(-1.5).toStringAsFixed(0)} ${(10.0).toStringAsFixed(20)}'; }",
          r"{ return '${(3.5).toInt()} ${(-3.5).toInt()} ${(2.5).round()} ${(-2.5).round()} ${(2.5).floor()} ${(-2.5).ceil()}'; }",
          r"{ final s = '😀a'; return '${s.length} ${s.substring(0, 1).length} ${s[0].codeUnitAt(0)} ${s.split('').length} ${s.codeUnitAt(2)}'; }",
          r"{ return '${RegExp(r'(a)|(b)').firstMatch('b')!.group(1)} ${'abc'.contains(RegExp('B', caseSensitive: false))} ${RegExp(r'^\w+$').hasMatch('ñ')} ${RegExp(r'\s').hasMatch(' ')} ${RegExp(r'.').hasMatch('\n')}'; }",
          r"{ final now = DateTime(2024, 1, 31); return '${DateTime(2024, 2, 30)} ${now.add(const Duration(days: 30))} ${DateTime(2024, 13, 1)} ${now.weekday} ${DateTime(2024, 3, 10, 25)} ${DateTime.utc(2024).toIso8601String()} ${DateTime.utc(2024, 1, 1, 0, 0, 0, 5)} ${DateTime.utc(2024, 1, 1).difference(DateTime.utc(2023, 1, 1)).inDays}'; }",
          r"{ return '${Duration(seconds: 90)} ${Duration(milliseconds: 1500)} ${Duration(hours: 25, minutes: 3)} ${const Duration(seconds: -5)} ${Duration(days: 1).inHours} ${Duration(microseconds: 5)}'; }",
          r"{ final m = <int, String>{2: 'b', 1: 'a', 10: 'z'}; final s = <int>{3, 1, 2}; return '${m.keys.toList()} ${m.values.toList()} ${s.toList()} ${s.union({0}).toList()} ${m.entries.map((e) => e.key).toList()}'; }",
          r"{ return '${Uri.encodeComponent('a b&c/é')} ${Uri.encodeFull('a b/é')} ${Uri.decodeComponent('a%20b')}'; }",
          r"{ return '${'abc'.substring(1)} ${'abc'.substring(1, 1)} ${'abc'.startsWith('b', 1)} ${'abc'.endsWith('')} ${'a\tb'.contains('\t')} ${'Hello'.split('l')} ${'a b  c'.split(' ')} ${'abc'.toString()} ${'%'.codeUnitAt(0)} ${'é'.length}'; }",
        ],
        checked: false,
        imports: "import 'dart:convert';\nimport 'dart:math' as math;",
      ),
    );

    test(
      'number semantics: the listed double differences (integral doubles print as ints)',
      () => run(
        [
          r"{ final l = [3, 1, 2]; final w = ['b10', 'a2', 'B1', 'a10']; w.sort(); l.sort((a, b) => b - a); return '$l $w ${[1.5, 1, 2.5].reduce((a, b) => a > b ? a : b)} ${[0.1, 0.2, 0.3].fold(0.0, (a, b) => a + b)} ${[1, 2, 3].map((x) => x / 2).toList()} ${[1, 2, 3].fold(0, (a, b) => a + b) / 3}'; }",
          r"{ return '${identical(1, 1)} ${1 == 1.0} ${[1] == [1]} ${double.nan == double.nan} ${double.nan.isNaN} ${(0.1 + 0.2 == 0.3)} ${1 / 3 * 3 == 1} ${5 ~/ 2 * 2.0}'; }",
          r"{ final i = 5; final d = 2.0; final n = i > 3 ? 1 : 2.5; return '${i / d} ${i * d} ${i + d} ${n} ${(i * 1.0)} ${i.toDouble()} ${d.toInt()} ${(i as num) / 2} ${i.isEven} ${d.isFinite} ${d.sign} ${i.sign} ${(-i).abs()} ${i.clamp(0, 3)} ${d.clamp(0, 1)}'; }",
        ],
        checked: false,
        vm: {0: 'web: numbers', 1: 'web: numbers', 2: 'web: numbers'},
        imports: "import 'dart:convert';\nimport 'dart:math' as math;",
      ),
    );

    test(
      'an int past 2^53 or a 64-bit overflow differs between VM and web and is not listed',
      () => run(
        [
          r"{ return '${int.parse('9007199254740993')} ${int.parse('9223372036854775807')} ${int.parse('9007199254740992') + 1} ${int.parse('4611686018427387904') * 2}'; }",
          r"{ final big = double.parse('1e20'); return '${big.toInt()} ${big.round()} ${big.floor()} ${double.parse('1e300').toInt()}'; }",
          r"{ return '${math.sqrt(16)} ${math.pow(2, 3)} ${math.pow(2, 0.5)} ${math.pow(2.0, 3)} ${math.max(1, 2.0)} ${math.max(1, 2)} ${math.min(1.0, 2)} ${math.sin(0)} ${math.cos(0)} ${math.pi} ${math.e} ${math.log(1)} ${math.exp(0)} ${math.atan2(1, 1)} ${math.pow(2, -1)} ${math.pow(10, 21)} ${math.pow(0, 0)}'; }",
        ],
        checked: false,
        // By design the web has one number type: an int
        // past 2^53 loses digits, a 64-bit overflow does not wrap, an
        // integral double prints as an int, pow(10, 21) is 1e+21.
        vm: {
          0: 'web: ints are doubles',
          1: 'web: ints are doubles',
          2: 'web: ints are doubles',
        },
        imports: "import 'dart:convert';\nimport 'dart:math' as math;",
      ),
    );

    test(
      'toUpperCase of ß differs between VM and web and is not listed',
      () => run(
        [
          r"{ return 'ß'.toUpperCase() + 'İ'.toLowerCase() + 'ǅ'.toLowerCase() + 'ﬃ'.toUpperCase() + 'Σ'.toLowerCase() + 'ΑΣ'.toLowerCase(); }",
        ],
        checked: false,
        // By design: JS (and dart2js) map case with the full Unicode tables
        // (`ß` to `SS`, final sigma); the VM keeps the simple mapping.
        vm: {0: 'web: full Unicode case mapping'},
        imports: "import 'dart:convert';\nimport 'dart:math' as math;",
      ),
    );

    test(
      'integer division and modulo by zero throw like dart2js',
      () => run(
        [
          r"{ final z = int.parse('0'); return tryIt(() => 1 ~/ z) + tryIt(() => 5 % z) + '${(5 / z)}'; }",
        ],
        checked: true,
        // VM: `%` by zero throws too; dart2js gives NaN (only `~/` throws).
        vm: {0: 'web: % by zero is NaN'},
        imports: "import 'dart:convert';\nimport 'dart:math' as math;",
      ),
    );

    test(
      'int.tryParse and double.tryParse accept what dart2js rejects',
      () => run(
        [
          r"{ return '${int.tryParse('0x10')} ${int.tryParse('1e3')} ${int.tryParse(' 5')} ${int.tryParse('+5')} ${int.tryParse('5 ')} ${double.tryParse('1_0')} ${double.tryParse('.5')} ${double.tryParse('5.')} ${double.tryParse('1e3')} ${double.tryParse('Infinity')} ${double.tryParse('NaN')} ${double.tryParse('0x10')} ${double.tryParse('-')}'; }",
        ],
        checked: false,
        vm: {0: 'web: an integral double is an int'},
        imports: "import 'dart:convert';\nimport 'dart:math' as math;",
      ),
    );

    test(
      'negative zero and parsing: what agrees (printing -0.0 is a listed '
      'web difference, see the next test)',
      () => run(
        [
          r"{ final x = -0.0; return '${x == 0} ${(-0.4).round()} ${(-0.4).toStringAsFixed(0)} ${(-0.0).abs()} ${1 / x}'; }",
          r"{ return '${double.parse('1e3')} ${double.parse('  7  ')} ${num.parse('7')} ${num.parse('7.0')} ${num.parse('1e2')} ${int.parse('-0')}'; }",
          r"{ return '${jsonEncode({'a': 1.0, 'b': [1, 2.5], 'c': null, 'd': 'é\n'})}'; }",
        ],
        checked: false,
        vm: {0: 'web: numbers', 1: 'web: numbers', 2: 'web: numbers'},
        imports: "import 'dart:convert';\nimport 'dart:math' as math;",
      ),
    );

    test(
      '-0.0 prints 0 in the lite (by design: web, listed in docs)',
      () async {
        // dart2js prints `-0.0` (its own number formatter) and JS `0`; the
        // formatter would cost bytes on every double interpolation.
        final js = await _translate(
          _header +
              r'''
class ZState extends ThorState {
  String z() { final x = -0.0; return '$x ${x.toStringAsFixed(1)}'; }
}
''',
        );
        if (!_node) return markTestSkipped('node is not installed');
        expect(_run(js, 'out.z = S.z();')['z'], '0 0.0');
      },
    );

    test(
      'padLeft with a pad of several characters',
      () => run(
        [
          r"{ return '${'a,b,,c'.split(',')} ${''.split(',')} ${'abc'.split('')} ${'  x '.trim()} ${'x'.padLeft(3, 'ab')} ${'abc'.replaceAll('', '-')} ${'aaa'.replaceFirst('a', 'b')} ${'abc'.indexOf('')} ${'abc'.lastIndexOf('')} ${'abc'.compareTo('abd')} ${'a'.compareTo('B')}'; }",
        ],
        checked: false,
        imports: "import 'dart:convert';\nimport 'dart:math' as math;",
      ),
    );

    test(
      'right shifts of negatives are dart2js\'s (unsigned 32 bits); '
      'large doubles print like JS',
      () => run(
        [
          r"{ final z = int.parse('0'); final m = int.parse('-1'); return '${1 << 32} ${1 << 31} ${0xFFFFFFFF + 1} ${(1 << 40) >> 3} ${(m + z) >> 1} ${(-8 + z) >> 1} ${m >> 40} ${0xFFFFFFFF & 0x1FFFFFFFF} ${5 | (1 << 33)} ${~5} ${7 ^ 2}'; }",
          // Runtime values: dart2js folds a literal's text itself (`1e21`
          // as digits), the running program prints like JS.
          r"{ final z = int.parse('0'); return '${1e21 + z} ${1e-7} ${123456789012345680000.0 + z} ${1e20 + z} ${0.000001} ${1.5e300 * 1e10} ${5e-324}'; }",
        ],
        checked: false,
        // By design (web): bit operations are 32-bit unsigned (`1 << 32` is 0,
        // `-1 >> 1` is 4294967295), an integral double prints as an int.
        vm: {0: 'web: 32-bit bit operations', 1: 'web: numbers'},
        imports: "import 'dart:convert';\nimport 'dart:math' as math;",
      ),
    );

    test(
      'double literals from 2^63 up are themselves (not saturated ints)',
      () => run(
        [
          r"{ final z = int.parse('0'); return '${1e20 + z} ${123456789012345680000.0 + z} ${9.3e18 + z} ${1e19 + z} ${1e18 + z} ${2e21 + z}'; }",
          r"{ final z = int.parse('0'); return '${1e20 + 1 + z} ${(1e20 + z).toStringAsFixed(0)} ${1e20 > 1e19} ${1e19 < 1e20} ${9.3e18 > 9223372036854775807.0}'; }",
        ],
        checked: false,
        vm: {0: 'web: numbers', 1: 'web: numbers'},
      ),
    );
  });

  test(
    'adversarial: typed parts of a multi-argument value in lite '
    '(DateTime, double, bool, enum, int) and what a tampered one does',
    () async {
      final js = await _translate('''
$_header
enum Role { admin, guest }

class TypesState extends ThorState {
  final log = state('');

  void mix(DateTime when, double price, bool on) =>
      log.value = '\${when.toIso8601String()}|\$price|\$on';
  void roles(Role role, int n, String rest) =>
      log.value = '\${role.name}|\$n|\$rest';
  void tail(String a, int n) => log.value = '\$a|\$n';
}
''');
      if (!_node) return markTestSkipped('node is not installed');
      final out = _run(js, r'''
const tries = {};
const t = (name, f) => { try { f(); tries[name] = S.log(); } catch (e) { tries[name] = 'throws ' + (e?.name ?? e) + ' ' + e?.message; } };
// What the server writes for a bound call: DateTime.toString, double.toString.
t('ok', () => S.mix('2024-01-02 03:04:05.000~1e+21~true'));
t('okRole', () => S.roles('guest~7~x~y'));
t('nan', () => S.mix('2024-01-02~NaN~false'));
t('negZero', () => S.roles('admin~-0~z'));
t('badEnum', () => S.roles('root~7~x'));
t('enumByIndex', () => S.roles('1~7~x'));
t('badInt', () => S.roles('admin~1e3~x'));
t('badDate', () => S.mix('nope~1~true'));
t('badDouble', () => S.mix('2024-01-02~1,5~true'));
t('fourth', () => S.tail('a~1~2'));
t('missing', () => S.tail('a'));
t('big', () => S.tail('a~9007199254740993'));
out.tries = tries;
''');
      final tries = out['tries']! as Map;
      expect(tries['ok'], endsWith('|1e+21|true'));
      expect(tries['okRole'], 'guest|7|x~y');
      expect(tries['nan'], '2024-01-02T00:00:00.000|NaN|false');
      for (final k in [
        'badEnum',
        'enumByIndex',
        'badInt',
        'badDate',
        'badDouble',
      ]) {
        expect(tries[k], startsWith('throws'), reason: '$k: ${tries[k]}');
      }
      // A missing part is an empty String, or a FormatException for an int.
      expect(tries['missing'], startsWith('throws'));
      // `fourth`: 'a~1~2' has two parts for (String, int): the int is '1~2'.
      expect(tries['fourth'], startsWith('throws'));
      // Accepted: JavaScript numbers are doubles, so an int past 2^53 rounds
      // (dart2js does the same; the docs keep ids below it).
      expect(tries['big'], 'a|9007199254740992');
    },
  );
}
