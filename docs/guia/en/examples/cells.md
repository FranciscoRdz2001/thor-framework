# Spreadsheet

A grid of editable cells that accept formulas with references (`=A1*2`, `=SUM(A1:A3)`) and recalculate on their own.

:::flutter Flutter: `Table` and one `TextField` per cell · Thor: a computed value that evaluates the sheet

:::example recipe-cells
:::

## One evaluation per change

The ViewModel (`ThorState`) keeps the text of each cell. A computed value (`derived`) evaluates the whole sheet once per change and returns what each cell shows; a cycle shows `#CYCLE`, a division by zero `#DIV/0` and an invalid formula `#ERROR`.

Each cell reads its result with `withArg`, and its `Gesture` selects the cell with one tap and edits it with two:

```dart
class SheetCell extends StatelessWidget {
  const SheetCell(this.index, {super.key});

  final int index;

  @override
  Widget build(BuildContext context) => Gesture(
    onTap: sheet.select.withArg(index),
    onDoubleTap: sheet.edit.withArg(index),
    child: SizedBox(height: 28, child: Watch(sheet.text.withArg(index))),
  );
}
```

## A single field for editing

A single `TextField` is placed over the cell being edited, instead of one field per cell. The arrow keys move the selection with a `CallbackShortcuts`; Enter or F2 start editing, Enter confirms and Esc cancels.

Related: [Gestures](../gestures.md) · [State](../state.md)
