# THOR-R001 · Thor doesn't know how to build this widget

**Where:** `thor_ui` · server-side render.

## What happened

A widget doesn't extend `StatelessWidget`, `StatefulWidget` or `InheritedWidget`.

## Why

Thor builds the tree on the server with the same three families as Flutter. A `RenderObjectWidget` or a direct subclass of `Widget` has no equivalent: its painting lives in Flutter's renderer, which doesn't exist here.

## How to fix it

```dart
// WRONG
class Gauge extends LeafRenderObjectWidget { ... }
```

```dart
// RIGHT
// Compose it from thor widgets (CSS and HTML):
class Gauge extends StatelessWidget {
  const Gauge({super.key, required this.value});
  final double value;
  @override
  Widget build(BuildContext context) => LinearProgressIndicator(value: value);
}
```

[All codes](README.md)
