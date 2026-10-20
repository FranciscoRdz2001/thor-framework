# Rutas y navegación

Declara las rutas de la app en una tabla de Dart, `ThorRouter`: cada `ThorRoute` une una URL con una página, y los enlaces salen de la propia ruta.

:::flutter Flutter: `GoRouter`, `GoRoute`, `ShellRoute`, `context.go` · Thor: `ThorRouter`, `ThorRoute`, `Group`, `Link`

## La tabla de rutas

Cada ruta es una variable de nivel superior y la tabla las reúne en grupos: uno para el marco de la app y uno por módulo.

:::example routes-tree
:::

:::flutter
Cada pantalla es un documento con su URL, que el servidor renderiza en cada petición.
@flutter
```dart no-check
final router = GoRouter(
  routes: [
    GoRoute(path: '/about', builder: (context, state) => const AboutPage()),
    GoRoute(
      path: '/orders/:id',
      builder: (context, state) =>
          OrderPage(id: int.parse(state.pathParameters['id']!)),
    ),
  ],
);
```
@thor
```dart
final aboutRoute = ThorRoute('/about', const AboutPage());
final orderRoute = ThorRoute('/orders/:id:int', const OrderPage());

final ThorRouter router = ThorRouter([
  Group(children: [aboutRoute, orderRoute]),
]);

class AboutPage extends ThorPage<void> {
  const AboutPage();

  @override
  Widget build(BuildContext context, PageState<void> state) =>
      const Text('Roasting coffee since 1998.');
}
```
:::

> **Importante:** La tabla guarda una sola instancia `const` de cada página, compartida por todas las peticiones. Los datos de una petición van en `load` ([Leer datos](leer-datos.md)), nunca en campos de la página.

## Parámetros con tipo

Un segmento `:id:int` solo acepta enteros, y cualquier otro valor responde 404. Construir un enlace con un parámetro que falta o de otro tipo es un error en tu código, no un 404 en producción.

| En la ruta | Acepta | Se lee con |
|---|---|---|
| `/about` | un segmento fijo | — |
| `/product/:slug` | cualquier segmento | `request.param('slug')` |
| `/orders/:id:int` | solo enteros | `request.paramInt('id')` |
| `/docs/*rest` | el resto de la URL, al final | `request.param('rest')` |

```dart
// in OrderPage
@override
Future<Order> load(PageRequest request) =>
    request.context.get(ordersKey).find(request.paramInt('id'));
```

La query (`/orders?status=open`) se lee con `request.queryParameters['status']`.

## Enlaces

Un enlace a una página de la app sale de su `ThorRoute`, en lugar de un `context.go(...)` dentro de un `onPressed`. Si la URL cambia, cambia en un solo lugar.

:::bench bench-route-link
:::

`Link(current: true)` marca el enlace de la página actual (`aria-current="page"`) en la navegación de un layout.

:::example routes-nav
:::

El `href` es un `RouteUrl`: lo que devuelve `route.link()`, `const RouteUrl('#pricing')` o `RouteUrl.external('https://example.com')` (solo `http`, `https`, `mailto` y `tel`). Un `String` suelto no se acepta en `Link(href:)`, `Redirect` ni `PageMeta(canonical:)`. `.withQuery({'q': 'x'})` y `.withFragment('id')` derivan una URL nueva.

El navegador carga por adelantado la página a la que apunta el puntero, así que el clic la muestra casi al instante. `Link(prefetch: false)` lo desactiva en un enlace que cambia algo, como `/logout`.

Un enlace `#contact` desplaza la página hasta el widget con `Semantics(identifier: 'contact')`.

## Grupos, layouts y módulos

Un `Group` reúne rutas que comparten un `layout`, un `middleware` y las páginas de `error` y `notFound`. Los grupos se anidan, y cada módulo declara el suyo en `lib/modules/<module>/<module>_routes.dart`.

:::flutter
@flutter
```dart no-check
ShellRoute(
  builder: (context, state, child) => SalesShell(child: child),
  routes: [
    GoRoute(path: '/sales/orders', builder: (context, state) => const OrdersPage()),
  ],
)
```
@thor
```dart
final ordersRoute = ThorRoute('/sales/orders', const OrdersPage());

final salesModule = Group(
  prefix: '/sales',
  layout: const SalesLayout(),
  middleware: [requireRole(Role.sales)],
  error: const SalesErrorPage(),
  children: [ordersRoute],
);
```
:::

