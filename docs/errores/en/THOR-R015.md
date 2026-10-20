# THOR-R015 · `8.px` inside a `const`

**Where:** `thor_lints` · rule `length_unit_in_const` (in `dart analyze` and the IDE).

## What happened

A length written with the units extension (`8.px`, `1.5.rem`, `50.percent`) is inside a `const` expression.

## Why

`8.px` is a getter from an extension on `num`, and Dart doesn't run getters in a constant. The compiler only says "Extension methods can't be used in constant expressions", without naming the fix. It mostly happens when writing `const Style(gap: 8.px)` or `const [Box(style: Style(padding: 16.px))]` out of Flutter habit.

## How to fix it

```dart
// WRONG
const card = Style(gap: 8.px, padding: 16.px);
```

```dart
// RIGHT: Length's const constructor
const card = Style(gap: Length.px(8), padding: Length.px(16));

// or without const
final card = Style(gap: 8.px, padding: 16.px);
```

[All codes](README.md)
