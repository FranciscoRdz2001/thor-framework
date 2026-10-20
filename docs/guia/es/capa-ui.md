# Capa de interfaz

Escribe la vista como un widget y el ViewModel en dos mitades: un `ThorState` para lo que cambia en el navegador, y `load` y las acciones para el servidor.

:::flutter Flutter: View + ViewModel (`ChangeNotifier`) · Thor: widget + `ThorState` + `load` y acciones

:::layers orders-ui
:::

## La vista

La vista muestra lo que expone el ViewModel y le pasa los eventos del usuario. Solo contiene lógica de presentación: un `if` para mostrar u ocultar, el layout, una animación.

```dart
// lib/modules/orders/widgets/orders_view.dart
import 'package:thor_ui/thor_ui.dart';

import '../state/orders_view_model.dart';

class OrdersView extends StatelessWidget {
  const OrdersView({super.key, required this.viewModel});

  final OrdersViewModel viewModel;

  @override
  Widget build(BuildContext context) => Watch.list(
    viewModel.rows,
    itemKey: viewModel.keyOf,
    each: (row) => ListTile(
      title: row.text(viewModel.title),
      trailing: TextButton(
        onPressed: viewModel.cancel.run.withArg(row.key),
        child: const Text('Cancel'),
      ),
    ),
  );
}
```

> **Diferencia con Flutter:** Una vista es siempre un `StatelessWidget`; no hay `setState`. Lo que la vista recuerda vive en el ViewModel, y cada callback es un método del ViewModel, nunca un closure.

## El ViewModel

Un ViewModel (`ThorState`) es una clase con cuatro tipos de miembro: queries, commands, campos de estado y valores calculados. Cumple el papel del `ChangeNotifier` de Flutter.

```dart
// lib/modules/orders/state/orders_view_model.dart
import 'package:thor_ui/thor_ui.dart';

import '../data/order.dart';
import '../data/orders_scope.dart';

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

final orders = OrdersViewModel();
```

| Necesitas | Escribes | En Flutter |
|---|---|---|
| Leer datos del servidor | `query(fn)`, `queryWith(fn, arg: x)` | `Command0` y el repositorio |
| Escribir y actualizar la lista | `commandWith(fn, invalidates: …)` | `Command1` |
| Recordar lo que cambia el usuario | `state(value)` | un campo y `notifyListeners()` |
| Un valor calculado | `derived(() => …)` | un getter |
| Saber si espera o falló | `cancel.pending`, `cancel.error`, `list.loading` | `command.running`, `command.error` |

La instancia es una variable `final` de nivel superior, y la vista la recibe por el constructor: `OrdersView(viewModel: orders)`. `invalidates:` recibe el propio ViewModel porque el campo se declara antes de que exista `this`. Los tipos que caben en un ViewModel están en [Estado](estado.md).

> **Diferencia con Flutter:** El `State<T>` de Flutter pertenece a un widget y desaparece con él. Un ViewModel pertenece a la pantalla y lo comparten varias vistas, por eso nunca se declara dentro de un widget.

### Carga, error y datos

`QueryBuilder` es el `FutureBuilder` de una query: el servidor renderiza una variante por estado y el navegador cambia entre ellas.

```dart
// lib/modules/orders/widgets/orders_panel.dart
import 'package:thor_ui/thor_ui.dart';

import '../state/orders_view_model.dart';
import 'orders_view.dart';

class OrdersPanel extends StatelessWidget {
  const OrdersPanel({super.key});

  @override
  Widget build(BuildContext context) => QueryBuilder(
    query: orders.list,
    builder: (context, snapshot) {
      if (snapshot.hasError) return QueryError(orders.list);
      if (!snapshot.hasData) return const Skeleton(height: 120);
      return OrdersView(viewModel: orders);
    },
  );
}
```

> **Diferencia con Flutter:** `snapshot.error` es el `String` que el servidor dejó pasar, no un `Object`. Como el `builder` se ejecuta en el servidor, `QueryError(orders.list)` muestra ese mensaje y lo actualiza en el navegador.

## Carga de la página y acciones

La otra mitad del ViewModel está en la página, en el servidor: `load` trae los datos antes de renderizar y una acción recibe un formulario. Lanzar `NotFound` o `Redirect` decide qué página se ve.

```dart
// lib/modules/orders/pages/order_page.dart
import 'package:thor_server/thor_server.dart';
import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

import '../data/order.dart';
import '../data/orders_scope.dart';
import '../orders_routes.dart';

class OrderPage extends ThorPage<Order> {
  const OrderPage();

  // Runs on the server before the page is rendered.
  @override
  Future<Order> load(PageRequest request) =>
      request.context.get(ordersKey).find(request.param('id'));

  // A form posts here, with or without JavaScript.
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
}
```

Si el pedido no existe, el repositorio lanza `NotFound` y la página muestra el 404 sin código adicional en `load`. El repositorio llega a la petición por un middleware ([Capa de datos](capa-datos.md#inyección-de-dependencias)).

## Elegir dónde se cargan los datos

| Quieres | Usa | Sin JavaScript |
|---|---|---|
| Los datos de la primera carga, el 404 o una redirección | `load` | sí |
| Volver a pedir sin recargar, o un dato que no hace falta al renderizar | `query`, `queryWith` o `query(fn, ssr: false)` | no |
| Cambiar algo y actualizar la lista | `command` con `invalidates:` | no |
| Un formulario con validación | una acción (`onPost`, `onValid`) | sí |

Si la página debe funcionar sin JavaScript, la acción es la base y el `command` la mejora ([Servidor y acciones](red-y-servidor.md)).

> **Cuidado:** `load`, las acciones y las funciones de una `query` o un `command` corren en el servidor, y cualquier usuario que abra la página puede llamarlos. Autoriza dentro de cada uno con el usuario de la petición; en una query o un command, la petición es `PageRequest.current`.

## Siguientes pasos

:::cards
- [Capa de datos](capa-datos.md) — de dónde sale `listOrders`
- [Patrones](patrones.md) — commands, errores y estado optimista
- [Estado](estado.md) — listas, controladores y lo que cabe en un ViewModel
:::
