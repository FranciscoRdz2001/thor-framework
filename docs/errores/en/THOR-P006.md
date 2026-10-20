# THOR-P006 · `request.parent<T>()` without a layout that loads `T`

**Where:** `thor_server` · `PageRequest.parent`.

## What happened

A `load` asked for `request.parent<T>()` and no layout above loads a `T`, or it was called outside a `load`.

## Why

`parent<T>()` waits for the `load` of the nearest layout that returns a `T` (its declared type). If none does, there is nothing to wait for; outside a `load` (in an action, a guard or a widget) there are no layouts loading.

## How to fix it

```dart
// WRONG
// the Group's layout (AppLayout) loads a Company, the page asks for a User
final user = await r.parent<User>();
```

```dart
// RIGHT
// Ask for the type the layout loads (the message lists which ones there are)…
final company = await r.parent<Company>();
// …or, in an action, read what a middleware puts in request.context.
```

[All codes](README.md)
