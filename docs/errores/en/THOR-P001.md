# THOR-P001 · Two routes catch the same URLs

**Where:** `thor_server` · `Router` (at startup).

## What happened

Two pages have the same URL shape, e.g. `/item/:id` and `/item/:slug`.

## Why

A parameter is a wildcard: both routes match exactly the same URLs and one of them would never be reached.

## How to fix it

```dart
// WRONG
ThorRoute('/item/:id', const ItemPage()),
ThorRoute('/item/:slug', const ItemBySlugPage()),
```

```dart
// RIGHT
ThorRoute('/item/:id', const ItemPage()),
ThorRoute('/item/by-slug/:slug', const ItemBySlugPage()),
```

[All codes](README.md)
