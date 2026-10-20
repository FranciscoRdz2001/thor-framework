# Capa de datos

Escribe un servicio que habla con el backend y un repositorio que convierte sus respuestas en modelos y en errores de página. Los dos corren en el servidor.

:::flutter Flutter: Repository + Service + `Result` · Thor: interfaz + `ThorHttpClient` + excepciones

:::layers orders-data
:::

## Modelos

Un modelo es una clase inmutable. Si llega a un ViewModel (`ThorState`) por una `query`, viaja como JSON y necesita `toJson` y `fromJson`.

```dart
// lib/modules/orders/data/order.dart
enum OrderStatus { open, shipped, cancelled }

class Order {
  const Order({required this.id, required this.title, required this.status});

  factory Order.fromJson(Map<String, Object?> json) => Order(
    id: json['id']! as String,
    title: json['title']! as String,
    status: OrderStatus.values.byName(json['status']! as String),
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'status': status.name,
  };

  final String id;
  final String title;
  final OrderStatus status;

  bool get isOpen => status == OrderStatus.open;
}
```

El modelo no conoce las pantallas: lo que solo importa a una vista, como un texto o un color, lo calcula el ViewModel.

## El servicio

Un servicio envuelve un backend, sin estado ni reglas: hace la petición y devuelve la respuesta. `ThorHttpClient` aplica el plazo, reutiliza las conexiones y convierte un fallo de red en un `502` o un `504`.

```dart
// lib/modules/orders/data/orders_service.dart
import 'package:thor_server/thor_server.dart';

// One client for the whole backend: it keeps its connections open.
final _http = ThorHttpClient(
  headers: {HttpHeader.accept: 'application/json'},
  timeout: const Duration(seconds: 5),
);

class OrdersService {
  OrdersService(this._base);

  final Uri _base;

  Future<ThorHttpResponse> fetchAll() => _http.get(_base.resolve('orders'));

  Future<ThorHttpResponse> fetch(String id) =>
      _http.get(_base.resolve('orders/$id'));

  Future<ThorHttpResponse> cancel(String id) =>
      _http.post(_base.resolve('orders/$id/cancel'));
}
```

## El repositorio

El repositorio es la fuente de verdad de un tipo de dato. Es una interfaz con una implementación HTTP, para poder cambiar de backend o usar uno falso.

```dart
// lib/modules/orders/data/orders_repository.dart
import 'package:thor_server/thor_server.dart';

import 'order.dart';
import 'orders_service.dart';

abstract interface class OrdersRepository {
  Future<List<Order>> list();

  /// Throws [NotFound] when there is no such order.
  Future<Order> find(String id);
  Future<void> cancel(String id);
}

class HttpOrdersRepository implements OrdersRepository {
  HttpOrdersRepository(this._service);

  final OrdersService _service;

  @override
  Future<List<Order>> list() async {
    final json = _check(await _service.fetchAll()).json()! as List<Object?>;
    return [for (final j in json) Order.fromJson(j! as Map<String, Object?>)];
  }

  @override
  Future<Order> find(String id) async {
    final response = _check(await _service.fetch(id));
    return Order.fromJson(response.json()! as Map<String, Object?>);
  }

  @override
  Future<void> cancel(String id) async {
    final response = await _service.cancel(id);
    if (response.statusCode == StatusCode.conflict) {
      throw const HttpError(
        StatusCode.conflict,
        'The order has already shipped.',
      );
    }
    _check(response);
  }

  // The backend's errors become what a page's load can throw.
  // A 401 stays a 401: where to sign in is the middleware's decision.
  ThorHttpResponse _check(ThorHttpResponse response) {
    if (response.statusCode == StatusCode.notFound) throw const NotFound();
    if (response.statusCode == StatusCode.unauthorized) {
      throw const HttpError(StatusCode.unauthorized);
    }
    return response.ensureOk();
  }
}
```

Los repositorios no se conocen entre sí: si una pantalla necesita datos de dos, los combina su ViewModel.

## Errores del backend a la página

El repositorio traduce cada respuesta del backend a un error que Thor sabe mostrar. No devuelve un `Result`: lanza una excepción. Nunca lanza un `Redirect`; adónde va un usuario sin sesión lo decide el middleware.

