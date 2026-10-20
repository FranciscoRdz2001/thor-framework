# THOR-R034 · A `ResponsiveLayout` carries the same heavy content in two variants

**Where:** `thor_ui` · `ResponsiveLayout(mobile:, tablet:, desktop:)` (a `thor dev` warning, it doesn't fail).

## What happened

Two variants of a `ResponsiveLayout` each carry a `FutureBuilder`, a `Watch.list` or more than 16 KB of HTML. The message says which one and in which variants.

## Why

`ResponsiveLayout` renders **all** the variants and CSS hides the ones that don't apply: that's how it works with SSR and without flicker. Whatever goes in two variants is sent, parsed and stored twice: a grid of 24 products in `mobile` and in `desktop` is a grid of 24 products in the HTML twice (256 KB in a real store). A `FutureBuilder` or a `Watch.list` in both is painted and maintained twice.

## How to fix it

If only the **arrangement** changes, keep a single tree and change its layout per breakpoint with `.when()`.

```dart
// WRONG: the grid is on the page twice
ResponsiveLayout(
  mobile: ProductGrid(columns: 2, products: products),
  desktop: ProductGrid(columns: 4, products: products),
)
```

```dart
// RIGHT: one grid, its columns per breakpoint
Grid(
  layout: GridLayout(columns: 2, gap: 8).when(large: GridLayout(columns: 4)),
  children: [for (final p in products) ProductCard(p)],
)

// RIGHT: a column that is a row from lg up
Column(
  layout: FlexLayout().when(large: FlexLayout(direction: Axis.horizontal)),
  children: [sidebar, Expanded(child: content)],
)
```

If what changes is truly different (a drawer on the phone, a top bar on desktop), keep only that in the `ResponsiveLayout` and pull the shared part out of the variants: the heavy content goes once, outside.

```dart
Column(children: [
  ResponsiveLayout(mobile: const MenuButton(), desktop: const TopBar()),
  ProductGrid(products: products), // once
])
```

[All codes](README.md)
