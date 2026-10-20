# THOR-S041 · A `state(...)` field with a class that doesn't travel as JSON

**Where:** `thor_engine` · the server, when writing the page state.

## What happened

A `state(...)` field of a `ThorState` changed on the server and holds a class from your app (alone, in a `List` or in a `Map<String, …>`) that doesn't know how to convert itself to JSON, and the field has no `encode:`.

## Why

The server writes into the page the value of each field that changed; the browser reads it back. A number, a string, a bool, a list or a map travel on their own. A class of yours needs to say how: with `toJson()` and `factory fromJson(Map<String, Object?> json)` (like the result of a `query`), and the build registers it automatically. Without that there's no way to know how it's written or how it's read.

## How to fix it

```dart
// WRONG: Order does not know how to travel
class Order {
  const Order(this.id);
  final int id;
}
final orders = state<List<Order>>(const []);
```

```dart
// RIGHT: toJson and fromJson; the field needs nothing else
class Order {
  const Order(this.id);
  factory Order.fromJson(Map<String, Object?> json) => Order(json['id']! as int);
  final int id;
  Map<String, Object?> toJson() => {'id': id};
}
final orders = state<List<Order>>(const []);
```

```dart
// RIGHT: or the field says how, without touching the class
final orders = state<List<Order>>(
  const [],
  encode: (list) => [for (final o in list) o.id],
  decode: (json) => [for (final id in json! as List) Order(id as int)],
);
```

More in [State](../../guia/en/state.md).

[All codes](README.md)
