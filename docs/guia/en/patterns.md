# Patterns

Write the patterns from Flutter's architecture guide in Thor: commands, errors as results, optimistic state, caches and preferences.

| Flutter pattern | In Thor |
|---|---|
| Command | `command` and `commandWith`, with `pending`, `error` and `result` |
| Result | whatever the repository throws, and `errorKind` on a `command` |
| Optimistic state | a ViewModel method |
| Key-value data | `state(value, cookie: 'name')` or `state(value, local: 'name')` |
| SQL | your repository, on the server, with any database |
| Offline-first | does not exist in Thor |

List state in the URL is covered in [Server and actions](server-and-actions.md#paginated-lists-in-the-url), and lists with hundreds of rows in [Long lists](long-lists.md).

## Commands

A `command` is a server function with its own state: `pending` while it waits, `error` if it fails and `result` with what it returned. A second `run` while the first one is waiting gets queued and goes out when the previous one finishes.

:::bench bench-command
:::

:::flutter
@flutter
```dart no-check
ListenableBuilder(
  listenable: viewModel.cancel,
  builder: (context, _) => viewModel.cancel.running
      ? const Text('Cancelling…')
      : FilledButton(
          onPressed: () => viewModel.cancel.execute(order.id),
          child: const Text('Cancel'),
        ),
)
```
@thor
```dart
// lib/modules/orders/widgets/cancel_button.dart
import 'package:thor_ui/thor_ui.dart';

import '../state/orders_view_model.dart';

class CancelButton extends StatelessWidget {
  const CancelButton({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) => Watch(
    orders.cancelling.withArg(id),
    builder: (busy) => busy
        ? const Text('Cancelling…')
        : FilledButton(
            onPressed: orders.cancel.run.withArg(id),
            child: const Text('Cancel'),
          ),
  );
}
```
:::

> **Difference from Flutter:** The `Command` in Flutter's guide ignores `execute` while it runs; Thor's queues the call. To prevent a second tap, hide the button while it waits, as in the code above.

`cancelling` is a ViewModel method that asks whether that row is waiting: `bool cancelling(String id) => cancel.pendingFor(id);`. With `cancel.pending`, cancelling one row would block all of them.

> **Important:** A `command` needs JavaScript. If the page must work without it, the baseline is an action with its form ([Server and actions](server-and-actions.md)) and the `command` is the enhancement.

## Errors as results

A `command` never throws: `run` returns `null` if it failed and `error` says why. To decide based on the kind of failure, `errorKind` is an enum.

```dart
// lib/modules/orders/state/cancel_failure_view_model.dart
import 'package:thor_ui/thor_ui.dart';

import '../data/orders_scope.dart';

class CancelFailureViewModel extends ThorState {
  final cancel = commandWith(cancelOrder);

  bool needsSignIn() => cancel.errorKind.value == ServerErrorKind.unauthorized;
  bool offline() => cancel.errorKind.value == ServerErrorKind.network;
  String message() => cancel.error.value ?? '';
}

final cancelFailure = CancelFailureViewModel();
```

| `errorKind` | When |
|---|---|
| `network`, `timeout` | no response, or past the deadline (30 s by default) |
| `aborted` | something outside the ViewModel cancelled the request |
| `unauthorized`, `forbidden` | 401 and 403 |
| `validation`, `client` | 400 and 422; any other 4xx |
| `server` | 5xx |

You write the text of `error`: an `HttpError(409, 'The order has already shipped.')` from the repository arrives as is, and the generic messages come from `ThorApp(serverMessages:)`. How to throw them: [Data layer](data-layer.md#backend-errors-to-the-page).

> **Difference from Flutter:** There is no `Result` class. In `load`, what gets thrown (`NotFound`, `Redirect`, `HttpError`) decides the page; in a `command`, the result is `error`, `errorKind` and `result`.

## Optimistic state

The interface changes before the server responds and rolls back if it fails. Thor ships no helper for this: it is a three-line ViewModel method.

:::bench bench-optimistic
:::

The view reads `starred` with `Watch.field` and the button calls `toggle.withArg(id)`. Use it only when failure is rare and reversible; a payment or a deletion is never shown as done before it is.

> **Tip:** A second tap while it waits goes out after the first. If you don't want two requests, disable the button while `star.pending` is `true`.

## Tag-based caches

A page can share its HTML across users for a while. With `tags:`, a write invalidates only the pages that depend on that data.

```dart
// lib/modules/orders/pages/orders_summary_page.dart
import 'package:thor_server/thor_server.dart';
import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

import '../data/orders_scope.dart';

class OrdersSummaryPage extends ThorPage<int> {
  const OrdersSummaryPage()
    : super(cache: const Duration(minutes: 5), tags: const ['orders']);

  @override
  Future<int> load(PageRequest request) async =>
      (await request.context.get(ordersKey).list()).length;

  Future<ActionResult?> cancel(PageRequest request) async {
    await request.context.get(ordersKey).cancel(request.param('id'));
    revalidateTag('orders'); // only the pages tagged 'orders' render again
    return null;
  }

  @override
  Widget build(BuildContext context, PageState<int> state) =>
      Text('${state.data} orders');
}
```

The cache is only shared between requests without personal data, and a successful write already clears the whole cache. With `invalidateOnWrite: false`, only the tags decide what gets cleared ([Server and actions](server-and-actions.md)).

## Preferences

A state field with `cookie:` keeps its value across pages and reloads, like `SharedPreferences` in Flutter.

:::flutter
@flutter
```dart no-check
class ThemeViewModel extends ChangeNotifier {
  ThemeViewModel(this._preferences)
    : dark = _preferences.getBool('dark') ?? false;

  final SharedPreferences _preferences;

  bool dark;

  Future<void> toggle() async {
    dark = !dark;
    await _preferences.setBool('dark', dark);
    notifyListeners();
  }
}
```
@thor
```dart
class ThemeViewModel extends ThorState {
  final dark = state(false, cookie: 'theme');

  void toggle() => dark.value = !dark.value;
}

final theme = ThemeViewModel();
```
:::

> **Caution:** The user can write that cookie. Use it for the page's appearance, never for permissions.

What the server doesn't need (a draft, the last filter) goes in `localStorage` with `local:`. It isn't sent with every request, has no cookie size limit, and the site's other tabs get the change.

```dart
class NoteViewModel extends ThorState {
  final draft = state('', local: 'note-draft');

  void edit(String text) => draft.value = text;
}

final note = NoteViewModel();
```

The server paints the value in the code and the browser applies the stored one when the engine starts, so Chromium and Firefox show the initial value for a moment. For what shows on load (theme, a collapsed panel), use `cookie:`. If the browser blocks storage, the value only lasts while the page is open, without errors.

## What Thor doesn't do

- **Offline-first.** There is no database in the browser and no sync: a `query` or a `command` without a connection ends with `errorKind` set to `network`, and `data.value` keeps the last data received.
- **Built-in optimistic state.** It's written as a ViewModel method.
- **A `Result` type.** Errors are thrown, or arrive through `error` and `errorKind`.

## Next steps

:::cards
- [State](state.md) — `query`, `command` and everything that fits in a ViewModel
- [Server and actions](server-and-actions.md) — `load`, actions, lists and caching
- [Testing](testing.md) — the test client and fake backends
:::
