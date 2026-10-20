import 'package:thor_ui/thor_ui.dart';

import '../../../core/repositories/orders_repository.dart';

/// `/orders`: a query whose argument is a class. `next` moves
/// the page with `copyWith`; `same` sets an equal value (nothing to ask);
/// `search` starts again from page 1.
class OrdersListState extends ThorState {
  final found = queryWith(
    ordersRepository.search,
    arg: const OrdersFilter(tags: ['a', 'b']),
  );

  void next() =>
      found.setArg(found.arg.value.copyWith(page: found.arg.value.page + 1));
  void same() => found.setArg(found.arg.value.copyWith());
  void search(String q) =>
      found.setArg(found.arg.value.copyWith(q: q, page: 1));

  String foundText() =>
      'found: ${(found.data.value ?? const <String>[]).join(',')}';
  String argText() =>
      'arg: ${found.arg.value.q}|${found.arg.value.page}|${found.arg.value.tags.join(',')}';
}

/// The state.
final ordersList = OrdersListState();
