// Adversarial oracle tests for lite collections and strings.
@Timeout(Duration(minutes: 3))
library;

import 'package:test/test.dart';

import 'lite_oracle.dart';

void main() {
  test('split with a RegExp: anchors, lookaheads, flags, captures', () async {
    await sameAsWeb(r"""
String t0() => '${'abc'.split(RegExp(r'(?=b)'))} ${'abc'.split(RegExp(r'$'))} ${'abc'.split(RegExp(r'^'))} ${'aXbX'.split(RegExp('X*'))}';
String t1() => '${'a\nb\nc'.split(RegExp(r'^', multiLine: true))} ${'a,b'.split(RegExp(r'(,)?'))} ${'ab'.split(RegExp(r'(x)?'))}';
String t2() => '${'one  two   three'.split(RegExp(r'\s+'))} ${' lead'.split(RegExp(r'\s'))} ${'trail '.split(RegExp(r'\s'))} ${' '.split(RegExp(r'\s'))}';
String t3() => '${'aAbB'.split(RegExp('a', caseSensitive: false))} ${'a.b'.split(RegExp(r'.', dotAll: true))} ${'2020-01-02'.split(RegExp(r'(\d+)-(\d+)'))}';
String t4() => '${'a1b'.split(RegExp(r'(?<d>\d)'))} ${'abc'.split(RegExp(r'b|'))} ${'😀😀'.split(RegExp(r'(?:)', unicode: true)).length}';
String t5() {
  final re = RegExp(r'\d');
  // The same RegExp object used twice (a global JS regexp has lastIndex).
  return '${'1a2'.split(re)} ${'1a2'.split(re)} ${'x3y'.split(re)}';
}
String t6() => '${'a-b'.split(RegExp(r'-'), ).length} ${'abc'.split('').length} ${'abc'.split(RegExp(r'c'))} ${'abc'.split(RegExp(r'a'))}';
""", 7);
  });

  test('indexed on Map.entries and keys, whereType nullable', () async {
    await sameAsWeb(r"""
String t0() {
  final m = {'a': 1, 'b': 2, 'c': 3};
  final out = <String>[];
  for (final (i, e) in m.entries.indexed) {
    out.add('$i${e.key}${e.value}');
  }
  for (final (i, k) in m.keys.indexed) {
    out.add('$i$k');
  }
  return '${out.join(',')} ${m.values.indexed.map((e) => e.$1 + e.$2).join('|')}';
}
String t1() {
  final l = <Object?>[1, null, 'a', null, 2];
  return '${l.whereType<int?>().length} ${l.whereType<int>().length} ${l.whereType<Object>().length} ${l.whereType<String?>().length}';
}
String t2() {
  final l = <int?>[1, null, 3];
  final nn = l.whereType<int>().toList();
  nn.add(7);
  return '${nn.length} ${l.length} ${l.nonNulls.fold<int>(0, (a, b) => a + b)}';
}
String t3() {
  final s = <int>{5, 6, 7, 8};
  s.removeWhere((x) => x.isOdd);
  final t = <int>{1, 2, 3};
  t.retainWhere((x) => x > 1);
  final u = <String>{'a', 'bb'};
  u.removeWhere((x) => x.length > 5);
  return '${s.length} ${s.contains(6)} ${t.length} ${t.contains(1)} ${u.length}';
}
String t4() {
  final s = {3, 1, 2};
  final l = [...s, 9];
  final r = s.toList()..sort();
  final copy = {...s}..add(4);
  return '${l.length} $r ${copy.length} ${s.length} ${[for (final x in s) x * 2].length}';
}
""", 5);
  });

  test('Set methods that mutate stay on the set', () async {
    await sameAsWeb(r"""
String t0() {
  final s = {1, 2, 3, 4};
  s.removeAll([1, 2]);
  s.addAll([9, 3]);
  final a = s.remove(9);
  final b = s.remove(100);
  return '${s.length} $a $b ${s.contains(3)} ${s.containsAll([3, 4])}';
}
""", 1);
  });
}
