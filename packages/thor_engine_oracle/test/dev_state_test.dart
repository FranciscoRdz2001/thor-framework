import 'dart:convert';

import 'package:test/test.dart';
import 'package:thor_engine/thor_engine.dart';
import 'package:thor_engine_oracle/src/dev_state.dart';

enum Size { s, m, l }

/// A state whose members are given: the same `$type` with other members
/// is "the class after an edit".
class _State extends ThorState {
  _State(this.$type, this.fields, {super.key});

  @override
  final String $type;

  /// Name → its signal, or null for a method with that name.
  final Map<String, StateSignal<Object?>?> fields;

  @override
  List<ThorMember> get $members => [
    for (final MapEntry(:key, :value) in fields.entries)
      if (value == null)
        ThorMember(key, () {}, call: (_) => null)
      else
        ThorMember.state(key, value),
  ];
}

int _json(Object? json) => jsonEncode(json).length;

/// An enum field: it needs its encoding.
StateSignal<Size> _size(Size initial) => state(
  initial,
  encode: (v) => v.name,
  decode: (j) => Size.values.byName(j! as String),
);

/// What the browser keeps between the two pages: JSON text.
Object? _through(Map<String, Object?> snapshot) =>
    jsonDecode(jsonEncode(snapshot));

class _Opaque {
  const _Opaque();
}

