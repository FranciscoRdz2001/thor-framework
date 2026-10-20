# Widgets

Write the interface as widget classes, with the same names and types as Flutter. Thor renders them on the server as HTML.

:::flutter Flutter: `StatelessWidget` with `build` · Thor: the same class, rendered on the server

## A widget is a class

A widget is a `StatelessWidget` with its `build`, as in Flutter. Thor runs `build` once per request and the browser receives the page already rendered.

:::example card
:::

Every piece of interface is a class, never a function that returns a `Widget`: that way it supports `const`, can be tested on its own and has a name in the tree.

:::flutter
`LocaleFormat` wraps `NumberFormat` and takes the page's language from `context`.
@flutter
```dart no-check
class PriceTag extends StatelessWidget {
  const PriceTag({super.key, required this.price});

  final double price;

  @override
  Widget build(BuildContext context) => Text(
    NumberFormat.simpleCurrency(
      locale: Localizations.localeOf(context).toString(),
      name: 'USD',
    ).format(price),
  );
}
```
@thor
```dart
class PriceTag extends StatelessWidget {
  const PriceTag({super.key, required this.price});

  final double price;

  @override
  Widget build(BuildContext context) =>
      Text(LocaleFormat.of(context).currency(price, name: 'USD'));
}
```
:::

## Composing widgets

A screen is built by nesting small widgets. Data comes in through the constructor; the `UserTile` class doesn't change even if the arrangement does.

:::bench bench-compose
:::

Create a new widget when something repeats or has its own name on the screen, like `UserTile` or `PriceTag`.

## One element per widget

`Padding`, `Expanded`, `Opacity` and `Center` don't add an element to the page: they merge into their child's. Each widget produces the HTML element that fits it (a button is a `<button>`, a `Link` is an `<a>`), and the screen reader announces it as such.

```dart
// A single element: the padding and the flex share belong to the Text.
Row(
  children: [
    Expanded(
      child: Padding(padding: EdgeInsets.all(8), child: Text('Hello')),
    ),
  ],
)
```

Dialogs, menus and accordions work without JavaScript because they use the browser's native elements ([Dialogs and menus](dialogs-and-menus.md)).

## What changes in the browser

A `StatelessWidget` doesn't change after it's rendered. What changes without reloading lives in a ViewModel (`ThorState`), which the widget reads with `Watch`; the full counter is in [Interactivity](interactivity.md).

## Next steps

:::cards
- [Layout](layout.md) — `Row`, `Column`, `Stack`, grids and responsive design
- [Interactivity](interactivity.md) — ViewModels, `Watch` and callbacks
- [Components](components.md) — every widget with its example, its code and its parameters
:::
