# Feedback

Dialogs, short messages, progress indicators and popup menus.

## AlertDialog

:::flutter Flutter: `showDialog(AlertDialog(…))` · Thor: `DialogTrigger(dialog: AlertDialog(…))`

:::bench cat-alert-dialog
:::

A dialog with a title, content and actions. `DialogTrigger(dialog:)` places it next to the button that opens it and `DialogClose` closes the dialog from an action. It closes with Esc and, with `barrierDismissible: true`, with a tap outside.

> **Difference from Flutter:** There is no `showDialog(context)`: the dialog is in the page from the moment it's rendered, closed, next to the `DialogTrigger` that opens it.

## Dialog

:::bench cat-dialog-controller
:::

`Dialog` accepts any content. To open or close it from a method, the ViewModel (`ThorState`) declares a `DialogController` and the dialog receives it in `controller`; `AlertDialog`, `Drawer` and `ModalBottomSheet` accept the same parameter.

## SnackBar

:::flutter Flutter: `ScaffoldMessenger.showSnackBar` · Thor: `toast()` or `SnackBar(visible:)`

:::bench cat-snackbar
:::

A short message at the bottom, announced by screen readers. `SnackBarBehavior.fixed`, the default, spans the full width; `SnackBarBehavior.floating` is a centered card. It hides after `duration`, and the countdown pauses while it has the pointer or focus.

To show a message from a method, call `toast()`: it doesn't need a `BuildContext`, hides on its own and queues up.

```dart
void save() {
  // …
  toast('Changes saved', duration: const Duration(seconds: 3));
}
```

> **Difference from Flutter:** There is no `ScaffoldMessenger`. `toast()`, `hideToast()` and `clearToasts()` replace `showSnackBar`, `hideCurrentSnackBar` and `clearSnackBars`; for a message on the next page, use `Redirect(url).flash('…')`.

## Progress indicators

:::bench cat-progress
:::

`LinearProgressIndicator` and `CircularProgressIndicator` spin indefinitely when they have no `value`; with a `value` between 0 and 1 they show the progress.

| Parameter | What it does |
| --- | --- |
| `value` | from 0 to 1; `null` for the indeterminate indicator |
| `color` | the progress color |
| `semanticsLabel` | its name for screen readers |
| `size`, `strokeWidth` | the size and stroke width of the circular one |
| `minHeight` | the height of the linear bar |

## PopupMenuButton

:::bench cat-popup-menu
:::

A button that opens a menu. `onSelected` receives the `value` of the chosen option, and Esc or a tap outside closes it. For a panel with any content, like filters or a form, use `Popover` ([Dialogs and menus](dialogs-and-menus.md)).
