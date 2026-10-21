# Dialogs and menus

Open dialogs, sheets, drawers and menus without writing `onPressed`: they are
native browser elements that trap focus and close with Esc.

:::flutter Flutter: `showDialog`, `showModalBottomSheet`, `Scaffold.drawer` · Thor: `AlertDialog`, `ModalBottomSheet`, `Drawer` with `DialogTrigger`

## Open a dialog

`DialogTrigger(dialog:)` turns its child into the button that opens the
dialog, and `DialogClose` into the button that closes it. The dialog is
already on the page, closed, next to its button.

:::bench bench-overlay
:::

It works with `AlertDialog`, `Dialog`, `ModalBottomSheet` and `Drawer`. The
browser closes the dialog with Esc and, with `barrierDismissible: true` (the
default), with a click outside; on close, focus returns to the button. A
button inside `DialogTrigger` or `DialogClose` works without `onPressed`.

> **Difference from Flutter:** `showDialog(context)` and `Navigator.pop`
> compile, but the editor marks them as deprecated and, at render time, they
> fail with an error that names the replacement ([Coming from Flutter](from-flutter.md#flutter-names-that-dont-exist)).

`dialog:` also takes a component of yours that builds the dialog (`DialogTrigger(dialog: const CreateDialog(), …)`): one component per class, no long `AlertDialog` inside the button.

The child does not have to be a button: around a tappable card
(`DialogTrigger(dialog: …, child: InkWell(child: Card(…)))`) the card becomes a
focusable `role="button"` and the dialog opens on a click, Enter or Space.
`DialogClose` works the same.

Add `showClose: true` to an `AlertDialog`, `Dialog`, `ModalBottomSheet` or
`Drawer` and it brings its own close button in the top corner, named by the
localized "Close", so you don't repeat a `DialogClose` in every panel.

## A dialog that does not block

`Dialog(modal: false)` and `AlertDialog(modal: false)` are a `<dialog open>` drawn without `showModal`: they show from the first paint, the rest of the page stays active and there is no backdrop, scroll lock or close with Esc. `DialogClose` closes them and they are placed like any box (with `Positioned`). They take no `controller` or `DialogTrigger`.

## Separate dialog and button

When the button and the dialog are far apart (one dialog per row, or one that
a method opens), name the dialog with `controller:` (a `DialogController`, a
ViewModel field), `key:` or `id:`, and the button says which one with
`DialogTrigger(controller:)` or `DialogTrigger(id:)`.

```dart
class OrderViewModel extends ThorState {
  final confirm = DialogController();
}

final order = OrderViewModel();

class ConfirmOrderPanel extends StatelessWidget {
  const ConfirmOrderPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      DialogTrigger(
        controller: order.confirm,
        child: const FilledButton(child: Text('Open')),
      ),
      AlertDialog(
        controller: order.confirm,
        title: const Text('Confirm order'),
        actions: [DialogClose(child: const TextButton(child: Text('Done')))],
      ),
    ]);
  }
}
```

`DialogClose` closes the dialog that contains it. Outside a dialog it fails at
render time and asks for the `id:` of the dialog it should close.

## Ask and notify from code

From a ViewModel method, `confirm(…)` asks and `toast(…)` notifies. The page
ships a single dialog and a single toast for every call, styled by the theme.

```dart
Future<void> remove(int id) async {
  if (!await confirm('Delete the order?', confirmLabel: 'Delete')) return;
  await orders.remove(id);
  toast('Order deleted', kind: ToastKind.success);
}
```

:::example state-feedback
:::

| You need | Write |
|---|---|
| to ask from a method | `await confirm('…', message: …)` |
| to notify from a method | `toast('…', kind: ToastKind.error)`; `hideToast()` and `clearToasts()` close them |
| to ask before an action | `FilledButton(onPost: …, confirm: ConfirmSpec('…'))` ([Server and actions](server-and-actions.md#asking-before-submitting)) |
| to notify on the next page | `Redirect(url).flash('…')` ([Server and actions](server-and-actions.md#a-notice-on-the-next-page)) |
| a dialog with custom content | `AlertDialog` or `Dialog` with a `DialogController` |

The toast shows above an open drawer or dialog. For a notice that depends on
the page's state, use `SnackBar`
([Feedback](components-feedback.md#snackbar)).

## Date and time picker

`DatePickerDialog` opens like any dialog, and the date reaches a ViewModel
method when OK is pressed. Cancel, Esc or a click outside discard the choice.

```dart
class DeliveryViewModel extends ThorState {
  final picker = DialogController();
  void setDelivery(DateTime d) {}
}

final delivery = DeliveryViewModel();

class DeliveryPicker extends StatelessWidget {
  const DeliveryPicker({super.key});

  @override
  Widget build(BuildContext context) => Column(children: [
    DialogTrigger(
      controller: delivery.picker,
      child: const FilledButton(child: Text('Delivery date')),
    ),
    DatePickerDialog(
      controller: delivery.picker,
      firstDate: DateTime(2026),
      lastDate: DateTime(2027, 12, 31),
      selectableDayPredicate: (d) => d.weekday < DateTime.saturday,
      onDatePicked: delivery.setDelivery,   // void setDelivery(DateTime d)
    ),
  ]);
}
```

In a form, `DatePickerFormField(id:, name:, …)` is the complete field, with a
calendar button, and `TimePickerDialog(controller:, initialTime:,
onTimePicked:)` picks the time ([Inputs](components-inputs.md)).

> **Difference from Flutter:** `await showDatePicker(context: …)` does not
> exist: the value arrives through `onDatePicked` or through the form.
> `selectableDayPredicate` runs on the server and gets each day as a UTC date:
> compare its fields or use `DateUtils.isSameDay`, not `==` with a local
> `DateTime`.

## Drawer and bottom sheet

`Drawer` is the side drawer and `ModalBottomSheet`, the sheet that slides up
from the bottom. The app's drawer goes in the `Scaffold`, as in Flutter, and
the `AppBar` adds the menu button.

```dart
Scaffold(
  appBar: AppBar(title: const Text('Orders')),
  drawer: Drawer(child: Menu()),
  endDrawer: Drawer(child: Filters()),
  body: const OrdersList(),
)
```

:::example cat-drawer
:::

`automaticallyImplyLeading: false` removes the button and `DrawerButton()`
places it anywhere. Outside the `Scaffold`, a sheet or a drawer takes a
`DialogController` and opens with `DialogTrigger(controller:)`:

```dart
class ShopViewModel extends ThorState {
  final filters = DialogController();
}

final shop = ShopViewModel();

class FilterSheet extends StatelessWidget {
  const FilterSheet({super.key});

  @override
  Widget build(BuildContext context) => Column(children: [
    DialogTrigger(
      controller: shop.filters,
      child: const TextButton(child: Text('Filters')),
    ),
    ModalBottomSheet(controller: shop.filters, child: Filters()),
  ]);
}
```

> **Difference from Flutter:** `Scaffold.of(context).openDrawer()` does not
> exist: the drawer is opened by its button.

### Close the drawer when an item is tapped

In Flutter, the item calls `Navigator.pop(context)`. In Thor, wrap it in
`DialogClose`: it closes the drawer and calls `onTap`.

```dart
Drawer(
  padding: EdgeInsets.zero,
  child: ListView(children: [
    const DrawerHeader(child: Text('Menu')),
    DialogClose(
      child: ListTile(
        leading: const Icon(Icons.settings),
        title: const Text('Settings'),
        onTap: files.openSettings,   // void openSettings() => toast('…')
      ),
    ),
  ]),
)
```

If the method decides when to close, use the drawer's `DialogController`
(`menu.close()`). A link inside a `Drawer` or a `Popover` closes it on
navigation; `closeOnNavigate: false` prevents that.

### Permanent drawer from a breakpoint

`Drawer(permanentFrom:)` is a drawer on the phone and a fixed side panel from
the given breakpoint up. It goes in a `Row`, before the content.

```dart
Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Drawer(
      controller: shop.filters,
      permanentFrom: WindowSizeClass.medium,
      width: 320,                              // the modal sheet
      permanentWidth: 200,                     // the sidebar
      label: 'Filters',
      child: Filters(),
    ),
    Expanded(
      child: Column(children: [
        DialogTrigger(
          controller: shop.filters,
          hiddenFrom: WindowSizeClass.medium,           // nothing to open once it is inline
          child: TextButton(child: const Text('Filters')),
        ),
        const Results(),
      ]),
    ),
  ],
)
```

:::example dialog-permanent-drawer
:::

`permanentFrom` also works in `Scaffold(drawer:)` and `endDrawer:`. Always
give the fixed panel a `label:`: it is what the screen reader announces.

## Popover and menus

`Popover` shows any content next to its button. `PopupMenuButton` is
Flutter's options menu: choosing an option closes the menu and `onSelected`
receives its `value`.

:::example menu
:::

```dart
PopupMenuButton(
  items: const [                // web: a list, not an itemBuilder: no BuildContext on the server
    PopupMenuItem(value: 'price', child: Text('By price')),
    PopupMenuItem(value: 'name', child: Text('By name')),
  ],
  onSelected: catalog.sort,     // void sort(String field)
  child: const Text('Sort'),
)
```

> **Difference from Flutter:** `PopupMenuButton` takes `items:`, the list
> already built, instead of `itemBuilder:`: the server renders the items once,
> without the user's `BuildContext`.

`PopupMenuButton<T>` and `PopupMenuItem<T>` are generic like Flutter's: `value` and `onSelected` share the same `T` (a `String`, a number, a `bool`, an `enum` or a model registered with `registerJsonModel`), and the state method receives it already typed as `T`.

`Popover` takes the button's content in `trigger:` and the panel's in
`child:`; `label:` names the button when `trigger` has no text.

```dart
Popover(
  trigger: const Icon(Icons.person),
  label: 'Account',
  child: AccountSummary(),
)
```

For a short label on hover, use `Tooltip`
([Content](components-content.md#tooltip)).

### `MenuAnchor`

`MenuAnchor` is Flutter's menu with items. The anchor is the button that
`builder` returns, and no `controller` is needed. A `MenuItemButton` with
`onPressed` closes the menu and calls the method; with `href`, it is a link.

```dart
MenuAnchor(
  builder: (context, controller, child) =>
      const OutlinedButton(child: Text('My account')),
  menuChildren: [
    MenuItemButton(onPressed: account.signOut, child: const Text('Sign out')),
    const MenuItemButton(href: '/orders', leadingIcon: Icon(Icons.list), child: Text('My orders')),
    SubmenuButton(
      menuChildren: [MenuItemButton(href: '/help', child: const Text('Help'))],
      child: const Text('More'),
    ),
  ],
)
```

:::example menu-anchor
:::

| Parameter | Effect |
|---|---|
| `MenuItemButton.closeOnActivate` | `false` keeps the menu open after choosing |
| `MenuAnchor.alignmentOffset` | offsets the menu |
| `MenuAnchor.style`, `MenuItemButton.style` | `MenuStyle` of the panel, `ButtonStyle` of each row |

On a page with a ViewModel, the menu responds to the arrows, Home, End and the
first letter of each item, opens submenus with the right arrow and closes with
Esc. Without JavaScript, Tab goes through the items. `PopupMenuButton`
behaves the same.

> **Difference from Flutter:** The anchor must be a button (`IconButton`,
> `TextButton`…). There is no `onOpen`, `onClose` or keyboard shortcuts.

## Accordion

`ExpansionTile` is a native element: the browser opens it, closes it and
finds it with find-in-page. For only one to stay open, give them the same
`name` or use `ExpansionPanelList`.

```dart
ExpansionPanelList(
  name: 'faq',
  children: [
    ExpansionTile(title: const Text('Is it free?'), children: [const Text('Yes, always.')]),
    ExpansionTile(title: const Text('How do I cancel?'), children: [const Text('From your account settings.')]),
  ],
)
```

:::example accordion
:::

### Accordion on the phone, column on the desktop

`ExpansionTile(permanentFrom:)` opens and closes below the breakpoint; from it
up, it shows its content and the header stops being a control. It is the
usual footer of a store.

```dart
ExpansionTile(
  permanentFrom: WindowSizeClass.medium,
  title: Text('Help'),
  children: [Link(href: RouteUrl('/shipping'), child: Text('Shipping'))],
)
```

It requires Chrome 131, Safari 18.4 or Firefox 143; in older browsers it
stays an accordion at any width.

## Next steps

:::cards
- [Accessibility](accessibility.md) — names, focus and screen readers
- [Navigation](components-navigation.md) — `AppBar`, `NavigationBar` and tabs
- [State](state.md) — the ViewModel that calls `confirm()` and `toast()`
:::
