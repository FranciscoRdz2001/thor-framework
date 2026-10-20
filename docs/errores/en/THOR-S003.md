# THOR-S003 · `Watch` with `builder` over a value that isn't finite

**Where:** `thor_ui` · `Watch(builder:)`, `Watch.field(builder:)`, `row.watch`.

## What happened

A `Watch` with `builder` (or `row.watch`) observes a value that is neither `bool` nor `enum`, and no `count:` was passed for an `int`; or a nullable field (`bool?`, `Mood?`): `null` has no copy to paint.

## Why

A `Watch` with `builder` is rendered **once per possible state** on the server and the browser switches between those versions. That's why it needs a finite, known set: `bool`, an `enum`, or an `int` with `count:`.

## How to fix it

```dart
// WRONG
Watch(state.selectedName, builder: (name) => Text(name)) // String: infinite
```

```dart
// RIGHT
// Text that changes: no builder.
Watch(state.selectedName)

// Structure that changes: a bool or an enum.
bool hasSelection() => selected.value != null;
Watch(state.hasSelection, builder: (yes) => yes ? const Details() : const Empty())

// A bounded int (a method, or the field with Watch.field):
Watch(state.step, count: 3, builder: (i) => Steps(i))
Watch.field(state.step, count: 3, builder: (i) => Steps(i))

// A bool? or an enum?: remove the null (state(false), or a `none` case),
// or watch a method that resolves it:
bool shown() => flag.value ?? false;
```

[All codes](README.md)
