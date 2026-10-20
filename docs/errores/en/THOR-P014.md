# THOR-P014 · A malformed route or link

**Where:** `thor_ui/router.dart` · `ThorRoute(…)` and `ThorRouter([…])` at startup, and `route.link(…)` when linking.

## What happened

- A `ThorRoute`'s path does not start with `/`, has an empty segment (`//`), repeats a parameter, puts `*rest` before the end, uses a type that is not `:id:int` or has `[ ] ( ) * :` in a fixed segment.
- `SitemapRoute` or `RobotsRoute` are not at the top level of the table.
- `link(…)` receives a parameter the route does not have, is missing one, or its value is not of the type (`:id:int` asks for an `int`).

## Why

The route table is the single definition of each URL: the router and the links share it, so a mistake there shows up at startup or when linking, not as a 404 in production.

## How to fix it

```dart
// WRONG
final itemRoute = ThorRoute('item/:id', const ItemPage());
itemRoute.link({'id': '7', 'extra': 1});
```

```dart
// RIGHT
final itemRoute = ThorRoute('/item/:id:int', const ItemPage());
itemRoute.link({'id': 7});
```

[All codes](README.md)
