# THOR-R037 · A value that depends on text direction reached a place that needs the physical side

**Where:** `thor_style` · `EdgeInsetsGeometry` (`add`, `+`, `cssLeft`, `cssRight`),
`EdgeInsetsDirectional`, `AlignmentDirectional`; and `SafeArea` when its
`Padding` is directional.

## What happened

The left or right side was requested from something given as `start`/`end`
(`EdgeInsetsDirectional`, `AlignmentDirectional`), or an
`EdgeInsets.only(left: …)` was added to an `EdgeInsetsDirectional.only(start: …)`, or a
fractional `AlignmentDirectional` was used (`AlignmentDirectional(0.5, 0)`).

## Why

`start` is the left in left-to-right text and the right in
right-to-left text; the browser decides that. CSS can't
add `padding-left` to `padding-inline-start` (the second one wins, they don't
add up), nor move a child a fraction "toward the end" without knowing the direction.
That's why the render fails with this code instead of painting the wrong side.

## How to fix it

```dart
// WRONG: two forms of the same side, they cannot be added in CSS
Padding(
  padding: EdgeInsets.only(left: 4).add(EdgeInsetsDirectional.only(start: 8)),
  child: child,
)
```

```dart
// RIGHT: a single form, or fix the direction with resolve
Padding(
  padding: EdgeInsetsDirectional.only(start: 12),
  child: child,
)
Padding(
  padding: EdgeInsets.only(left: 4)
      .add(EdgeInsetsDirectional.only(start: 8))
      .resolve(TextDirection.ltr),
  child: child,
)
```

An `AlignmentDirectional` with `start` at −1, 0 or 1 (`topStart`, `centerEnd`…)
doesn't need a direction; a fractional one does: use `Alignment` or
`alignment.resolve(TextDirection.ltr)`.

[All codes](README.md)
