# THOR-B018 · A state class the registry cannot name

**Where:** `thor dev` / `thor build` / `thor test`.

## What happened

A class that extends `ThorState` is private (`_CartState`), abstract or has type parameters (`Box<T>`), or one of its methods returns a private enum.

## Why

Thor registers each state from outside your file and names the class, its methods and its enum values from there: a private name is not visible from another library, and an abstract or generic class is not a concrete state of a page.

## How to fix it

```dart
// WRONG
class _CartState extends ThorState { … }
enum _Tab { home, cart }
class ShopState extends ThorState {
  _Tab tab() => _Tab.home;
}
```

```dart
// RIGHT
class CartState extends ThorState { … }
enum Tab { home, cart }
class ShopState extends ThorState {
  Tab tab() => Tab.home;
}
```

[All codes](README.md)
