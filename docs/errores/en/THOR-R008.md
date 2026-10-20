# THOR-R008 · Missing `DefaultTabController`

**Where:** `thor_ui` · `TabBar`, `TabBarView`.

## What happened

A `TabBar` or `TabBarView` without a `DefaultTabController` above it.

## Why

Same as in Flutter: the tabs and their views are connected through the controller (in Thor, the radio group and the panel they show).

## How to fix it

```dart
// WRONG
Column(children: [TabBar(tabs: tabs), TabBarView(children: views)])
```

```dart
// RIGHT
DefaultTabController(
  length: 2,
  child: Column(children: [TabBar(tabs: tabs), Expanded(child: TabBarView(children: views))]),
)
```

[All codes](README.md)
