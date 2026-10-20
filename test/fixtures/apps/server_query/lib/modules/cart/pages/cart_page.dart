import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

import '../state/cart_state.dart';

/// `/cart`: no `load` and no form — queries read the cart and commands
/// change it; each command's answer refreshes the queries.
class CartPage extends ThorPage<void> {
  const CartPage();

  @override
  PageMeta meta(PageState<void> state) => const PageMeta(title: 'Carrito');

  @override
  Widget build(BuildContext context, PageState<void> state) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: 16,
    children: [
      const Text('Carrito', style: TextStyle(fontSize: 24)),
      Row(
        spacing: 12,
        children: [
          FilledButton(
            onPressed: cart.add.run.withArg('taza'),
            child: const Text('Agregar taza'),
          ),
          FilledButton(
            onPressed: cart.add.run.withArg('libreta'),
            child: const Text('Agregar libreta'),
          ),
          FilledButton(
            onPressed: cart.add.run.withArg('pluma'),
            child: const Text('Agregar pluma'),
          ),
          OutlinedButton(
            onPressed: cart.add.run.withArg('termo'),
            child: const Text('Agregar termo'),
          ),
          Watch(
            cart.adding,
            builder: (busy) => Semantics(
              label: 'estado del carrito',
              child: Text(busy ? 'Agregando…' : 'Listo'),
            ),
          ),
        ],
      ),
      Watch(cart.lastAdded),
      Watch(cart.addError, style: const TextStyle(color: Color(0xFFB3261E))),
      Watch.list(
        cart.rows,
        itemKey: cart.lineKey,
        each: (row) => row.text(cart.lineText),
      ),
      Watch(
        cart.showingAll,
        builder: (all) => all
            ? const Text('Todo el carrito')
            : TextButton(
                onPressed: cart.showAll,
                child: const Text('Ver todo'),
              ),
      ),
      Watch(cart.totalText),
      Row(
        spacing: 12,
        children: [
          Watch(
            cart.clearing,
            builder: (busy) => OutlinedButton(
              onPressed: busy ? null : cart.clear.run,
              child: const Text('Vaciar'),
            ),
          ),
          TextButton(onPressed: cart.checkout.run, child: const Text('Pagar')),
          Watch(
            cart.checkoutError,
            style: const TextStyle(color: Color(0xFFB3261E)),
          ),
        ],
      ),
    ],
  );
}
