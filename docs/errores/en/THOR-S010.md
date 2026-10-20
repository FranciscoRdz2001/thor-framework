# THOR-S010 · An unregistered `ThorState`

**Where:** `thor_ui` · `ThorState` (the first time a state is used).

## What happened

The app or its tests ran without `thor`: a plain `dart run bin/server.dart` or `dart test`. A state (`class CartState extends ThorState`) doesn't have its methods or values registered, and the page can't name them.

## Why

Dart can't list a class's members at runtime. `thor` prepares them before each run (`thor dev`, `thor build`, `thor preview`, `thor test`); without it, the first state the page or the test touches throws this error.

## How to fix it

```bash
# WRONG
dart run bin/server.dart
dart test
```

```bash
# RIGHT
thor dev            # or thor build / thor preview
thor test           # same arguments as dart test
thor test test/cart_state_test.dart -n 'adds a line'
```

Run the commands from the app's root.

[All codes](README.md)
