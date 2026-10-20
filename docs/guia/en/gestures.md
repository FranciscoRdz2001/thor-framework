# Gestures

Respond to taps, long presses, drags, swipes and pinches with
`GestureDetector` and `Gesture`: the browser follows the finger and your
method runs on release.

:::flutter Flutter: `GestureDetector`, `InkWell`, `Dismissible`, `Draggable` · Thor: the same ones, with ViewModel methods

## Tap position

`onTapDown` and `onTapUp` receive the position in pixels from the element's
top-left corner. A canvas is a single element and the method knows where to
draw.

:::bench bench-tap-position
:::

:::flutter
@flutter
```dart no-check
GestureDetector(
  onTapUp: (details) => addAt(details.localPosition),
  child: const SizedBox(width: 300, height: 180),
)
```
@thor
```dart
Gesture(
  onTapUp: circles.at,                   // void at(double x, double y)
  child: const SizedBox(width: 300, height: 180),
)
```
:::

`onTapDown` is called when the pointer goes down, even if the touch ends up
as a drag. `onTapUp` is only called if the touch ends as a tap: not after
moving more than 8 px, swiping or holding. With the keyboard, Enter or Space
on the focused element is a tap at its center.

> **Difference from Flutter:** `Gesture` delivers `x` and `y` as two numbers;
> `GestureDetector` delivers `TapDownDetails` and `TapUpDetails`. `onTap` is
> called immediately even when there is an `onDoubleTap`. Callbacks are
> methods of a ViewModel (`ThorState`), not closures.

## `Gesture`

`Gesture` brings together every gesture and the drag and pinch options. In a
drag, your method receives `dx` and `dy` on release.

:::bench bench-drag
:::

```dart
// A card dragged vertically that stays where you drop it.
Gesture(
  onDragEnd: board.moved,             // void moved(double dx, double dy)
  drag: const Drag(axis: Axis.vertical, snapBack: false),
  child: TaskCard(t),
)

// A photo that zooms with two fingers.
Gesture(
  onScaleEnd: viewer.zoom,            // void zoom(double scale)
  pinch: const Pinch(max: 3),
  child: Image.network(url, width: 800, height: 600),
)
```

| Gesture | Your method receives | With the keyboard |
|---|---|---|
| `onTap`, `onDoubleTap`, `onLongPress` | nothing, or the `withArg` argument | Enter or Space (`onTap`); menu key (`onLongPress`) |
| `onTapDown`, `onTapUp` | `x`, `y` | Enter, Space (at the center) |
| `onSwipe` | `SwipeDirection` (`start`, `end`, `up`, `down`) | Shift + arrow |
| `onDragEnd` | `dx`, `dy` | arrows |
| `onScaleEnd` | the scale | `+` / `−` |

`onDoubleTap` counts two taps within 300 ms; `onLongPress`, holding for about
500 ms without moving, or a right click.

| Object | Parameters | For |
|---|---|---|
| `Swipe` | `axis` (horizontal), `dismiss`, `threshold` (0.4 of the width) | `onSwipe` |
| `Drag` | `axis` (`null`: free), `snapBack`, `step` (px per arrow) | `onDragEnd` |
| `Pinch` | `min`, `max`, `snapBack`, `step` (per key) | `onScaleEnd` |
| `Press` | `scale`, `opacity` | visual feedback on press |

`Gesture` adds no elements: it applies to its child's element. If the child
is not a button or a link, it gives it the button role and keyboard handling.
A horizontal swipe lets the page's vertical scroll through, and vice versa.

> **Important:** While the drag lasts, the gesture's offset and scale replace
> whatever the element has. With reduced motion, `feedback: Press()` scales
> without animating.

### Swipe

Swiping is a path-based gesture, and the accessibility guidelines (WCAG
2.5.1) require another way to do it: `onSwipe` also responds to Shift +
arrow. Also add a visible button for the same action.

:::example gesture-swipe-keys
:::

```dart
Gesture(
  onSwipe: inbox.swiped.withArg(m.id),   // void swiped(int id, SwipeDirection d)
  swipe: const Swipe(dismiss: true),
  feedback: const Press(scale: 0.97),
  child: MessageRow(m),
)
```

