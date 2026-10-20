// A bundle ships only the helpers its code reaches: an app that never asks
// for value equality carries none of the equality machinery.
@Timeout(Duration(minutes: 2))
library;

import 'package:test/test.dart';

import 'lite_oracle.dart';

const _helpers = [
  r'$deq',
  r'$req',
  r'$HS',
  r'$HM',
  r'$hash',
  r'$ixeq',
  r'$lixeq',
  r'$Completer',
  r'$wait',
  r'$resplit',
  r'$removeWhere',
];

void main() {
  test('an app with plain state ships no equality or future helper', () async {
    final js = await translate('''
$header
class CState extends ThorState {
  final count = state(0);
  final names = state<List<String>>([]);
  final seen = state<Set<String>>({});
  final byId = state<Map<String, int>>({});
  void inc() => count.value++;
  bool same(String a, String b) => a == b && count.value != 2;
  void add(String n) {
    if (names.value.contains(n) || seen.value.contains(n)) return;
    names.value = [...names.value, n];
    seen.value = {...seen.value, n};
    byId.value = {...byId.value, n: names.value.indexOf(n)};
  }
  String label() => names.value.map((n) => n.toUpperCase()).join(',');
}
''');
    for (final h in _helpers) {
      expect(js, isNot(contains(h)), reason: '$h is shipped without use');
    }
    final short = await translate('''
$header
class CState extends ThorState {
  final count = state(0);
  void inc() => count.value++;
}
''', shortNames: true);
    expect(RegExp(r'\$(HS|HM|deq|req|hash)\b').hasMatch(short), isFalse);
  });

  test('a record key brings the equality helpers, and only those', () async {
    final js = await translate('''
$header
class CState extends ThorState {
  final n = state(0);
  bool has(int a, int b) {
    final seen = <(int, int)>{(1, 2)};
    return seen.contains((a, b));
  }
}
''');
    expect(js, contains(r'$HS'));
    for (final h in [r'$Completer', r'$wait', r'$resplit', r'$HM']) {
      expect(js, isNot(contains(h)), reason: h);
    }
  });
}
