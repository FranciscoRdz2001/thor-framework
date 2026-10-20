# THOR-P030 · `Form(defaults:)` no es un mapa ni tiene `toJson()`

**Dónde:** `thor_ui` · `Form(defaults:)` (al dibujar el formulario).

## Qué pasó

`defaults` recibió algo que no es un `Map` ni un objeto con `toJson()`.

## Por qué

Los campos se rellenan por `name`: hace falta un mapa nombre → valor. Un modelo tiene que decir cuáles son sus campos, y `toJson()` es la forma que thor ya pide para los datos de una `query`.

## Cómo se arregla

```dart
// WRONG
Form(defaults: 42, child: …)
Form(defaults: order, child: …)      // Order no tiene toJson()
```

```dart
// RIGHT
Form(defaults: order, child: …)      // class Order { Map<String, Object?> toJson() => {...}; }
Form(defaults: {'customer': order.customer}, child: …)
```

[Todos los códigos](README.md)
