# THOR-S015 · A state read while the server paints

**Where:** `thor_lints` · rule `frozen_state_read` (in the editor and in `dart analyze`); `thor dev` and `thor build` print it as a warning.

## What happened

A `build` (or a function it calls) read the `.value` of a `state(...)` field or of a `query` (`orders.data.value`), called the field (`counter.count()`) or a `ThorState` method or getter that reads state (`Text(counter.label())`), or iterated with `for`, `.map` or `ListView.builder` over a list returned by a `ThorState` method or getter. The page looks fine the first time and **doesn't change** when the state changes in the browser.

## Why

`build` runs once, on the server. What it reads there is a snapshot of the state at that moment and ends up written into the HTML; the browser doesn't run `build` again. Only what is bound to the state (`Watch`, `row.text`) updates. A reactive value read outside a scope that tracks it doesn't update.

It's a warning, not an error: sometimes the snapshot is what you want. These aren't flagged:

- whatever goes inside a `Watch`, `ValueListenableBuilder`, `QueryBuilder` or `row.watch` (`builder:` and `each:`), nor the code of a `ThorState` (it runs in the browser);
- a closure that is a callback (`onPressed: () => …`: it runs later);
- `untracked(() => x.value)` and `x.peek()`: the name already says it's a snapshot;
- a control's initial value (`value:`, `groupValue:`, `initialValue:` or `selected:` of a widget with `onChanged:`): from then on the control carries its own value;
- a field that isn't `state(...)` (data the state holds that doesn't change).

To keep a snapshot on purpose, `// ignore: thor_lints/frozen_state_read` with the reason on the line above.

## How to fix it

```dart
// WRONG
Text('Orders: ${orders.pending.value}')
ListView(children: [
  for (final o in ordersState.rows()) ListTile(title: Text(o.customer)),
])
```

```dart
// RIGHT: the field (or a state method) goes to Watch
Watch(ordersState.pendingLabel)

// a list: Watch.list, and each row reads its texts with methods
Watch.list(
  ordersState.rows,
  itemKey: ordersState.rowKey,
  each: (row) => ListTile(title: row.text(ordersState.customerOf)),
)
```

[All codes](README.md)
