# Routes and navigation

Declare the app's routes in a Dart table, `ThorRouter`: each `ThorRoute` ties a URL to a page, and links come from the route itself.

:::flutter Flutter: `GoRouter`, `GoRoute`, `ShellRoute`, `context.go` · Thor: `ThorRouter`, `ThorRoute`, `Group`, `Link`

## The route table

Each route is a top-level variable, and the table gathers them into groups: one for the app's frame and one per module.

:::example routes-tree
:::

:::flutter
Each screen is a document with its own URL, which the server renders on every request.
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

> **Important:** The table holds a single `const` instance of each page, shared by every request. A request's data goes in `load` ([Reading data](reading-data.md)), never in fields of the page.

## Typed parameters

A `:id:int` segment only accepts integers, and any other value responds 404. Building a link with a missing parameter or one of the wrong type is an error in your code, not a 404 in production.

| In the route | Accepts | Read with |
|---|---|---|
| `/about` | a fixed segment | — |
| `/product/:slug` | any segment | `request.param('slug')` |
| `/orders/:id:int` | integers only | `request.paramInt('id')` |
| `/docs/*rest` | the rest of the URL, at the end | `request.param('rest')` |

```dart
// in OrderPage
@override
Future<Order> load(PageRequest request) =>
    request.context.get(ordersKey).find(request.paramInt('id'));
```

The query (`/orders?status=open`) is read with `request.queryParameters['status']`.

## Links

A link to a page of the app comes from its `ThorRoute`, instead of a `context.go(...)` inside an `onPressed`. If the URL changes, it changes in one place.

:::bench bench-route-link
:::

`Link(current: true)` marks the current page's link (`aria-current="page"`) in a layout's navigation.

:::example routes-nav
:::

The `href` is a `RouteUrl`: what `route.link()` returns, `const RouteUrl('#pricing')` or `RouteUrl.external('https://example.com')` (only `http`, `https`, `mailto` and `tel`). A bare `String` is not accepted in `Link(href:)`, `Redirect` or `PageMeta(canonical:)`. `.withQuery({'q': 'x'})` and `.withFragment('id')` derive a new URL.

The browser preloads the page the pointer is on, so the click shows it almost instantly. `Link(prefetch: false)` turns this off for a link that changes something, such as `/logout`.

A `#contact` link scrolls the page to the widget with `Semantics(identifier: 'contact')`.

## Groups, layouts and modules

A `Group` gathers routes that share a `layout`, a `middleware`, and the `error` and `notFound` pages. Groups nest, and each module declares its own in `lib/modules/<module>/<module>_routes.dart`.

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

`prefix:` declares the part of the URL the group serves, with its layout and its 404 page; the routes inside write the full URL. A layout is a `ThorLayout<T>` that receives the already built page in `child`.

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

A page can ask its frame for something. `forLayouts` returns plain objects that the layouts around it read, by type, with `state.fromPage<V>()`, so a layout needs no list of routes.

```dart
class HideFooter {
  const HideFooter();
}

class CheckoutPage extends ThorPage<void> {
  const CheckoutPage();

  @override
  List<Object> forLayouts(PageState<void> state) => [const HideFooter()];

  @override
  Widget build(BuildContext context, PageState<void> state) => const Text('Pay');
}

class ShopLayout extends ThorLayout<void> {
  const ShopLayout();

  @override
  Widget build(BuildContext context, PageState<void> state, Widget child) =>
      Column(
        children: [
          child,
          if (state.fromPage<HideFooter>() == null) const Text('Footer'),
        ],
      );
}
```

A screen without a frame, such as sign-in, goes in a separate group.

### Error pages

An error page extends `ErrorPage`. The one from the group closest to the failing route responds, and `notFound:` handles URLs with no route.

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

A middleware wraps every request to its group's routes: it continues with `next()`, stops with a `Redirect` or an `HttpError`, or changes the response. It replaces `GoRouter`'s `redirect`, per group of routes.

:::bench bench-middleware
:::

Middleware stores values in `request.context` under a `ContextKey` (`const currentUser = ContextKey<User>('user');`), and the `load` methods and actions of the group's routes read them with their type: `request.context.get(currentUser)`. Middleware runs from the outside in and from left to right, on every request, even when the page comes from the cache.

### Redirecting

`load`, an action or a middleware can throw:

```dart
throw Redirect(homeRoute.link());               // 303
throw Redirect.found(loginRoute.link());        // 302, temporary
throw Redirect.moved(oldRoute.link());          // 301, moved for good
throw Redirect.permanent(newRoute.link());      // 308, keeps the method
throw const NotFound();                         // 404: the error page
throw const HttpError(StatusCode.forbidden, 'You do not have access.');
```

Thor normalizes any destination: `//other.site` becomes `/other.site`.

## Navigating from a ViewModel

A ViewModel (`ThorState`) method navigates with `PageNavigator`. The URL is built on the server and reaches the method with `withArg`.

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

### Going back and reloading

`PageNavigator.pop` is the back button; if there is no app page to go back to, it loads `fallback` (`/` by default). `PageNavigator.canPop()` tells whether there is one, and `PageNavigator.reload()` reloads the page.

> **Difference from Flutter:** There is no `Navigator.push`: each screen is a document. `PageNavigator.go` loads the new URL like a link, and the browser's back button works as on any site.

## Endpoints and events

`ThorRoute.resource` responds with something that isn't a page, such as JSON or bytes, and `ThorRoute.stream` opens a stream of server events. Their groups' middleware applies the same way; they only handle `GET` and `HEAD`.

```dart
final itemRoute = ThorRoute<void>.resource(
  '/api/items/:id:int',
  (request) async => ThorResponse.json(
    await items.find(request.paramInt('id')),
    maxAge: const Duration(minutes: 1),
  ),
);
```

A ViewModel receives the stream with `events(url)` ([Live data](live-data.md)).

## Next steps

:::cards
- [Reading data](reading-data.md) — a page's `load` and its repositories
- [Server and actions](server-and-actions.md) — actions, caching and data that arrives later
- [Forms](forms.md) — controls, validation and actions
:::
