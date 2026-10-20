import 'package:test/test.dart';
import 'package:thor_engine/thor_engine.dart';

void main() {
  test('effects run on start and on every change of what they read', () {
    final a = Signal(1);
    final seen = <int>[];
    effect(() => seen.add(a.value));
    a.value = 2;
    a.value = 2; // same value: no run
    a.value = 3;
    expect(seen, [1, 2, 3]);
  });

  test('dependencies are dynamic (branches re-track)', () {
    final useA = Signal(true), a = Signal('a'), b = Signal('b');
    final seen = <String>[];
    effect(() => seen.add(useA.value ? a.value : b.value));
    b.value = 'b2'; // not read yet
    useA.value = false;
    a.value = 'a2'; // no longer read
    b.value = 'b3';
    expect(seen, ['a', 'b2', 'b3']);
  });

  test('computed is lazy and cached', () {
    var runs = 0;
    final n = Signal(2);
    final doubled = Computed(() {
      runs++;
      return n.value * 2;
    });
    expect(runs, 0);
    final seen = <int>[];
    effect(() => seen.add(doubled.value));
    expect(doubled.value, 4);
    expect(runs, 1);
    n.value = 5;
    expect(seen, [4, 10]);
    expect(runs, 2);
  });

  test('batch runs each dependent effect once', () {
    final a = Signal(0), b = Signal(0);
    var runs = 0;
    effect(() {
      a.value;
      b.value;
      runs++;
    });
    batch(() {
      a.value = 1;
      b.value = 1;
    });
    expect(runs, 2);
  });

  test('disposed effects stop; untracked reads do not subscribe', () {
    final a = Signal(0), b = Signal(0);
    final seen = <int>[];
    final stop = effect(() => seen.add(a.value + untracked(() => b.value)));
    b.value = 5;
    a.value = 1;
    stop();
    a.value = 2;
    expect(seen, [0, 6]);
  });

  test('protocol round-trips event handlers', () {
    final spec = encodeOn({'click': 'cart-add', 'transitionend': 'bump'});
    expect(spec, 'click:cart-add;transitionend:bump');
    expect(decodeOn(spec), {'click': 'cart-add', 'transitionend': 'bump'});
  });

  group('SignalScope (per-request values on the server)', () {
    test('concurrent requests never see each other\'s writes', () async {
      final user = Signal('nobody');
      final label = Computed(() => 'hi ${user.value}');
      Future<String> request(String name, int delayMs) =>
          SignalScope.run(() async {
            user.value = name;
            await Future<void>.delayed(Duration(milliseconds: delayMs));
            return '${user.value}/${label.value}';
          });
      final results = await Future.wait([
        request('ana', 20),
        request('beto', 5),
      ]);
      expect(results, ['ana/hi ana', 'beto/hi beto']);
      // The global value is untouched.
      expect(user.peek(), 'nobody');
      expect(label.value, 'hi nobody');
    });

    test('reads fall back to the global value; update works in scope', () {
      final n = Signal(1)..value = 5;
      SignalScope.run(() {
        expect(n.value, 5);
        n.update((v) => v + 1);
        expect(n.value, 6);
        expect(SignalScope.isActive, isTrue);
      });
      expect(n.value, 5);
      expect(SignalScope.isActive, isFalse);
    });

    test('writes in a scope do not run global effects', () {
      final n = Signal(0);
      final seen = <int>[];
      effect(() => seen.add(n.value));
      SignalScope.run(() => n.value = 9);
      expect(seen, [0]);
    });
  });

  group('parity with the lite runtime', () {
    test('a computed that recomputes to an equal value does not rerun '
        'its dependents', () {
      final n = Signal(1);
      final parity = Computed(() => n.value.isEven);
      var runs = 0;
      effect(() {
        parity.value;
        runs++;
      });
      n.value = 3; // still odd
      n.value = 5;
      expect(runs, 1);
      n.value = 6;
      expect(runs, 2);
    });

    test('equality is identity or ==, so a fresh list always changes', () {
      final n = Signal(0);
      final list = Computed(() => [n.value ~/ 10]);
      var runs = 0;
      effect(() {
        list.value;
        runs++;
      });
      n.value = 1; // a new List each time: not identical, not ==
      expect(runs, 2);
    });

    test('a diamond runs its effect once per write', () {
      final a = Signal(1);
      final b = Computed(() => a.value + 1);
      final c = Computed(() => a.value * 2);
      final seen = <int>[];
      effect(() => seen.add(b.value + c.value));
      a.value = 2;
      a.value = 3;
      expect(seen, [4, 7, 10]);
    });

    test('a computed that reads itself throws a clear error', () {
      late final Computed<int> self;
      self = Computed(() => self.value + 1);
      expect(
        () => self.value,
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('cycle'),
          ),
        ),
      );
    });

    test('an effect loop stops after 1000 rounds and the engine goes on', () {
      final n = Signal(0);
      var runs = 0, armed = false;
      final stop = effect(() {
        runs++;
        final v = n.value;
        if (armed) n.value = v + 1; // reads and writes itself
      });
      armed = true;
      expect(
        () => n.value = 100,
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('cycle'),
          ),
        ),
      );
      expect(runs, lessThan(1100));
      stop();
      final m = Signal(0);
      final seen = <int>[];
      effect(() => seen.add(m.value));
      m.value = 1;
      expect(seen, [0, 1]);
    });
  });

  test(
    'a derived computes once per render on the server, again after a write',
    () {
      var runs = 0;
      final n = Signal(1);
      final doubled = derived(() {
        runs++;
        return n.value * 2;
      });
      SignalScope.run(() {
        expect([doubled.value, doubled(), doubled.value], [2, 2, 2]);
        expect(runs, 1);
        n.value = 5;
        expect(doubled.value, 10);
        expect(runs, 2);
      });
      // a Computed made by hand still computes on every read in a scope
      var plain = 0;
      final c = Computed(() => ++plain);
      SignalScope.run(() => [c.value, c.value]);
      expect(plain, 2);
    },
  );
}