Horizontally you get `start` or `end`, which follow the text direction: in
Arabic or Hebrew, swiping left is `end`. Vertically you get `up` or `down`. A
text field keeps its keys, so it is not swiped with the keyboard.

## `GestureDetector` and `InkWell`

`GestureDetector` and `InkWell` are Flutter's widgets, built on `Gesture`:
`GestureDetector` for gestures with no look of their own, `InkWell` and
`InkResponse` for a tappable area that responds to the pointer.

```dart
GestureDetector(
  onTap: inbox.open,                  // void open()
  onLongPress: inbox.menu,
  onHorizontalDragEnd: inbox.swiped,  // void swiped(SwipeDirection d)
  child: MessageTile(m),
)

InkWell(
  onTap: inbox.open,
  borderRadius: BorderRadius.circular(12),
  child: MessageTile(m),
)
```

:::example gesture-inkwell
:::

| `GestureDetector` | Receives |
|---|---|
| `onTap`, `onDoubleTap`, `onLongPress` | the same as in `Gesture` |
| `onTapDown`, `onTapUp` | `TapDownDetails`, `TapUpDetails` (`localPosition`) |
| `onPanUpdate` | `DragUpdateDetails` (`delta`) |
| `onPanEnd` | `DragEndDetails` (`velocity`, `localPosition`, `globalPosition`; `primaryVelocity` is null, as for a pan) |
| `onHorizontalDragEnd`, `onVerticalDragEnd` | `SwipeDirection` on that axis |
| `onScaleEnd` | the scale |

Callbacks the browser cannot deliver (`onTapCancel`, `onPanStart`,
`onScaleUpdate`…) are marked `@Deprecated` and fail at render time with
[THOR-R040](../../errores/en/THOR-R040.md), which says what to use instead.

`InkWell` does not draw ripples: on hover, with focus and on press it shows a
translucent layer (`hoverColor`, `focusColor`, `highlightColor`).
`borderRadius` and `customBorder` round it; `InkResponse` draws it as a
circle. Without `onTap`, `onDoubleTap` or `onLongPress` it does not respond,
as in Flutter.

| `InkWell` child | Result |
|---|---|
| text, icon or image | a native button |
| a box (`Container`, `Row`, `Card`…) | button role, focus, Enter and Space |
| a button (`FilledButton`, `IconButton`…) | the child's button, with no new role |

> **Important:** A control inside a box with `InkWell` is still its own
> button, but a screen reader announces a button inside another. Move the
> control out of the tappable area.

## `Dismissible`

A row that is dismissed by dragging it, with Flutter's API. Past the
threshold (0.4 of its size, or a quick fling), it slides out, asks
`confirmDismiss`, collapses and calls `onDismissed`. With the keyboard,
Delete or Backspace dismiss it.

:::example gesture-dismissible
:::

```dart
Dismissible(
  key: ValueKey(m.id),
  direction: DismissDirection.endToStart,
  onDismissed: inbox.archived.withArg(m.id),   // void archived(int id, DismissDirection d)
  confirmDismiss: inbox.ask.withArg(m.id),     // Future<bool> ask(int id, DismissDirection d)
  background: const ColoredBox(color: Color(0xFF16A34A)),
  child: MessageTile(m),
)
```

| Parameter | Use |
|---|---|
| `onDismissed` | ViewModel method that removes the row; receives the `DismissDirection` |
| `confirmDismiss` | returns `bool` or `Future<bool>`; `false` puts the row back in place |
| `direction` | `horizontal` (the default), `vertical`, `startToEnd`, `endToStart`, `up`, `down` or `none` |
| `background`, `secondaryBackground` | the first for `startToEnd` and `down`; the second for `endToStart` and `up` |
| `dismissThresholds` | threshold per direction (`{DismissDirection.endToStart: 0.7}`) |
| `resizeDuration`, `movementDuration` | the collapse (`null`: no collapse) and the slide |

> **Difference from Flutter:** There is no `onUpdate`, `onResize`,
> `crossAxisEndOffset` or `dragStartBehavior`. Without JavaScript the row is
> just its child: offer the same action in a button.

## `Draggable` and `DragTarget`

`feedback` is what follows the pointer and `childWhenDragging` takes the
source's place in the meantime. The target decides what it accepts.

:::example gesture-draggable
:::

