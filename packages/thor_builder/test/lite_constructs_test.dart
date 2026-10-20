// Constructs the lite translator supports: each runs as lite JS in node and
// must print what the same Dart prints on the web (dart2js).
@Timeout(Duration(minutes: 3))
library;

import 'package:test/test.dart';
import 'package:thor_lints/lite.dart';

import 'lite_oracle.dart';

void main() {
  group('futures', () {
    test(
      'Future.wait keeps the order of the futures, not of completion',
      () async {
        await sameAsWeb(r"""
Future<String> t0() async {
  final r = await Future.wait([
    Future.delayed(const Duration(milliseconds: 20), () => 1),
    Future.value(2),
    Future.delayed(const Duration(milliseconds: 5), () => 3),
  ]);
  return '$r ${r.length}';
}
Future<String> t1() async {
  final r = await Future.wait(<Future<int>>[]);
  return '$r';
}
Future<String> t2() async {
  final a = Future.delayed(const Duration(milliseconds: 5), () => 'a');
  final b = Future.value('7');
  final r = await Future.wait([a, b]);
  return '${r[0]}${r[1]}';
}
""", 3);
      },
    );

    test(
      'Future.wait with one failure: the error, after all are done',
      () async {
        await sameAsWeb(r"""
Future<String> t0() async {
  final log = <String>[];
  Future<int> ok(int ms, int v) => Future.delayed(Duration(milliseconds: ms), () { log.add('ok$v'); return v; });
  Future<int> bad(int ms) => Future.delayed(Duration(milliseconds: ms), () { log.add('bad'); throw StateError('boom'); });
  try {
    await Future.wait([ok(30, 1), bad(5), ok(10, 2)]);
  } on StateError catch (e) {
    log.add('caught $e');
  }
  return log.join(',');
}
// With eagerError the result fails at once; the others still finish.
Future<String> t1() async {
  final log = <String>[];
  Future<int> ok(int ms, int v) => Future.delayed(Duration(milliseconds: ms), () { log.add('ok$v'); return v; });
  Future<int> bad(int ms) => Future.delayed(Duration(milliseconds: ms), () { log.add('bad'); throw StateError('boom'); });
  try {
    await Future.wait([ok(30, 1), bad(5)], eagerError: true);
  } on StateError catch (e) {
    log.add('caught $e');
  }
  await Future.delayed(const Duration(milliseconds: 50));
  return log.join(',');
}
// Two failures: the first to happen is the one reported.
Future<String> t2() async {
  Future<int> bad(int ms, String m) => Future.delayed(Duration(milliseconds: ms), () => throw StateError(m));
  try {
    await Future.wait([bad(20, 'late'), bad(5, 'early')]);
    return 'no error';
  } on StateError catch (e) {
    return '$e';
  }
}
""", 3);
      },
    );

    test('.then chains: values, futures returned and the order', () async {
      await sameAsWeb(r"""
Future<String> t0() async {
  final r = await Future.value(2)
      .then((v) => v * 10)
      .then((v) => Future.delayed(const Duration(milliseconds: 3), () => v + 1))
      .then((v) => 'got $v');
  return r;
}
Future<String> t1() async {
  final log = <String>[];
  final f = Future.value(1).then((v) { log.add('then $v'); });
  log.add('sync');
  await f;
  return log.join(',');
}
""", 2);
    });

    test(
      'an error thrown in .then goes down the chain to catchError',
      () async {
        await sameAsWeb(r"""
Future<String> t0() async {
  final log = <String>[];
  final r = await Future.value(1)
      .then((v) { log.add('a'); throw StateError('in a'); })
      .then((v) { log.add('b'); return 'b'; })
      .catchError((Object e) { log.add('caught ${e is StateError}'); return 'recovered'; })
      .then((v) { log.add('after $v'); return v; });
  return '$r ${log.join(',')}';
}
// onError of then handles what came before it, not what its own onValue throws.
Future<String> t1() async {
  final log = <String>[];
  try {
    await Future<int>.error(StateError('first')).then(
      (v) { log.add('value'); return 1; },
      onError: (Object e) { log.add('onError ${e is StateError}'); throw ArgumentError('second'); },
    );
  } on ArgumentError catch (e) {
    log.add('outer $e');
  }
  return log.join(',');
}
// catchError(test:) lets a non-matching error through.
Future<String> t2() async {
  try {
    await Future<int>.error(StateError('s')).catchError((Object e) => 0, test: (e) => e is ArgumentError);
    return 'swallowed';
  } on StateError catch (e) {
    return 'passed $e';
  }
}
Future<String> t3() async {
  final v = await Future<int>.error(ArgumentError('x')).catchError((Object e) => 7, test: (e) => e is ArgumentError);
  return '$v';
}
""", 4);
      },
    );

    test(
      'whenComplete runs on success and failure, and its error wins',
      () async {
        await sameAsWeb(r"""
Future<String> t0() async {
  final log = <String>[];
  final v = await Future.value(5).whenComplete(() => log.add('done'));
  try {
    await Future<int>.error(StateError('x')).whenComplete(() => log.add('done2'));
  } on StateError catch (e) {
    log.add('err $e');
  }
  return '$v ${log.join(',')}';
}
Future<String> t1() async {
  try {
    await Future<int>.error(StateError('first')).whenComplete(() => throw ArgumentError('second'));
    return 'no';
  } on ArgumentError catch (e) {
    return 'replaced $e';
  } on StateError {
    return 'kept';
  }
}
// The action's value is ignored; a future it returns is awaited.
Future<String> t2() async {
  final log = <String>[];
  final v = await Future.value(1).whenComplete(() => Future.delayed(const Duration(milliseconds: 5), () => log.add('slept')));
  return '$v ${log.join(',')}';
}
""", 3);
      },
    );

    test('Future.error, sync, microtask, any, forEach, doWhile', () async {
      await sameAsWeb(r"""
Future<String> t0() async {
  try {
    await Future<void>.error('plain');
    return 'no';
  } on String catch (e) {
    return 'caught $e';
  }
}
Future<String> t1() async {
  final a = await Future.sync(() => 4);
  final b = await Future.microtask(() => 5);
  try {
    await Future<int>.sync(() => throw StateError('sync'));
  } on StateError catch (e) {
    return '$a $b $e';
  }
  return 'no';
}
Future<String> t2() async {
  final r = await Future.any([
    Future.delayed(const Duration(milliseconds: 30), () => 'slow'),
    Future.delayed(const Duration(milliseconds: 3), () => 'fast'),
  ]);
  return r;
}
Future<String> t3() async {
  final seen = <int>[];
  await Future.forEach([3, 1, 2], (int x) async {
    await Future.delayed(Duration(milliseconds: x));
    seen.add(x);
  });
  var n = 0;
  await Future.doWhile(() async {
    n++;
    return n < 4;
  });
  return '$seen $n';
}
""", 4);
    });
  });

  group('Completer', () {
    test('complete, completeError, future, isCompleted', () async {
      await sameAsWeb(r"""
Future<String> t0() async {
  final c = Completer<int>();
  final log = <String>[];
  log.add('${c.isCompleted}');
  Future.delayed(const Duration(milliseconds: 3), () => c.complete(42));
  final v = await c.future;
  log.add('$v ${c.isCompleted}');
  return log.join(',');
}
Future<String> t1() async {
  final c = Completer<void>();
  c.complete();
  await c.future;
  final d = Completer<String>();
  d.completeError(StateError('bad'));
  try {
    await d.future;
  } on StateError catch (e) {
    return 'done $e ${d.isCompleted}';
  }
  return 'no';
}
// A Completer completed twice is a StateError, and the first value stays.
Future<String> t2() async {
  final c = Completer<int>();
  c.complete(1);
  var msg = '';
  try {
    c.complete(2);
  } on StateError catch (e) {
    msg = '$e';
  }
  try {
    c.completeError(ArgumentError('late'));
  } on StateError catch (e) {
    msg += '|$e';
  }
  return '${await c.future} $msg';
}
// A listener added after completion still hears it; completing with a future.
Future<String> t3() async {
  final c = Completer<int>();
  c.complete(Future.delayed(const Duration(milliseconds: 3), () => 9));
  final log = <String>['${c.isCompleted}'];
  log.add('${await c.future}');
  final done = Completer<String>();
  final seen = done.future.then((v) => 'then $v');
  done.complete('x');
  log.add(await seen);
  return log.join(',');
}
""", 4);
    });
  });

  group('iterables', () {
    test('nonNulls, indexed, cast, whereType', () async {
      await sameAsWeb(r"""
String t0() {
  final l = <int?>[1, null, 3, null];
  final s = <String?>{'a', null, 'b'};
  return '${l.nonNulls.toList()} ${s.nonNulls.length} ${<int?>[].nonNulls.isEmpty}';
}
String t1() {
  final out = <String>[];
  for (final (i, x) in ['a', 'b', 'c'].indexed) {
    out.add('$i$x');
  }
  for (final e in {'x', 'y'}.indexed) {
    out.add('${e.$1}${e.$2}');
  }
  return out.join(',') + ' ' + ['p', 'q'].indexed.map((e) => '${e.$1}:${e.$2}').join('|');
}
// A cast list is a view: what the original gains shows through.
String t2() {
  final Object o = <int>[1, 2];
  final base = <Object>[1, 2, 3];
  final view = base.cast<int>();
  base.add(4);
  final sum = view.fold<int>(0, (a, b) => a + b);
  final ints = (o as List).cast<int>().map((x) => x * 2).toList();
  final set = <Object>{1, 2}.cast<int>();
  final m = <Object, Object>{'a': 1}.cast<String, int>();
  return '$sum ${view.length} $ints ${set.length} ${m['a']}';
}
String t3() {
  final mixed = <Object?>[1, 'a', 2.5, null, 'b', 3, true, <int>[1]];
  final ints = mixed.whereType<int>().toList();
  final strs = mixed.whereType<String>().toList();
  final nums = mixed.whereType<num>().length;
  final bools = mixed.whereType<bool>().length;
  final lists = mixed.whereType<List>().length;
  return '$ints $strs $nums $bools $lists';
}
String t4() {
  final os = <Object>{1, 'a', 2};
  return '${os.whereType<int>().toList()} ${os.whereType<String>().first}';
}
""", 5);
    });

    test('whereType over the app\'s classes', () async {
      await sameAsWeb(r"""
class Animal { final String name; Animal(this.name); }
class Dog extends Animal { Dog(super.name); }
class Cat extends Animal { Cat(super.name); }
String t0() {
  final zoo = <Animal>[Dog('rex'), Cat('tom'), Dog('fido')];
  return '${zoo.whereType<Dog>().map((d) => d.name).join(',')} ${zoo.whereType<Cat>().length}';
}
""", 1);
    });
  });

  group('maps', () {
    test('update, updateAll, removeWhere, addEntries', () async {
      await sameAsWeb(r"""
String t0() {
  final m = <String, int>{'a': 1, 'b': 2};
  final r1 = m.update('a', (v) => v + 10);
  final r2 = m.update('c', (v) => v + 1, ifAbsent: () => 100);
  m.updateAll((k, v) => v * 2);
  m.removeWhere((k, v) => v == 4);
  m.addEntries([MapEntry('z', 0), MapEntry('a', -1)]);
  return '$r1 $r2 ${m.entries.map((e) => '${e.key}=${e.value}').join(',')}';
}
// A missing key without ifAbsent is an ArgumentError, the map untouched.
String t1() {
  final m = <String, int>{'a': 1};
  try {
    m.update('nope', (v) => v);
    return 'no';
  } on ArgumentError {
    return 'argument error ${m.length}';
  }
}
// update can change the value type of a counter and keeps the order.
String t2() {
  final counts = <String, int>{};
  for (final w in 'a b a c b a'.split(' ')) {
    counts.update(w, (n) => n + 1, ifAbsent: () => 1);
  }
  return counts.entries.map((e) => '${e.key}${e.value}').join(' ');
}
""", 3);
    });

    test(
      'Map.map, fromEntries, fromIterable, fromIterables, entries',
      () async {
        await sameAsWeb(r"""
String t0() {
  final m = {'a': 1, 'b': 2, 'c': 3};
  final inv = m.map((k, v) => MapEntry(v, k));
  final up = m.map((k, v) => MapEntry(k.toUpperCase(), v * v));
  // Two entries with one key: the last wins, at the first one's place.
  final clash = m.map((k, v) => MapEntry('k', v));
  return '${inv.entries.map((e) => '${e.key}${e.value}').join()} ${up.keys.join()} ${up.values.join()} ${clash.length} ${clash['k']}';
}
String t1() {
  final a = Map.fromEntries([MapEntry('x', 1), MapEntry('y', 2), MapEntry('x', 3)]);
  final b = Map<String, int>.fromEntries(['p', 'qq'].map((s) => MapEntry(s, s.length)));
  final c = Map<String, int>.fromIterable([1, 2, 3], key: (x) => 'k${x as int}', value: (x) => (x as int) * 10);
  final d = Map.fromIterables(['u', 'v'], [7, 8]);
  final e = Map<int, int>.fromIterable([4, 5]);
  final f = Map<int, int>.fromIterable([4, 5]);
  return '${a.length}${a['x']} ${b['qq']} ${c['k2']} ${d['v']} ${e[5]}';
}
String t2() {
  final m = {'one': 1, 'two': 2, 'three': 3};
  final sorted = m.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  final top = sorted.first;
  final total = m.entries.fold<int>(0, (s, e) => s + e.value);
  return '${top.key} $total ${m.entries.where((e) => e.value > 1).map((e) => e.key).join()}';
}
""", 3);
      },
    );
  });

  group('String.split with a RegExp', () {
    test('matches dart:core on the edges', () async {
      await sameAsWeb(r"""
String t0() => '${'a1b22c'.split(RegExp(r'\d+'))} ${'a, b,c ,d'.split(RegExp(r'\s*,\s*'))}';
// Leading, trailing and consecutive separators.
String t1() => '${',a,,b,'.split(RegExp(','))} ${'12'.split(RegExp(r'\d'))} ${''.split(RegExp(','))}';
// Captured groups are not part of the result.
String t2() => '${'a1b2c'.split(RegExp(r'(\d)'))} ${'x-y_z'.split(RegExp(r'([-_])'))}';
// Empty matches: between every character, none at the ends.
String t3() => '${'abc'.split(RegExp(''))} ${'abc'.split(RegExp(r'x*'))} ${'a b'.split(RegExp(r'\b'))}';
String t4() => '${'Hello World'.split(RegExp('o', caseSensitive: false)).length} ${'line1\nline2\r\nline3'.split(RegExp(r'\r?\n'))}';
String t5() => '${'a😀b'.split(RegExp(''))}';
""", 6);
    });

    test('indexOf and startsWith with a RegExp', () async {
      await sameAsWeb(r"""
String t0() => '${'ab12cd34'.indexOf(RegExp(r'\d'))} ${'ab12cd34'.indexOf(RegExp(r'\d'), 3)} ${'abc'.indexOf(RegExp(r'\d'))} ${'abc'.indexOf(RegExp(r'c'), 3)}';
String t1() => '${'12ab'.startsWith(RegExp(r'\d+'))} ${'ab12'.startsWith(RegExp(r'\d'))} ${'ab12'.startsWith(RegExp(r'\d'), 2)} ${'xx'.startsWith(RegExp(''))}';
""", 2);
    });
  });

  group('mixins on plain classes', () {
    test('methods, getters, fields and the order of resolution', () async {
      await sameAsWeb(r"""
mixin Named {
  String name = 'anon';
  String hello() => 'hi $name';
  String get shout => name.toUpperCase();
}
mixin Counted {
  int count = 0;
  int bump() => ++count;
}
class Base {
  String who() => 'base';
}
class Mixed with Named, Counted {}
class Dog extends Base with Named {
  Dog(String n) { name = n; }
  @override
  String who() => 'dog ${super.who()}';
}
String t0() {
  final m = Mixed();
  m.name = 'ann';
  m.bump();
  m.bump();
  return '${m.hello()} ${m.shout} ${m.count}';
}
String t1() {
  final d = Dog('rex');
  return '${d.who()} ${d.hello()} ${d is Named} ${d is Base} ${Mixed() is Named} ${Base() is Named}';
}
// Each instance has its own mixin fields.
String t2() {
  final a = Mixed(), b = Mixed();
  a.bump();
  return '${a.count} ${b.count}';
}
""", 3);
    });

    test(
      'mixin method resolution order: the last mixin wins, super goes down',
      () async {
        await sameAsWeb(r"""
class Base {
  String f() => 'base';
}
mixin A on Base {
  @override
  String f() => 'A(${super.f()})';
}
mixin B on Base {
  @override
  String f() => 'B(${super.f()})';
}
mixin C {
  String g() => 'C';
}
mixin D {
  String g() => 'D';
}
class AB extends Base with A, B {}
class BA extends Base with B, A {}
class Own extends Base with A {
  @override
  String f() => 'own(${super.f()})';
}
class CD with C, D {}
class DC with D, C {}
String t0() => '${AB().f()} ${BA().f()} ${Own().f()}';
String t1() => '${CD().g()} ${DC().g()}';
// The class's own member beats the mixin's.
class Shadow with C {
  @override
  String g() => 'shadow';
}
String t2() => Shadow().g();
// Dispatch through the mixin's type and the base's.
String t3() {
  final List<Base> l = [AB(), BA(), Own(), Base()];
  return l.map((b) => b.f()).join('|');
}
""", 4);
      },
    );

    test(
      'a mixin declared after the class, constructors and abstract members',
      () async {
        await sameAsWeb(r"""
class Item extends Entity with Auditable {
  final String label;
  Item(int id, this.label) : super(id);
  @override
  String describe() => '$label#$id';
}
class Entity {
  final int id;
  Entity(this.id);
  String describe() => 'entity $id';
}
mixin Auditable {
  final log = <String>[];
  String describe();
  String audited() {
    log.add(describe());
    return log.join(';');
  }
}
String t0() {
  final i = Item(7, 'box');
  i.audited();
  return '${i.audited()} ${i.id}';
}
String t1() {
  final Auditable a = Item(1, 'x');
  return '${a.audited()} ${a is Item} ${a is Entity}';
}
""", 2);
      },
    );

    test('what a mixin can not carry says how', () async {
      Future<List<LiteError>> errors(String top) => liteErrors('''
$header
$top
class PState extends ThorState {
  String run() => W().g();
}
''');
      final a = await errors(
        'mixin M { static int n = 1; String g() => "x\${M.n}"; }\nclass W with M {}',
      );
      expect(a.single.message, contains('Static field M.n in a mixin'));
      final b = await errors(
        'mixin class M { String g() => "x"; }\nclass W with M {}',
      );
      expect(b.map((e) => e.message), contains(contains('mixin class')));
    });
  });

  test('an enum that mixes in says how', () async {
    final e = await liteErrors('''
$header
mixin Labeled {
  String shout() => 'x';
}
enum Color with Labeled { red }
class PState extends ThorState {
  String go() => Color.red.shout();
}
''');
    expect(e.first.message, contains('mixes in'));
    expect(e.first.hint, contains('`mixin` declared in the app'));
  });

  test('a mixin of a state can not also be mixed in a plain class', () async {
    final e = await liteErrors('''
$header
mixin Both on ThorState {
  String hi() => 'hi';
}
class Plain with Both {}
class PState extends ThorState with Both {
  String go() => Plain().hi();
}
''');
    expect(e.map((x) => x.message), contains(contains('used by a ThorState')));
  });

  test('a class declared before its superclass still extends it', () async {
    await sameAsWeb(r"""
class Child extends Parent {
  Child(super.name);
  @override
  String hello() => 'child ${super.hello()}';
}
class Parent {
  final String name;
  Parent(this.name);
  String hello() => 'parent $name';
}
String t0() => Child('x').hello();
""", 1);
  });

  for (final short in [false, true]) {
    group('mixins on a ThorState${short ? ' (short names)' : ''}', () {
      String src(String body) =>
          '''
$header
$body
''';

      test('fields and methods of the mixin are the state\'s', () async {
        final js = await translate(
          shortNames: short,
          src(r'''
mixin Counting on ThorState {
  final count = state(0);
  void inc() => count.value++;
  String label() => 'n=${count.value}';
}
class CState extends ThorState with Counting {
  final extra = state('x');
  String both() => '${label()} ${extra.value}';
  void incTwice() { inc(); inc(); }
}
'''),
        );
        if (!hasNode) return markTestSkipped('node is not installed');
        final out = runJs(js, r'''
S.incTwice();
out.label = S.label();
out.both = S.both();
out.count = S.$s.count.value;
out.keys = Object.keys(S).sort();
''');
        expect(out['label'], 'n=2');
        expect(out['both'], 'n=2 x');
        expect(out['count'], 2);
        expect(
          out['keys'],
          containsAll(['inc', 'label', 'count', 'both', 'incTwice']),
        );
      });

      test(
        'an override reaches the mixin it overrides with super, in order',
        () async {
          final js = await translate(
            shortNames: short,
            src(r'''
mixin M1 on ThorState {
  String describe() => 'm1';
}
mixin M2 on M1 {
  @override
  String describe() => 'm2(${super.describe()})';
}
class SState extends ThorState with M1, M2 {
  @override
  String describe() => 'state(${super.describe()})';
}
class UState extends ThorState with M1 {}
'''),
          );
          if (!hasNode) return markTestSkipped('node is not installed');
          final out = runJs(js, r'''
out.s = S.describe();
out.u = make('UState').describe();
''');
          expect(out['s'], 'state(m2(m1))');
          expect(out['u'], 'm1');
        },
      );

      test(
        'onHydrated and dispose of a mixin run when the state calls super',
        () async {
          final js = await translate(
            shortNames: short,
            src(r'''
mixin Logs on ThorState {
  final log = state('');
  @override
  void onHydrated() {
    log.value += 'mixin;';
  }
  @override
  void dispose() {
    log.value += 'mixin-dispose;';
  }
}
class LState extends ThorState with Logs {
  @override
  void onHydrated() {
    super.onHydrated();
    log.value += 'state;';
  }
}
class QuietState extends ThorState with Logs {}
'''),
          );
          if (!hasNode) return markTestSkipped('node is not installed');
          final out = runJs(js, r'''
S.$l.h();
out.a = S.$s.log.value;
const q = make('QuietState');
q.$l.h();
q.$l.d();
out.b = q.$s.log.value;
''');
          expect(out['a'], 'mixin;state;');
          expect(out['b'], 'mixin;mixin-dispose;');
        },
      );

      test('a field the state declares again replaces the mixin\'s', () async {
        final js = await translate(
          shortNames: short,
          src(r'''
mixin Base on ThorState {
  final value = state(1);
  int twice() => value.value * 2;
}
class RState extends ThorState with Base {
  @override
  final value = state(10);
}
'''),
        );
        if (!hasNode) return markTestSkipped('node is not installed');
        final out = runJs(js, r'''
out.twice = S.twice();
out.value = S.$s.value.value;
''');
        expect(out['twice'], 20);
        expect(out['value'], 10);
        expect(RegExp(r"\$\.state\('value'").allMatches(js).length, 1);
      });

      test('what a state can not mix in says how', () async {
        final e = await liteErrors(
          src(r'''
class NotMixin { String f() => 'x'; }
class BadState extends ThorState with NotMixin {}
'''),
        );
        expect(e.first.message, contains('only a `mixin` of the app'));
      });
    });
  }

  group('operator == and hashCode', () {
    const point = r"""
class Point {
  final int x, y;
  const Point(this.x, this.y);
  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Point && other.x == x && other.y == y;
  @override
  int get hashCode => Object.hash(x, y);
  @override
  String toString() => 'P($x,$y)';
}
class Point3 extends Point {
  final int z;
  const Point3(super.x, super.y, this.z);
  @override
  bool operator ==(Object other) =>
      other is Point3 && super == other && other.z == z;
  @override
  int get hashCode => Object.hash(super.hashCode, z);
}
""";

    test(
      '== and != call the operator, also through Object and a base type',
      () async {
        await sameAsWeb('''
$point
${r"""
String t0() {
  final a = Point(1, 2), b = Point(1, 2), c = Point(2, 1);
  Point? n;
  return '${a == b} ${a != b} ${a == c} ${a == n} ${n == a} ${n == null} ${identical(a, b)}';
}
String t1() {
  final Object a = Point(1, 2);
  final Object b = Point(1, 2);
  final dynamic c = Point(1, 2);
  return '${a == b} ${c == a} ${a == 'x'} ${a == 1}';
}
String t2() {
  final Point a = Point3(1, 2, 3), b = Point3(1, 2, 3), c = Point3(1, 2, 4);
  return '${a == b} ${a == c} ${a == Point(1, 2)} ${Point(1, 2) == a}';
}
String t3() => '${Point(1, 2).hashCode == Point(1, 2).hashCode} ${Point(1, 2).hashCode == Point(2, 1).hashCode}';
"""}''', 4);
      },
    );

    test('an == that is never true is asked, even against itself', () async {
      await sameAsWeb(r"""
class Never {
  @override
  bool operator ==(Object other) => false;
  @override
  int get hashCode => 1;
}
class Always {
  @override
  bool operator ==(Object other) => true;
  @override
  int get hashCode => 1;
}
String t0() {
  final n = Never(), a = Always(), a2 = Always();
  return '${n == n} ${n != n} ${a == a2} ${a == Never()} ${[n].contains(n)}';
}
// Equal hash, different value: still different keys.
class Clash {
  final int v;
  Clash(this.v);
  @override
  bool operator ==(Object o) => o is Clash && o.v == v;
  @override
  int get hashCode => 7;
}
String t1() {
  final s = {Clash(1), Clash(2), Clash(1), Clash(3)};
  final m = {Clash(1): 'a', Clash(2): 'b'};
  m[Clash(1)] = 'c';
  return '${s.length} ${m.length} ${m[Clash(1)]} ${m[Clash(9)]} ${s.contains(Clash(3))}';
}
// == without hashCode: two equal objects are two keys (identity hash).
class NoHash {
  final int v;
  NoHash(this.v);
  @override
  bool operator ==(Object o) => o is NoHash && o.v == v;
}
String t2() {
  final a = NoHash(1);
  final s = {a, NoHash(1)};
  return '${a == NoHash(1)} ${s.length} ${s.contains(a)} ${s.contains(NoHash(1))}';
}
""", 3);
    });

    test('Set and Map keys, lists and signals use ==', () async {
      await sameAsWeb('''
$point
${r"""
String t0() {
  final s = {Point(1, 2), Point(3, 4), Point(1, 2)};
  s.add(Point(3, 4));
  final removed = s.remove(Point(1, 2));
  return '${s.length} $removed ${s.contains(Point(3, 4))} ${s.contains(Point(1, 2))} ${s.toList()}';
}
String t1() {
  final m = <Point, String>{Point(0, 0): 'origin', Point(1, 1): 'one'};
  m[Point(0, 0)] = 'zero';
  m.putIfAbsent(Point(2, 2), () => 'two');
  m.putIfAbsent(Point(1, 1), () => 'dup');
  m.update(Point(2, 2), (v) => '$v!');
  final gone = m.remove(Point(1, 1));
  return '${m.length} ${m[Point(0, 0)]} ${m[Point(2, 2)]} $gone ${m.containsKey(Point(1, 1))} ${m.keys.toList()} ${m.values.toList()}';
}
String t2() {
  final l = [Point(1, 1), Point(2, 2), Point(1, 1)];
  final removed = l.remove(Point(1, 1));
  return '${l.contains(Point(2, 2))} ${l.indexOf(Point(1, 1))} ${l.lastIndexOf(Point(2, 2))} $removed ${l.length} ${l.indexOf(Point(9, 9))}';
}
String t3() {
  final l = [Point(1, 1), Point(2, 2), Point(1, 1)];
  final s = l.toSet();
  final u = s.union({Point(3, 3), Point(1, 1)});
  final i = s.intersection({Point(2, 2), Point(5, 5)});
  final d = s.difference({Point(1, 1)});
  return '${s.length} ${u.length} ${i.length} ${d.length} ${s.containsAll([Point(1, 1)])}';
}
// Order of insertion survives; removing and adding again moves to the end.
String t4() {
  final m = <Point, int>{Point(1, 1): 1, Point(2, 2): 2, Point(3, 3): 3};
  m.remove(Point(1, 1));
  m[Point(1, 1)] = 4;
  m[Point(2, 2)] = 5;
  return m.entries.map((e) => '${e.key}${e.value}').join(',');
}
String t5() {
  final byPoint = Map.fromEntries([MapEntry(Point(1, 1), 'a'), MapEntry(Point(1, 1), 'b')]);
  final mapped = {Point(1, 1): 1, Point(2, 2): 2}.map((k, v) => MapEntry(Point(k.x, 0), v));
  return '${byPoint.length} ${byPoint[Point(1, 1)]} ${mapped.length} ${mapped[Point(1, 0)]}';
}
String t6() {
  final m = {1: Point(1, 1)};
  return '${m.containsValue(Point(1, 1))} ${m.containsValue(Point(1, 2))}';
}
"""}''', 7);
    });

    test('records compare and hash by value', () async {
      await sameAsWeb(r"""
String t0() {
  const a = (1, 'x'), b = (1, 'x'), c = (2, 'x');
  final n = (a: 1, b: 2), m = (b: 2, a: 1);
  return '${a == b} ${a == c} ${a != c} ${n == m} ${a.hashCode == b.hashCode} ${n.hashCode == m.hashCode} ${((1, 2), 'z') == ((1, 2), 'z')}';
}
String t1() {
  final s = {(1, 2), (3, 4), (1, 2)};
  final m = <(int, int), String>{(0, 0): 'o'};
  m[(0, 0)] = 'z';
  m[(1, 1)] = 'w';
  return '${s.length} ${s.contains((3, 4))} ${m[(0, 0)]} ${m.length} ${m.containsKey((1, 1))} ${m.containsKey((1, 2))}';
}
String t2() {
  final l = <(String, int)>[('a', 1), ('b', 2)];
  return '${l.contains(('b', 2))} ${l.indexOf(('a', 1))} ${l.indexOf(('a', 2))} ${l.remove(('a', 1))} ${l.length}';
}
// Records in records, with a class that has ==.
class Id {
  final int v;
  Id(this.v);
  @override
  bool operator ==(Object o) => o is Id && o.v == v;
  @override
  int get hashCode => v;
}
String t3() {
  final a = (Id(1), [1].length), b = (Id(1), 1);
  final s = {a, b, (Id(2), 1)};
  return '${a == b} ${s.length} ${s.contains((Id(2), 1))}';
}
String t4() {
  final h1 = Object.hash(1, 'a', null), h2 = Object.hash(1, 'a', null);
  final u1 = Object.hashAllUnordered([1, 2, 3]), u2 = Object.hashAllUnordered([3, 1, 2]);
  return '${h1 == h2} ${Object.hashAll([1, 2]) == Object.hashAll([1, 2])} ${Object.hashAll([1, 2]) == Object.hashAll([2, 1])} ${u1 == u2}';
}
""", 5);
    });

    test(
      'plain comparisons stay plain: no deq helper for a String against Object?',
      () async {
        final js = await translate('''
$header
class PState extends ThorState {
  bool a(List<dynamic> l) => l.contains('x');
  bool b(Object? o) => o == 'x';
  bool c(Object? o, int n) => o == n;
  bool d(List<Object?> l, int n) => l.indexOf(n) >= 0;
}
''');
        expect(js, isNot(contains(r'$deq')));
        expect(js, contains('.includes('));
        final byValue = await translate('''
$header
class PState extends ThorState {
  bool a(List<Object?> l, Object? o) => l.contains(o);
  bool b(Object? x, Object? y) => x == y;
}
''');
        expect(byValue, contains(r'$deq'));
      },
    );

    test('the record comparison ships only with records', () async {
      final plain = await translate('''
$header
class PState extends ThorState {
  bool b(Object? x, Object? y) => x == y;
}
''');
      expect(plain, contains(r'const $deq'));
      expect(plain, isNot(contains(r'$req')));
      final withRecords = await translate('''
$header
class PState extends ThorState {
  bool b(Object? x, Object? y) => x == y || (1, 2) == (1, 2);
}
''');
      expect(withRecords, contains(r'const $req'));
    });

    test('a list keeps comparing dates by value', () async {
      await sameAsWeb(r"""
String t0() {
  final l = [DateTime.utc(2024, 1, 1), DateTime.utc(2024, 1, 2)];
  return '${l.contains(DateTime.utc(2024, 1, 2))} ${l.indexOf(DateTime.utc(2024, 1, 3))} ${l.remove(DateTime.utc(2024, 1, 1))} ${l.length} ${DateTime.utc(2024) == DateTime.utc(2024)}';
}
""", 1);
    });

    test('a signal does not notify for an equal value', () async {
      final js = await translate('''
$header
${r"""
class Point {
  final int x, y;
  const Point(this.x, this.y);
  @override
  bool operator ==(Object other) => other is Point && other.x == x && other.y == y;
  @override
  int get hashCode => Object.hash(x, y);
}
class PState extends ThorState {
  final p = state(const Point(1, 2));
  final r = state((1, 2));
  final plain = state(0);
  void same() { p.value = Point(1, 2); r.value = (1, 2); }
  void other() { p.value = Point(2, 2); r.value = (2, 2); }
  void inc() { plain.value += 0; }
}
"""}''');
      if (!hasNode) return markTestSkipped('node is not installed');
      final out = runJs(js, r'''
S.same();
out.afterSame = [S.$s.p.n, S.$s.r.n];
S.other();
out.afterOther = [S.$s.p.n, S.$s.r.n];
S.same();
out.back = [S.$s.p.n, S.$s.r.n];
''');
      expect(out['afterSame'], [0, 0]);
      expect(out['afterOther'], [1, 1]);
      expect(out['back'], [2, 2]);
    });

    test('runtimeType compares classes; printing it says why not', () async {
      await sameAsWeb(r"""
class A {
  final int v;
  A(this.v);
  @override
  bool operator ==(Object other) =>
      other.runtimeType == runtimeType && other is A && other.v == v;
  @override
  int get hashCode => v;
}
class B extends A {
  B(super.v);
}
String t0() => '${A(1) == A(1)} ${A(1) == B(1)} ${B(1) == B(1)} ${B(1) == A(1)}';
""", 1);
      final e = await liteErrors('''
$header
class PState extends ThorState {
  String f(Object o) => '\${o.runtimeType}';
}
''');
      expect(e.first.message, contains('runtimeType'));
    });

    test('what stays out says how', () async {
      final e = await liteErrors('''
$header
class P {
  final int a;
  P(this.a);
  bool operator <(P o) => a < o.a;
}
class PState extends ThorState {
  bool f() => P(1) < P(2);
}
''');
      expect(e.first.message, contains('Operator'));
      final d = await liteErrors('''
$header
class PState extends ThorState {
  Object f() => {DateTime.utc(2024)};
}
''');
      expect(d.first.message, contains('compare by value'));
    });
  });

  group('FormatException', () {
    test('message and toString, as dart2js gives them', () async {
      await sameAsWeb(
        r"""
String caught(void Function() f) {
  try {
    f();
    return 'none';
  } on FormatException catch (e) {
    return '${e.message}|$e';
  }
}
String t0() => caught(() => int.parse('12a'));
String t1() => caught(() => double.parse('x1'));
String t2() => caught(() => double.parse('${'9' * 80}z'));
String t3() => caught(() => throw const FormatException('bad input'));
String t4() => caught(() => throw const FormatException());
String t5() {
  try {
    jsonDecode('{');
    return 'none';
  } on FormatException catch (e) {
    return e.message.isEmpty ? 'empty' : 'has message';
  }
}
""",
        6,
        imports: "import 'dart:convert';",
      );
    });

    test('DateTime.parse of a bad date is a FormatException', () async {
      await sameAsWeb(r"""
String caught(void Function() f) {
  try {
    f();
    return 'none';
  } on FormatException catch (e) {
    return '${e.message}|$e';
  } catch (e) {
    return 'other';
  }
}
String t0() => caught(() => DateTime.parse('2024-13-45x'));
String t1() => caught(() => DateTime.parse(''));
String t2() => caught(() => DateTime.parse('2024-01-01T10:00${'0' * 80}'));
String t3() => caught(() => DateTime.parse('+999999-01-01'));
String t4() => '${DateTime.tryParse('nope')}|${DateTime.parse('2024-02-03').day}';
""", 5);
    });
  });

  group('what stays out says how', () {
    test('Future.wait(cleanUp:), Completer.sync, timeout', () async {
      Future<List<LiteError>> errors(String body) => liteErrors('''
$header
class PState extends ThorState {
  Future<void> run() async {
$body
  }
}
''');
      final a = await errors(
        '    await Future.wait([Future.value(1)], cleanUp: (v) {});',
      );
      expect(a.single.message, contains('Future.wait(cleanUp:)'));
      expect(a.single.hint, contains('try/finally'));
      final b = await errors(
        '    final c = Completer<int>.sync(); c.complete(1);',
      );
      expect(b.single.message, contains('Completer.sync'));
      expect(b.single.hint, contains('`Completer()`'));
      final c = await errors(
        '    await Future.value(1).timeout(const Duration(seconds: 1));',
      );
      expect(c.single.hint, contains('Timer'));
    });
  });
}
