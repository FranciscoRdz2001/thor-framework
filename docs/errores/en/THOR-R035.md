# THOR-R035 · A `LazyPiece`'s `id` doesn't fit in a URL

**Where:** `thor_ui` · `LazyPiece(id: …)`.

## What happened

A `LazyPiece`'s `id` has a character that isn't a letter, digit, `-`, `_`
or `.` (a space, a slash, an accent).

## Why

The `id` is part of the piece's URL: the page requests `?thor-piece=<id>` and the
server looks for the `LazyPiece` with that name when it renders the page again. An
`id` with URL characters would be read differently on each side.

## How to fix it

Use a simple name that is unique in the page; if it comes from data, turn it into
a slug.

```dart
// WRONG
LazyPiece<List<Category>>(id: 'branch of ${department.name}', …)

// RIGHT
LazyPiece<List<Category>>(id: 'branch-${department.slug}', …)
```

[All codes](README.md)
