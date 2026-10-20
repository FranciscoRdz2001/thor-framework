# THOR-S042 · Una `row.length` leída fuera de su fila

**Dónde:** `thor_ui` · `row.length(...)` en `Watch.list`.

## Qué pasó

Un elemento usa una longitud de `row.length(...)` (o un color de `row.color(...)`) (en `StyleProps`, `Positioned(leftLength:)`, `SizedBox(widthLength:)`...) que ninguna fila que lo contiene creó: la longitud salió del `each` (o de lo que construye) de la lista que la creó.

## Por qué

La longitud vale por fila: el elemento que la lee busca la fila que lo contiene y pone en sí mismo el enlace y el primer valor. Eso funciona en el `each` y también en el `build` de un componente de la fila. Fuera de la fila la variable no tiene valor y el layout se rompería sin ningún aviso.

## Cómo se arregla

```dart
// WRONG: la longitud sale del each
late final RowLength x;
Watch.list(circles.rows.call, itemKey: circles.keyOf, each: (row) {
  x = row.length(circles.left);
  return const SizedBox();
});
```

```dart
// RIGHT: se crea y se usa dentro de la fila (en el each o en un componente)
Watch.list(circles.rows.call, itemKey: circles.keyOf, each: (row) {
  final x = row.length(circles.left);
  return SizedBox(widthLength: x);
});

Watch.list(circles.rows.call, itemKey: circles.keyOf, each: CircleView.new);
```

Más en [Listas largas](../guia/es/listas-largas.md).

[Todos los códigos](README.md)
