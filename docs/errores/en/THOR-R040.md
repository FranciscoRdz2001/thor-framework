# THOR-R040 · A `GestureDetector` or `InkWell` callback the browser can't provide

**Where:** `thor_ui` · `GestureDetector`, `InkWell` and `InkResponse` (at render time).

## What happened

You passed `GestureDetector`, `InkWell` or `InkResponse` a Flutter callback that has no equivalent in the browser (`onTapCancel`, `onPanStart`, `onScaleUpdate`, `onHover`…), or you asked for both `onHorizontalDragEnd` and `onVerticalDragEnd` at once.

## Why

The finger movement is handled by the browser on the compositor and your method runs once, on release. A per-event callback (finger down, each frame of the pinch) would force sending every event to the state. Letting it through with no effect would make the gesture not work without saying why; that's why it fails, and the message names each callback and what to use instead.

## How to fix it

```dart
// WRONG
GestureDetector(onTapCancel: () => cancelled(), onPanStart: (_) => started(), child: tile)
InkWell(onHover: (h) => hovering(h), onTap: open, child: tile)
```

```dart
// RIGHT
GestureDetector(onTap: state.open, onPanUpdate: state.moved, child: tile)
Gesture(onTap: state.open, feedback: const Press(), child: tile) // look while pressed
InkWell(onTap: state.open, hoverColor: const Color(0x14000000), child: tile)
MouseRegion(onEnter: state.enter, onExit: state.leave, child: tile) // a method when the pointer passes over
```

For a single swipe axis, one `GestureDetector` per axis or `Gesture(onSwipe:, swipe: Swipe(axis: …))`.

[All codes](README.md)
