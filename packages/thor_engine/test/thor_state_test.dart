import 'dart:convert';

import 'package:test/test.dart';
import 'package:thor_engine/thor_engine.dart';

enum Tab { home, cart }

// The member list thor generates for [CounterState], by hand.
abstract class _CounterStateMembers extends ThorState {
  _CounterStateMembers({super.key});

  @override
  String get $type => 'CounterState';

  @override
  List<ThorMember> get $members {
    final s = this as CounterState;
    return [
      ThorMember.state('count', s.count),
      ThorMember('label', s.label, call: (_) => s.label()),
      ThorMember(
        'isZero',
        s.isZero,
        call: (_) => s.isZero(),
        variants: const [false, true],
      ),
      ThorMember('inc', s.inc, call: (_) => s.inc()),
      ThorMember('add', s.add, call: (a) => s.add(int.parse(a!))),
      ThorMember('tab', s.tab, call: (_) => s.tab(), variants: Tab.values),
    ];
  }
}

class CounterState extends _CounterStateMembers {
  CounterState({super.key});

  final count = state(0);
  final current = Tab.home;

  String label() => '${count.value}';
  bool isZero() => count.value == 0;
  Tab tab() => current;
  void inc() => count.value++;
  void add(int n) => count.value += n;
}

/// The form an app writes today: no generated base, a registry instead.
class CartState extends ThorState {
  CartState({super.key});

  final items = state(0);

  bool isEmpty() => items.value == 0;
  void add() => items.value++;
}

/// A state nobody registered (an app run without thor's entry).
class LostState extends ThorState {
  void go() {}
}

// What thor writes into .dart_tool/thor/states.dart for [CartState].
void registerCart() => ThorState.register({
  CartState: ThorStateType('CartState', (state) {
    final s = state as CartState;
    return [
      ThorMember.state('items', s.items),
      ThorMember(
        'isEmpty',
        s.isEmpty,
        call: (_) => s.isEmpty(),
        variants: const [false, true],
      ),
      ThorMember('add', s.add, call: (_) => s.add()),
    ];
  }),
});

String Function() asSource(String Function() f) => f;
int Function() asIntSource(int Function() f) => f;

