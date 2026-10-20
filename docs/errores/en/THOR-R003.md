# THOR-R003 · `Cached` contains the `<head>` or the document

**Where:** `thor_ui` · `Cached`.

## What happened

A subtree inside `Cached` writes to `Document.head` or contains `<html>`, `<head>` or `<body>`.

## Why

The document moves those nodes into place when the render finishes; a stored fragment can't carry them.

## How to fix it

```dart
// WRONG
Cached(cacheKey: 'page', child: Document(title: 'x', body: ...))
```

```dart
// RIGHT
Document(title: 'x', body: Cached(cacheKey: 'body', child: ...))
```

[All codes](README.md)
