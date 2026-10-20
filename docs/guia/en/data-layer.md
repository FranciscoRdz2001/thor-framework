# Data layer

Write a Service that talks to the backend and a Repository that turns its responses into models and page errors. Both run on the server.

:::flutter Flutter: Repository + Service + `Result` · Thor: interface + `ThorHttpClient` + exceptions

:::layers orders-data
:::

## Models

A model is an immutable class. If it reaches a ViewModel (`ThorState`) through a `query`, it travels as JSON and needs `toJson` and `fromJson`.

```dart
// lib/modules/orders/data/order.dart
enum OrderStatus { open, shipped, cancelled }

class Order {
  const Order({required this.id, required this.title, required this.status});

  factory Order.fromJson(Map<String, Object?> json) => Order(
    id: json['id']! as String,
    title: json['title']! as String,
    status: OrderStatus.values.byName(json['status']! as String),
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'status': status.name,
  };

  final String id;
  final String title;
  final OrderStatus status;

  bool get isOpen => status == OrderStatus.open;
}
```

The model knows nothing about screens: whatever only matters to a View, such as a label or a color, is computed by the ViewModel.

## The Service

A Service wraps a backend, with no state or rules: it makes the request and returns the response. `ThorHttpClient` applies the timeout, reuses connections, and turns a network failure into a `502` or a `504`.

```dart
// lib/modules/orders/data/orders_service.dart
import 'package:thor_server/thor_server.dart';

// One client for the whole backend: it keeps its connections open.
final _http = ThorHttpClient(
  headers: {HttpHeader.accept: 'application/json'},
  timeout: const Duration(seconds: 5),
);

class OrdersService {
  OrdersService(this._base);

  final Uri _base;

  Future<ThorHttpResponse> fetchAll() => _http.get(_base.resolve('orders'));

  Future<ThorHttpResponse> fetch(String id) =>
      _http.get(_base.resolve('orders/$id'));

  Future<ThorHttpResponse> cancel(String id) =>
      _http.post(_base.resolve('orders/$id/cancel'));
}
```

## The Repository

The Repository is the source of truth for one type of data. It is an interface with an HTTP implementation, so you can switch backends or use a fake one.

```dart
// lib/modules/orders/data/orders_repository.dart
import 'package:thor_server/thor_server.dart';

import 'order.dart';
import 'orders_service.dart';

abstract interface class OrdersRepository {
  Future<List<Order>> list();

  /// Throws [NotFound] when there is no such order.
  Future<Order> find(String id);
  Future<void> cancel(String id);
}

class HttpOrdersRepository implements OrdersRepository {
  HttpOrdersRepository(this._service);

  final OrdersService _service;

  @override
  Future<List<Order>> list() async {
    final json = _check(await _service.fetchAll()).json()! as List<Object?>;
    return [for (final j in json) Order.fromJson(j! as Map<String, Object?>)];
  }

  @override
  Future<Order> find(String id) async {
    final response = _check(await _service.fetch(id));
    return Order.fromJson(response.json()! as Map<String, Object?>);
  }

  @override
  Future<void> cancel(String id) async {
    final response = await _service.cancel(id);
    if (response.statusCode == StatusCode.conflict) {
      throw const HttpError(
        StatusCode.conflict,
        'The order has already shipped.',
      );
    }
    _check(response);
  }

  // The backend's errors become what a page's load can throw.
  // A 401 stays a 401: where to sign in is the middleware's decision.
  ThorHttpResponse _check(ThorHttpResponse response) {
    if (response.statusCode == StatusCode.notFound) throw const NotFound();
    if (response.statusCode == StatusCode.unauthorized) {
      throw const HttpError(StatusCode.unauthorized);
    }
    return response.ensureOk();
  }
}
```

Repositories don't know about each other: if a screen needs data from two of them, its ViewModel combines it.

## Backend errors to the page

