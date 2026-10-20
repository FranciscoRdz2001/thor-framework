# THOR-P015 · `request.param` for a parameter the route does not have

**Where:** `thor_server` · `PageRequest.param` / `paramInt`.

## What happened

The page asked for `request.param('name')`, but its `ThorRoute` has no `:name` in the path.

## Why

Parameters come from the route's path (`/article/:slug` → `param('slug')`); a name that is not there is a bug in the app, not missing data.

## How to fix it

```dart
// WRONG
final articleRoute = ThorRoute('/article/:slug', const ArticlePage());
request.param('id');
```

```dart
// RIGHT
request.param('slug');
```

[All codes](README.md)