`prefix:` declara la parte de la URL que atiende el grupo, con su layout y su página 404; las rutas de adentro escriben la URL completa. Un layout es un `ThorLayout<T>` que recibe en `child` la página ya construida.

```dart
class SalesLayout extends ThorLayout<void> {
  const SalesLayout();

  @override
  Widget build(BuildContext context, PageState<void> state, Widget child) =>
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [Nav(), Expanded(child: child)],
      );
}
```

Una pantalla sin marco, como el inicio de sesión, va en un grupo aparte.

### Páginas de error

Una página de error extiende `ErrorPage`. Responde la del grupo más cercano a la ruta que falló, y `notFound:` atiende las URLs sin ruta.

```dart
class AppErrorPage extends ErrorPage {
  const AppErrorPage();

  @override
  Widget build(BuildContext context, ErrorState state) => Column(
    spacing: 12,
    children: [
      Text(state.status == StatusCode.notFound ? 'Page not found' : 'Something went wrong'),
      Link(href: RouteUrl('/'), child: const Text('Back to home')),
    ],
  );
}
```

## Middleware

Un middleware envuelve cada petición a las rutas de su grupo: continúa con `next()`, corta con un `Redirect` o un `HttpError`, o cambia la respuesta. Reemplaza al `redirect` de `GoRouter`, por grupo de rutas.

:::bench bench-middleware
:::

El middleware guarda valores en `request.context` bajo una `ContextKey` (`const currentUser = ContextKey<User>('user');`), y los `load` y las acciones de las rutas del grupo los leen con su tipo: `request.context.get(currentUser)`. Los middleware se ejecutan de afuera hacia adentro y de izquierda a derecha, en cada petición, también cuando la página sale de la caché.

### Redirigir

`load`, una acción o un middleware pueden lanzar:

```dart
throw Redirect(homeRoute.link());               // 303
throw Redirect.found(loginRoute.link());        // 302, temporary
throw Redirect.permanent(newRoute.link());      // 308
throw const NotFound();                         // 404: the error page
throw const HttpError(StatusCode.forbidden, 'You do not have access.');
```

Thor normaliza cualquier destino: `//other.site` queda como `/other.site`.

## Navegar desde un ViewModel

Un método de un ViewModel (`ThorState`) navega con `PageNavigator`. La URL se construye en el servidor y llega al método con `withArg`.

:::flutter
@flutter
```dart no-check
TextButton(
  onPressed: () => context.go('/orders/${order.id}'),
  child: const Text('See order'),
)
// and to go back:
context.pop();
```
@thor
```dart
class OrdersViewModel extends ThorState {
  void open(String url) => PageNavigator.go(url);
  void close() => PageNavigator.pop(fallback: '/orders');
}

final orders = OrdersViewModel();

TextButton(
  onPressed: orders.open.withArg(orderRoute.link({'id': order.id})),
  child: const Text('See order'),
)
```
:::

### Volver y recargar

`PageNavigator.pop` equivale al botón atrás; si no hay una página de la app a la que volver, carga `fallback` (por defecto `/`). `PageNavigator.canPop()` indica si hay una, y `PageNavigator.reload()` recarga la página.

> **Diferencia con Flutter:** No hay `Navigator.push`: cada pantalla es un documento. `PageNavigator.go` carga la URL nueva como un enlace, y el botón atrás del navegador funciona igual que en cualquier sitio.

## Endpoints y eventos

`ThorRoute.resource` responde algo que no es una página, como JSON o bytes, y `ThorRoute.stream` abre un flujo de eventos del servidor. El middleware de sus grupos se aplica igual; solo atienden `GET` y `HEAD`.

```dart
final itemRoute = ThorRoute<void>.resource(
  '/api/items/:id:int',
  (request) async => ThorResponse.json(
    await items.find(request.paramInt('id')),
    maxAge: const Duration(minutes: 1),
  ),
);
```

Un ViewModel recibe el flujo con `events(url)` ([Datos en vivo](datos-vivos.md)).

## Siguientes pasos

:::cards
- [Leer datos](leer-datos.md) — el `load` de una página y sus repositorios
- [Servidor y acciones](red-y-servidor.md) — acciones, caché y datos que llegan después
- [Formularios](formularios.md) — controles, validación y acciones
:::
