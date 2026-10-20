# THOR-B021 · A query or a command whose value or argument does not travel as JSON

**Where:** `thor dev` / `thor build` / `thor test`.

## What happened

A `query(fn)`, `queryWith(fn, arg: …)`, `command(fn)` or `commandWith(fn)` field of a `ThorState` returns a type that cannot be sent to the browser, or receives an argument that is not a simple value.

## Why

`fn` runs on the server. Its result reaches the browser as JSON (in the first page's HTML, on every `refresh` and in the response to every `run` of a command), and the argument travels back the same way. The build checks the types before publishing so serialization never fails silently:

- **Argument:** `int`, `double`, `num`, `String` or `bool` (or their nullable version), a record of them (`({String q, int page})`) or a class of your app with `toJson()` and `factory fromJson(Map<String, Object?> json)`. A command (`commandWith`) accepts the same.
- **Result:** a simple value, a `List` or a `Map<String, …>` of them, or a class of your app with `toJson()` and `factory fromJson(Map<String, Object?> json)` (or a `List` of them). The server uses `toJson`; the browser, `fromJson`. A command can also return nothing (`void`).

## How to fix it

```dart
// WRONG — Profile has no toJson/fromJson; the argument is a class
class Profile {
  const Profile(this.name);
  final String name;
}
final info = query(repo.info);                          // Future<Profile> info()
final page = queryWith(repo.page, arg: const Filter()); // Future<List<Order>> page(Filter f), Filter has no toJson()
```

```dart
// RIGHT
class Profile {
  const Profile(this.name);
  factory Profile.fromJson(Map<String, Object?> json) => Profile(json['name']! as String);
  final String name;
  Map<String, Object?> toJson() => {'name': name};
}
final info = query(repo.info);
final page = queryWith(repo.page, arg: 0);              // Future<List<Order>> page(int n)
```

```dart
// RIGHT — the argument as a class (or a record) that travels as JSON
class OrdersFilter {
  const OrdersFilter({this.q = '', this.page = 1});
  factory OrdersFilter.fromJson(Map<String, Object?> json) =>
      OrdersFilter(q: json['q']! as String, page: json['page']! as int);
  final String q;
  final int page;
  OrdersFilter copyWith({String? q, int? page}) =>
      OrdersFilter(q: q ?? this.q, page: page ?? this.page);
  Map<String, Object?> toJson() => {'q': q, 'page': page};
}
final orders = queryWith(repo.orders, arg: const OrdersFilter());   // Future<List<Order>> orders(OrdersFilter f)
// in a state method: orders.setArg(orders.arg.value.copyWith(page: 2));
```

[All codes](README.md)
