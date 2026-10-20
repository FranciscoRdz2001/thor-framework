# THOR-S043 · A key met twice in a `Watch.tree`

**Where:** `thor_ui` · `Watch.tree(itemKey: …)`.

## What happened

Two nodes of the tree returned the same key, or a node is among its own descendants (a cycle).

## Why

The browser reconciles each level by key, and a callback with `withArg(row.key)` names one node: with two nodes of the same key it wouldn't know which one. A cycle never ends: the server stops at the first key it sees again.

## How to fix it

```dart
// WRONG: the widget type's id, which repeats
String idOf(Node n) => n.type;
```

```dart
// RIGHT: an id unique in the whole tree
String idOf(Node n) => n.id;
```

More in [State](../../guia/en/state.md#trees).

[All codes](README.md)
