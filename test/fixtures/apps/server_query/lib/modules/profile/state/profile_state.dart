import 'package:thor_ui/thor_ui.dart';

import '../../../core/models/order.dart';
import '../../../core/repositories/profile_repository.dart';

/// The profile page's state: server state (`query`) next to browser state
/// (`state`). The repository's methods run on the server only (sqlite3);
/// the browser gets their JSON and asks again with `refresh`.
class ProfileState extends ThorState {
  /// The profile (server).
  final info = query(profileRepository.info);

  /// A page of orders (server), by page number.
  final orders = queryWith(profileRepository.orders, arg: 0);

  /// A query that fails on the server.
  final ledger = query(profileRepository.ledger);

  /// Whether the edit panel is open (browser only).
  final editing = state(false);

  String name() => info.data.value?.name ?? '';
  String email() => info.data.value?.email ?? '';
  String visits() => 'Lecturas del perfil: ${info.data.value?.visits ?? 0}';
  bool busy() => info.loading.value;

  List<Order> rows() => orders.data.value ?? const [];
  String orderKey(Order o) => '${o.id}';
  String orderText(Order o) => '${o.item} · \$${o.total}';
  String pageLabel() => 'Página ${orders.arg.value + 1}';
  bool firstPage() => orders.arg.value == 0;
  bool ordersBusy() => orders.loading.value;
  void nextPage() => orders.setArg(orders.arg.value + 1);
  void previousPage() => orders.setArg(orders.arg.value - 1);

  bool ledgerFailed() => ledger.error.value != null;
  String ledgerText() => ledger.error.value ?? '${ledger.data.value ?? 0}';

  bool isEditing() => editing.value;
  void toggleEditing() => editing.value = !editing.value;
}

/// The profile page's state.
final profile = ProfileState();
