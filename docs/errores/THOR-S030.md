# THOR-S030 · La clave de una fila que no es texto ni entero

**Dónde:** `thor_ui` · `Watch.list(itemKey: …)`.

## Qué pasó

`Watch.list` recibió un `itemKey` que devuelve otra cosa que un `String` o un `int` (un `bool`, un enum, un objeto), o una fila cuya clave es `-9007199254740991`, el número que la plantilla de fila usa como marcador.

## Por qué

El navegador agrega, mueve y quita filas por su clave y la escribe en la página como texto. Un `String` y un `int` viajan sin pérdida; un objeto no tiene un texto que lo identifique. El marcador de la plantilla no puede ser una clave real, o el navegador reemplazaría una fila de verdad.

## Cómo se arregla

```dart
// WRONG
Watch.list(orders.rows.call, itemKey: orders.isPaid, each: …)   // bool isPaid(Order o)
```

```dart
// RIGHT: el id o su texto
int idOf(Order o) => o.id;              // row.key es un int
String slugOf(Order o) => o.slug;       // row.key es un String
Watch.list(orders.rows.call, itemKey: orders.idOf, each: (row) => …)
```

Más en [Estado](../guia/es/estado.md#listas).

[Todos los códigos](README.md)