void main() {
  test('tear-offs resolve to their member (equality, not identity)', () {
    final c = CounterState(key: 't1');
    expect(ThorState.resolve(c.inc)?.$2.name, 'inc');
    expect(ThorState.resolve(asSource(c.label))?.$2.name, 'label');
    // A signal field used as a function.
    expect(ThorState.resolve(asIntSource(c.count.call))?.$2.name, 'count');
    var calls = 0;
    expect(ThorState.resolve(() => calls++), isNull);
  });

  test('a tear-off resolves to its own instance, not an equal one', () {
    final a = CounterState(key: 'r1'), b = CounterState(key: 'r2');
    expect(identical(ThorState.resolve(b.inc)?.$1, b), isTrue);
    expect(identical(ThorState.resolve(a.inc)?.$1, a), isTrue);
    expect(a.memberOf(b.inc), isNull);
    // Many lookups, one answer (the index is built once).
    for (var i = 0; i < 1000; i++) {
      expect(a.memberOf(a.add)?.name, 'add');
    }
  });

  test('withArg keeps the member and the argument', () {
    final c = CounterState(key: 't2');
    final f = c.add.withArg(3);
    final bound = BoundCall.of(f)!;
    expect(ThorState.resolve(bound.function)?.$2.name, 'add');
    expect(bound.arg, 3);
    f();
    expect(c.count.value, 3);
  });

  test('ids and state JSON', () {
    final c = CounterState(key: 'j')..count.value = 7;
    expect(c.idPrefix, 'CounterState#j');
    expect(stateJson([c]), {'CounterState#j.count': 7});
    c.count.value = 0; // back to the code's value: nothing to ship
    expect(stateJson([c]), isEmpty);
    c.count.restoreJson(2);
    expect(c.label(), '2');
    expect(encodeArg(Tab.cart), 'cart');
  });

  test('the key of an id escapes the separator and the percent', () {
    expect(CounterState(key: 'a~b').idPrefix, 'CounterState#a%7Eb');
    expect(CounterState(key: '100%').idPrefix, 'CounterState#100%25');
    expect(CounterState(key: 'a;b|c').idPrefix, 'CounterState#a%3Bb|c');
    expect(CounterState(key: 'x%3B').idPrefix, 'CounterState#x%253B');
    expect(parseBindingId('${CounterState(key: 'a~b').idPrefix}.add'), (
      'CounterState#a%7Eb.add',
      null,
    ));
  });

  test('decoded JSON lists and maps take the field type', () {
    final tags = state(const <String>[]);
    tags.restoreJson(jsonDecode('["a","b"]'));
    expect(tags.value, isA<List<String>>());
    expect(tags.value, ['a', 'b']);
    final scores = state(const <double>[]);
    scores.restoreJson(jsonDecode('[1, 2.5]'));
    expect(scores.value, [1.0, 2.5]);
    final names = state(const <String, String>{});
    names.restoreJson(jsonDecode('{"a":"x"}'));
    expect(names.value, isA<Map<String, String>>());
  });

  group('registered states (no generated base class)', () {
    setUpAll(registerCart);

    test('take their name and members from the registry', () {
      final cart = CartState(key: 'reg1');
      expect(cart.$type, 'CartState');
      expect(cart.idPrefix, 'CartState#reg1');
      expect(
        [for (final m in cart.members) m.name],
        ['items', 'isEmpty', 'add'],
      );
      expect(ThorState.resolve(cart.add)?.$2.name, 'add');
      expect(cart.members[1].variants, [false, true]);
      cart.members.last.call!(null);
      expect(cart.items.value, 1);
      expect(ThorState.isRegistered(CartState), isTrue);
    });

    test('declaresCall: only the query and command fields the build lists', () {
      ThorState.register({
        CartState: ThorStateType(
          'CartState',
          (state) => [ThorMember('add', (state as CartState).add)],
          calls: const {'total', 'checkout'},
        ),
      });
      addTearDown(registerCart);
      expect(ThorState.declaresCall('CartState.total'), isTrue);
      expect(ThorState.declaresCall('CartState#left.checkout'), isTrue);
      expect(ThorState.declaresCall('CartState.add'), isFalse);
      expect(ThorState.declaresCall('CartState.nope'), isFalse);
      expect(ThorState.declaresCall('OtherState.total'), isFalse);
      expect(ThorState.declaresCall('total'), isFalse);
      expect(ThorState.declaresCall('.total'), isFalse);
    });

    test('declaresCall: a registry without calls may name anything', () {
      registerCart();
      expect(ThorState.declaresCall('CartState.anything'), isTrue);
      expect(ThorState.declaresCall('OtherState.total'), isFalse);
    });

    test('registering again replaces the class (a hot reload)', () {
      ThorState.register({
        CartState: ThorStateType(
          'CartState',
          (state) => [ThorMember('add', (state as CartState).add)],
        ),
      });
      expect([for (final m in CartState().members) m.name], ['add']);
      registerCart();
      expect(CartState().members, hasLength(3));
    });

    test('an instance made before a new registry takes its members', () {
      // A top-level state lives across `thor dev`'s hot reload, which
      // registers the classes again with a member added or removed.
      final cart = CartState(key: 'reload');
      cart.items.value = 4;
      expect(ThorState.resolve(cart.isEmpty)?.$2.name, 'isEmpty');
      ThorState.register({
        CartState: ThorStateType('CartState', (state) {
          final s = state as CartState;
          return [
            ThorMember.state('items', s.items),
            ThorMember('add', s.add, call: (_) => s.add()),
          ];
        }),
      });
      expect([for (final m in cart.members) m.name], ['items', 'add']);
      expect(ThorState.resolve(cart.isEmpty), isNull);
      expect(ThorState.resolve(cart.add)?.$2.name, 'add');
      // The values stay: same signals.
      expect(cart.members.first.signal?.value, 4);
      registerCart();
      expect(cart.members, hasLength(3));
      expect(ThorState.resolve(cart.isEmpty)?.$2.name, 'isEmpty');
    });

    test('an unregistered state is THOR-S010, with how to fix it', () {
      final lost = LostState();
      expect(ThorState.isRegistered(LostState), isFalse);
      expect(
        () => lost.members,
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('LostState is not registered'),
              // The exact commands, and what a plain `dart test` lacks.
              contains('`thor test`'),
              contains('instead of `dart test`'),
              contains('`thor dev`'),
              contains('instead of `dart run'),
              contains('code generation'),
              contains('THOR-S010'),
            ),
          ),
        ),
      );
      // A widget's callback is looked up among every state: the lost one
      // fails the same way, never as "not a state method".
      expect(() => ThorState.resolve(lost.go), throwsStateError);
    });

    test('the old generated base still wins over the registry', () {
      ThorState.register({
        CounterState: ThorStateType('Other', (_) => const []),
      });
      final c = CounterState(key: 'reg-old');
      expect(c.$type, 'CounterState');
      expect(c.members, isNotEmpty);
    });
  });
}
