# Coming from Flutter

You write the same Flutter widgets; what changes is where `build` runs, how you handle state and how navigation works.

:::flutter Flutter: `build` runs on the device · Thor: `build` runs on the server

## What stays the same

| Area | Same as in Flutter |
|---|---|
| Layout | `Row`, `Column`, `Container`, `Expanded`, `ListView` |
| Screen structure | `Scaffold`, `AppBar`, `NavigationBar` |
| Inputs | `Form`, `TextFormField`, `FilledButton`, `onPressed`, `onChanged` |
| Theme | `ThemeData`, `Theme.of(context).colorScheme` and `.textTheme`, which follow dark mode |

The web adds links on any widget (`Link`, `FilledButton(href:)`), variants with `.when()` for screen size, pointer and dark mode, and responsive images with `srcSet`.

## State and events

Whatever changes without a reload lives in a ViewModel (`ThorState`): a class with state fields and methods. `Watch` displays a value and the method is passed as a callback. A `StatefulWidget` compiles, but `setState` changes nothing in the browser ([THOR-S014](../../errores/en/THOR-S014.md)).

:::bench bench-counter-step
:::

> **Difference from Flutter:** A `ThorState` is the equivalent of a `ChangeNotifier`, not of `State<T>`: it belongs to the screen, not to a widget, and lives in a top-level variable. That's why the classes are named `CounterViewModel` or `OrdersViewModel`.

The details are in [Interactivity](interactivity.md).

## Navigation and dialogs

Each screen is a route and each dialog is part of the page that opens it, with no imperative calls like `Navigator.push` or `showDialog`.

### Routes

Each screen is a URL with its page in the route table, as in `go_router`. You get there with a link, not with `push`.

:::flutter
@flutter
```dart no-check
TextButton(
  onPressed: () => context.go('/orders/42'),
  child: const Text('See order'),
)
```
@thor
```dart
Link(
  href: orderRoute.link({'id': 42}),
  child: const Text('See order'),
)
```
:::

From a ViewModel method you navigate with `PageNavigator.go(url)`; from an action, with `Redirect`. More in [Routes and navigation](navigation.md).

### Dialogs

The dialog is on the page, closed, next to the button that opens it. It's a native `<dialog>`: focus and the Escape key work with no code.

:::flutter
@flutter
```dart no-check
showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('Charge \$187.00?'),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
    ],
  ),
);
```
@thor
```dart
class ChargeButton extends StatelessWidget {
  const ChargeButton({super.key});

  @override
  Widget build(BuildContext context) => DialogTrigger(
    dialog: AlertDialog(
      title: const Text(r'Charge $187.00?'),
      actions: [DialogClose(child: TextButton(child: const Text('Cancel')))],
    ),
    child: FilledButton(child: const Text('Charge')),
  );
}
```
:::

From a ViewModel method, `await confirm('…')` asks for confirmation and `toast('…')` shows a toast. More in [Dialogs and menus](dialogs-and-menus.md).

## Screen and pointer

The browser resolves screen size and pointer: the widget declares each variant and doesn't query values in `build`.

### Screen size

The server doesn't know the screen, and the browser does the layout. A value changes by size class with `.when()`.

:::flutter
@flutter
```dart no-check
final wide = MediaQuery.sizeOf(context).width >= 600;
return wide
    ? Row(children: items)
    : Column(children: items);
```
@thor
```dart
Grid(
  layout: const GridLayout(columns: 1, gap: 16)
      .when(medium: const GridLayout(columns: 3)),
  children: items,
)
```
:::

