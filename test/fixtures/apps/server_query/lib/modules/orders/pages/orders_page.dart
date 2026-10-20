import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

import '../../../core/repositories/orders_repository.dart';
import '../state/orders_state.dart';

/// What `/orders` loads: one page of rows and the list it came from.
class OrdersData {
  const OrdersData(this.rows, this.list, this.total);

  final List<Order> rows;
  final ListQuery list;
  final int total;
}

/// `/orders`: the list state lives in the URL (`listQuery`,
/// `Pagination`), an action keeps the query, and a query takes a class as
/// its argument.
class OrdersListPage extends ThorPage<OrdersData> {
  const OrdersListPage();

  @override
  PageMeta meta(PageState<OrdersData> state) =>
      const PageMeta(title: 'Pedidos');

  @override
  Future<OrdersData> load(PageRequest request) async {
    final list = request.listQuery(
      pageSize: 10,
      sorts: const {'customer', 'total'},
      defaultSort: 'customer',
      filters: const {'status'},
    );
    final r = ordersRepository.page(
      q: list.q,
      status: list.filter('status'),
      sort: list.sort,
      descending: list.descending,
      offset: list.offset,
      limit: list.limit,
    );
    return OrdersData(r.rows, list.within(r.total), r.total);
  }

  Future<ActionResult?> touch(PageRequest request) async {
    ordersRepository.touched.add(request.uri.query);
    return null;
  }

  Future<ActionResult?> fail(PageRequest request) async =>
      const ActionResult.fail(422, 'no');

  @override
  Widget build(BuildContext context, PageState<OrdersData> state) {
    final data = state.data;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Form(
          formMethod: FormMethod.get,
          child: Row(
            spacing: 8,
            children: [
              TextField(
                name: 'q',
                initialValue: data.list.q,
                decoration: const InputDecoration(labelText: 'Buscar'),
              ),
              FilledButton(
                buttonType: ButtonType.submit,
                onPressed: () {},
                child: const Text('Buscar'),
              ),
            ],
          ),
        ),
        Text('total: ${data.total} page: ${data.list.page}'),
        for (final o in data.rows) Text('${o.id} ${o.customer} ${o.status}'),
        Pagination(list: data.list, total: data.total),
        Form(
          onPost: touch,
          child: Row(
            spacing: 8,
            children: [
              const TextField(
                name: 'note',
                decoration: InputDecoration(labelText: 'Note'),
              ),
              FilledButton(
                buttonType: ButtonType.submit,
                onPressed: () {},
                child: const Text('Guardar'),
              ),
              FilledButton(
                buttonType: ButtonType.submit,
                onPressed: null,
                onPost: fail,
                child: const Text('Fallar'),
              ),
            ],
          ),
        ),
        Row(
          spacing: 8,
          children: [
            OutlinedButton(
              onPressed: ordersList.next,
              child: const Text('Siguiente'),
            ),
            OutlinedButton(
              onPressed: ordersList.same,
              child: const Text('Igual'),
            ),
            OutlinedButton(
              onPressed: ordersList.search.withArg('ñ'),
              child: const Text('Buscar ñ'),
            ),
          ],
        ),
        Watch(ordersList.foundText),
        Watch(ordersList.argText),
      ],
    );
  }
}
