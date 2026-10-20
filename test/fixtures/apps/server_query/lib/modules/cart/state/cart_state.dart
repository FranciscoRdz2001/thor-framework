import 'package:thor_ui/thor_ui.dart';

import '../../../core/models/cart_line.dart';
import '../../../core/repositories/cart_repository.dart';

/// The cart page's state: server reads (`query`) and server writes
/// (`command`). A command's answer brings the new values of the page's
/// queries: after `add`, the lines and the total are fresh without a
/// second request.
class CartState extends ThorState {
  /// The first lines of the cart (server), as many as [lines]' argument.
  final lines = queryWith(cartRepository.lines, arg: 2);

  /// The cart's total (server).
  final total = query(cartRepository.total);

  /// Adds a product (server): `onPressed: cart.add.run.withArg('taza')`.
  final add = commandWith(cartRepository.add);

  /// Empties the cart (server): `onPressed: cart.clear.run`.
  final clear = command(cartRepository.clear);

  /// Recounts the total (server): a command that only the total cares about.
  final recount = command(
    cartRepository.total,
    invalidates: (CartState s) => [s.total],
  );

  /// A write that fails on the server.
  final checkout = command(cartRepository.checkout);

  List<CartLine> rows() => lines.data.value ?? const [];
  String lineKey(CartLine l) => l.sku;
  String lineText(CartLine l) => '${l.name} × ${l.qty}';
  String totalText() => 'Total: \$${total.data.value ?? 0}';
  bool showingAll() => lines.arg.value > 2;
  void showAll() => lines.setArg(100);

  bool adding() => add.pending.value;
  String addError() => add.error.value ?? '';
  String lastAdded() {
    final units = add.result.value;
    return units == null ? '' : 'Unidades de ese producto: $units';
  }

  bool clearing() => clear.pending.value;
  String checkoutError() => checkout.error.value ?? '';
}

/// The cart page's state.
final cart = CartState();
