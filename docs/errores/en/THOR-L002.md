# THOR-L002 · `Expanded`/`Flexible` outside a flex

**Where:** development inspector (debug mode, in the browser).

## What happened

An `Expanded` or `Flexible` ended up on an element whose parent is not a `Row`, `Column` or `Flex`.

## Why

It is Flutter's "Incorrect use of ParentDataWidget": `flex: 1` only means something inside a flex container. It usually happens when wrapping a `Row`'s child in a `Padding`/`Container` that ends up in between.

## How to fix it

```dart
// WRONG
Row(children: [Padding(padding: p, child: Expanded(child: field))])
```

```dart
// RIGHT
Row(children: [Expanded(child: Padding(padding: p, child: field))])
```

[All codes](README.md)
