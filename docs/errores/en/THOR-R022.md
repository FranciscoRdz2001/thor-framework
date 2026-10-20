# THOR-R022 · An element with two ids

**Where:** `thor_ui` · `Semantics(identifier:)` on a child that already has
its own `id`.

## What happened

A `Semantics(identifier: 'a')` merges into its child's element, and that
element already carried another id (another `Semantics(identifier: 'b')` inside, or a
widget that puts its own on that same element).

## Why

A DOM element has a single `id`. If Thor let one win, the other
would disappear without warning and a link to that anchor (`href="#a"`) would no longer
lead anywhere.

## How to fix it

```dart
// WRONG
Semantics(
  identifier: 'contact',
  child: Semantics(identifier: 'form', child: form),
)
```

```dart
// RIGHT: one id per element; the other one, on another element
Semantics(
  identifier: 'contact',
  child: Column(children: [
    title,
    Semantics(identifier: 'form', child: form),
  ]),
)
```

[All codes](README.md)
