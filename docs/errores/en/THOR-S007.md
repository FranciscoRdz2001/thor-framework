# THOR-S007 · `Cached` contains widgets bound to a `ThorState`

**Where:** `thor_ui` · `Cached`.

## What happened

A subtree inside `Cached` uses a `ThorState` (`Watch`, `onPressed: state.method`…).

## Why

`Cached` stores the HTML and reuses it in other requests. A widget bound to state carries values from **this** request (the counter at 3, someone's session), which would be served to other visitors.

## How to fix it

```dart
// WRONG
Cached(cacheKey: 'header', child: Row(children: [Logo(), Watch(cart.count)]))
```

```dart
// RIGHT
Row(children: [
  const Cached(cacheKey: 'logo', child: Logo()),
  Watch(cart.count), // outside Cached
])
```

[All codes](README.md)
