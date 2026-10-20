# THOR-R009 · The `DefaultTabController` length doesn't match

**Where:** `thor_ui` · `TabBar`, `TabBarView`.

## What happened

The controller's `length` differs from the number of tabs or views.

## Why

Each tab controls the view at its same index; with different lengths some would be left without a partner (Flutter fails too).

## How to fix it

```dart
// WRONG
DefaultTabController(length: 3, child: TabBar(tabs: [a, b]))
```

```dart
// RIGHT
DefaultTabController(length: 2, child: TabBar(tabs: [a, b]))
```

[All codes](README.md)