| El backend responde | El repositorio lanza | El usuario ve |
|---|---|---|
| 404 | `NotFound()` | la página 404; en un `command`, `errorKind` es `client` |
| 401 | `HttpError(401)` | la página 401, o el inicio de sesión con `signInOn401` ([Sesión y seguridad](sesion-y-seguridad.md)); en un `command`, `errorKind` es `unauthorized` |
| 409 o 422 | `HttpError(409, 'text')` | ese texto, en la página de error o en `error` |
| 5xx o sin respuesta | nada: `ThorHttpClient` lanza un `504` (plazo) o un `502` (red, o un 5xx con `ensureOk()`) | la página de error; en un `command`, `errorKind` es `server`, `timeout` o `network` |

Un formulario inválido no es asunto del repositorio: la acción lo rechaza con `values.fail('text', field)` ([Formularios](formularios.md)).

> **Diferencia con Flutter:** En Flutter, el patrón `Result` obliga a tratar cada fallo en el ViewModel. En Thor, lo que lanza `load` decide la página, y un `command` nunca lanza: `run` devuelve `null` y `error` dice por qué ([Patrones](patrones.md)). El texto de una `Exception` corriente nunca llega al usuario; solo el de un `HttpError`.

## Inyección de dependencias

Un middleware guarda el repositorio en la petición con un `ContextKey`, y quien lo necesita lo lee. Cumple el papel de `Provider` en Flutter.

```dart
// lib/modules/orders/data/orders_scope.dart
import 'package:thor_server/thor_server.dart';

import 'order.dart';
import 'orders_repository.dart';

// personal: false: the same for every user, so pages can still be cached.
const ordersKey = ContextKey<OrdersRepository>('orders', personal: false);

Middleware provideOrders(OrdersRepository repository) => (request, next) {
  request.context.set(ordersKey, repository);
  return next();
};

// A ViewModel's query and command take no request: they reach it with
// PageRequest.current.
OrdersRepository get _repository => PageRequest.current.context.get(ordersKey);

Future<List<Order>> listOrders() => _repository.list();

Future<void> cancelOrder(String id) => _repository.cancel(id);
```

```dart
// lib/modules/orders/orders_routes.dart
import 'package:thor_ui/router.dart';

import 'data/orders_repository.dart';
import 'data/orders_scope.dart';
import 'data/orders_service.dart';
import 'pages/order_page.dart';
import 'pages/orders_page.dart';

final ordersRoute = ThorRoute('/orders', const OrdersPage());
final orderRoute = ThorRoute('/orders/:id', const OrderPage());

final ordersModule = Group(
  middleware: [
    provideOrders(
      HttpOrdersRepository(
        OrdersService(Uri.parse('https://api.example.com/')),
      ),
    ),
  ],
  children: [ordersRoute, orderRoute],
);
```

Una página lee el repositorio con `request.context.get(ordersKey)` y un ViewModel con `listOrders`. Ninguno de los dos sabe si es el real. Los valores personales del contexto están en [Sesión y seguridad](sesion-y-seguridad.md).

## Probar la capa

Con un backend falso, ninguna petición sale a la red.

```dart
// test/orders_test.dart
import 'package:test/test.dart';
import 'package:thor_test/thor_test.dart';

void main() {
  test('a 404 from the backend is a 404 page', () async {
    final fake = MockTransport.fixtures({
      'GET https://api.example.com/orders/9': ThorHttpFixture.json({}, status: 404),
    });
    final app = appHandler().client(httpOverrides: fake);
    expect(await app.get('/orders/9'), hasStatus(404));
  });
}
```

`MockTransport` responde las peticiones de `ThorHttpClient`; una petición sin respuesta preparada hace fallar la prueba ([Pruebas](pruebas.md#backends-falsos)).

## Siguientes pasos

:::cards
- [Capa de interfaz](capa-ui.md) — el ViewModel que llama a `listOrders`
- [Patrones](patrones.md) — commands, errores y cachés por etiqueta
- [Servidor y acciones](red-y-servidor.md) — `load`, acciones y caché de páginas
:::
