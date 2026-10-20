# Paquetes de pub

Elige dónde usar cada paquete: en el servidor funciona cualquiera de la VM de Dart; en un ViewModel, que corre en el navegador, solo algunos.

## Qué funciona dónde

En `load`, las acciones y el middleware puedes usar cualquier paquete que corra en la VM de Dart. Dentro de un ViewModel (`ThorState`) la lista es corta:

| Paquete | En un ViewModel | Alternativa |
|---|---|---|
| `collection` | parcial: `firstWhereOrNull`, `lastWhereOrNull`, `sorted`, `sortedBy`, `groupBy`, `groupListsBy`, `mapIndexed`, `whereIndexed`, `forEachIndexed`, `sum`, `max`, `min` | el resto, en el servidor |
| `intl` | solo los mensajes de [Idiomas](idiomas.md) | `NumberFormat` y `DateFormat` en `load` o `build` |
| `json_serializable` | si el ViewModel no usa la clase generada | una clase simple con `fromJson` y `toJson` |
| `http`, `dio` | no | una `query` o un `command` ([Estado](estado.md#datos-del-servidor)) |
| `freezed`, `equatable` | no | campos finales; compara lo que importa |
| `uuid`, `crypto`, `markdown`, `yaml`, `path`, `sqlite3` | no | en el servidor, detrás de un repositorio o en `load` |

Dart sin paquetes funciona dentro de un ViewModel: un `Map<String, List<Task>>`, ordenar con comparadores, aritmética de `DateTime`, `Timer.periodic`, `jsonEncode`, `jsonDecode` y métodos `async` con `Future.delayed`. La lista completa está en [Estado](estado.md#qué-cabe-en-un-viewmodel). `shelf` y `formz` no hacen falta: Thor tiene su propio `Middleware` y [`FormSchema`](formularios.md#un-esquema-para-el-navegador-y-el-servidor).

## Cuando un paquete no cabe en el ViewModel

La compilación se detiene con [THOR-B012](../../errores/THOR-B012.md) y lista cada uso con su archivo y su línea. El arreglo es uno de tres:

1. **Moverlo al servidor.** El ViewModel no llama al paquete, pero puede pedir su resultado: la función de una `query` o un `command` corre solo en el servidor.
2. **Formatear antes.** Lo que no cambia en el navegador (un precio, una fecha) se formatea en `load` o en `build`. Si el ViewModel muestra un número que cambia, guarda el número y arma el texto con interpolación o con un mensaje ARB.
3. **Pasar datos simples.** Las clases de `json_serializable`, `freezed` o `equatable` sirven en el servidor; al ViewModel llega una clase simple (campos finales, un constructor, `fromJson` y `toJson`) o valores planos.

```dart
// WRONG (THOR-B012): the ViewModel calls the package, which can't run in the browser
class OrdersViewModel extends ThorState {
  final rows = state(<Order>[]);
  Future<void> reload() async => rows.value = await listOrders();
}

// RIGHT: the function runs on the server; the ViewModel gets its JSON
class OrdersViewModel extends ThorState {
  final orders = query(listOrders);
  List<Order> rows() => orders.data.value ?? const [];
  void reload() => orders.refresh();
}
```

Para escribir, lo mismo con `command`: `final add = commandWith(addToCart);` y `onPressed: cart.add.run.withArg(sku)`.

> **Cuidado:** La función de una `query` o un `command` debe autorizar lo que lee o escribe: cualquiera que pase el middleware de la página puede llamarla.

```dart
// WRONG (THOR-B012): freezed's equality inside a ViewModel
final line = state(const OrderLine(productId: 'mug', quantity: 1), …);
bool isOne() => line.value == const OrderLine(productId: 'mug', quantity: 1);

// RIGHT: plain fields; compare what matters
final quantity = state(1);
bool isOne() => quantity.value == 1;
```

## Archivos públicos de un paquete

Un paquete que trae archivos para la web (fuentes, imágenes) los declara en su `pubspec.yaml`. `thor dev`, `thor build` y `thor test` los copian al `web/` de cada app que depende de él, solo lo que falta o cambió.

```yaml
# the package's pubspec.yaml
thor:
  public:
    fonts: fonts # its fonts/ folder → the app's web/fonts/
```

La clave es la carpeta de destino dentro de `web/` y el valor, la carpeta del paquete. La app los usa por su URL (`/fonts/…`), y `thor doctor --fix` los sincroniza. Los archivos propios de la app van directamente en `web/` ([El comando thor](cli.md)).

## Servicios en el contexto

Un cliente HTTP o una base de datos llegan a las páginas por el contexto de la petición, y así las pruebas pueden pasar dobles (`MockClient` de `http`, un `HttpClientAdapter` de `dio`).

```dart
const labServices = ContextKey<LabServices>('services', personal: false);

RouteHandler(
  routes: app.routes,
  renderer: appRenderer(),
  onRequest: (request) => request.context.set(labServices, services),
);

Future<DataModel> load(PageRequest request) async {
  final s = request.context.get(labServices);
  final response = await s.client.get(s.upstream.resolve('products'));
  if (response.statusCode != 200) throw HttpError(StatusCode.badGateway, 'upstream');
  return DataModel.parse(response.body);
}
```

`onRequest` corre después del middleware de la ruta, así que un middleware no ve lo que pone. Lo que necesita un middleware, como la clave de un JWT, se lee del [entorno](sesion-y-seguridad.md#entorno-y-secretos).

## JWT como middleware

Con `dart_jsonwebtoken`, el middleware verifica el token y deja sus datos en el contexto.

```dart no-check
const currentClaims = ContextKey<Claims>('claims');

Future<ThorResponse> requireJwt(PageRequest request, Next next) async {
  final token = request.headers['authorization']?.replaceFirst('Bearer ', '')
      ?? request.cookies['jwt'];
  if (token == null) throw const HttpError(StatusCode.unauthorized, 'no token');
  try {
    final jwt = JWT.verify(token, SecretKey(env.of(AppEnv.jwtSecret)));
    request.context.set(currentClaims, Claims(jwt.subject ?? ''));
  } on JWTException {
    throw const HttpError(StatusCode.unauthorized, 'invalid token');
  }
  return next();
}

final authModule = Group(middleware: [requireJwt], children: [accountRoute]);
```

Una `ContextKey` es personal por omisión: la página que la lee no sale de la caché compartida.

## Markdown

`markdownToHtml` de `package:markdown` corre en el servidor. El HTML resultante no tiene widgets: se inserta con `html.RawText` y se le da estilo con [`Styled(descendants:)`](estilos-avanzados.md).

> **Cuidado:** No insertes HTML escrito por un usuario. Con `markdown`, agrega una sintaxis que escape el HTML del texto de origen.

## Código generado

`json_serializable` y `freezed` funcionan con Thor: `thor dev`, `thor build` y `thor test` corren `build_runner` cuando una biblioteca de `lib/` tiene un `part` generado (`x.g.dart`, `x.freezed.dart`). Guarda los archivos generados en el repositorio, como los mensajes de [Idiomas](idiomas.md).

## Siguientes pasos

:::cards
- [Estado](estado.md) — `query` y `command` para llamar al servidor
- [Capa de datos](capa-datos.md) — servicios y repositorios
- [Sesión y seguridad](sesion-y-seguridad.md) — entorno, secretos y sesión
:::
