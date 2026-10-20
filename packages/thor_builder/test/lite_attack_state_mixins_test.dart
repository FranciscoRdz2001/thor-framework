// Adversarial: a state mixin used by two states, plain fields, `is M`,
// initializer order across mixins; run with long and short names.
@Timeout(Duration(minutes: 3))
library;

import 'package:test/test.dart';

import 'lite_oracle.dart';

void main() {
  for (final short in [false, true]) {
    group(short ? 'short names' : 'readable names', () {
      test('two states, one mixin: fields stay apart', () async {
        final js = await translate(shortNames: short, '''
$header
mixin Tally on ThorState {
  final total = state(0);
  final seen = <int>[];
  int bonus = 100;
  void add(int n) { total.value += n; seen.add(n); bonus++; }
  int sum() => seen.fold<int>(0, (a, b) => a + b) + bonus;
}
class AState extends ThorState with Tally {
  final own = state('a');
}
class BState extends ThorState with Tally {
  final own = state('b');
}
''');
        if (!hasNode) return markTestSkipped('node is not installed');
        final out = runJs(js, r'''
const a = make('AState'), b = make('BState');
a.add(1); a.add(2); b.add(10);
out.a = a.sum(); out.b = b.sum();
out.at = a.$s.total.value; out.bt = b.$s.total.value;
const c = make('AState');
out.c = c.sum();
''');
        expect(out['a'], 1 + 2 + 102);
        expect(out['b'], 10 + 101);
        expect(out['at'], 3);
        expect(out['bt'], 10);
        expect(out['c'], 100);
      });

      test('a mixin field that reads an earlier one, state order', () async {
        final js = await translate(shortNames: short, '''
$header
mixin First on ThorState {
  final a = state(1);
}
mixin Second on First {
  final b = state(2);
  int both() => a.value * 10 + b.value;
}
class DState extends ThorState with First, Second {
  final c = state(3);
}
''');
        if (!hasNode) return markTestSkipped('node is not installed');
        final out = runJs(js, 'out.v = S.both(); out.c = S.\$s.c.value;');
        expect(out['v'], 12);
        expect(out['c'], 3);
      });
    });
  }
}
