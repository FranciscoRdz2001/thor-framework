/// The layer sets `:::layers id` can show, by id. A set is data: add one by
/// writing a [LayerSet] and registering it here.
library;

import 'package:thor_ui/thor_ui.dart';

import 'layer_set.dart';
import 'orders_data_layers.dart';
import 'orders_ui_layers.dart';

/// Every layer set, by the id the markdown names.
final layerSets = <String, LayerSet>{
  'orders': ordersLayers,
  'orders-ui': ordersUiLayers,
  'orders-data': ordersDataLayers,
};

/// What a `:::layers id` block shows (`DocView`'s `layersEmbed` is
/// `LayersEmbed.new`): the layer diagram of that set, or nothing for an id
/// with no set (the block is dropped).
class LayersEmbed extends StatelessWidget {
  /// The diagram of the layer set [id].
  const LayersEmbed(this.id, {super.key});

  /// Its id in [layerSets].
  final String id;

  @override
  Widget build(BuildContext context) {
    final set = layerSets[id];
    return set == null ? const SizedBox.shrink() : LayersView(set);
  }
}

/// The orders example of the architecture pages: one feature (list the
/// orders, cancel one) written layer by layer in Flutter (the shape of
/// Flutter's app-architecture guide: `ChangeNotifier`, `Command0/Command1`,
/// `ListenableBuilder`, a repository interface with a remote implementation,
/// `Result`) and in Thor. The same classes are in `orders_ui_layers.dart` and
/// `orders_data_layers.dart`: view `OrdersView`, ViewModel `OrdersViewModel`,
/// `OrdersRepository` with `HttpOrdersRepository`, `OrdersService`.
final ordersLayers = LayerSet([
  LayerSpec(
    title: 'View',
    kind: (t) => t.layersOrdersViewKind,
    description: (t) => t.layersOrdersViewDescription,
    flutterCode: r'''
class OrdersView extends StatelessWidget {
  const OrdersView({super.key, required this.viewModel});

  final OrdersViewModel viewModel;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: viewModel,
    builder: (context, _) => ListView(
      children: [
        for (final order in viewModel.orders)
          ListTile(
            title: Text(order.title),
            trailing: TextButton(
              onPressed: () => viewModel.cancel.execute(order.id),
              child: const Text('Cancel'),
            ),
          ),
      ],
    ),
  );
}''',
    thorCode: r'''
class OrdersView extends StatelessWidget {
  const OrdersView({super.key, required this.viewModel});

  final OrdersViewModel viewModel;

  @override
  Widget build(BuildContext context) => Watch.list(
    viewModel.rows,
    itemKey: viewModel.keyOf,
    each: (row) => ListTile(
      title: row.text(viewModel.title),
      trailing: Watch(
        viewModel.cancelling.withArg(row.key),
        builder: (busy) => busy
            ? const Text('Cancelling…')
            : TextButton(
                // A method of the ViewModel, never a closure.
                onPressed: viewModel.cancel.run.withArg(row.key),
                child: const Text('Cancel'),
              ),
      ),
    ),
  );
}''',
  ),
  LayerSpec(
    title: 'ViewModel',
    kind: (t) => t.layersOrdersViewModelKind,
    description: (t) => t.layersOrdersViewModelDescription,
    flutterCode: r'''
class OrdersViewModel extends ChangeNotifier {
  OrdersViewModel({required OrdersRepository ordersRepository})
    : _ordersRepository = ordersRepository {
    load = Command0(_load)..execute();
    cancel = Command1(_cancel);
  }

  final OrdersRepository _ordersRepository;

  late final Command0 load;
  late final Command1<void, String> cancel;

  List<Order> _orders = [];
  List<Order> get orders => _orders;

  Future<Result<void>> _load() async {
    final result = await _ordersRepository.list();
    switch (result) {
      case Ok<List<Order>>():
        _orders = result.value;
        notifyListeners();
        return const Result.ok(null);
      case Error<List<Order>>():
        return Result.error(result.error);
    }
  }

  Future<Result<void>> _cancel(String id) async {
    final result = await _ordersRepository.cancel(id);
    if (result is Error<void>) return result;
    return _load();
  }
}''',
    thorCode: r'''
class OrdersViewModel extends ThorState {
  // Functions of the data layer: they run on the server.
  final list = query(listOrders);

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

final orders = OrdersViewModel();''',
  ),
  LayerSpec(
    title: 'Repository',
    kind: (t) => t.layersOrdersRepositoryKind,
    description: (t) => t.layersOrdersRepositoryDescription,
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
  Future<Result<List<Order>>> list() => _ordersService.getOrders();

  // find() and cancel() the same way…
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
  Future<List<Order>> list() async {
    final json = _check(await _service.fetchAll()).json()! as List<Object?>;
    return [for (final j in json) Order.fromJson(j! as Map<String, Object?>)];
  }

  // find() and cancel() the same way…

  // The backend's errors become what a page's load can throw. Who is
  // signed in is for the middleware: a 401 stays a 401.
  ThorHttpResponse _check(ThorHttpResponse response) {
    if (response.statusCode == StatusCode.notFound) throw const NotFound();
    if (response.statusCode == StatusCode.unauthorized) throw const HttpError(StatusCode.unauthorized);
    return response.ensureOk();
  }
}

// What a ViewModel's query and command call: the repository of this request.
OrdersRepository get _repository => PageRequest.current.context.get(ordersKey);
Future<List<Order>> listOrders() => _repository.list();
Future<void> cancelOrder(String id) => _repository.cancel(id);''',
  ),
  LayerSpec(
    title: 'Service',
    kind: (t) => t.layersOrdersServiceKind,
    description: (t) => t.layersOrdersServiceDescription,
    flutterCode: r'''
class OrdersService {
  OrdersService(this._client, this._baseUrl);

  final http.Client _client;
  final Uri _baseUrl;

  Future<Result<List<Order>>> getOrders() async {
    try {
      final response = await _client.get(_baseUrl.resolve('orders'));
      if (response.statusCode != 200) {
        return Result.error(const HttpException('Invalid response'));
      }
      final json = jsonDecode(response.body) as List<Object?>;
      return Result.ok([
        for (final j in json) Order.fromJson(j! as Map<String, Object?>),
      ]);
    } on Exception catch (e) {
      return Result.error(e);
    }
  }

  // getOrder() and cancelOrder() the same way…
}''',
    thorCode: r'''
// One client for the whole backend: it keeps its connections open.
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
    description: (t) => t.layersOrdersInjectionDescription,
    flutterCode: r'''
MultiProvider(
  providers: [
    Provider(
      create: (_) => OrdersService(http.Client(), Uri.parse('https://api.example.com/')),
    ),
    Provider<OrdersRepository>(
      create: (context) => OrdersRepositoryRemote(ordersService: context.read()),
    ),
  ],
  child: const MyApp(),
)''',
    thorCode: r'''
const ordersKey = ContextKey<OrdersRepository>('orders', personal: false);

// Runs before every page of the group: the repository is in the request.
Middleware provideOrders(OrdersRepository repository) => (request, next) {
  request.context.set(ordersKey, repository);
  return next();
};

// In the route table (see Navigation): no global repository, one per group.
Group(
  middleware: [
    provideOrders(
      HttpOrdersRepository(OrdersService(Uri.parse('https://api.example.com/'))),
    ),
  ],
  children: [ordersRoute],
)''',
  ),
  LayerSpec(
    title: 'Navigation',
    kind: (t) => t.layersOrdersNavigationKind,
    description: (t) => t.layersOrdersNavigationDescription,
    flutterCode: r'''
final router = GoRouter(
  routes: [
    GoRoute(
      path: '/orders',
      builder: (context, state) => OrdersView(
        viewModel: OrdersViewModel(ordersRepository: context.read()),
      ),
    ),
  ],
);

// context.go('/orders')''',
    thorCode: r'''
class OrdersPage extends ThorPage<void> {
  const OrdersPage();

  @override
  Widget build(BuildContext context, PageState<void> state) =>
      OrdersView(viewModel: orders);
}

final ordersRoute = ThorRoute('/orders', const OrdersPage());

final router = ThorRouter([
  Group(
    middleware: [
      provideOrders(
        HttpOrdersRepository(OrdersService(Uri.parse('https://api.example.com/'))),
      ),
    ],
    children: [ordersRoute],
  ),
]);

// Link(href: ordersRoute.link(), child: const Text('Orders'))''',
  ),
  LayerSpec(
    title: 'Tests',
    kind: (t) => t.layersOrdersTestsKind,
    description: (t) => t.layersOrdersTestsDescription,
    flutterCode: r'''
void main() {
  test('the repository returns the orders of the service', () async {
    final repository = OrdersRepositoryRemote(
      ordersService: FakeOrdersService(),
    );
    final result = await repository.list();
    expect(result, isA<Ok<List<Order>>>());
  });

  testWidgets('the view lists the orders', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: OrdersView(
          viewModel: OrdersViewModel(ordersRepository: FakeOrdersRepository()),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Coffee'), findsOneWidget);
  });
}''',
    thorCode: r'''
void main() {
  late ThorTestClient app;

  // A new user per test, with a fake repository in the request.
  setUp(() => app = appHandler(repository: FakeOrdersRepository()).client());

  test('the page lists the orders', () async {
    final page = await app.get('/orders');
    expect(page, hasStatus(200));
    expect(page.text, contains('Coffee'));
  });

  test('cancelling an order refreshes the list', () async {
    await app.get('/orders');
    final cancelled = await app.command(orders.cancel, '1');
    expect(cancelled.queries['OrdersViewModel.list'], isNotEmpty);
  });
}''',
  ),
]);
