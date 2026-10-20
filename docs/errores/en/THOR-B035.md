# THOR-B035 · A `derived(...)` that writes a field

**Where:** `thor_lints` · the `state_misuse` rule (in the editor and in `dart analyze`), `thor dev` and `thor build`, with its file and line.

## What happened

The function of a `derived(() => …)` assigns a `state(...)` field (`x.value = …`, `x.value++`) or calls `update`, `toggle`, `add`, `remove` or `clear` on one.

## Why

A `derived` runs when someone reads its value: in the middle of drawing the page or of propagating a change, and only if something it reads changed. A write there makes the result depend on who read first and how many times, and in the browser it fires effects while others are still being computed.

## How to fix it

The function only reads. The change goes in the state method that handles the event.

```dart
// WRONG
late final visible = derived(() {
  shown.value = rows.value.length; // writes
  return rows.value.where((r) => r.ok).toList();
});
```

```dart
// RIGHT
late final visible = derived(() => rows.value.where((r) => r.ok).toList());
int shown() => visible.value.length; // what is shown is derived too
```

More in [State](../../guia/en/state.md#computed-values).

[All codes](README.md)
