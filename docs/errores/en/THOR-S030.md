# THOR-S030 · A row key that is neither a string nor an integer

**Where:** `thor_ui` · `Watch.list(itemKey: …)`.

## What happened

`Watch.list` received an `itemKey` that returns something other than a `String` or an `int` (a `bool`, an enum, an object), or a row whose key is `-9007199254740991`, the number the row template uses as a marker.

## Why

The browser adds, moves and removes rows by their key and writes it into the page as text. A `String` and an `int` travel without loss; an object has no text that identifies it. The template marker can't be a real key, or the browser would replace a real row.

## How to fix it

```dart
// WRONG
Watch.list(orders.rows.call, itemKey: orders.isPaid, each: …)   // bool isPaid(Order o)
```

```dart
// RIGHT: the id or its text
int idOf(Order o) => o.id;              // row.key is an int
String slugOf(Order o) => o.slug;       // row.key is a String
Watch.list(orders.rows.call, itemKey: orders.idOf, each: (row) => …)
```

More in [State](../../guia/en/state.md#lists).

[All codes](README.md)
