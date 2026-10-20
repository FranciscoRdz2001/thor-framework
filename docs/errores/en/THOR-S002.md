# THOR-S002 · A per-row method doesn't receive the item

**Where:** `thor_ui` · `row.text`, `row.watch`, `row.attributes` inside `Watch.list`.

## What happened

A per-row binding points to a method that doesn't take the list item (or that doesn't accept the fixed argument from `withArg`).

## Why

In a keyed list the browser clones the row and computes each value by calling the method **with the item** of that row. The method has to receive it: `String f(Item item)`, or a fixed argument first and the item after.

## How to fix it

```dart
// WRONG
String lineName() => ...;          // does not receive the row
row.text(state.lineName)
```

```dart
// RIGHT
String lineName(Line line) => line.name;
row.text(state.lineName)

// With a fixed argument (column) and then the item:
String cellLabel(int column, Line line) => ...;
row.text(state.cellLabel.withArg(3))
```

[All codes](README.md)
