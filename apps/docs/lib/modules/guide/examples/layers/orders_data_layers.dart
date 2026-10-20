/// The data layer of the orders example, for `capa-datos.md` (`:::layers
/// orders-data`): the model, the repository (an interface with an HTTP
/// implementation that maps backend errors), the service, the injection and
/// the tests with a fake. Every Thor name is real: `ThorHttpClient`,
/// `ThorHttpResponse.ensureOk`, `NotFound`, `HttpError`, `ContextKey`,
/// `Middleware`, `PageRequest`.
library;

import 'layer_set.dart';

/// The model, the repository, the service, the injection and the tests of
/// the data layer.
final ordersDataLayers = LayerSet([
  LayerSpec(
    title: 'Model',
    kind: (t) => t.layersOrdersModelKind,
    description: (t) => t.layersOrdersModelDescription,
    flutterCode: r'''
@freezed
class Order with _$Order {
  const factory Order({
    required String id,
    required String title,
    required OrderStatus status,
  }) = _Order;

  factory Order.fromJson(Map<String, Object?> json) => _$OrderFromJson(json);
}''',
    thorCode: r'''
enum OrderStatus { open, shipped, cancelled }

class Order {
  const Order({required this.id, required this.title, required this.status});

  factory Order.fromJson(Map<String, Object?> json) => Order(
    id: json['id']! as String,
    title: json['title']! as String,
    status: OrderStatus.values.byName(json['status']! as String),
  );

  // Immutable; a query's answer travels as JSON, so it needs toJson too.
  Map<String, Object?> toJson() => {'id': id, 'title': title, 'status': status.name};

  final String id;
  final String title;
  final OrderStatus status;

  bool get isOpen => status == OrderStatus.open;
}''',
  ),
  LayerSpec(
    title: 'Repository',
    kind: (t) => t.layersOrdersRepositoryKind,
    description: (t) => t.layersOrdersDataRepositoryDescription,
    flutterCode: r'''
abstract interface class OrdersRepository {
  Future<Result<List<Order>>> list();
  Future<Result<Order>> find(String id);
  Future<Result<void>> cancel(String id);
}

class OrdersRepositoryRemote implements OrdersRepository {
  OrdersRepositoryRemote({required OrdersService ordersService})
    : _ordersService = ordersService;

  final OrdersService _ordersService;

  @override
  Future<Result<Order>> find(String id) async {
    try {
      return await _ordersService.getOrder(id);
    } on Exception catch (e) {
      return Result.error(e);
    }
  }

  // list() and cancel() the same way…
}''',
    thorCode: r'''
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
  Future<Order> find(String id) async {
    final response = _check(await _service.fetch(id));
    return Order.fromJson(response.json()! as Map<String, Object?>);
  }

  @override
  Future<void> cancel(String id) async {
    final response = await _service.cancel(id);
    if (response.statusCode == StatusCode.conflict) {
      throw const HttpError(StatusCode.conflict, 'The order has already shipped.');
    }
    _check(response);
  }

  // list() the same way…

  // The backend's errors become what a page's load can throw. Who is
  // signed in is for the middleware: a 401 stays a 401, never a Redirect.
  ThorHttpResponse _check(ThorHttpResponse response) {
    if (response.statusCode == StatusCode.notFound) throw const NotFound();
    if (response.statusCode == StatusCode.unauthorized) throw const HttpError(StatusCode.unauthorized);
    return response.ensureOk();
  }
}''',
  ),
  LayerSpec(
    title: 'Service',
    kind: (t) => t.layersOrdersServiceKind,
    description: (t) => t.layersOrdersDataServiceDescription,
    flutterCode: r'''
class OrdersService {
  OrdersService(this._client, this._baseUrl);

  final http.Client _client;
  final Uri _baseUrl;

  Future<Result<Order>> getOrder(String id) async {
    try {
      final response = await _client.get(_baseUrl.resolve('orders/$id'));
      if (response.statusCode != 200) {
        return Result.error(const HttpException('Invalid response'));
      }
      final json = jsonDecode(response.body) as Map<String, Object?>;
      return Result.ok(Order.fromJson(json));
    } on Exception catch (e) {
      return Result.error(e);
    }
  }

  // getOrders() and cancelOrder() the same way…
}''',
    thorCode: r'''
// One client for the whole app: it keeps its connections open.
final _http = ThorHttpClient(
  headers: {HttpHeader.accept: 'application/json'},
  timeout: const Duration(seconds: 5),
);

class OrdersService {
  OrdersService(this._base);

  final Uri _base;

  // No state, no rules: it asks and returns the response as it is.
  Future<ThorHttpResponse> fetchAll() => _http.get(_base.resolve('orders'));

  Future<ThorHttpResponse> fetch(String id) =>
      _http.get(_base.resolve('orders/$id'));

  Future<ThorHttpResponse> cancel(String id) =>
      _http.post(_base.resolve('orders/$id/cancel'));
}''',
  ),
  LayerSpec(
    title: 'Injection',
    kind: (t) => t.layersOrdersInjectionKind,
    description: (t) => t.layersOrdersDataInjectionDescription,
    flutterCode: r'''
void main() {
  runApp(
    MultiProvider(
      providers: [
        Provider(create: (_) => OrdersService(http.Client(), apiBase)),
        Provider<OrdersRepository>(
          create: (context) => OrdersRepositoryRemote(
            ordersService: context.read(),
          ),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

// In development: Provider<OrdersRepository>(create: (_) => OrdersRepositoryLocal())''',
    thorCode: r'''
const ordersKey = ContextKey<OrdersRepository>('orders', personal: false);

Middleware provideOrders(OrdersRepository repository) => (request, next) {
  request.context.set(ordersKey, repository);
  return next();
};

// In the route table: the whole group gets the real one…
Group(
  middleware: [provideOrders(HttpOrdersRepository(OrdersService(apiBase)))],
  children: [ordersRoute, orderRoute],
)

// …and a test hands it a fake with the same call:
// provideOrders(FakeOrdersRepository())''',
  ),
  LayerSpec(
    title: 'Tests',
    kind: (t) => t.layersOrdersTestsKind,
    description: (t) => t.layersOrdersDataTestsDescription,
    flutterCode: r'''
void main() {
  test('find returns the order', () async {
    final repository = OrdersRepositoryRemote(
      ordersService: FakeOrdersService(),
    );
    final result = await repository.find('1');
    expect(result, isA<Ok<Order>>());
  });
}''',
    thorCode: r'''
class FakeOrdersRepository implements OrdersRepository {
  @override
  Future<Order> find(String id) async => id == '1'
      ? const Order(id: '1', title: 'Coffee', status: OrderStatus.open)
      : throw const NotFound();

  @override
  Future<List<Order>> list() async => [await find('1')];

  @override
  Future<void> cancel(String id) async {}
}

void main() {
  test('an unknown order is a 404', () async {
    final app = appHandler(repository: FakeOrdersRepository()).client();
    expect(await app.get('/orders/9'), hasStatus(404));
  });
}''',
  ),
]);