The Repository translates each backend response into an error Thor knows how to show. It doesn't return a `Result`: it throws an exception. It never throws a `Redirect`; where a signed-out user goes is the middleware's decision.

| The backend responds | The Repository throws | The user sees |
|---|---|---|
| 404 | `NotFound()` | the 404 page; in a `command`, `errorKind` is `client` |
| 401 | `HttpError(401)` | the 401 page, or sign-in with `signInOn401` ([Session and security](session-and-security.md)); in a `command`, `errorKind` is `unauthorized` |
| 409 or 422 | `HttpError(409, 'text')` | that text, on the error page or in `error` |
| 5xx or no response | nothing: `ThorHttpClient` throws a `504` (timeout) or a `502` (network, or a 5xx with `ensureOk()`) | the error page; in a `command`, `errorKind` is `server`, `timeout` or `network` |

An invalid form is not the Repository's business: the action rejects it with `values.fail('text', field)` ([Forms](forms.md)).

> **Difference from Flutter:** In Flutter, the `Result` pattern forces you to handle every failure in the ViewModel. In Thor, what `load` throws decides the page, and a `command` never throws: `run` returns `null` and `error` says why ([Patterns](patterns.md)). The text of an ordinary `Exception` never reaches the user; only that of an `HttpError` does.

## Dependency injection

A middleware stores the Repository on the request with a `ContextKey`, and whoever needs it reads it. It plays the role of `Provider` in Flutter.

```dart
// lib/modules/orders/data/orders_scope.dart
import 'package:thor_server/thor_server.dart';

import 'order.dart';
import 'orders_repository.dart';

// personal: false: the same for every user, so pages can still be cached.
const ordersKey = ContextKey<OrdersRepository>('orders', personal: false);

Middleware provideOrders(OrdersRepository repository) => (request, next) {
  request.context.set(ordersKey, repository);
  return next();
};

// A ViewModel's query and command take no request: they reach it with
// PageRequest.current.
OrdersRepository get _repository => PageRequest.current.context.get(ordersKey);

Future<List<Order>> listOrders() => _repository.list();

Future<void> cancelOrder(String id) => _repository.cancel(id);
```

```dart
// lib/modules/orders/orders_routes.dart
import 'package:thor_ui/router.dart';

import 'data/orders_repository.dart';
import 'data/orders_scope.dart';
import 'data/orders_service.dart';
import 'pages/order_page.dart';
import 'pages/orders_page.dart';

final ordersRoute = ThorRoute('/orders', const OrdersPage());
final orderRoute = ThorRoute('/orders/:id', const OrderPage());

final ordersModule = Group(
  middleware: [
    provideOrders(
      HttpOrdersRepository(
        OrdersService(Uri.parse('https://api.example.com/')),
      ),
    ),
  ],
  children: [ordersRoute, orderRoute],
);
```

A page reads the Repository with `request.context.get(ordersKey)` and a ViewModel with `listOrders`. Neither knows whether it's the real one. Personal context values are covered in [Session and security](session-and-security.md).

## Testing the layer

With a fake backend, no request goes out to the network.

```dart
// test/orders_test.dart
import 'package:test/test.dart';
import 'package:thor_test/thor_test.dart';

void main() {
  test('a 404 from the backend is a 404 page', () async {
    final fake = MockTransport.fixtures({
      'GET https://api.example.com/orders/9': ThorHttpFixture.json({}, status: 404),
    });
    final app = appHandler().client(httpOverrides: fake);
    expect(await app.get('/orders/9'), hasStatus(404));
  });
}
```

`MockTransport` answers `ThorHttpClient`'s requests; a request with no prepared response fails the test ([Testing](testing.md#fake-backends)).

## Next steps

:::cards
- [Interface layer](ui-layer.md) — the ViewModel that calls `listOrders`
- [Patterns](patterns.md) — commands, errors and tag-based caches
- [Server and actions](server-and-actions.md) — `load`, actions and page caching
:::
