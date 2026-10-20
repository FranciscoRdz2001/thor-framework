# THOR-P013 · A page with data but no `load`

**Where:** `thor_ui/router.dart` · the first request to that page.

## What happened

The class extends `ThorPage<T>` (or `ThorLayout<T>`) with a data type, but does not override `load`: there is nowhere to get `state.data` from.

## Why

`T` says what `build` receives in `state.data`; only `load` produces it. A page without data is `ThorPage<void>`.

## How to fix it

```dart
// WRONG
class ArticlePage extends ThorPage<Article> {
  const ArticlePage();
  @override
  Widget build(BuildContext context, PageState<Article> state) => ...;
}
```

```dart
// RIGHT
class ArticlePage extends ThorPage<Article> {
  const ArticlePage();
  @override
  Future<Article> load(PageRequest request) => api.article(request.param('slug'));
  @override
  Widget build(BuildContext context, PageState<Article> state) => ...;
}
```

[All codes](README.md)
