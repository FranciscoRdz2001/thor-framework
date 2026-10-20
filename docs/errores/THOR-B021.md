# THOR-B021 · Una query o un comando cuyo valor o argumento no viaja como JSON

**Dónde:** `thor dev` / `thor build` / `thor test`.

## Qué pasó

Un campo `query(fn)`, `queryWith(fn, arg: …)`, `command(fn)` o `commandWith(fn)` de un `ThorState` devuelve un tipo que no se puede mandar al navegador, o recibe un argumento que no viaja como JSON.

## Por qué

`fn` corre en el servidor. Su resultado llega al navegador como JSON (en el HTML de la primera página, en cada `refresh` y en la respuesta de cada `run` de un comando), y el argumento viaja de vuelta igual. El build revisa los tipos antes de publicar para que nunca falle en silencio al serializar:

- **Argumento:** `int`, `double`, `num`, `String` o `bool` (o su versión nullable), un record de ellos (`({String q, int page})`) o una clase de tu app con `toJson()` y `factory fromJson(Map<String, Object?> json)`. Un comando (`commandWith`) acepta lo mismo.
- **Resultado:** un valor simple, una `List` o un `Map<String, …>` de ellos, o una clase de tu app con `toJson()` y `factory fromJson(Map<String, Object?> json)` (o una `List` de ellas). El servidor usa `toJson`; el navegador, `fromJson`. Un comando también puede no devolver nada (`void`).

## Cómo se arregla

```dart
// WRONG — Profile has no toJson/fromJson; the argument is a class
class Profile {
  const Profile(this.name);
  final String name;
}
final info = query(repo.info);                          // Future<Profile> info()
final page = queryWith(repo.page, arg: const Filter()); // Future<List<Order>> page(Filter f), Filter sin toJson()
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

[Todos los códigos](README.md)
