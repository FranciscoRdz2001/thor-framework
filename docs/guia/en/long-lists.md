# Long lists

Show thousands of rows without slowing the page down: a fixed height per row, deferred layout, and a window of rows for lists that change.

:::flutter Flutter: `ListView.builder` · Thor: `ListView.builder` and `Watch.list`

## A list that doesn't change

`ListView.builder` is Flutter's. `itemExtent` fixes the height of each row, so the scrollbar is exact from the start, and `lazyLayout: true` makes the browser skip layout for rows that are off screen.

:::flutter
@flutter
```dart no-check
ListView.builder(
  itemExtent: 56,
  itemCount: orders.length,
  itemBuilder: (context, i) => ListTile(title: Text(orders[i].customer)),
)
```
@thor
```dart
ListView.builder(
  itemExtent: 56,
  lazyLayout: true, // web: the browser skips off-screen rows
  itemCount: orders.length,
  itemBuilder: (context, i) => ListTile(title: Text(orders[i].customer)),
)
```
:::

Every row stays on the page: the browser's find (Ctrl+F) finds them and Tab reaches them.

> **Important:** In Chromium-based browsers, `lazyLayout` removes distant rows from the accessibility tree until they get close, and clips whatever a row paints outside its box (a shadow, the focus ring).

## A list that changes

A list that comes from a ViewModel (`ThorState`), such as an order board or a market, is a `Watch.list`: the browser adds, moves and removes rows by their key, and updates only the ones that changed. With `virtual: true`, the page keeps only the rows near the screen.

:::bench bench-long-list
:::

```dart
// lib/market_view_model.dart
class Quote {
  const Quote(this.id, this.symbol, this.price);
  final int id;
  final String symbol;
  final int price; // in cents

  factory Quote.fromJson(Map<String, Object?> json) => Quote(
    json['id']! as int,
    json['symbol']! as String,
    json['price']! as int,
  );

  Map<String, Object?> toJson() => {'id': id, 'symbol': symbol, 'price': price};
}

List<Quote> seed() => [for (var i = 1; i <= 700; i++) Quote(i, 'S$i', 1000 + i)];

class MarketViewModel extends ThorState {
  final quotes = state<List<Quote>>(seed());

  List<Quote> rows() => quotes.value;
  String keyOf(Quote q) => 'q${q.id}';
  String symbol(Quote q) => q.symbol;
  String price(Quote q) => '${q.price ~/ 100}.${(q.price % 100).toString().padLeft(2, '0')}';
}

final market = MarketViewModel();
```

```dart
// lib/market_page.dart
Watch.list(
  market.rows,
  itemKey: market.keyOf,
  itemExtent: 34, // the height of each row, in px
  lazyLayout: true, // the browser skips off-screen rows
  virtual: true, // and the page keeps only the rows near the screen
  each: (row) => Row(children: [
    Expanded(child: row.text(market.symbol)),
    row.text(market.price),
  ]),
)
```

| Option | What it changes | What it costs |
|---|---|---|
| `itemExtent: 34` | every row is 34 px tall, as in Flutter | whatever doesn't fit in that height is clipped |
| `lazyLayout: true` | the browser skips layout for what is off screen | distant rows leave the accessibility tree |
| `virtual: true` | the page keeps only the rows near the screen | Ctrl+F and Tab only reach the rows present |

`virtual` requires `itemExtent` ([THOR-S040](../../errores/en/THOR-S040.md)): the browser works out which rows are visible by dividing the scroll position by the height, without measuring any of them. The list has no `gap`; separate the rows with a border inside their height.

Without JavaScript, the page is the full list. Each row tells the screen reader its position in the whole list, and the focused row is kept even if it leaves the window. Rows that leave are not kept: the ones that come in are created again, and they are list items, not rows of a data table.

## A long page

`LazyLayout` applies the same idea to a whole section: the browser doesn't lay it out until it gets close to the screen, and `extentEstimate` reserves its height in the meantime.

```dart
Column(children: [
  const HeroSection(), // the first screen: never lazy
  LazyLayout(extentEstimate: 640, child: const ProductGrid()),
  LazyLayout(extentEstimate: 480, child: const Results()),
  LazyLayout(extentEstimate: 320, child: const Content()),
])
```

