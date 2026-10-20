// `StateSignal<bool>.toggle()` and `state(<String>{})` with
// add/remove/toggle/contains: a set changes by a new value (what notifies).
import 'package:test/test.dart';
import 'package:thor_engine/thor_engine.dart';

void main() {
  group('toggle', () {
    test('flips a bool and notifies once per flip', () {
      final open = state(false);
      var calls = 0;
      open.addListener(() => calls++);
      open.toggle();
      expect(open.value, isTrue);
      open.toggle();
      expect(open.value, isFalse);
      expect(calls, 2);
    });
  });

  group('sets', () {
    test('add, remove and toggle replace the value and notify', () {
      final picked = state(<String>{});
      var calls = 0;
      picked.addListener(() => calls++);
      final first = picked.value;
      picked.add('a');
      expect(picked.contains('a'), isTrue);
      expect(identical(first, picked.value), isFalse, reason: 'a new set');
      picked.toggle('b');
      expect(picked.value, {'a', 'b'});
      picked.toggle('a');
      expect(picked.value, {'b'});
      picked.remove('b');
      expect(picked.isEmpty, isTrue);
      expect(calls, 4);
    });

    test('a no-op does not notify (add of a member, remove of a stranger)', () {
      final picked = state(<int>{1});
      var calls = 0;
      picked.addListener(() => calls++);
      picked.add(1);
      picked.remove(9);
      picked.clear();
      picked.clear();
      expect(calls, 1);
      expect(picked.length, 0);
    });

    test('the old value is never mutated (a Watch holding it is safe)', () {
      final picked = state(<String>{'x'});
      final before = picked.value;
      picked.add('y');
      expect(before, {'x'});
    });

    test('travels to the page as a list and comes back as a set', () {
      final picked = state(<String>{'a'});
      picked.add('b');
      expect(picked.toJson(), ['a', 'b']);
      final other = state(<String>{});
      other.restoreJson(['a', 'b', 'a']);
      expect(other.value, {'a', 'b'});
      expect(other.value, isA<Set<String>>());
      final ints = state(<int>{});
      ints.restoreJson([3, 1]);
      expect(ints.value, {1, 3});
    });

    test('a hostile cookie value of another shape is rejected', () {
      final picked = state(<String>{});
      expect(() => picked.fromJson({'a': 1}), throwsA(anything));
      expect(() => picked.fromJson([1, 2]), throwsA(anything));
    });
  });
}