```dart
Draggable<String>(
  data: task.id,
  feedback: TaskCard(task),
  childWhenDragging: Opacity(opacity: 0.3, child: TaskCard(task)),
  onDragCompleted: board.picked.withArg(task.id),
  child: TaskCard(task),
)

DragTarget<String>(
  onWillAcceptWithDetails: board.fits.withArg(column.id),   // bool fits(String column, String task)
  onAcceptWithDetails: board.moved.withArg(column.id),      // void moved(String column, String task)
  overStyle: const StyleProps(opacity: 0.8),
  builder: (context, candidates, rejected) => Content(column),
)
```

- **Data:** reaches the target's method as a `String`, number, `bool` or
  enum; a `Map` or a `List`, as JSON. `onWillAcceptWithDetails` decides
  whether it fits.
- **Target:** `builder` runs once on the server. `overStyle` applies while
  something that fits is over it, and `rejectStyle`, something that doesn't.
- **`LongPressDraggable`:** waits for a long press (`delay`, 500 ms) so that
  moving earlier scrolls the page. Useful in scrolling lists.
- **Callbacks:** `onDragStarted`, `onDragCompleted`, `onDraggableCanceled` and
  `onDragEnd` on the source; `onLeave` and `onMove` on the target.
- **Edges:** near the edge, the page or the container scrolls on its own.

With the keyboard (WCAG 2.5.7), Space or Enter picks up the source, the
arrows go through the targets that accept it, Space or Enter drops it and Esc
cancels. A screen reader announces each step; `labels: DragLabels(...)`
translates the phrases.

> **Difference from Flutter:** There is no per-frame `onDragUpdate`,
> `rootOverlay` or `ignoringFeedbackSemantics`, and one element is dragged at
> a time. The `feedback` does not take the source's size: give it its own.
> Without JavaScript there is no dragging.

## `ReorderableListView`

The user drags an item's handle to change the order. `onReorder(oldIndex,
newIndex)` uses Flutter's indices: `newIndex` counts the list before the item
is removed, so when moving down you subtract one.

`header` and `footer` are not items: they render next to the `role="list"` element, not inside it, so the list holds only its items. They scroll with the items, as in Flutter, and `padding` goes around all three.

:::example gesture-reorderable
:::

```dart
Watch.list(
  todo.items,
  itemKey: todo.keyOf,
  container: (rows) => ReorderableListView(onReorder: todo.reorder, children: rows),
  each: (row) => TaskCard(row),
)
```

Each item carries a handle (`buildDefaultDragHandles`);
`ReorderableDragStartListener` puts it wherever you want and
`ReorderableDelayedDragStartListener` waits for a long press. With the
keyboard, Space or Enter on the handle picks up the item, the arrows move it,
Space or Enter drops it and Esc puts it back; Alt + arrow moves it one place.
`labels: ReorderLabels(...)` translates the phrases.

> **Difference from Flutter:** There is no `proxyDecorator`: the dragged
> element is the same one, with the look of `draggingStyle: StyleProps(...)`.
> `shrinkWrap` and `physics` are accepted with no effect.

## Pointer, focus and accordion

Three Flutter callbacks that react in the browser, each one a ViewModel
method.

```dart
MouseRegion(onEnter: card.hover, onExit: card.unhover, child: card)
Focus(canRequestFocus: false, onFocusChange: form.focused, child: fields)
ExpansionTile(title: title, onExpansionChanged: faq.changed, children: body)
```

:::example events-hover-focus
:::

:::example events-expansion
:::

| Widget | Callback | Receives |
|---|---|---|
| `MouseRegion` | `onEnter`, `onExit` | nothing |
| `Focus` | `onFocusChange` | `true` if focus enters the element or a descendant; `false` if it leaves |
| `ExpansionTile` | `onExpansionChanged` | `true` on open, `false` on close |

`MouseRegion` counts the mouse and the pen, not the finger. Moving focus
between two inner fields does not call `onFocusChange`. In an accordion
(`name:` or `ExpansionPanelList`), `onExpansionChanged` notifies the one that
closes first and then the one that opens.

## Next steps

:::cards
- [Interactivity](interactivity.md) — a ViewModel's methods
- [Animations](animations.md) — the motion of a state change
- [Accessibility](accessibility.md) — keyboard and screen readers
:::