> **Important:** `LazyLayout` clips whatever the section paints outside its box (a shadow, a glow). Don't use it on the first screen.

## When to use which

| Your list | Use |
|---|---|
| fewer than 100 rows | nothing special |
| 100 to 1,000 rows that people search or read with a screen reader | `itemExtent` and [`Pagination`](server-and-actions.md#paginated-lists-in-the-url) |
| hundreds of rows that change live | `Watch.list` with `itemExtent` and `virtual: true` |
| long content read straight through (articles, cards) | `lazyLayout: true` or `LazyLayout` |

## Live updates

The browser updates a row only if its item is no longer the same object as before. When a message arrives, create a new object for each row that changed and keep the rest.

```dart
// lib/live_market_view_model.dart
import 'market_view_model.dart';

class LiveMarketViewModel extends MarketViewModel {
  // One message: only the quotes that changed, and the pairs of positions that swap.
  void onMessage(List<Quote> changed, List<int> swaps) {
    final byId = {for (final q in changed) q.id: q};
    final r = [for (final q in quotes.value) byId[q.id] ?? q]; // the rest keep their object
    for (var i = 0; i + 1 < swaps.length; i += 2) {
      final t = r[swaps[i]];
      r[swaps[i]] = r[swaps[i + 1]];
      r[swaps[i + 1]] = t;
    }
    quotes.value = r;
  }
}
```

There's no need to batch messages that arrive together: the browser updates the screen once per frame.

## Selecting a row

`row.selected` makes part of the row depend on whether its key is the value of a state field. When the field changes, only the previously chosen row and the new one are updated.

```dart no-check
class OrdersViewModel extends ThorState {
  final items = state(const <Order>[]);
  final selected = state<int>(0); // the key of the chosen row

  List<Order> rows() => items.value;
  int keyOf(Order o) => o.id;
  String title(Order o) => o.title;
  void select(int id) => selected.value = id;
}

Watch.list(orders.rows, itemKey: orders.keyOf, each: (row) =>
    row.selected(orders.selected, builder: (on) =>
        ListTile(selected: on, title: row.text(orders.title))));
```

The field holds a single key (`int` or `String`, the same type as `itemKey`). For several rows marked at once, use `row.watch` with a method.

## Per-row values

`row.length` turns a number from each item into a `Length` that the browser keeps up to date, like `BoundLength` outside a list. It works in `each` and in the `build` of a row component; outside a row it fails with [THOR-S042](../../errores/en/THOR-S042.md).

```dart
// lib/circles_view_model.dart
class Circle {
  const Circle(this.id, this.x, this.diameter);
  final int id;
  final double x;
  final double diameter;

  factory Circle.fromJson(Map<String, Object?> json) => Circle(
    json['id']! as int,
    (json['x']! as num).toDouble(),
    (json['diameter']! as num).toDouble(),
  );

  Map<String, Object?> toJson() => {'id': id, 'x': x, 'diameter': diameter};
}

class CirclesViewModel extends ThorState {
  final items = state<List<Circle>>(const [Circle(1, 10, 24), Circle(2, 60, 40)]);

  List<Circle> rows() => items.value;
  int keyOf(Circle c) => c.id;
  double left(Circle c) => c.x;
  double diameter(Circle c) => c.diameter;
}

final circles = CirclesViewModel();
```

```dart
// lib/circles_page.dart
Watch.list(
  circles.rows,
  itemKey: circles.keyOf,
  container: (rows) => Stack(children: rows),
  each: (row) {
    final x = row.length(circles.left);
    final d = row.length(circles.diameter);
    return Styled(
      style: StyleProps(position: BoxPosition.absolute(left: x), minWidth: d, minHeight: d),
      child: const DecoratedBox(
        decoration: BoxDecoration(shape: BoxShape.circle, color: ThemeColor.primary),
      ),
    );
  },
)
```

The methods receive the item and return pixels (`double` or `int`). The full example is in [Circles with undo](examples/circle-drawer.md).

## Next steps

:::cards
- [State](state.md#lists) — `Watch.list`, rows and methods with `withArg`
- [Layout](layout.md) — `ListView`, `GridView` and row height
- [Accessibility](accessibility.md) — what a screen reader reads in a list
:::
