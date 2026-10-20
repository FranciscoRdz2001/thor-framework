# THOR-S035 · `row.bind` on an attribute a binding can't write

**Where:** `thor_ui` · `row.bind(…)` when painting.

## What happened

The `String` returned by `row.bind(…)` ended up in an attribute the browser can't fill per row: a handler (`on*`), `style`, `class` or an internal Thor attribute.

## Why

`row.bind` doesn't write anything by itself: the widget that receives the `String` (`semanticLabel:`, `tooltip:`, `Semantics(label:)`…) writes it as an attribute, and Thor turns it into an attribute bound to the row (`row.attribute`). For security the browser only writes `aria-*`, `data-*` and a fixed set of simple attributes (`alt`, `title`, `href`, `value`, `placeholder`…).

## How to fix it

```dart
// WRONG: a parameter that ends up in `class`, `style` or a handler
Styled(className: row.bind(todos.titleOf), child: …)
```

```dart
// RIGHT: an accessibility or content parameter
Checkbox(value: done, semanticLabel: row.bind(todos.titleOf), onChanged: …)
IconButton(tooltip: row.bind(todos.titleOf), icon: …, onPressed: …)

// a visible text: row.text
row.text(todos.titleOf)

// a look variant: row.watch
row.watch(todos.isDone, builder: (done) => …)
```

[All codes](README.md)
