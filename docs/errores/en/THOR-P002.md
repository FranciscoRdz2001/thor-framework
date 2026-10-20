# THOR-P002 · Exporting a site that negotiates the language

**Where:** `thor_server` · `exportSite` (`thor export`).

## What happened

A site with `LocaleStrategy.negotiate` was exported as static.

## Why

Negotiating means **one URL for all languages**, chosen by `Accept-Language`/cookie on every request. A static host cannot choose: it serves a single file per URL.

## How to fix it

```dart
// WRONG
RouteHandler(locales: LocaleRouting(..., strategy: LocaleStrategy.negotiate))
```

```dart
// RIGHT
RouteHandler(locales: LocaleRouting(..., strategy: LocaleStrategy.prefix))
// /es/..., /en/... and a picker page at /
```

[All codes](README.md)
