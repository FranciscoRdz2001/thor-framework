# THOR-B023 · A page with actions the registry cannot name

**Where:** `thor dev` / `thor build` / `thor test`.

## What happened

A private page class (`_ContactPage`) or one with type parameters has action methods (`Future<ActionResult?> x(PageRequest …)`).

## Why

Thor registers actions from outside your file and names the class to get its methods (`(p as ContactPage).send`). A private class cannot be named from another file, and a generic one does not have a single type.

## How to fix it

```dart
// WRONG
class _ContactPage extends ThorPage<void> { Future<ActionResult?> send(…) … }
```

```dart
// RIGHT
class ContactPage extends ThorPage<void> { Future<ActionResult?> send(…) … }
```

[All codes](README.md)
