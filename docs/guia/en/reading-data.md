# Reading data

Load a page's data on the server with its `load` method. The browser receives the complete page, with no loading state and no JavaScript.

:::flutter Flutter: `FutureBuilder` and a repository · Thor: `ThorPage<T>.load` and `state.data`

## The page's data

The page's type is whatever its `load` returns: `ThorPage<List<Order>>` loads a list, and `build` receives it in `state.data`. What `load` throws decides the response.

:::bench bench-load
:::

:::flutter
@flutter
```dart no-check
class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key, required this.ordersRepository});

  final OrdersRepository ordersRepository;

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  late final Future<Result<List<Order>>> _orders;

  @override
  void initState() {
    super.initState();
    _orders = widget.ordersRepository.list();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: _orders,
    builder: (context, snapshot) {
      final result = snapshot.data;
      if (snapshot.hasError || result is Error<List<Order>>) {
        return const ErrorView();
      }
      if (result is! Ok<List<Order>>) return const CircularProgressIndicator();
      return OrderList(orders: result.value);
    },
  );
}
```
@thor
```dart {5-6,10}
class OrdersPage extends ThorPage<List<Order>> {
  const OrdersPage();

  @override
  Future<List<Order>> load(PageRequest request) =>
      request.context.get(ordersKey).list();

  @override
  Widget build(BuildContext context, PageState<List<Order>> state) =>
      OrdersList(state.data);
}
```
:::

`load` runs on the server on every request and can use any Dart package, such as a database client or an HTTP client with credentials. A page without data is `ThorPage<void>` and doesn't define `load`.

> **Difference from Flutter:** There is no loading state to draw: the server waits for `load` and responds with the complete page. Slow data that shouldn't delay the page is sent afterwards ([Server and actions](server-and-actions.md)).

## One item per URL

The route parameter is read with `request.param('id')`, or already converted to an integer with `request.paramInt('id')` on a `/orders/:id:int` route ([Routes and navigation](navigation.md#typed-parameters)). If there is nothing to show, throw `NotFound`.

```dart
class OrderPage extends ThorPage<Order> {
  const OrderPage();

  // find() throws NotFound when there is no such order.
  @override
  Future<Order> load(PageRequest request) =>
      request.context.get(ordersKey).find(request.paramInt('id'));

  @override
  Widget build(BuildContext context, PageState<Order> state) =>
      Text(state.data.title);
}
```

| `load` throws | The request ends in |
|---|---|
| `NotFound()` | the group's error page, with status 404 |
| `HttpError(503, 'message')` | the error page, with that status and that message |
| `Redirect(url)` | another page |
| any other exception | a 500 that doesn't show the message |

## A Repository between the page and the backend

The page doesn't call the backend: it asks a Repository in its module for the data, which returns typed models. A middleware places it in the request context with a `ContextKey`.

```dart
abstract interface class OrdersRepository {
  Future<List<Order>> list();
  Future<Order> find(int id);
  Future<void> cancel(int id);
}

const ordersKey = ContextKey<OrdersRepository>('orders', personal: false);

Middleware provideOrders(OrdersRepository repository) => (request, next) {
  request.context.set(ordersKey, repository);
  return next();
};
```

`personal: false` says the value is the same for every user, so the page can be served from the cache. In a test, it's enough to put a fake Repository in the context, with no server or network ([Testing](testing.md)). How to write the Repository is covered in [Data layer](data-layer.md).

## Filters and sorting in the URL

What the user picks in a list (search, sort, filter, page) goes in the query: it survives a reload, can be shared and works without JavaScript. `load` reads the query and the server filters.

```dart
@override
Future<List<Order>> load(PageRequest request) async {
  final status = request.queryParameters['status'];
  final orders = await request.context.get(ordersKey).list();
  return [
    for (final o in orders)
      if (status == null || o.status.name == status) o,
  ];
}
```

Pagination and validated sorting (`request.listQuery`, `Pagination`) are in [Server and actions](server-and-actions.md).

## Next steps

:::cards
- [Server and actions](server-and-actions.md) — actions, caching and data that arrives later
- [Data layer](data-layer.md) — Repositories and Services
- [Interactivity](interactivity.md) — what changes without reloading the page
:::
