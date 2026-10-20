# THOR-R002 · `Cached` is inside a wrapper

**Where:** `thor_ui` · `Cached`.

## What happened

`Cached` ended up below a wrapper that decorates its first element (`Expanded`, `Semantics`, `Link`, `Opacity`…).

## Why

Those wrappers don't emit an element of their own: they add classes or attributes **to the child's first element**. If the child is `Cached`, the stored HTML wouldn't include that decoration and another request would serve it without it.

## How to fix it

```dart
// WRONG
Expanded(child: Cached(cacheKey: 'list', child: ProductList()))
```

```dart
// RIGHT
Cached(cacheKey: 'list', child: Expanded(child: ProductList()))
// …or an element of its own in between (Container, SizedBox).
```

[All codes](README.md)
