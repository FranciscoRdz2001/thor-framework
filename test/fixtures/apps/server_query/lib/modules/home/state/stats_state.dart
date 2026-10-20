import 'package:thor_ui/thor_ui.dart';

import '../../../core/repositories/stats_repository.dart';

/// The public home's state: a query anyone may call (no middleware).
class StatsState extends ThorState {
  final orders = query(statsRepository.orderCount);

  String label() => 'Pedidos en el sistema: ${orders.data.value ?? 0}';
}

/// The home's state.
final stats = StatsState();
