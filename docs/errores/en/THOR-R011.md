# THOR-R011 · A `Table` column width that CSS can't express

**Where:** `thor_ui` · `MaxColumnWidth` / `MinColumnWidth`.

## What happened

A `MaxColumnWidth` or `MinColumnWidth` combines two widths that a CSS grid
track can't compare (the smaller of a flexible part and a length, or of
the content and a length).

## Why

Thor turns each `TableColumnWidth` into a `grid-template-columns` track
and lets the browser measure the columns. `max()`/`min()` only compare
lengths (`px`, `%`); a flexible part (`fr`) can only be the maximum of
a `minmax()`.

## How to fix it

```dart
// WRONG: the smaller of 200 px and a share of the free space
MinColumnWidth(FixedColumnWidth(200), FlexColumnWidth())
```

```dart
// RIGHT: two lengths, or a flexible share with a minimum
MinColumnWidth(FixedColumnWidth(200), FractionColumnWidth(0.3))
MaxColumnWidth(FixedColumnWidth(120), FlexColumnWidth())
```

[All codes](README.md)
