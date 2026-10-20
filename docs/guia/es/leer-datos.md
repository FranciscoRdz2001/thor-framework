# Leer datos

Carga los datos de una página en el servidor con su método `load`. El navegador recibe la página completa, sin estado de carga ni JavaScript.

:::flutter Flutter: `FutureBuilder` y un repositorio · Thor: `ThorPage<T>.load` y `state.data`

## Los datos de la página

El tipo de la página es lo que devuelve su `load`: `ThorPage<List<Order>>` carga una lista, y `build` la recibe en `state.data`. Lo que lanza `load` decide la respuesta.

:::bench bench-load
:::

:::flutter
@flutter
```dart no-check
class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key, required this.ordersRepository});

  final OrdersRepository ordersRepository;

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  late final Future<Result<List<Order>>> _orders;

  @override
  void initState() {
    super.initState();
    _orders = widget.ordersRepository.list();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: _orders,
    builder: (context, snapshot) {
      final result = snapshot.data;
      if (snapshot.hasError || result is Error<List<Order>>) {
        return const ErrorView();
      }
      if (result is! Ok<List<Order>>) return const CircularProgressIndicator();
      return OrderList(orders: result.value);
    },
  );
}
```
@thor
```dart {5-6,10}
class OrdersPage extends ThorPage<List<Order>> {
  const OrdersPage();

  @override
  Future<List<Order>> load(PageRequest request) =>
      request.context.get(ordersKey).list();

  @override
  Widget build(BuildContext context, PageState<List<Order>> state) =>
      OrdersList(state.data);
}
```
:::

`load` se ejecuta en el servidor en cada petición y puede usar cualquier paquete de Dart, como un cliente de base de datos o uno HTTP con credenciales. Una página sin datos es `ThorPage<void>` y no define `load`.

> **Diferencia con Flutter:** No hay un estado de carga que dibujar: el servidor espera a `load` y responde con la página completa. Un dato lento que no debe retrasar la página se envía después ([Servidor y acciones](red-y-servidor.md)).

## Un dato por URL

El parámetro de la ruta se lee con `request.param('id')`, o ya convertido a entero con `request.paramInt('id')` en una ruta `/orders/:id:int` ([Rutas y navegación](navegacion.md#parámetros-con-tipo)). Si no hay nada que mostrar, lanza `NotFound`.

```dart
class OrderPage extends ThorPage<Order> {
  const OrderPage();

  // find() throws NotFound when there is no such order.
  @override
  Future<Order> load(PageRequest request) =>
      request.context.get(ordersKey).find(request.paramInt('id'));

  @override
  Widget build(BuildContext context, PageState<Order> state) =>
      Text(state.data.title);
}
```

| `load` lanza | La petición termina en |
|---|---|
| `NotFound()` | la página de error del grupo, con estado 404 |
| `HttpError(503, 'message')` | la página de error, con ese estado y ese mensaje |
| `Redirect(url)` | otra página |
| cualquier otra excepción | un 500 que no muestra el mensaje |

## Un repositorio entre la página y el backend

La página no llama al backend: pide los datos a un repositorio de su módulo, que devuelve modelos tipados. Un middleware lo coloca en el contexto de la petición con una `ContextKey`.

```dart
abstract interface class OrdersRepository {
  Future<List<Order>> list();
  Future<Order> find(int id);
  Future<void> cancel(int id);
}

const ordersKey = ContextKey<OrdersRepository>('orders', personal: false);

Middleware provideOrders(OrdersRepository repository) => (request, next) {
  request.context.set(ordersKey, repository);
  return next();
};
```

`personal: false` indica que el valor es el mismo para todos los usuarios, así que la página puede servirse desde la caché. En una prueba basta con poner un repositorio falso en el contexto, sin servidor ni red ([Pruebas](pruebas.md)). Cómo se escribe el repositorio está en [Capa de datos](capa-datos.md).

## Filtros y orden en la URL

Lo que el usuario elige en una lista (búsqueda, orden, filtro, página) va en la query: sobrevive a una recarga, se puede compartir y funciona sin JavaScript. `load` lee la query y el servidor filtra.

```dart
@override
Future<List<Order>> load(PageRequest request) async {
  final status = request.queryParameters['status'];
  final orders = await request.context.get(ordersKey).list();
  return [
    for (final o in orders)
      if (status == null || o.status.name == status) o,
  ];
}
```

La paginación y el orden validado (`request.listQuery`, `Pagination`) están en [Servidor y acciones](red-y-servidor.md).

## Siguientes pasos

:::cards
- [Servidor y acciones](red-y-servidor.md) — acciones, caché y datos que llegan después
- [Capa de datos](capa-datos.md) — repositorios y servicios
- [Interactividad](interactividad.md) — lo que cambia sin recargar la página
:::
