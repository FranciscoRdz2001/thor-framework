# THOR-S032 · Una fila con lambda sin la sonda de su clase

**Dónde:** `thor_ui` · `row.text((o) => o.property)` al pintar.

## Qué pasó

`row.text` recibió un lambda y thor no tiene registrada la clase de la fila. Pasa al correr la app sin `thor` (`dart run bin/server.dart` a secas, un test con `dart test`).

## Por qué

thor averigua qué propiedad lee el lambda al preparar la app, y eso corre con `thor dev`, `thor build`, `thor test` y `thor render`.

## Cómo se arregla

Corre la app o sus pruebas con `thor`. O pasa un método del estado, que no necesita sonda:

```dart
row.text(orders.customerOf)      // String customerOf(Order o) => o.customer
```

Más en [Estado](../guia/es/estado.md#listas).

[Todos los códigos](README.md)
