// A `state(...)` that holds the app's own classes (a list of them, a map, a
// nullable one) needs no `encode:`/`decode:` when the class has `toJson()`
// and `factory fromJson`: the build registers it (`registerJsonModel`), a
// state that holds one that does not travel is THOR-S041.
import 'dart:convert';

import 'package:test/test.dart';
import 'package:thor_engine/thor_engine.dart';

class Order {
  const Order(this.id, this.customer);
  factory Order.fromJson(Map<String, Object?> json) =>
      Order(json['id']! as int, json['customer']! as String);
  final int id;
  final String customer;
  Map<String, Object?> toJson() => {'id': id, 'customer': customer};

  @override
  bool operator ==(Object other) =>
      other is Order && other.id == id && other.customer == customer;

  @override
  int get hashCode => Object.hash(id, customer);
}

/// A class that does not know JSON.
class Draft {
  const Draft(this.text);
  final String text;
}

class OrdersState extends ThorState {
  OrdersState({super.key});

  final orders = state<List<Order>>(const []);
  final byId = state<Map<String, Order>>(const {});
  final current = state<Order?>(null);
  final drafts = state<List<Draft>>(const []);
}

void main() {
  setUp(() {
    clearJsonModels();
    registerJsonModel<Order>(Order.fromJson, (o) => o.toJson());
    ThorState.register({
      OrdersState: ThorStateType('OrdersState', (state) {
        final s = state as OrdersState;
        return [
          ThorMember.state('orders', s.orders),
          ThorMember.state('byId', s.byId),
          ThorMember.state('current', s.current),
          ThorMember.state('drafts', s.drafts),
        ];
      }),
    });
  });
  tearDown(clearJsonModels);

  test('a list of the app\'s classes goes out as JSON and comes back', () {
    final s = OrdersState();
    s.orders.value = const [Order(1, 'Ana'), Order(2, 'Luis')];
    final json = jsonDecode(jsonEncode(s.orders.toJson()));
    expect(json, [
      {'id': 1, 'customer': 'Ana'},
      {'id': 2, 'customer': 'Luis'},
    ]);
    final back = OrdersState()..orders.restoreJson(json);
    expect(back.orders.value, const [Order(1, 'Ana'), Order(2, 'Luis')]);
    expect(back.orders.value, isA<List<Order>>());
  });

  test('a map and a nullable class travel the same way', () {
    final s = OrdersState();
    s.byId.value = const {'a': Order(1, 'Ana')};
    s.current.value = const Order(2, 'Luis');
    final back = OrdersState()
      ..byId.restoreJson(jsonDecode(jsonEncode(s.byId.toJson())))
      ..current.restoreJson(jsonDecode(jsonEncode(s.current.toJson())));
    expect(back.byId.value, isA<Map<String, Order>>());
    expect(back.byId.value['a'], const Order(1, 'Ana'));
    expect(back.current.value, const Order(2, 'Luis'));
    back.current.restoreJson(null);
    expect(back.current.value, isNull);
  });

  test('explicit encode and decode still win', () {
    final s = state<List<Order>>(
      const [],
      encode: (l) => [for (final o in l) o.id],
      decode: (j) => [for (final i in j! as List) Order(i as int, '#$i')],
    );
    s.value = const [Order(7, 'x')];
    expect(s.toJson(), [7]);
    s.restoreJson([7]);
    expect(s.value, const [Order(7, '#7')]);
  });

  test('the page state of a changed field is its JSON', () {
    final s = OrdersState(key: 'm')..orders.value = const [Order(1, 'Ana')];
    expect(stateJson([s]), {
      'OrdersState#m.orders': [
        {'id': 1, 'customer': 'Ana'},
      ],
    });
  });

  test('a class that does not travel is THOR-S041 and names the field', () {
    final s = OrdersState(key: 'd')..drafts.value = const [Draft('hi')];
    expect(
      () => encodeStateJson(stateJson([s])),
      throwsA(
        isA<StateError>()
            .having(
              (e) => e.message,
              'message',
              contains('OrdersState#d.drafts'),
            )
            .having((e) => e.message, 'message', contains('Draft'))
            .having((e) => e.message, 'message', contains('THOR-S041')),
      ),
    );
  });
}
