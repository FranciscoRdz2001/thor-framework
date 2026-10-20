# UI layer

Write the view as a widget and the ViewModel in two halves: a `ThorState` for what changes in the browser, and `load` and actions for the server.

:::flutter Flutter: View + ViewModel (`ChangeNotifier`) · Thor: widget + `ThorState` + `load` and actions

:::layers orders-ui
:::

## The view

The view shows what the ViewModel exposes and passes user events to it. It only contains presentation logic: an `if` to show or hide, the layout, an animation.

```dart
// lib/modules/orders/widgets/orders_view.dart
import 'package:thor_ui/thor_ui.dart';

import '../state/orders_view_model.dart';

class OrdersView extends StatelessWidget {
  const OrdersView({super.key, required this.viewModel});

  final OrdersViewModel viewModel;

  @override
  Widget build(BuildContext context) => Watch.list(
    viewModel.rows,
    itemKey: viewModel.keyOf,
    each: (row) => ListTile(
      title: row.text(viewModel.title),
      trailing: TextButton(
        onPressed: viewModel.cancel.run.withArg(row.key),
        child: const Text('Cancel'),
      ),
    ),
  );
}
```

> **Difference from Flutter:** A view is always a `StatelessWidget`; there is no `setState`. Whatever the view remembers lives in the ViewModel, and every callback is a ViewModel method, never a closure.

## The ViewModel

A ViewModel (`ThorState`) is a class with four kinds of member: queries, commands, state fields and computed values. It plays the role of Flutter's `ChangeNotifier`.

```dart
// lib/modules/orders/state/orders_view_model.dart
import 'package:thor_ui/thor_ui.dart';

import '../data/order.dart';
import '../data/orders_scope.dart';

class OrdersViewModel extends ThorState {
  // query: reads from the repository, on the server.
  final list = query(listOrders);

  // command: writes through the repository; list comes back refreshed.
  final cancel = commandWith(
    cancelOrder,
    invalidates: (OrdersViewModel s) => [s.list],
  );

  // A state field: what the user changes in the browser.
  final onlyOpen = state(false);

  // A computed value: derived from the others, never a second list.
  late final visible = derived(
    () => [
      for (final o in list.data.value ?? const <Order>[])
        if (!onlyOpen.value || o.isOpen) o,
    ],
  );

  List<Order> rows() => visible.value;
  String keyOf(Order o) => o.id;
  String title(Order o) => o.title;
  bool cancelling(String id) => cancel.pendingFor(id);
  void setOnlyOpen(bool value) => onlyOpen.value = value;
}

final orders = OrdersViewModel();
```

| You need | You write | In Flutter |
|---|---|---|
| Read data from the server | `query(fn)`, `queryWith(fn, arg: x)` | `Command0` and the repository |
| Write and refresh the list | `commandWith(fn, invalidates: …)` | `Command1` |
| Remember what the user changes | `state(value)` | a field and `notifyListeners()` |
| A computed value | `derived(() => …)` | a getter |
| Know whether it's waiting or failed | `cancel.pending`, `cancel.error`, `list.loading` | `command.running`, `command.error` |

The instance is a top-level `final` variable, and the view receives it through the constructor: `OrdersView(viewModel: orders)`. `invalidates:` receives the ViewModel itself because the field is declared before `this` exists. The types that fit in a ViewModel are in [State](state.md).

> **Difference from Flutter:** Flutter's `State<T>` belongs to a widget and goes away with it. A ViewModel belongs to the screen and is shared by several views, which is why it is never declared inside a widget.

### Loading, error and data

`QueryBuilder` is the `FutureBuilder` of a query: the server renders one variant per state and the browser switches between them.

```dart
// lib/modules/orders/widgets/orders_panel.dart
import 'package:thor_ui/thor_ui.dart';

import '../state/orders_view_model.dart';
import 'orders_view.dart';

class OrdersPanel extends StatelessWidget {
  const OrdersPanel({super.key});

  @override
  Widget build(BuildContext context) => QueryBuilder(
    query: orders.list,
    builder: (context, snapshot) {
      if (snapshot.hasError) return QueryError(orders.list);
      if (!snapshot.hasData) return const Skeleton(height: 120);
      return OrdersView(viewModel: orders);
    },
  );
}
```

> **Difference from Flutter:** `snapshot.error` is the `String` the server let through, not an `Object`. Since the `builder` runs on the server, `QueryError(orders.list)` shows that message and updates it in the browser.

## Page loading and actions

The other half of the ViewModel lives in the page, on the server: `load` fetches the data before rendering and an action receives a form. Throwing `NotFound` or `Redirect` decides which page is shown.

```dart
// lib/modules/orders/pages/order_page.dart
import 'package:thor_server/thor_server.dart';
import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

import '../data/order.dart';
import '../data/orders_scope.dart';
import '../orders_routes.dart';

class OrderPage extends ThorPage<Order> {
  const OrderPage();

  // Runs on the server before the page is rendered.
  @override
  Future<Order> load(PageRequest request) =>
      request.context.get(ordersKey).find(request.param('id'));

  // A form posts here, with or without JavaScript.
  Future<ActionResult?> cancel(PageRequest request) async {
    await request.context.get(ordersKey).cancel(request.param('id'));
    return Redirect(ordersRoute.link()).flash('Order cancelled');
  }

  @override
  Widget build(BuildContext context, PageState<Order> state) => Column(
    children: [
      Text(state.data.title),
      Form(
        child: FilledButton(onPost: cancel, child: const Text('Cancel')),
      ),
    ],
  );
}
```

If the order doesn't exist, the repository throws `NotFound` and the page shows the 404 with no extra code in `load`. The repository reaches the request through a middleware ([Data layer](data-layer.md#dependency-injection)).

## Choosing where data is loaded

| You want | Use | Without JavaScript |
|---|---|---|
| The data for the first load, the 404 or a redirect | `load` | yes |
| Fetch again without reloading, or data not needed for rendering | `query`, `queryWith` or `query(fn, ssr: false)` | no |
| Change something and refresh the list | `command` with `invalidates:` | no |
| A form with validation | an action (`onPost`, `onValid`) | yes |

If the page must work without JavaScript, the action is the baseline and the `command` is the enhancement ([Server and actions](server-and-actions.md)).

> **Caution:** `load`, actions and the functions of a `query` or a `command` run on the server, and any user who opens the page can call them. Authorize inside each one with the request's user; in a query or a command, the request is `PageRequest.current`.

## Next steps

:::cards
- [Data layer](data-layer.md) — where `listOrders` comes from
- [Patterns](patterns.md) — commands, errors and optimistic state
- [State](state.md) — lists, controllers and what fits in a ViewModel
:::
