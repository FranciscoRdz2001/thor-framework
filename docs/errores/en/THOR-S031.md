# THOR-S031 · A page without the dialog or toast a state asks for

**Where:** the browser console.

## What happened

A state method called `confirm(…)` or `toast(…)` and the page doesn't include the `<dialog>` or the toast they use. `confirm` answered no (the method continues down its "cancel" branch) and `toast` showed nothing.

## Why

The server writes the dialog and the toast only once per page, only on pages whose states use them. It knows from the build: starting at the state's file it follows the calls to functions and methods of your own app (a helper function in another file, in turn called by another…) and sees whether any of them calls `confirm(…)` or `toast(…)`. It doesn't see what isn't a call to a named function: an abstract method implemented in another file and called through the interface, a function stored in a field or a list, or code from a package.

## How to fix it

Call `confirm(…)`/`toast(…)` from a named function in your app (the build follows it across files), or put the call in the file of the state class.

```dart
// RIGHT: in the same file as the class
class OrdersState extends ThorState {
  Future<void> remove(int id) async {
    if (!await confirm('Delete the order?')) return;
    …
    toast('Order deleted', kind: ToastKind.success);
  }
}
```

More in [Dialogs and menus](../../guia/en/dialogs-and-menus.md#ask-and-notify-from-code).

[All codes](README.md)
