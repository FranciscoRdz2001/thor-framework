# Layout

Position and size widgets with `Row`, `Column`, `Expanded`, `Stack` and `Grid`, as in Flutter. The browser does the layout.

:::flutter Flutter: `Row`, `Stack`, `GridView`, `MediaQuery` · Thor: the same widgets and `.when()`, no `MediaQuery`

## `Row` and `Column`

`mainAxisAlignment` distributes the free space along the main axis, and `spacing` separates the children.

:::bench bench-row-align
:::

In a `Column`, `crossAxisAlignment` decides the children's width: with `start` or `center` each one is as wide as its content; with `stretch`, all of them take the full width.

:::bench bench-column-align
:::

## `Expanded` and `Flexible`

Both share out the leftover space in a `Row` or a `Column`. `Expanded` takes its whole share; `Flexible` can stay at the size of its content. `Spacer` is an empty space that pushes the next child to the end.

:::bench bench-flex
:::

### A column without a height

A `Column` is as tall as its content, unless its parent gives it a height. Without a height from the parent, an `Expanded` keeps its content's height, so a `Flex` that is a column on the phone and a row on wide screens works in both cases.

```dart
// No height to share: Expanded keeps its content's height.
Column(
  children: [
    Text('Basic plan'),
    Expanded(child: Text('Sized by its content')),
    Text('Choose'),
  ],
)

// With a height, Expanded fills what the other children leave.
SizedBox(
  height: 170,
  child: Column(
    children: [
      Text('Basic plan'),
      Expanded(child: Text('Fills the leftover height')),
      Text('Choose'),
    ],
  ),
)
```

> **Difference from Flutter:** In Flutter, an `Expanded` inside a `Column` without a height is an error. In Thor it keeps its content's height, but ignores the `height` of its direct child: put the height on the content (`Container(child: SizedBox(height: 120))`) or use `Flexible`.

## Sizes

`SizedBox` gives an exact size; `Container` combines size, padding and color; `ConstrainedBox` sets a minimum and a maximum; `FractionallySizedBox` takes a fraction of the parent's width.

`FittedBox(fit:, alignment:, clipBehavior:)` fits an image to its box with `BoxFit` (CSS `object-fit`, no measuring). A child that is not media (a text, a box) is not scaled: `contain`, `cover` and `fill` stretch it to the box, `scaleDown` caps it at the box and `none` keeps its size.

:::example layout-sizes
:::

### Relative to the window

The server doesn't know the screen, so there is no `MediaQuery`. A size relative to the window uses units in `Styled`: `vw` is a percentage of the width and `dvh` of the height. `Length.clamp` bounds the value between a minimum and a maximum.

:::example layout-screen
:::

### Phone safe areas

`SafeArea` keeps its child clear of the notch and the system bars. Each side uses the larger of the value the device reports and `minimum`.

```dart
SafeArea(
  minimum: const EdgeInsets.symmetric(horizontal: 16),
  child: const Text('Clear of the notch'),
)
```

## `Stack` and `Positioned`

The first child without `Positioned` sets the `Stack`'s size, and each `Positioned` is placed relative to its edges. As in Flutter, the `Stack` clips whatever sticks out; `clipBehavior: Clip.none` shows it in full.

`alignment` places the children without `Positioned`: the nine named ones and any fractional `Alignment(0.5, -0.5)`, in `Stack` and `IndexedStack`.

:::bench bench-stack
:::

### A Stack with only positioned children

If every child is `Positioned`, none of them gives it a height and the `Stack` measures 0. Give it a parent with a size, a child without `Positioned`, or `StackFit.expand` inside a parent with a size.

```dart
// Measures 0: no child gives it a height.
Stack(
  children: [
    Positioned(left: 8, top: 4, child: Container(width: 120, height: 40)),
  ],
)

// The SizedBox gives it the height.
SizedBox(
  height: 60,
  child: Stack(
    children: [
      Positioned(left: 8, top: 4, child: Container(width: 120, height: 40)),
    ],
  ),
)
```

> **Difference from Flutter:** In Flutter, a `Stack` with no regular children takes all the space it receives; in Thor it is 0 tall.

