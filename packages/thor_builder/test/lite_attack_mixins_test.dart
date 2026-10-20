// Adversarial oracle tests for lite mixins and equality.
@Timeout(Duration(minutes: 3))
library;

import 'package:test/test.dart';

import 'lite_oracle.dart';

void main() {
  test('linearization: both mixins override and call super', () async {
    await sameAsWeb(r"""
class Base {
  String who() => 'base';
  String get tag => 'B';
  int _n = 0;
  int get n => _n;
  set n(int v) { _n = v; }
}
mixin M1 on Base {
  @override
  String who() => 'm1<${super.who()}>';
  @override
  String get tag => 'M1${super.tag}';
  @override
  set n(int v) { super.n = v + 1; }
}
mixin M2 on Base {
  @override
  String who() => 'm2<${super.who()}>';
  @override
  String get tag => 'M2${super.tag}';
  @override
  set n(int v) { super.n = v * 10; }
}
class A extends Base with M1, M2 {
  @override
  String who() => 'a<${super.who()}>';
}
class B extends Base with M2, M1 {}
class C extends A with M1 {
  @override
  String who() => 'c<${super.who()}>';
}
String t0() => '${A().who()} ${B().who()} ${C().who()}';
String t1() => '${A().tag} ${B().tag} ${C().tag}';
String t2() {
  final a = A(); a.n = 2;
  final b = B(); b.n = 2;
  final c = C(); c.n = 2;
  return '${a.n} ${b.n} ${c.n}';
}
String t3() {
  final Base a = A();
  return '${a is M1} ${a is M2} ${a is A} ${B() is M1} ${Base() is M1} ${C() is A} ${C() is M2}';
}
""", 4);
  });

  // Initializers that print run in JS order (superclass first), not Dart's
  // (subclass first): a documented difference; values are the same.
  test('mixin fields and initializers: defaults and isolation', () async {
    await sameAsWeb(r"""
mixin Counter {
  int count = 3;
  final List<int> items = [];
  void bump() { count++; items.add(count); }
}
mixin Named {
  String name = 'n';
}
class Base {
  final int b = 1;
  Base() { count0++; }
}
int count0 = 0;
class X extends Base with Counter, Named {
  final int own = 5;
  X() { count0 += 10; }
}
class Y with Counter {}
String t0() {
  count0 = 0;
  final x = X();
  return '$count0 ${x.count} ${x.name} ${x.own} ${x.b}';
}
String t1() {
  final a = Y(), b = Y();
  a.bump(); a.bump(); b.bump();
  return '${a.items.length} ${b.items.length} ${a.count} ${b.count} ${identical(a.items, b.items)}';
}
String t2() {
  final a = X(), b = X();
  a.name = 'changed';
  return '${a.name} ${b.name != 'changed'}';
}
""", 3);
  });

  test('a mixin that overrides operator == and hashCode', () async {
    await sameAsWeb(r"""
mixin ById {
  int get id;
  @override
  bool operator ==(Object other) => other is ById && other.id == id;
  @override
  int get hashCode => id.hashCode;
}
class User with ById {
  @override
  final int id;
  final String name;
  User(this.id, this.name);
}
class Order with ById {
  @override
  final int id;
  Order(this.id);
}
String t0() {
  final a = User(1, 'a'), b = User(1, 'b'), c = User(2, 'a');
  return '${a == b} ${a == c} ${a != c} ${a == Order(1)} ${Order(1) == a}';
}
String t1() {
  final s = {User(1, 'a'), User(1, 'b'), User(2, 'c')};
  final m = {User(1, 'a'): 'x'};
  m[User(1, 'z')] = 'y';
  return '${s.length} ${m.length} ${m[User(1, 'q')]} ${s.contains(User(2, 'zz'))}';
}
String t2() {
  final l = [User(1, 'a'), User(2, 'b')];
  return '${l.contains(User(2, 'x'))} ${l.indexOf(User(2, 'x'))} ${l.remove(User(1, 'q'))} ${l.length}';
}
""", 3);
  });

  test(
    'equality edge cases: nested records, lists by identity, null',
    () async {
      await sameAsWeb(r"""
String t0() {
  final l = [1, 2];
  final a = (1, (2, 'x')), b = (1, (2, 'x')), c = (1, (2, 'y'));
  return '${a == b} ${a == c} ${(l, 1) == (l, 1)} ${([1, 2], 1) == ([1, 2], 1)} ${(a: 1, b: 2) == (a: 1, b: 2)}';
}
String t1() {
  final s = {(1, 2), (1, 2), (2, 1)};
  final m = {(1, 2): 'a', (3, 4): 'b', (1, 2): 'c'};
  return '${s.length} ${m.length} ${m[(1, 2)]} ${m.keys.length} ${m.keys.first.$1} ${m.containsKey((3, 4))}';
}
String t2() {
  final m = <(int, int), String>{};
  m[(3, 1)] = 'a'; m[(1, 1)] = 'b'; m[(2, 1)] = 'c'; m[(3, 1)] = 'd';
  return m.entries.map((e) => '${e.key.$1}:${e.value}').join(',');
}
String t3() {
  Object? n;
  final Object o = (1, 2);
  return '${n == null} ${o == (1, 2)} ${o == 'x'} ${o == null} ${(1, 2) == (1, 2, 3)} ${(1, 'a') == (1, 'a')}';
}
String t4() {
  final s = {(1, 2), (3, 4), (5, 6)};
  s.removeWhere((r) => r.$1 == 3);
  final t = {(1, 2), (3, 4), (5, 6)};
  t.retainWhere((r) => r.$1 == 3);
  return '${s.length} ${s.contains((5, 6))} ${t.length} ${t.contains((3, 4))} ${s.toList().length} ${[...t].length}';
}
String t5() {
  final s = {(1, 2), (3, 4)};
  final l = s.toList();
  final l2 = [...s, (9, 9)];
  final t = l2.toSet();
  return '${l.length} ${l2.length} ${t.length} ${s.union({(1, 2), (7, 7)}).length} ${s.intersection({(1, 2), (7, 7)}).length} ${s.difference({(1, 2)}).length}';
}
""", 6);
    },
  );

  test('mutable key mutation after insertion (Dart: lookup fails)', () async {
    await sameAsWeb(r"""
class K {
  int v;
  K(this.v);
  @override
  bool operator ==(Object o) => o is K && o.v == v;
  @override
  int get hashCode => v;
}
String t0() {
  final k = K(1);
  final s = {k};
  final m = {k: 'a'};
  k.v = 2;
  return '${s.contains(k)} ${s.contains(K(2))} ${s.contains(K(1))} ${s.length} ${m[k]} ${m[K(1)]} ${m.containsKey(K(2))} ${m.length}';
}
String t1() {
  final k = K(1);
  final l = [k];
  k.v = 5;
  return '${l.contains(K(5))} ${l.contains(K(1))} ${l.indexOf(K(5))}';
}
""", 2);
  });

  test('overriding one half of a getter/setter pair keeps the other', () async {
    await sameAsWeb(r"""
class Base {
  int _n = 0;
  int get n => _n;
  set n(int v) { _n = v; }
}
class OnlySet extends Base {
  @override
  set n(int v) { super.n = v + 1; }
}
class OnlyGet extends Base {
  @override
  int get n => super.n * 2;
}
mixin Twice on Base {
  @override
  set n(int v) { super.n = v * 2; }
}
class WithMixin extends Base with Twice {}
class Deep extends OnlySet {}
String t0() { final a = OnlySet(); a.n = 1; return '${a.n}'; }
String t1() { final a = OnlyGet(); a.n = 3; return '${a.n}'; }
String t2() { final a = WithMixin(); a.n = 4; return '${a.n}'; }
String t3() { final a = Deep(); a.n = 1; a.n += 1; return '${a.n}'; }
""", 4);
  });

  test('overriding half of a field with an accessor says how', () async {
    final errors = await liteErrors(r'''
import 'package:thor_ui/thor_ui.dart';


class F { int n = 0; }
class FSet extends F {
  @override
  set n(int v) { super.n = v + 1; }
}
String t0() { final a = FSet(); a.n = 3; return '${a.n}'; }
class PState extends ThorState { String e0() => t0(); }
''');
    expect(errors.single.message, contains('one half of a field'));
  });
}
