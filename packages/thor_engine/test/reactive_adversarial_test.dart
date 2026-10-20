import 'dart:async';

import 'package:test/test.dart';
import 'package:thor_engine/thor_engine.dart';

class _Throwing {
  @override
  bool operator ==(Object other) => throw StateError('eq');
  @override
  int get hashCode => 0;
}

void main() {
  test('a computed that flips back to equal inside a batch reruns nothing', () {
    final a = Signal(1);
    final parity = Computed(() => a.value.isEven);
    var runs = 0;
    effect(() {
      parity.value;
      runs++;
    });
    batch(() {
      a.value = 2;
      a.value = 3;
    });
    expect(runs, 1);
  });

  test('NaN and signed zero follow the lite rules', () {
    final s = Signal<double>(double.nan);
    var runs = 0;
    effect(() {
      s.value;
      runs++;
    });
    s.value = double.nan;
    expect(runs, 1, reason: 'identical NaN is not a change');
    final z = Signal<double>(0.0);
    var zr = 0;
    effect(() {
      z.value;
      zr++;
    });
    z.value = -0.0; // 0.0 == -0.0 in Dart and in JS `===`
    expect(zr, 1);
  });

  test(
    'a throwing == surfaces from the write and leaves the signal usable',
    () {
      final s = Signal<Object>(_Throwing());
      var runs = 0;
      effect(() {
        s.value;
        runs++;
      });
      expect(() => s.value = _Throwing(), throwsStateError);
      s.value = 5;
      expect(runs, 2);
      s.value = 6;
      expect(runs, 3);
    },
  );

  test('a nested batch inside an effect still flushes once', () {
    final a = Signal(0), b = Signal(0);
    final seen = <int>[];
    effect(() => seen.add(b.value));
    var first = true;
    effect(() {
      final v = a.value;
      if (first) {
        first = false;
        return;
      }
      batch(() {
        b.value = v;
        b.value = v + 10;
      });
    });
    a.value = 1;
    expect(seen, [0, 11]);
  });

  test('an effect disposing another queued effect keeps it from running', () {
    final a = Signal(0);
    late void Function() stopB;
    var bRuns = 0;
    effect(() {
      if (a.value == 1) stopB();
    });
    stopB = effect(() {
      a.value;
      bRuns++;
    });
    a.value = 1;
    expect(bRuns, 1);
  });

  test('a computed read in an effect that writes a source settles', () {
    final a = Signal(0);
    final d = Computed(() => a.value * 2);
    final seen = <int>[];
    effect(() {
      final v = d.value;
      seen.add(v);
      if (a.peek() < 3) a.value = a.peek() + 1;
    });
    expect(seen.last, 6);
    expect(seen.every((v) => v.isEven), isTrue);
  });

  test(
    'two failing effects: the first is rethrown, the second is reported',
    () async {
      final a = Signal(0);
      var armed = false;
      effect(() {
        a.value;
        if (armed) throw StateError('one');
      });
      effect(() {
        a.value;
        if (armed) throw StateError('two');
      });
      var after = 0;
      effect(() {
        a.value;
        after++;
      });
      armed = true;
      final reported = <Object>[];
      Object? thrown;
      await runZonedGuarded(() async {
        try {
          a.value = 1;
        } on Object catch (e) {
          thrown = e;
        }
        await Future<void>.delayed(Duration.zero);
      }, (e, _) => reported.add(e));
      expect((thrown as StateError).message, 'one');
      expect(after, 2, reason: 'the effects after a failing one still run');
      expect(reported.map((e) => (e as StateError).message), ['two']);
    },
  );

  test('the loop guard keeps the first error and later updates work', () {
    final n = Signal(0);
    var armed = false;
    final stop = effect(() {
      final v = n.value;
      if (armed && v == 1) throw StateError('first');
    });
    final stop2 = effect(() {
      final v = n.value;
      if (armed) n.value = v + 1;
    });
    armed = true;
    expect(
      () => n.value = 1,
      throwsA(isA<StateError>().having((e) => e.message, 'message', 'first')),
    );
    stop();
    stop2();
    final m = Signal(0);
    final seen = <int>[];
    effect(() => seen.add(m.value));
    m.value = 1;
    expect(seen, [0, 1]);
  });

  test('a computed that throws and recovers does not serve a stale value', () {
    final a = Signal(0);
    final c = Computed(() {
      if (a.value == 1) throw StateError('boom');
      return a.value * 10;
    });
    expect(c.value, 0);
    a.value = 1;
    expect(() => c.value, throwsStateError);
    expect(() => c.value, throwsStateError, reason: 'still failing');
    a.value = 2;
    expect(c.value, 20);
  });
}
