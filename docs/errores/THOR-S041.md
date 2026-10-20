# THOR-S041 · Un campo `state(...)` con una clase que no viaja como JSON

**Dónde:** `thor_engine` · el servidor, al escribir el estado de la página.

## Qué pasó

Un campo `state(...)` de un `ThorState` cambió en el servidor y guarda una clase de tu app (sola, en una `List` o en un `Map<String, …>`) que no sabe convertirse en JSON, y el campo no trae `encode:`.

## Por qué

El servidor escribe en la página el valor de cada campo que cambió; el navegador lo lee de vuelta. Un número, un texto, un bool, una lista o un mapa viajan solos. Una clase tuya necesita decir cómo: con `toJson()` y `factory fromJson(Map<String, Object?> json)` (como el resultado de una `query`), y el build la registra sola. Sin eso no hay forma de saber cómo se escribe ni cómo se lee.

## Cómo se arregla

```dart
// WRONG: Order no sabe viajar
class Order {
  const Order(this.id);
  final int id;
}
final orders = state<List<Order>>(const []);
```

```dart
// RIGHT: toJson y fromJson; el campo no necesita nada más
class Order {
  const Order(this.id);
  factory Order.fromJson(Map<String, Object?> json) => Order(json['id']! as int);
  final int id;
  Map<String, Object?> toJson() => {'id': id};
}
final orders = state<List<Order>>(const []);
```

```dart
// RIGHT: o el campo dice cómo, sin tocar la clase
final orders = state<List<Order>>(
  const [],
  encode: (list) => [for (final o in list) o.id],
  decode: (json) => [for (final id in json! as List) Order(id as int)],
);
```

Más en [Estado](../guia/es/estado.md).

[Todos los códigos](README.md)
