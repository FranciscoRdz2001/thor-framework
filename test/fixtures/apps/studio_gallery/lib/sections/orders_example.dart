// The orders example of the architecture pages: one feature, written layer
// by layer in Flutter and in Thor. Every Thor name is real (`ThorState`,
// `query`, `commandWith`, `QueryBuilder`, `ThorHttpClient`, `ContextKey`).
import 'package:thor_studio/thor_studio.dart';

/// View, ViewModel, Repository and Service of the orders screen, with what
/// each layer is for and its code in both frameworks.
const ordersLayers = [
  StudioLayer(
    title: 'View',
    kind: 'Widget',
    description:
        'Muestra el estado y avisa lo que hace la persona. No tiene lógica: '
        'lee el ViewModel y llama a sus métodos.',
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
              onPressed: () => viewModel.cancel(order.id),
              child: const Text('Cancel'),
            ),
          ),
      ],
    ),
  );
}''',
    thorCode: r'''
class OrdersView extends StatelessWidget {
  const OrdersView({super.key});

  @override
  Widget build(BuildContext context) => QueryBuilder<List<Order>>(
    query: orders.list,
    builder: (context, snapshot) => !snapshot.hasData
        ? const Skeleton(height: 120)
        : Watch.list(
            orders.ids,
            itemKey: orders.key,
            each: (row) => row.text(orders.title),
          ),
  );
}''',
  ),
  StudioLayer(
    title: 'ViewModel',
    kind: 'ThorState',
    description:
        'Guarda el estado de la pantalla y las acciones que la vista puede '
        'pedir. En Thor es un ThorState: una query lee, un command cambia.',
    flutterCode: r'''
class OrdersViewModel extends ChangeNotifier {
  OrdersViewModel(this._repository);

  final OrdersRepository _repository;

  List<Order> orders = const [];

  Future<void> load() async {
    orders = await _repository.list();
    notifyListeners();
  }

  Future<void> cancel(String id) async {
    await _repository.cancel(id);
    await load();
  }
}''',
    thorCode: r'''
class OrdersState extends ThorState {
  final list = query(ordersRepository.list);

  final cancel = commandWith(
    ordersRepository.cancel,
    invalidates: (OrdersState s) => [s.list],
  );

  List<String> ids() => [
    for (final o in list.data.value ?? const <Order>[]) o.id,
  ];

  String key(String id) => id;

  String title(String id) =>
      list.data.value!.firstWhere((o) => o.id == id).title;
}

final orders = OrdersState();''',
  ),
  StudioLayer(
    title: 'Repository',
    kind: 'Clase',
    description:
        'La fuente única de los pedidos: le pide al servicio, convierte la '
        'respuesta en objetos Order y esconde de dónde vienen los datos.',
    flutterCode: r'''
class OrdersRepository {
  OrdersRepository(this._service);

  final OrdersService _service;

  Future<List<Order>> list() async {
    final json = await _service.fetch() as List;
    return [for (final j in json) Order.fromJson(j as Map<String, Object?>)];
  }

  Future<void> cancel(String id) => _service.cancel(id);
}''',
    thorCode: r'''
class OrdersRepository {
  // The service is the one this request's middleware injected.
  OrdersService get _service =>
      PageRequest.current.context.get(ordersServiceKey);

  Future<List<Order>> list() async {
    final json = await _service.fetch() as List;
    return [for (final j in json) Order.fromJson(j as Map<String, Object?>)];
  }

  Future<void> cancel(String id) => _service.cancel(id);
}

final ordersRepository = OrdersRepository();''',
  ),
  StudioLayer(
    title: 'Service',
    kind: 'Cliente HTTP',
    description:
        'Habla con el backend y nada más. En Thor usa ThorHttpClient en el '
        'servidor y un middleware lo deja en la petición con un ContextKey.',
    flutterCode: r'''
class OrdersService {
  OrdersService(this._client, this._base);

  final http.Client _client;
  final Uri _base;

  Future<Object?> fetch() async {
    final response = await _client.get(_base.resolve('orders'));
    return jsonDecode(response.body);
  }

  Future<void> cancel(String id) async {
    await _client.post(_base.resolve('orders/$id/cancel'));
  }
}''',
    thorCode: r'''
final _http = ThorHttpClient(headers: {'accept': 'application/json'});

class OrdersService {
  OrdersService(this._base);

  final Uri _base;

  Future<Object?> fetch() => _http.getJson(_base.resolve('orders'));

  Future<void> cancel(String id) async {
    (await _http.post(_base.resolve('orders/$id/cancel'))).ensureOk();
  }
}

const ordersServiceKey = ContextKey<OrdersService>(
  'ordersService',
  personal: false,
);''',
  ),
];
