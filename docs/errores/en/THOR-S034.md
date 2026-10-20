# THOR-S034 · A state method called with the row key while painting

**Where:** `thor_lints` · rule `row_server_read` (in the editor and in `dart analyze`); `thor dev` and `thor build` print it as a warning.

## What happened

In the builder of a `Watch.list` row (`each: (row) => …`, the `builder` of `row.watch` or a function that receives the `row`) a `ThorState` method was called with the row key, or a `.value` was read whose chain mentions the row:

```dart
Checkbox(value: done, semanticLabel: todos.titleById(row.key), onChanged: …)
Text(todos.selected.value.contains(row.key) ? 'yes' : 'no')
```

The rows the server painted look fine. The ones the **browser adds later** end up with an empty or wrong value (a checkbox without an accessible name, for example), and nothing warns about it.

## Why

The row builder runs on the server: once per row the page paints and once more for the row **template**, with a placeholder key. The browser doesn't run it again: new rows are clones of that template and only the bound texts and attributes are filled in (`row.text`, `row.attribute`, `row.bind`, `row.watch`). `todos.titleById(row.key)` written directly was evaluated with the placeholder key and stayed in the template.

Not flagged: `row.text`, `row.attribute`, `row.bind`, `todos.remove.withArg(row.key)` (it builds the handler, it doesn't call it), a callback (`onPressed: () => …`: its rule is [THOR-S011](THOR-S011.md)) or `untracked(() => …)`.

## How to fix it

```dart
// WRONG
Checkbox(value: done, semanticLabel: todos.titleById(row.key), onChanged: …)
```

```dart
// RIGHT: a method that receives the item, bound to the row
String titleOf(Todo t) => t.title;            // in the state

Checkbox(
  value: done,
  semanticLabel: row.bind(todos.titleOf),     // or row.bind((t) => t.title)
  onChanged: todos.setDone.withArg(row.key),
)
IconButton(tooltip: row.bind(todos.titleOf), icon: …, onPressed: …)

// a visible text
row.text(todos.titleOf)

// a look that changes (strikethrough, color)
row.watch(todos.isDone, builder: (done) => …)
```

To keep the snapshot on purpose, `// ignore: thor_lints/row_server_read` with the reason on the line above.

[All codes](README.md)
