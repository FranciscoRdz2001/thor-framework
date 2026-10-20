# Circles with undo

A canvas where a click adds a circle or selects one, and a dialog changes its diameter, with undo and redo.

:::flutter Flutter: `CustomPaint` and `GestureDetector` · Thor: `Watch.list` and a single `Gesture`

:::example recipe-circles
:::

## History is snapshots

Each change stores the circles as a string in `snapshots` and advances `cursor`. Undo and redo only move the cursor, and a computed value reads the circles from the current snapshot.

```dart
class HistoryViewModel extends ThorState {
  final snapshots = state(const ['']);
  final cursor = state(0);

  late final current = derived(() => snapshots.value[cursor.value]);

  bool cannotUndo() => cursor.value == 0;
  bool cannotRedo() => cursor.value >= snapshots.value.length - 1;

  void push(String snapshot) => batch(() {
    snapshots.value = [
      ...snapshots.value.sublist(0, cursor.value + 1),
      snapshot,
    ];
    cursor.value = cursor.value + 1;
  });

  void undo() {
    if (!cannotUndo()) cursor.value = cursor.value - 1;
  }

  void redo() {
    if (!cannotRedo()) cursor.value = cursor.value + 1;
  }
}
```

## A single element for the canvas

The canvas is a `Gesture` that receives where the tap landed (`onTapDown(x, y)`, `onTapUp(x, y)`). Each circle is a `Watch.list` row whose position and size are row lengths (`row.length`), so the diameter changes without rebuilding anything.

```dart
Watch.list(
  circles.rows,
  itemKey: circles.idOf,
  container: (rows) => Gesture(
    onTapDown: circles.down,
    onTapUp: circles.up,
    onLongPress: circles.adjust,
    child: SizedBox(height: 280, child: Stack(children: rows)),
  ),
  each: (row) {
    final x = row.length(circles.left);
    final y = row.length(circles.top);
    final d = row.length(circles.diameter);
    return Styled(
      style: StyleProps(
        position: BoxPosition.absolute(left: x, top: y),
        minWidth: d,
        minHeight: d,
      ),
      child: const DecoratedBox(
        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.grey),
      ),
    );
  },
)
```

The dialog is an `AlertDialog(controller:)` with a `Slider` bound to the diameter of the selected circle.

> **Difference from Flutter:** `onLongPress` doesn't say where it happened: a right click or a long press opens the dialog for the circle that is already selected. With a finger, `onTapDown` selects it; with a mouse, left-click before right-clicking.

Related: [Gestures](../gestures.md) · [Dialogs and menus](../dialogs-and-menus.md)
