/// The UI layer of the orders example, for `capa-ui.md` (`:::layers
/// orders-ui`): the View, the ViewModel that lives in the browser and the
/// half of the ViewModel that lives on the server (`ThorPage.load` and its
/// actions). Every Thor name is real: `ThorState`, `query`, `commandWith`,
/// `QueryBuilder`, `Watch.list`, `ThorPage`, `PageRequest`, `NotFound`,
/// `Redirect`, `flash`.
library;

import 'layer_set.dart';

/// The View, the browser's ViewModel and the server's ViewModel.
final ordersUiLayers = LayerSet([
  LayerSpec(
    title: 'View',
    kind: (t) => t.layersOrdersViewKind,
    description: (t) => t.layersOrdersUiViewDescription,
    flutterCode: r'''
class OrdersView extends StatelessWidget {
  const OrdersView({super.key, required this.viewModel});

  final OrdersViewModel viewModel;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: viewModel.load,
    builder: (context, child) {
      if (viewModel.load.running) {
        return const Center(child: CircularProgressIndicator());
      }
      if (viewModel.load.error) return const Text('Could not load');
      return child!;
    },
    child: ListenableBuilder(
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
    ),
  );
}''',
    thorCode: r'''
class OrdersView extends StatelessWidget {
  const OrdersView({super.key, required this.viewModel});

  final OrdersViewModel viewModel;

  @override
  Widget build(BuildContext context) => QueryBuilder<List<Order>>(
    query: viewModel.list,
    builder: (context, snapshot) {
      if (snapshot.hasError) return QueryError(viewModel.list);
      if (!snapshot.hasData) return const Skeleton(height: 120);
      return Watch.list(
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
    },
  );
}''',
  ),
  LayerSpec(
    title: 'ViewModel',
    kind: (t) => t.layersOrdersViewModelKind,
    description: (t) => t.layersOrdersUiViewModelDescription,
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

final orders = OrdersViewModel();''',
  ),
  LayerSpec(
    title: 'Page',
    kind: (t) => t.layersOrdersPageKind,
    description: (t) => t.layersOrdersPageDescription,
    flutterCode: r'''
// The router builds the ViewModel and starts its load.
GoRoute(
  path: '/orders/:id',
  builder: (context, state) => OrderView(
    viewModel: OrderViewModel(
      ordersRepository: context.read(),
      id: state.pathParameters['id']!,
    )..load.execute(),
  ),
)''',
    thorCode: r'''
class OrderPage extends ThorPage<Order> {
  const OrderPage();

  // Runs on the server before the page is rendered. find() throws NotFound
  // when there is no such order: the page is the 404.
  @override
  Future<Order> load(PageRequest request) =>
      request.context.get(ordersKey).find(request.param('id'));

  // An action: a form posts to it, with or without JavaScript.
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
}''',
  ),
]);
