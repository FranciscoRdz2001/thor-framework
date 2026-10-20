# THOR-S001 · A `Watch` or a callback receives a closure

**Where:** `thor_ui` · `Watch`, `row.*`, `onPressed`/`onChanged` bound to a state.

## What happened

A `Watch`, an `itemKey` or a binding received an anonymous function instead of a field or a method of a `ThorState`.

## Why

The browser finds what it has to update **by name** (`counter.label`): the server writes that name in the HTML and the browser looks it up. A closure has no name the browser can look up.

The editor flags it as you type (`thor_lints`, rule `state_misuse`) when the closure is the source of a `Watch` and uses a state, and `thor dev` / `thor build` report it with file and line. A closure as a button callback is [THOR-S011](THOR-S011.md).

## How to fix it

```dart
// WRONG
Watch(() => '${counter.count.value} items')
```

```dart
// RIGHT
// In the state:
String itemsLabel() => '${count.value} items';

// In the widget:
Watch(counter.itemsLabel)
```

[All codes](README.md)
