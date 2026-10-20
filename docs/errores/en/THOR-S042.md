# THOR-S042 · A `row.length` read outside its row

**Where:** `thor_ui` · `row.length(...)` in `Watch.list`.

## What happened

An element uses a length from `row.length(...)` (or a color from `row.color(...)`) (in `StyleProps`, `Positioned(leftLength:)`, `SizedBox(widthLength:)`...) that no row containing it created: the length escaped the `each` (or what it builds) of the list that created it.

## Why

The length has a value per row: the element that reads it looks for the row that contains it and puts the binding and the first value on itself. That works in the `each` and also in the `build` of a row component. Outside the row the variable has no value and the layout would break without any warning.

## How to fix it

```dart
// WRONG: the length escapes the each
late final RowLength x;
Watch.list(circles.rows.call, itemKey: circles.keyOf, each: (row) {
  x = row.length(circles.left);
  return const SizedBox();
});
```

```dart
// RIGHT: created and used inside the row (in the each or in a component)
Watch.list(circles.rows.call, itemKey: circles.keyOf, each: (row) {
  final x = row.length(circles.left);
  return SizedBox(widthLength: x);
});

Watch.list(circles.rows.call, itemKey: circles.keyOf, each: CircleView.new);
```

More in [Long lists](../../guia/en/long-lists.md).

[All codes](README.md)
