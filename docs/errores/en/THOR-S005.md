# THOR-S005 · The browser can't find a member of a `ThorState`

**Where:** `thor_ui` · when the page starts in the browser.

## What happened

The HTML names a field or method (`counter.inc`) that the page doesn't know.

## Why

Almost always the page's JavaScript is stale or doesn't include that state: a state or a method was added and the app wasn't recompiled, or the state instance isn't top-level.

## How to fix it

```dart
// WRONG
// lib/cart_state.dart: new state, but the instance is not top-level
class CartState extends ThorState { ... }
Widget build(...) => Watch(CartState().total) // local instance
```

```dart
// RIGHT
// A top-level instance: thor includes it in the page.
final cart = CartState();
Watch(cart.total)

```

With `thor dev` the page recompiles itself when a file changes; if you see this error there, check the terminal: the compilation may have failed.

[All codes](README.md)
