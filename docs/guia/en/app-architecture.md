# App architecture

Organize your app into View, ViewModel, Repository and Service, as in Flutter's architecture guide; the Repository and the Service run on the server.

:::flutter Flutter: `ChangeNotifier`, `Provider`, `go_router` · Thor: `ThorState`, middleware, `ThorRouter`

The example is a list of orders that can be cancelled, written layer by layer in Flutter and in Thor.

:::layers orders
:::

## The layers

Each layer in [Flutter's architecture guide](https://docs.flutter.dev/app-architecture/concepts) has its equivalent in Thor. The View only talks to its ViewModel, and the ViewModel to the Repository.

| Layer | In Flutter | In Thor |
|---|---|---|
| View | a widget | a `StatelessWidget` |
| ViewModel | a `ChangeNotifier` | a ViewModel (`ThorState`) in the browser; the page's `load` and actions on the server |
| Repository | a class with an interface | the same class, on the server |
| Service | an HTTP client wrapped in a class | `ThorHttpClient` wrapped in a class, on the server |
| Domain (optional) | use cases | Dart functions or classes, when a ViewModel combines several repositories |

The recommendation tables use Flutter's levels: strongly recommended, recommended or conditional.

## Separation of concerns

The View shows data and reports events; the ViewModel decides what happens.

```dart
// WRONG (THOR-S011): the view decides, and the closure never reaches the browser
TextButton(
  onPressed: () async {
    await cancelOrder(order.id);
    orders.list.refresh();
  },
  child: const Text('Cancel'),
)

// RIGHT: the view calls a method of its ViewModel
TextButton(
  onPressed: viewModel.cancel.run.withArg(order.id),
  child: const Text('Cancel'),
)
```

In Thor the separation is mandatory: a closure that uses a ViewModel doesn't reach the browser ([THOR-S011](../../errores/en/THOR-S011.md)).

| Recommendation | Level | In Thor |
|---|---|---|
| Clearly defined data and interface layers | Strongly recommended | the View and the ViewModel only use the data layer's public functions ([Data layer](data-layer.md)) |
| The repository pattern | Strongly recommended | one Repository per type of data |
| Views and ViewModels | Strongly recommended | one `StatelessWidget` and one `ThorState` per screen ([Interface layer](ui-layer.md)) |
| No logic in widgets | Strongly recommended | every callback is a ViewModel method |
| `ChangeNotifier` and `Listenable` | Conditional | doesn't apply: the browser updates what `Watch` reads ([State](state.md)) |
| A domain layer | Conditional | Dart functions or classes, only if a ViewModel combines several repositories |

## Single source of truth

Each piece of data has one owner, the Repository. The ViewModel doesn't keep a copy to edit: it keeps a `query`'s response and computes the rest with a computed value (`derived`).

```dart
class OrdersViewModel extends ThorState {
  // The browser's only copy is the repository's last answer.
  final list = query(listOrders);

  // Computed from it, never a second list to keep in sync.
  late final count = derived(() => list.data.value?.length ?? 0);

  String countText() => '${count.value} orders';
}

final orders = OrdersViewModel();
```

| Recommendation | Level | In Thor |
|---|---|---|
| Immutable data models | Strongly recommended | classes with `final` fields and a `const` constructor |
| `freezed` or `built_value` | Recommended | any package on the server; what reaches a ViewModel is JSON with `toJson` and `fromJson` ([Pub packages](pub-packages.md)) |
| Separate API and domain models | Conditional | a `fromJson` in the Repository that converts one into the other |
| A list's state in the URL (Thor only) | Recommended | search, page and filters work with links and without JavaScript ([Server and actions](server-and-actions.md#paginated-lists-in-the-url)) |

## Unidirectional data flow

Data flows down from the Repository to the View through a `query` and `Watch`; events flow up from the View to the Repository through a ViewModel method and a `command`.

:::bench bench-command
:::

When the `command` succeeds, the server reruns the queries in `invalidates:` and returns them in the same response. No data is updated by hand.

| Recommendation | Level | In Thor |
|---|---|---|
| Unidirectional data flow | Strongly recommended | `query` and `Watch` toward the View; ViewModel methods and `command` toward the Repository |
| Commands for user events | Recommended | `command` and `commandWith`, with `pending` and `error` ([Patterns](patterns.md)) |
| An action as the baseline and a `command` as the enhancement (Thor only) | Recommended | without JavaScript only the action runs ([Server and actions](server-and-actions.md)) |

## UI is a function of state

`build` runs once, on the server. A value that changes isn't read in `build`: it's passed to `Watch`, and the browser updates that text.

:::flutter
@flutter
```dart no-check
ListenableBuilder(
  listenable: viewModel,
  builder: (context, _) => Text('${viewModel.orders.length} orders'),
)
```
@thor
```dart
Watch(orders.countText)
```
:::

> **Difference from Flutter:** Flutter's `builder` runs on every change. In Thor, `build` runs on the server, and reading `.value` there freezes the value the server rendered the page with ([THOR-S015](../../errores/en/THOR-S015.md)).

| Recommendation | Level | In Thor |
|---|---|---|
| Read `.value` only in ViewModel methods (Thor only) | Strongly recommended | `build` runs once, on the server |
| One top-level `final` instance per ViewModel (Thor only) | Strongly recommended | the browser starts with those instances ([THOR-S012](../../errores/en/THOR-S012.md)) |

## Extensibility and testing

The Repository is an interface, and a middleware hands it to each request, like a `Provider` in Flutter. Switching backends, or using a fake one in a test, means changing the middleware's argument.

```dart
final production = provideOrders(HttpOrdersRepository(OrdersService(apiBase)));
final inTests = provideOrders(FakeOrdersRepository());
```

Neither the View nor the ViewModel knows which one it gets. The middleware is written in [Data layer](data-layer.md) and the tests in [Testing](testing.md).

| Recommendation | Level | In Thor |
|---|---|---|
| Dependency injection | Strongly recommended | a middleware and a `ContextKey` |
| Abstract repositories | Strongly recommended | `abstract interface class OrdersRepository` and one implementation per environment |
| A declarative router | Recommended | `ThorRouter`: each page is a URL ([Routes and navigation](navigation.md)) |
| Naming by component | Recommended | `OrdersPage`, `OrdersViewModel`, `OrdersRepository`, `OrdersService` |
| Test each layer alone and all together | Strongly recommended | `test` for ViewModels and repositories; the test client for pages |
| Use fakes | Strongly recommended | `provideOrders(FakeOrdersRepository())` or `MockTransport` for the backend |

## Authorization

This recommendation doesn't exist in Flutter, because there the code runs on the user's device. In Thor, `load`, actions, and the functions of a `query` or a `command` run on the server, and any user who opens the page can call them.

```dart
Future<List<Order>> myOrders() async {
  final context = PageRequest.current.context;
  if (context.maybeGet(currentUser) == null) {
    throw const HttpError(StatusCode.unauthorized);
  }
  return context.get(ordersKey).list();
}
```

> **Caution:** Authorize inside every `load`, action, `query` and `command`, with the request's user ([Session and security](session-and-security.md)).

## Next steps

:::cards
- [Project structure](project-structure.md) — which folder each file goes in
- [Interface layer](ui-layer.md) — the View and the two halves of the ViewModel
- [Data layer](data-layer.md) — repositories, services and injection
:::