void main() {
  group('snapshot', () {
    test('every JSON field, changed or not, with the instance key', () {
      final a = _State('Counter', {
        'count': state<int>(0),
        'name': state<String>('x'),
      });
      final b = _State('Counter', {'count': state<int>(4)}, key: 'left');
      a.fields['name']!.value = 'y';
      final snap = snapshotStates([a, b], size: _json);
      expect(snap['v'], devStateVersion);
      expect(snap['s'], {
        'Counter.count': 0,
        'Counter.name': 'y',
        'Counter#left.count': 4,
      });
    });

    test('values that are not JSON are left out and named', () {
      final dropped = <String>[];
      final s = _State('Odd', {
        'object': state<Object?>(const _Opaque()),
        'set': state<Object?>({1, 2}),
        'intKeys': state<Object?>({1: 'a'}),
        'nan': state(double.nan),
        'infinite': state(double.infinity),
        'nested': state<Object?>([
          {'ok': const _Opaque()},
        ]),
        'throws': state<int>(1, encode: (_) => throw StateError('no')),
        'enum': _size(Size.m),
        'fine': state<Object?>({
          'a': [1, 2.5, null, true],
        }),
        'method': null,
      });
      final snap = snapshotStates([s], size: _json, dropped: dropped);
      expect((snap['s']! as Map).keys, ['Odd.enum', 'Odd.fine']);
      expect(dropped, [
        'Odd.object',
        'Odd.set',
        'Odd.intKeys',
        'Odd.nan',
        'Odd.infinite',
        'Odd.nested',
        'Odd.throws',
      ]);
    });

    test('a field declared a set is kept (as a list) and restored a set', () {
      final picked = state(<String>{'b', 'a'});
      final s = _State('Pick', {'picked': picked});
      final snap = snapshotStates([s], size: _json);
      expect((snap['s']! as Map)['Pick.picked'], ['b', 'a']);
      picked.value = <String>{};
      picked.restoreJson((snap['s']! as Map)['Pick.picked']);
      expect(picked.value, {'b', 'a'});
      expect(picked.value, isA<Set<String>>());
    });

    test('over the limit, the largest fields go first until it fits', () {
      final s = _State('Big', {
        'small': state('a'),
        'medium': state('m' * 50),
        'huge': state('h' * 500),
      });
      final dropped = <String>[];
      final snap = snapshotStates(
        [s],
        size: _json,
        limit: 100,
        dropped: dropped,
      );
      expect((snap['s']! as Map).keys, ['Big.small', 'Big.medium']);
      expect(dropped, ['Big.huge']);
      expect(jsonEncode(snap['s']).length, lessThanOrEqualTo(100));
      // Nothing fits: an empty snapshot, not an error.
      expect(snapshotStates([s], size: _json, limit: 0)['s'], isEmpty);
    });
  });

  group('restore', () {
    test('round trip, and it wins over the server values', () {
      final before = _State('Form', {
        'count': state<int>(0),
        'tags': state<List<String>>(const []),
        'scores': state<Map<String, int>>(const {}),
        'size': _size(Size.s),
      });
      before.fields['count']!.value = 5;
      before.fields['tags']!.value = ['a', 'b'];
      before.fields['scores']!.value = {'x': 3};
      before.fields['size']!.value = Size.l;
      final snap = _through(snapshotStates([before], size: _json));

      // The reloaded page: the server said 2.
      final after = _State('Form', {
        'count': state<int>(0)..value = 2,
        'tags': state<List<String>>(const []),
        'scores': state<Map<String, int>>(const {}),
        'size': _size(Size.s),
      });
      final r = restoreStates([after], snap);
      expect(r.dropped, isEmpty);
      expect(r.restored, hasLength(4));
      expect(after.fields['count']!.value, 5);
      expect(after.fields['tags']!.value, isA<List<String>>());
      expect(after.fields['tags']!.value, ['a', 'b']);
      expect(after.fields['scores']!.value, isA<Map<String, int>>());
      expect(after.fields['size']!.value, Size.l);
    });

    test('a changed class keeps what still fits and drops the rest', () {
      final snap = _through({
        'v': devStateVersion,
        's': {
          'Form.count': 5, // kept
          'Form.renamed': 'x', // the field is gone
          'Form.nowMethod': 1, // a method now
          'Form.nowString': 3, // int → String
          'Form.nowInts': ['a'], // List<String> → List<int>
          'Form.size': 'xl', // an enum value that no longer exists
          'Form.maybe': 'hi', // null now: anything fits a nullable
          'Removed.count': 1, // the whole class is gone
        },
      });
      final s = _State('Form', {
        'count': state<int>(0),
        'nowMethod': null,
        'nowString': state<String>('keep'),
        'nowInts': state<List<int>>(const [7]),
        'size': _size(Size.s),
        'maybe': state<String?>(null),
        'added': state<int>(9),
      });
      final r = restoreStates([s], snap);
      expect(r.restored, unorderedEquals(['Form.count', 'Form.maybe']));
      expect(r.dropped.keys, {
        'Form.renamed',
        'Form.nowMethod',
        'Form.nowString',
        'Form.nowInts',
        'Form.size',
        'Removed.count',
      });
      expect(r.dropped['Form.nowString'], 'was number, now string');
      expect(r.rolledBack, isFalse);
      // What was not restored keeps the server's value.
      expect(s.fields['count']!.value, 5);
      expect(s.fields['maybe']!.value, 'hi');
      expect(s.fields['nowString']!.value, 'keep');
      expect(s.fields['nowInts']!.value, [7]);
      expect(s.fields['size']!.value, Size.s);
      expect(s.fields['added']!.value, 9);
    });

    test('a null that no longer fits a non-nullable field is dropped', () {
      final s = _State('Form', {'count': state<int>(3)});
      final r = restoreStates(
        [s],
        {
          'v': devStateVersion,
          's': {'Form.count': null},
        },
      );
      expect(r.dropped.keys, ['Form.count']);
      expect(s.fields['count']!.value, 3);
    });

    test('anything that is not our snapshot is ignored', () {
      final s = _State('Form', {'count': state<int>(3)});
      for (final junk in <Object?>[
        null,
        'text',
        [1],
        {'s': <String, Object?>{}}, // no version
        {'v': devStateVersion + 1, 's': <String, Object?>{}},
        {'v': devStateVersion, 's': 'not a map'},
      ]) {
        final r = restoreStates([s], junk);
        expect(r.restored, isEmpty);
        expect(r.dropped, isEmpty);
      }
      expect(s.fields['count']!.value, 3);
    });

    test('effects run once for the whole restore', () {
      final a = state(0), b = state(0);
      final s = _State('Pair', {'a': a, 'b': b});
      final seen = <String>[];
      final stop = effect(() => seen.add('${a.value},${b.value}'));
      addTearDown(stop);
      restoreStates(
        [s],
        {
          'v': devStateVersion,
          's': {'Pair.a': 1, 'Pair.b': 2},
        },
      );
      expect(seen, ['0,0', '1,2']);
    });

    test('if the page throws with the restored values, all go back', () {
      final items = state(const <String>['a', 'b', 'c']);
      final selected = state(2);
      final s = _State('List', {'items': items, 'selected': selected});
      final shown = <String>[];
      // The code changed: `selected` indexes a list that is now shorter.
      final stop = effect(() => shown.add(items.value[selected.value]));
      addTearDown(stop);
      final r = restoreStates(
        [s],
        {
          'v': devStateVersion,
          's': {
            'List.items': ['x'],
            'List.selected': 2,
          },
        },
      );
      expect(r.rolledBack, isTrue);
      expect(r.restored, isEmpty);
      expect(r.dropped.keys, containsAll(['List.items', 'List.selected']));
      expect(items.value, ['a', 'b', 'c']);
      expect(selected.value, 2);
      // The page still reacts.
      selected.value = 0;
      expect(shown.last, 'a');
    });
  });

  test('isJson', () {
    expect(
      isJson({
        'a': 1,
        'b': <Object?>[null, 'x', false],
      }),
      isTrue,
    );
    expect(isJson(double.negativeInfinity), isFalse);
    expect(isJson(DateTime(2026)), isFalse);
    expect(isJson(<Object?, Object?>{null: 1}), isFalse);
  });

  test('the dev part is off unless the build asks for it', () {
    // Tests run without -Dthor.dev=true, like release builds.
    expect(devReload, isFalse);
    expect(devStateKey, 'thor:state:');
  });
}
