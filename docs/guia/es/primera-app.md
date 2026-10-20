# Tu primera app

Construye una tienda pequeña: un catálogo, un carrito que cambia sin recargar, un formulario de pedido y una página por producto.

Necesitas el comando `thor` ([Instalación](instalacion.md)). Cada bloque de Dart es un archivo completo y empieza con su ruta; cuando un archivo reaparece, las líneas en verde son las que cambian.

:::steps diff
### Crea la app

```bash
thor create store
cd store
thor dev
```

Abre `http://localhost:4300` y deja `thor dev` en marcha: la página se actualiza cada vez que guardas un archivo.

### Escribe la página

Escribe el catálogo, una tarjeta por producto y la página de inicio con widgets de Flutter. `.when(medium: …)` cambia un valor según el tamaño de la pantalla.

:::example start-store-grid
:::

> **Nota:** Borra el contador de ejemplo de `thor create`: `counter_card.dart` y `counter_view_model.dart` en `lib/modules/home/`, y `counter_view_model_test.dart` en `test/modules/home/`.

El marco (`AppShell`) completa el título de cada página con `titleTemplate`, donde `%s` es el título de la página.

```dart
// lib/shell/app_shell.dart
import 'package:store/modules/home/home_routes.dart';
import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

class AppShell extends ThorLayout<void> {
  const AppShell();

  @override
  PageMeta meta(PageState<void> state) =>
      const PageMeta(title: 'Store', titleTemplate: '%s · Store');

  @override
  Widget build(BuildContext context, PageState<void> state, Widget child) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            role: SemanticsRole.header,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0x1F000000))),
              ),
              child: Link(
                href: homeRoute.link(),
                child: const Text(
                  'Store',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Semantics(
              role: SemanticsRole.main,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 960),
                child: child,
              ),
            ),
          ),
          const Semantics(
            role: SemanticsRole.contentInfo,
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Built with Thor',
                style: TextStyle(fontSize: 13, color: Color(0x99000000)),
              ),
            ),
          ),
        ],
      );
}
```

```dart
// lib/core/catalog.dart
class Product {
  const Product(this.id, this.name, this.price, this.description);
  final int id;
  final String name;
  final double price;
  final String description;
}

const products = [
  Product(1, 'Cold brew', 4.5, 'With cinnamon and brown sugar.'),
  Product(2, 'Croissant', 3, 'Freshly baked, all butter.'),
  Product(3, 'Hot chocolate', 5, 'Single-origin cacao.'),
];

Product? findProduct(int id) {
  for (final p in products) {
    if (p.id == id) return p;
  }
  return null;
}
```

```dart
// lib/modules/home/widgets/product_card.dart
import 'package:store/core/catalog.dart';
import 'package:thor_ui/intl.dart';
import 'package:thor_ui/thor_ui.dart';

class ProductCard extends StatelessWidget {
  const ProductCard(this.product, {super.key});
  final Product product;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Semantics(
            headingLevel: 2,
            child: Text(product.name, style: theme.textTheme.titleLarge),
          ),
          Text(
            LocaleFormat.of(context).currency(product.price, name: 'USD'),
          ),
        ],
      ),
    );
  }
}
```

`Theme.of(context)` funciona como en Flutter y sigue el modo oscuro.

```dart
// lib/modules/home/pages/home_page.dart
import 'package:store/core/catalog.dart';
import 'package:store/core/widgets/page_title.dart';
import 'package:store/modules/home/widgets/product_card.dart';
import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

class HomePage extends ThorPage<void> {
  const HomePage();

  @override
  PageMeta meta(PageState<void> state) =>
      const PageMeta(description: 'Coffee, bread and chocolate.');

  @override
  Widget build(BuildContext context, PageState<void> state) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 24,
    children: [
      const PageTitle('Store'),
      Grid(
        layout: const GridLayout(columns: 1, gap: 16)
            .when(medium: const GridLayout(columns: 3)),
        children: [for (final p in products) ProductCard(p)],
      ),
    ],
  );
}
```

### Agrega un carrito

El carrito cambia sin recargar, así que vive en un ViewModel (`ThorState`): campos de estado `state(valor)` y métodos que los leen o los cambian.

```bash
thor add state Cart
```

:::example start-cart
:::

```dart
// lib/core/state/cart_view_model.dart
import 'package:thor_ui/thor_ui.dart';

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
```

