# THOR-S014 · `setState` in a `StatefulWidget`

**Where:** `thor_lints` · rule `stateful_set_state` (in the editor and in `dart analyze`) and the code generation of `thor dev` / `thor build`.

## What happened

A `State` of a `StatefulWidget` called `setState`. It compiles and changes nothing in the browser; in `debug` an `assert` fails.

## Why

`build` runs only once, on the server, and produces HTML. The `State` lives only for that moment: it never reaches the browser, so there's nothing to rebuild when it changes. What changes in the browser is a [`ThorState`](../../guia/en/state.md): `state(...)` fields and methods that the browser runs.

There's no place where `setState` is correct (not even in `initState`: the server paints once and the `assert` fails anyway), so every use in `lib/` is flagged. A `StatefulWidget` that only reads its fields when painting keeps working.

`thor build` fails with the file, the line and a code frame; `thor dev` shows it on the page and in the console.

## How to fix it

```dart
// WRONG
class _CounterState extends State<Counter> {
  int count = 0;

  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: () => setState(() => count++),
    child: Text('$count'),
  );
}
```

```dart
// RIGHT: the state is a ThorState and the button receives its method
class CounterState extends ThorState {
  final count = state(0);
  void increment() => count.value++;
}

final counter = CounterState();

class Counter extends StatelessWidget {
  const Counter({super.key});

  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: counter.increment,
    child: Watch(counter.count),
  );
}
```

More in [Coming from Flutter](../../guia/en/from-flutter.md) and in [State](../../guia/en/state.md).

[All codes](README.md)
