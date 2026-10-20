# Interactivity

What changes without reloading the page lives in a ViewModel (`ThorState`). Widgets read it with `Watch` and call its methods as callbacks.

:::flutter Flutter: `StatefulWidget` and `setState` · Thor: a ViewModel, `Watch` and its methods

## A ViewModel and its methods

A ViewModel is a class with state fields, `state(initialValue)`, and methods that read and assign `.value`. Its instance is a top-level `final` variable, which the browser starts from.

:::bench bench-counter-step
:::

:::flutter
@flutter
```dart no-check
class _CounterState extends State<Counter> {
  int count = 0;

  void increment() => setState(() => count++);

  @override
  Widget build(BuildContext context) =>
      FilledButton(onPressed: increment, child: Text('$count'));
}
```
@thor
```dart {1-8,15}
class CounterViewModel extends ThorState {
  final count = state(0);

  String label() => '${count.value}';
  void increment() => count.value++;
}

final counter = CounterViewModel();

class CounterButton extends StatelessWidget {
  const CounterButton({super.key});

  @override
  Widget build(BuildContext context) =>
      FilledButton(onPressed: counter.increment, child: Watch(counter.label));
}
```
:::

> **Important:** A ViewModel created inside a widget or in `build` is a different object the browser doesn't know about. The editor flags it with [THOR-S012](../../errores/en/THOR-S012.md).

## Showing values

`Watch(counter.label)` shows a text the browser keeps up to date; it keeps its line breaks (`\n`) even when the server drew it in one line. With `builder`, `Watch` builds one widget for each possible value of a `bool` or an enum: the server renders all of them and the browser shows the matching one.

:::example state-bool
:::

`Watch(favorite.isSaved, builder: (saved) => …)` receives a method's value; `Watch.field(favorite.saved, builder: …)` reads the field directly, without a method. An `int` needs `count:`, with values from `0` to `count - 1`.

> **Difference from Flutter:** The `builder` runs only on the server, once per value, not on every change. Everything that varies must come from the value it receives or from another `Watch`.

## Events

Pass the ViewModel method where Flutter expects a callback: `onPressed: counter.increment`. To fix an argument, use `withArg`.

:::example state-enum
:::

A closure doesn't reach the browser: the widget's code runs on the server and the button ends up with no event. If a button does several things, write a method that does them.

```dart
// WRONG (THOR-S011): the button does nothing in the browser
OutlinedButton(onPressed: () => counter.increment(), child: const Text('+'))

// RIGHT
OutlinedButton(onPressed: counter.increment, child: const Text('+'))
```

## Text fields and controls

Each control calls the method with its value: a `String` from a `TextField`, a `bool` from a `Checkbox` or a `Switch`, a `double` from a `Slider`.

:::bench bench-greeting
:::

As in Flutter, a control without `onChanged` is disabled. Forms submitted to the server are in [Forms](forms.md).

## Values that don't update

`build` runs once, on the server: reading `.value` there leaves in the HTML the value the server rendered the page with, and the browser doesn't update it. Pass `Watch` a ViewModel method, not its value.

```dart
// WRONG (THOR-S015): looks right and never changes
Text('Pending: ${orders.pending.value}')

// RIGHT
Watch(orders.pendingLabel)
```

The editor flags it and `thor dev` shows it in the console.

## Next steps

:::cards
- [State](state.md) — computed values, keyed lists, controllers and lifecycle
- [Reading data](reading-data.md) — the page's data, loaded on the server
- [Forms](forms.md) — controls, validation and actions
:::