```dart
// lib/modules/home/widgets/product_card.dart
import 'package:store/core/catalog.dart';
import 'package:store/core/state/cart_view_model.dart';
import 'package:thor_ui/intl.dart';
import 'package:thor_ui/thor_ui.dart';

class ProductCard extends StatelessWidget {
  const ProductCard(this.product, {super.key});
  final Product product;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Semantics(
            headingLevel: 2,
            child: Text(product.name, style: theme.textTheme.titleLarge),
          ),
          Text(
            LocaleFormat.of(context).currency(product.price, name: 'USD'),
          ),
          FilledButton(
            onPressed: cart.add.withArg(product.price),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
```

`withArg` fija el argumento del método para cada botón. `Watch` marca lo que cambia: el servidor renderiza el valor inicial y el navegador actualiza solo ese texto o ese botón.

```dart
// lib/modules/home/pages/home_page.dart
import 'package:store/core/catalog.dart';
import 'package:store/core/state/cart_view_model.dart';
import 'package:store/core/widgets/page_title.dart';
import 'package:store/modules/home/widgets/product_card.dart';
import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

class HomePage extends ThorPage<void> {
  const HomePage();

  @override
  PageMeta meta(PageState<void> state) =>
      const PageMeta(description: 'Coffee, bread and chocolate.');

  @override
  Widget build(BuildContext context, PageState<void> state) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 24,
    children: [
      const PageTitle('Store'),
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
      Grid(
        layout: const GridLayout(columns: 1, gap: 16)
            .when(medium: const GridLayout(columns: 3)),
        children: [for (final p in products) ProductCard(p)],
      ),
    ],
  );
}
```

### Valida un formulario

Cada regla de un campo es un `Validator` que el navegador comprueba. `onSubmit` se ejecuta solo cuando todos los campos son válidos, sin recargar la página.

```bash
thor add state Checkout
```

:::example start-checkout
:::

```dart
// lib/core/state/checkout_view_model.dart
import 'package:thor_ui/thor_ui.dart';

class CheckoutViewModel extends ThorState {
  final name = state('');
  final placed = state('');

  void setName(String value) => name.value = value;

  void placeOrder() => placed.value = name.value;

  String message() =>
      placed.value.isEmpty ? '' : 'Thanks, ${placed.value}: it will be ready.';
}

final checkout = CheckoutViewModel();
```

```dart
// lib/modules/home/widgets/order_form.dart
import 'package:store/core/state/checkout_view_model.dart';
import 'package:thor_ui/thor_ui.dart';

class OrderForm extends StatelessWidget {
  const OrderForm({super.key});

  @override
  Widget build(BuildContext context) => Form(
    onSubmit: checkout.placeOrder,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        TextFormField(
          name: 'name',
          onChanged: checkout.setName,
          autofillHints: const [AutofillHints.name],
          decoration: const InputDecoration(labelText: 'Name for pickup'),
          validators: const [Validator.required('Add a name for the order.')],
        ),
        FilledButton(
          buttonType: ButtonType.submit,
          child: const Text('Place order'),
        ),
        Watch(checkout.message),
      ],
    ),
  );
}
```

```dart
// lib/modules/home/pages/home_page.dart
import 'package:store/core/catalog.dart';
import 'package:store/core/state/cart_view_model.dart';
import 'package:store/core/widgets/page_title.dart';
import 'package:store/modules/home/widgets/order_form.dart';
import 'package:store/modules/home/widgets/product_card.dart';
import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

class HomePage extends ThorPage<void> {
  const HomePage();

  @override
  PageMeta meta(PageState<void> state) =>
      const PageMeta(description: 'Coffee, bread and chocolate.');

  @override
  Widget build(BuildContext context, PageState<void> state) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 24,
    children: [
      const PageTitle('Store'),
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
      Grid(
        layout: const GridLayout(columns: 1, gap: 16)
            .when(medium: const GridLayout(columns: 3)),
        children: [for (final p in products) ProductCard(p)],
      ),
      const OrderForm(),
    ],
  );
}
```

### Crea una página por producto

`thor add page` crea el módulo y agrega su ruta a `lib/router.dart`. El parámetro `:id:int` solo acepta enteros: `/product/abc` responde 404.

```bash
thor add page /product/:id:int
```

`load` se ejecuta en el servidor antes de renderizar y su resultado llega a `build` y a `meta` como `state.data`; `NotFound` responde 404 con la página de error. Los enlaces salen de la ruta (`productByIdRoute.link(...)`), así que la URL se define en un solo lugar.

```dart
// lib/shell/app_error_page.dart
import 'package:store/core/widgets/page_title.dart';
import 'package:store/modules/home/home_routes.dart';
import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

class AppErrorPage extends ErrorPage {
  const AppErrorPage();

  @override
  Widget build(BuildContext context, ErrorState state) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: 12,
    children: [
      PageTitle(state.message ?? 'Something went wrong.'),
      Link(href: homeRoute.link(), child: const Text('Back to the store')),
    ],
  );
}
```

