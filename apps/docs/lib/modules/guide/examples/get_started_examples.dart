// ignore_for_file: public_member_api_docs
// The examples of the "Get started" section: `que-es-thor` and `primera-app`.
// Each one is named by its region (`// region: id` … `// endregion`); the
// site shows the region as the example's Dart and renders it for the HTML
// and CSS tabs. The strings inside are the example's own content, like the
// ones of `gallery.dart`.
library;

import 'package:thor_ui/thor_ui.dart';

// region: start-widget-to-web
class WelcomeCard extends StatelessWidget {
  const WelcomeCard({super.key});

  @override
  Widget build(BuildContext context) => Container(
    width: 280,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: ThemeColor.surfaceContainer,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        const Semantics(
          headingLevel: 2,
          child: Text('Hello, Thor', style: ThemeText.titleLarge),
        ),
        const Text('Flutter widgets in, semantic HTML out.'),
        FilledButton(onPressed: () {}, child: const Text('Get started')),
      ],
    ),
  );
}
// endregion

// region: start-store-grid
class StoreCard extends StatelessWidget {
  const StoreCard(this.name, this.price, {super.key});

  final String name;
  final double price;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: ThemeColor.surfaceContainer,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Semantics(
          headingLevel: 2,
          child: Text(name, style: ThemeText.titleLarge),
        ),
        Text('\$${price.toStringAsFixed(2)}'),
      ],
    ),
  );
}

class StoreGrid extends StatelessWidget {
  const StoreGrid({super.key});

  static const products = [
    ('Cold brew', 4.5),
    ('Croissant', 3.0),
    ('Hot chocolate', 5.0),
  ];

  @override
  Widget build(BuildContext context) => Grid(
    layout: const GridLayout(
      columns: 1,
      gap: 16,
    ).when(medium: const GridLayout(columns: 3)),
    children: [for (final (name, price) in products) StoreCard(name, price)],
  );
}
// endregion

// region: start-cart
class CartViewModel extends ThorState {
  final count = state(0);
  final total = state(0.0);

  String label() => count.value == 0
      ? 'Your cart is empty'
      : '${count.value} in the cart · \$${total.value.toStringAsFixed(2)}';

  bool isEmpty() => count.value == 0;

  void add(double price) {
    count.value++;
    total.value += price;
  }

  void clear() {
    count.value = 0;
    total.value = 0;
  }
}

final cart = CartViewModel();

class CartExample extends StatelessWidget {
  const CartExample({super.key});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: 12,
    children: [
      Row(
        spacing: 12,
        children: [
          Watch(cart.label),
          Watch(
            cart.isEmpty,
            builder: (empty) => TextButton(
              onPressed: empty ? null : cart.clear,
              child: const Text('Clear'),
            ),
          ),
        ],
      ),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilledButton(
            onPressed: cart.add.withArg(4.5),
            child: const Text('Add cold brew'),
          ),
          FilledButton(
            onPressed: cart.add.withArg(3.0),
            child: const Text('Add croissant'),
          ),
        ],
      ),
    ],
  );
}
// endregion

// region: start-checkout
class CheckoutViewModel extends ThorState {
  final name = state('');
  final placed = state('');

  void setName(String value) => name.value = value;

  // Runs only when every field is valid; the page doesn't reload.
  void placeOrder() => placed.value = name.value;

  String message() =>
      placed.value.isEmpty ? '' : 'Thanks, ${placed.value}: it will be ready.';
}

final checkout = CheckoutViewModel();

class OrderForm extends StatelessWidget {
  const OrderForm({super.key});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 320,
    child: Form(
      onSubmit: checkout.placeOrder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          TextFormField(
            name: 'name',
            onChanged: checkout.setName,
            autofillHints: const [AutofillHints.name],
            decoration: const InputDecoration(labelText: 'Name for pickup'),
            validators: const [Validator.required('Add a name for the order.')],
          ),
          const FilledButton(
            buttonType: ButtonType.submit,
            child: Text('Place order'),
          ),
          Watch(checkout.message),
        ],
      ),
    ),
  );
}

// endregion
