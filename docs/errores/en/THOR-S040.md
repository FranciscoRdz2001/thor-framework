# THOR-S040 · A virtual list without its row height

**Where:** `thor_ui` · `Watch.list(virtual: true)`.

## What happened

`Watch.list` received `virtual: true` without `itemExtent`.

## Why

A virtual list keeps only the rows near the screen in the page. The browser knows which ones they are by adding up heights: with rows of the same height it's a division over the scroll position, without measuring any row. Without that height there's no way to know which row goes where.

## How to fix it

```dart
// WRONG
Watch.list(market.rows.call, itemKey: market.keyOf, virtual: true, each: …)
```

```dart
// RIGHT: the height of each row, in px
Watch.list(market.rows.call, itemKey: market.keyOf, itemExtent: 34, virtual: true, each: …)
```

More in [Long lists](../../guia/en/long-lists.md).

[All codes](README.md)
