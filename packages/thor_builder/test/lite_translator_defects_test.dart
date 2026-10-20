// Translator regressions: each group pins one construct.
@Timeout(Duration(minutes: 3))
library;

import 'package:test/test.dart';

import 'lite_oracle.dart';

void main() {
  group('persisted nullable non-interface types', () {
    test('a nullable record with a codec translates', () async {
      final js = await translate('''
$header
class PState extends ThorState {
  final pos = state<(int, int)?>(
    null,
    cookie: 'pos',
    encode: (p) => p == null ? null : [p.\$1, p.\$2],
    decode: (j) => j == null ? null : ((j as List)[0] as int, j[1] as int),
  );
}
''');
      expect(js, contains("'pos'"));
    });

    test('a nullable record without a codec says it needs one', () async {
      final errors = await liteErrors('''
$header
class PState extends ThorState {
  final pos = state<(int, int)?>(null, cookie: 'pos');
}
''');
      expect(errors.single.message, contains('needs encode/decode'));
    });
  });

  group('unsigned shift', () {
    test('a count of 32 or more gives 0, like the VM and dart2js', () async {
      await sameAsWeb(r'''
String t0() {
  final r = <int>[];
  for (final n in [0, 1, 4, 31, 32, 33, 40]) {
    r.add(5 >>> n);
    r.add(1000 >>> n);
  }
  var a = 255;
  var k = 33;
  a >>>= k;
  r.add(a);
  return r.join(',');
}
''', 1);
    });
  });

  group('expand', () {
    test('flattens a Set or a lazy iterable, not only a List', () async {
      await sameAsWeb(r'''
class Item {
  final Set<String> tags;
  final List<int> nums;
  Item(this.tags, this.nums);
}
Set<String> tagsOf(Item i) => i.tags;
String t0() {
  final items = [Item({'a', 'b'}, [1]), Item({'c'}, [2, 3])];
  final r = items.expand((i) => i.tags).toList();
  return '${r.length} ${r.join(',')}';
}
String t1() {
  final items = [Item({'a', 'b'}, [1]), Item({'c'}, [2, 3])];
  final r = items.expand(tagsOf).toList();
  return '${r.length} ${r.join(',')}';
}
String t2() {
  final items = [Item({'a', 'b'}, [1]), Item({'c'}, [2, 3])];
  final r = items.expand((i) => i.nums).toList();
  final q = items.expand((i) => i.nums.where((n) => n > 1)).toList();
  return '$r $q';
}
''', 3);
    });
  });

  group('interpolated strings', () {
    test('keep CR, CRLF and the lines of a multi-line string', () async {
      await sameAsWeb(r"""
String t0() {
  final a = 'x', b = 'y';
  final s = '$a\r\n$b\r$a\n$b\t$a';
  return '${s.length} ${s.indexOf('\r')} ${s.contains('\r\n')} ${s.split('\n').length}';
}
String t1() {
  final a = 'x';
  final s = '''l1 $a
  l2 $a
l3''';
  return '${s.length} ${s.split('\n').join('|')}';
}
""", 2);
    });
  });

  group('receivers are evaluated once', () {
    test('lastOrNull, singleOrNull, end, isNegative and Map.addAll', () async {
      await sameAsWeb(r'''
List<int> src(List<int> log) {
  log.add(1);
  return [1, 2, 3];
}
RegExpMatch pick(List<int> log) {
  log.add(1);
  return RegExp('b+').firstMatch('abbc')!;
}
int val(List<int> log) {
  log.add(1);
  return -3;
}
Map<String, int> holder(List<int> log, Map<String, int> m) {
  log.add(1);
  return m;
}
String t0() {
  final log = <int>[];
  final r = src(log).where((x) => x > 1).lastOrNull;
  return '$r ${log.length}';
}
String t1() {
  final log = <int>[];
  final r = src(log).where((x) => x == 2).singleOrNull;
  return '$r ${log.length}';
}
String t2() {
  final log = <int>[];
  return '${pick(log).end} ${log.length}';
}
String t3() {
  final log = <int>[];
  return '${val(log).isNegative} ${log.length}';
}
String t4() {
  final log = <int>[];
  final m = <String, int>{};
  holder(log, m).addAll({'a': 1, 'b': 2, 'c': 3});
  return '${m.length} ${log.length}';
}
''', 5);
    });

    test('inside a null-aware chain that stops short', () async {
      // `undo.lastOrNull?.changes.singleOrNull` on an empty list is null
      // (the grid app's undo): the bound receiver is the short-circuited
      // chain, not a list.
      await sameAsWeb(r'''
class Step {
  Step(this.changes, this.at);
  final List<int> changes;
  final int at;
}
List<Step> steps(List<int> log, List<Step> s) {
  log.add(1);
  return s;
}
String t0() {
  final log = <int>[];
  final none = steps(log, []).lastOrNull?.changes.singleOrNull;
  final one = steps(log, [Step([7], -1)]).lastOrNull?.changes.singleOrNull;
  return '$none $one ${log.length}';
}
String t1() {
  final log = <int>[];
  final none = steps(log, []).lastOrNull?.changes.lastOrNull;
  final neg = steps(log, []).lastOrNull?.at.isNegative;
  final yes = steps(log, [Step([1, 2], -1)]).lastOrNull?.at.isNegative;
  return '$none $neg $yes ${log.length}';
}
''', 2);
    });
  });

  group('line separators in string literals', () {
    test('are written as escapes, not as invisible characters', () async {
      final js = await translate('''
$header
String t0() => 'a\\u2028b\\u2029c';
String t1(String x) => '\$x\\u2028y\\u2029z';
class PState extends ThorState {
  String e0() => t0();
  String e1() => t1('w');
}
''');
      expect(js, contains(r'a\u2028b\u2029c'));
      expect(js, contains(r'\u2028y\u2029z'));
      expect(js, isNot(contains('\u2028')));
      expect(js, isNot(contains('\u2029')));
    });
  });

  group('short names and the mixin wrapper', () {
    test('a top-level declaration may take the name S', () async {
      // Enough declarations that one gets the short name `S`.
      final fns = [for (var i = 0; i < 90; i++) 'int f$i() => $i;'].join('\n');
      final sum = [for (var i = 0; i < 90; i++) 'f$i()'].join(' + ');
      await sameAsWeb('''
$fns
mixin M {
  int sum() => $sum;
}
class K with M {}
String t0() => '\${K().sum()}';
''', 1);
    });
  });

  group('tear-offs with optional parameters', () {
    test('where, fold and reduce pass only the element(s)', () async {
      await sameAsWeb(r'''
bool isLong(String s, [int min = 5]) => s.length >= min;
int add(int a, int b, [int extra = 0]) => a + b + extra;
String t0() {
  final names = ['abcdefg', 'abc', 'abcdef', 'a'];
  return names.where(isLong).join(',');
}
String t1() => [1, 2, 3, 4].fold(0, add).toString();
String t2() => [1, 2, 3, 4].reduce(add).toString();
String t3() {
  final names = ['abcdefg', 'abc', 'abcdef', 'a'];
  return names.firstWhere(isLong);
}
''', 4);
    });
  });
}