More in [Layout](layout.md#responsive).

### On hover

The hover change is a variant of the value: it needs no state and the browser applies it without JavaScript.

:::flutter
@flutter
```dart no-check
MouseRegion(
  onEnter: (_) => setState(() => hover = true),
  onExit: (_) => setState(() => hover = false),
  child: Container(color: hover ? Colors.indigo.shade50 : Colors.white),
)
```
@thor
```dart
Container(
  decoration: BoxDecoration(
    color: const Color(0xFFFFFFFF).when(hover: const Color(0xFFEEF0FF)),
  ),
)
```
:::

## Forms and data

Validation runs in the browser and the page's data is loaded on the server before rendering.

### Validation

Each rule is a `Validator` that the browser checks without a reload; `onSubmit` runs when every field is valid.

:::flutter
@flutter
```dart no-check
TextFormField(
  validator: (value) =>
      value == null || value.isEmpty ? 'Add a name.' : null,
)
```
@thor
```dart
TextFormField(
  name: 'name',
  validators: const [Validator.required('Add a name.')],
)
```
:::

More in [Forms](forms.md).

### Page data

Data is loaded on the server, in `load`, before rendering. Slow data is sent later with `defer`, in the same response, and `FutureBuilder` shows it when it arrives.

:::flutter
@flutter
```dart no-check
// in initState: _featured = widget.repo.featured();
FutureBuilder<List<Product>>(
  future: _featured,
  builder: (context, snapshot) => snapshot.hasData
      ? ProductGrid(snapshot.data!)
      : const CircularProgressIndicator(),
)
```
@thor
```dart
FutureBuilder<List<Product>>(
  future: state.data.featured, // defer(repo.featured()) in load
  builder: (context, snapshot) => snapshot.hasData
      ? ProductGrid(snapshot.data!)
      : const Skeleton(height: 240),
)
```
:::

More in [Reading data](reading-data.md).

## Flutter names that don't exist

These names compile, but the editor strikes them through with the alternative in the message. If the code runs, it fails with that same message and a link to this table.

| In Flutter | In Thor |
|---|---|
| `MediaQuery.of(context)` | `.when(medium: …)` on the value; `ResponsiveVisibility` to show or hide; `100.dvh` in `Styled` for the window height |
| `LayoutBuilder`, `OrientationBuilder` | `LayoutScope` with `.when(container: {…})` |
| `showDialog(…)` | an `AlertDialog` on the page, opened with `DialogTrigger` or `DialogController`; `await confirm('…')` from a ViewModel |
| `showModalBottomSheet(…)` | a `ModalBottomSheet` on the page, opened with `DialogTrigger` or `DialogController` |
| `showDatePicker(…)`, `showTimePicker(…)` | `DatePickerFormField`, `DatePickerDialog` or `TimePickerDialog` ([Inputs](components-inputs.md)) |
| `Navigator.push(…)`, `Navigator.pop(…)` | `Link(href: route.link())`; `PageNavigator.go(url)` from a ViewModel; `Redirect` from an action |
| `Navigator.pop(context)` when tapping a drawer item | `DialogClose(child: ListTile(onTap: viewModel.method))`: closes and runs the method |
| `ScaffoldMessenger.of(context).showSnackBar(…)` | `toast('…')` from a ViewModel; `Redirect(url).flash('…')` for the next page |
| `StreamBuilder` | a ViewModel field displayed with `Watch` ([State](state.md)) |
| `BottomNavigationBar` | `NavigationBar` in `Scaffold(bottomNavigationBar:)` |
| `CustomPaint` | doesn't exist: use SVG or an image |

## Behavior differences

| In Flutter | In Thor |
|---|---|
| `ListView.builder` over a list that changes | `Watch.list(viewModel.rows, itemKey: viewModel.idOf, each: …)`, with a typed `row.key` ([State](state.md)) |
| `Expanded` in a `Column` without a height | keeps the height of its content ([Layout](layout.md)) |
| `Stack` with only `Positioned` children | measures 0 in height; it needs a sized parent or a child that isn't `Positioned` |
| `GestureDetector` with a closure | `GestureDetector` or `Gesture` with a ViewModel method ([Gestures](gestures.md)) |
| `EdgeInsetsDirectional`, `AlignmentDirectional` | the browser applies the text direction; if the server needs to know it, it fails with [THOR-R037](../../errores/en/THOR-R037.md) |
| `Scaffold.of(context).openDrawer()` | `Scaffold(drawer:)` adds its menu button to the `AppBar` |
| a channel of a theme color (`.red`, `.value`) | fails with [THOR-R023](../../errores/en/THOR-R023.md); `withValues(alpha:)` works |
| tapping a control before the JavaScript loads | native elements respond (links, dialogs, forms); other taps are replayed once it loads |

## Next steps

:::cards
- [Your first app](first-app.md) — a shop with a cart, a form and routes, step by step
- [Layout](layout.md) — `Row`, `Column`, `Stack`, grids and responsive layout
- [Components](components.md) — every widget with its example, its code and its parameters
:::