```dart
// lib/modules/home/widgets/product_card.dart
import 'package:store/core/catalog.dart';
import 'package:store/core/state/cart_view_model.dart';
import 'package:store/modules/product/product_routes.dart';
import 'package:thor_ui/intl.dart';
import 'package:thor_ui/thor_ui.dart';

class ProductCard extends StatelessWidget {
  const ProductCard(this.product, {super.key});
  final Product product;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Semantics(
            headingLevel: 2,
            child: Text(product.name, style: theme.textTheme.titleLarge),
          ),
          Text(
            LocaleFormat.of(context).currency(product.price, name: 'USD'),
          ),
          FilledButton(
            onPressed: cart.add.withArg(product.price),
            child: const Text('Add'),
          ),
          Link(
            href: productByIdRoute.link({'id': product.id}),
            child: const Text('See details'),
          ),
        ],
      ),
    );
  }
}
```

```dart
// lib/modules/product/pages/product_by_id_page.dart
import 'package:store/core/catalog.dart';
import 'package:store/core/state/cart_view_model.dart';
import 'package:store/modules/home/home_routes.dart';
import 'package:thor_ui/intl.dart';
import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

class ProductByIdPage extends ThorPage<Product> {
  const ProductByIdPage();

  @override
  Product load(PageRequest request) =>
      findProduct(request.paramInt('id')) ??
      (throw const NotFound("That product doesn't exist."));

  @override
  PageMeta meta(PageState<Product> state) => PageMeta(
    title: state.data.name,
    description: state.data.description,
  );

  @override
  Widget build(BuildContext context, PageState<Product> state) {
    final product = state.data;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        Semantics(
          headingLevel: 1,
          child: Text(product.name, style: Theme.of(context).textTheme.headlineMedium),
        ),
        Text(product.description),
        FilledButton(
          onPressed: cart.add.withArg(product.price),
          child: Text(
            'Add for ${LocaleFormat.of(context).currency(product.price, name: 'USD')}',
          ),
        ),
        Link(href: homeRoute.link(), child: const Text('← Back')),
      ],
    );
  }
}
```

### Escribe una prueba

`test/app_test.dart` levanta el servidor en memoria y cada prueba pide una página como lo haría el navegador ([Pruebas](pruebas.md)).

```dart
// test/app_test.dart
import 'package:store/app.dart';
import 'package:test/test.dart';
import 'package:thor_test/thor_test.dart';
import 'package:thor_ui/router.dart';

void main() {
  final handler = RouteHandler(routes: app.routes, renderer: appRenderer());

  test('the home page lists the three products and the order form', () async {
    final page = await handler.client().get('/');
    expect(page.status, 200);
    for (final name in ['Cold brew', 'Croissant', 'Hot chocolate']) {
      expect(page.text, contains(name));
    }
    expect(page.text, contains('Name for pickup'));
  });

  test('a product page has its name and the cart button', () async {
    final page = await handler.client().get('/product/2');
    expect(page.status, 200);
    expect(page.text, contains('Croissant'));
    expect(page.text, contains(RegExp(r'Add for .*3[.,]00')));
  });

  test('a missing product is a 404 with its message', () async {
    final page = await handler.client().get('/product/99');
    expect(page.status, 404);
    expect(page.text, contains("That product doesn't exist."));
  });

  test('the home page has the title and description of its meta', () async {
    final page = (await handler.client().get('/')).text;
    expect(page, contains('<title>Store</title>'));
    expect(page, contains('Coffee, bread and chocolate.'));
  });
}
```

```bash
thor test
```

### Compila para producción

Detén `thor dev` con Ctrl-C. `thor build` compila el servidor nativo en `build/server` y los archivos públicos en `build/public`; `thor preview` lo sirve en `http://localhost:4400`.

```bash
thor build
thor preview
```
:::

## Lo que construiste

- Widgets de Flutter renderizados como HTML y CSS.
- Un ViewModel que actualiza el carrito con `Watch` y `onPressed`.
- Un formulario que el navegador valida antes de enviarlo.
- Rutas por módulo, datos cargados en el servidor, una página 404 y metadatos.
- Pruebas que piden las páginas como lo haría el navegador.

## Siguientes pasos

:::cards
- [Interactividad](interactividad.md) — ViewModels, `Watch` y callbacks en detalle
- [Leer datos](leer-datos.md) — `load`, repositorios y errores de la página
- [Compilar y publicar](publicar.md) — publicar el servidor o un sitio estático
:::
