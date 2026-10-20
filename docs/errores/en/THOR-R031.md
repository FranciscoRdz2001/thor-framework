# THOR-R031 · A `FutureBuilder` received a new future on every pass

**Where:** `thor_ui` · the render of a page that is painted in full (`cache:`, `thor export`, `HEAD`, the `thor_test` client).

## What happened

The page is painted several times until all its `FutureBuilder` widgets have their result, and after 8 passes there was still a future without a result: each pass created another one.

## Why

A `FutureBuilder` awaits a future that already existed when the page was painted, as in Flutter: one created inside `build` is a different object on every paint and is never the one that was awaited.

## How to fix it

```dart
// WRONG: a new call on every build
FutureBuilder<List<Product>>(
  future: catalog.featured(),
  builder: (context, snapshot) => ...,
)
```

```dart
// RIGHT: it starts in `load` and travels in the page's data
@override
Future<Home> load(PageRequest request) async =>
    Home(featured: defer(catalog.featured()));

// in build: future: state.data.featured
```

[All codes](README.md)
