# THOR-S012 · A `ThorState` created outside the top level

**Where:** `thor_lints` · rule `state_misuse` (in the editor and in `dart analyze`), `thor dev` and `thor build`.

## What happened

A `ThorState` was created in a widget field, in a local variable of `build` or anywhere that isn't the initializer of a top-level variable in a `lib/` file.

## Why

The browser only knows the states declared at the top level of the app's files. An instance created in a widget is a different one: the server paints it, but the browser doesn't know it and its methods do nothing. Also, a widget field creates a new state every time the widget is built.

`thor dev` shows the warning on the page with file and line, and `thor build` fails with it. Tests (`test/`) can create states wherever they need them.

## How to fix it

```dart
// WRONG
class CounterWidget extends StatelessWidget {
  final counterState = CounterState();

  @override
  Widget build(BuildContext context) =>
      OutlinedButton(onPressed: counterState.increment, child: const Text('+'));
}
```

```dart
// RIGHT
// lib/state/counter_state.dart, next to its class:
final counter = CounterState();

// In the widget:
class CounterWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      OutlinedButton(onPressed: counter.increment, child: const Text('+'));
}
```

[All codes](README.md)
