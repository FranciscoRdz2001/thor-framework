# THOR-S036 · `row.bind` used as text or transformed

**Where:** `thor_ui` · `row.bind(…)` when painting.

## What happened

The `String` returned by `row.bind(…)` ended up in visible text (`Text(row.bind(…))`, `Chip(label:)`, `labelText:`, `Tooltip(message:)`) or was transformed before reaching an attribute: interpolated (`'Task ${row.bind(…)}'`), concatenated, with `.toUpperCase()` or with a suffix.

## Why

`row.bind` isn't the value: it's a marker that the element writing the attribute turns into an attribute bound to the row. If it's displayed or computed on, the browser can't keep the result up to date and the marker would reach the page. Thor fails when painting instead of publishing it. A user's text with the same private characters isn't a marker (it carries a random per-process tag) and is written as data.

## How to fix it

```dart
// WRONG
Text(row.bind(todos.titleOf))
Checkbox(semanticLabel: 'Task ${row.bind(todos.titleOf)}', …)
```

```dart
// RIGHT: a visible text, row.text
row.text(todos.titleOf)

// a computed label: a state method that returns it
String labelOf(Todo t) => 'Task ${t.title}';
Checkbox(semanticLabel: row.bind(todos.labelOf), …)
```

[All codes](README.md)