## `Wrap` and `Grid`

`Wrap` lays the children out in a row and moves to the next line when they don't fit.

:::bench bench-wrap
:::

`Grid` distributes the children into equal columns, and each row is as tall as its tallest cell. `GridItem` makes a child span several columns or the full row.

:::bench bench-grid
:::

### `GridView`

`GridView.extent(maxCrossAxisExtent:)` computes the columns as in Flutter, with no breakpoints; `GridView.count` fixes their number and `GridView.builder` accepts both of Flutter's `SliverGridDelegate`s. With `autoRowHeight: true`, each row is as tall as its tallest cell, without `childAspectRatio`.

:::example layout-grid-extent
:::

> **Difference from Flutter:** `GridView.builder` builds every cell on the server, so `itemCount` is required.

### Fixed-width columns

`GridLayout(columnWidth:)` creates as many columns of exactly that width as fit, with `gap` between them. It combines with `.when()`: two fluid columns on the phone and 260-wide columns from `medium` up.

```dart
Grid(
  layout: GridLayout(columns: 2, gap: 16)
      .when(medium: GridLayout(columnWidth: 260, gap: 24)),
  children: [for (final p in products) ProductCard(p)],
)
```

### Proportional columns

`GridLayout(columnSizes:)` sizes each column, like `Expanded(flex:)` in a `Row`: `GridSize.flex(n)` shares the free space by proportion, `GridSize.fixed(px)` takes exactly that width and `GridSize.auto` fits its content. It also works with `.when()`.

```dart
Grid(
  layout: GridLayout(columnSizes: [GridSize.flex(1)], gap: 16)
      .when(medium: GridLayout(columnSizes: [GridSize.flex(2), GridSize.flex(1)])),
  children: [main, aside],
)
```

## Scrolling

A scroll view needs a size along its axis: a height for vertical scrolling and the parent's width for horizontal. `ListView` and `ListView.builder` work as in Flutter.

:::example layout-scroll
:::

### With the keyboard

A scrolling region with no focusable elements receives focus with Tab and scrolls with the arrow keys. A `Semantics(label:)` around it makes the screen reader announce it; `NeverScrollableScrollPhysics()` removes it from the tab order.

```dart
Semantics(
  label: 'Results',
  child: SizedBox(height: 300, child: ListView(children: rows)),
)
```

### `PageView`

`PageView` shows view-sized pages that snap into place when swiped with a finger, the trackpad or the keyboard, with no JavaScript. `pageSnapping: false` turns snapping off; to read or change the current page, use a `PageController` in a ViewModel ([State](state.md#pageview-and-pagecontroller)).

```dart
SizedBox(
  height: 120,
  child: PageView(children: const [Text('One'), Text('Two'), Text('Three')]),
)
```

## Responsive

`.when()` changes a value according to the window's width. The base value is the phone's, and each size class (`medium` 600, `expanded` 840, `large` 1200, `extraLarge` 1600, Material 3's `WindowSizeClass`es) replaces it from that width up.

:::example layout-responsive
:::

`.when()` accepts `EdgeInsets`, `BoxConstraints`, `BorderRadius`, `Color`, `TextStyle`, `BoxDecoration`, `StyleProps`, `FlexLayout` and `GridLayout`. `ResponsiveVisibility(visibleFrom: WindowSizeClass.medium, child: …)` shows a widget only from a size class up.

### By container

To follow a container's width instead of the window's, such as a card in a sidebar, wrap it in `LayoutScope` and use `.when(container: {…})`.

:::bench bench-responsive
:::

> **Tip:** `ResponsiveLayout(mobile:, desktop:)` renders every variant and hides the ones that don't apply, so the content travels twice. If only the arrangement changes, keep one tree and change its layout with `.when()`.

The equivalents of `MediaQuery` and `LayoutBuilder` are in [Coming from Flutter](from-flutter.md#flutter-names-that-dont-exist).

## Next steps

:::cards
- [Interactivity](interactivity.md) — what changes without reloading the page
- [Theme and styles](theme-and-styles.md) — colors, typography, dark mode and units
- [Components](components.md) — every widget with its example, its code and its parameters
:::
