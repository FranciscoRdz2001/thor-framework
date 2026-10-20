# THOR-L003 · Zero-width `LayoutScope`

**Where:** development inspector (debug mode, in the browser).

## What happened

A `LayoutScope` (container queries, Thor's `LayoutBuilder`) measures 0 px wide.

## Why

A query container cannot size itself by its content (CSS forces it to `inline-size`): inside an unbounded `Row`, or as the child of something that shrinks to fit its content, it collapses.

## How to fix it

```dart
// WRONG
Row(children: [LayoutScope(child: Cards())])
```

```dart
// RIGHT
Row(children: [Expanded(child: LayoutScope(child: Cards()))])
```

[All codes](README.md)
