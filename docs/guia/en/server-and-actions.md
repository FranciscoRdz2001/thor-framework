# Server and actions

Write what runs on the server around a page: form actions, lists in the URL, caching, deferred data and HTTP calls.

:::flutter Flutter: `FutureBuilder` and `package:http` · Thor: actions, `defer` and `ThorHttpClient`

## Layout data

A `ThorLayout<T>` also has a `load`, which runs in parallel with the page's. The page that needs that data waits for it with `request.parent<T>()`.

```dart
// in CompanyLayout extends ThorLayout<Company>
@override
Future<Company> load(PageRequest request) =>
    companies.current(request.context.get(currentUser));

// in ClientsPage
@override
Future<List<Client>> load(PageRequest request) async {
  final company = await request.parent<Company>();
  return clients.forCompany(company.id);
}
```

In `build`, the same data is `state.dataOf<Company>()`. Whatever a `load` throws ends the request: `NotFound` and `HttpError` show the [error page](navigation.md#error-pages), and `Redirect` goes to another page. What every page needs, such as the signed-in user, belongs in a [middleware](navigation.md#middleware), not in a layout. A `ThorPage<void>` may override `load` too, only for what it does (set a header or a cookie, check something, throw): its result is nothing.

## Form actions

An action is a page method that runs on the server. The form receives it by name, without parentheses, and the compiler checks that it exists and accepts that form.

```dart
class ContactPage extends ThorPage<void> {
  const ContactPage();

  // Runs on the server, only with a valid form.
  Future<ActionResult?> send(PageRequest request, FormValues<ContactForm> values) async {
    await messages.send(values.of(ContactForm.email)); // a String
    return Redirect(thanksRoute.link()); // 303
  }

  @override
  Widget build(BuildContext context, PageState<void> state) =>
      ContactFormView(onValid: send, failed: state.form);
}
```

:::example data-form
:::

The [schema](forms.md#one-schema-for-the-browser-and-the-server) is validated in the browser and again on the server, before `send`. If the submission fails, the page comes back with `422`, what the user typed and each field's message:

:::example data-form-failed
:::

| The action returns | Result |
|---|---|
| `null` | `303` to the same page: reloading does not resubmit |
| `Redirect(url)` | `303` to another page |
| `values.fail('Email already in use', ContactForm.email)` | the page again (`422`), with values and message |
| `ActionResult.success(data)` | the page again, without redirecting |

This is the Post/Redirect/Get pattern, and it works without JavaScript. A page with a single action posts to its own route (`POST /login`); with several, each form carries the name of its own (`POST /ruta?/signIn`). The middleware and the page's guards run before the action, and a form submitted from another site is rejected.

| Case | How |
|---|---|
| an action without fields | `Future<ActionResult?> favorite(PageRequest r)` and `Form(onPost: favorite)` |
| a button that posts to another action | `FilledButton(onPost: delete)` inside the form |
| another page's action | `Form(action: articleRoute.link({'slug': s}), onPost: const ArticlePage().favorite)` |
| dropping the URL query | `Form(preserveQuery: false)`; it is kept by default |

> **Important:** `onPost:` and `onValid:` take a method, not a closure: the server calls the action by name ([THOR-P020](../../errores/en/THOR-P020.md)).

### Actions with arguments

An action receives typed values after the request. The button sets them with `withArg` (`withArgs` if there are several), also without JavaScript.

```dart
Future<ActionResult?> delete(PageRequest request, int id) async {
  await orders.remove(id); // id is an int
  return null;
}

FilledButton(onPost: delete.withArg(o.id), child: const Text('Delete'))
OutlinedButton(onPost: assign.withArgs(o.id, Owner.luis), child: const Text('Assign to Luis'))
```

It accepts up to three arguments of type `int`, `double`, `num`, `String`, `bool`, `DateTime` or an enum. A value of another type, a missing one or an enum value that does not exist responds `400`.

> **Caution:** The browser writes the argument and the user can change it: `withArg` guarantees the type, not the permission. Check in the action that the user may modify that `id` (`orders.remove(id, owner: user.id)`), just as with a URL parameter.

### Asking before submitting

`confirm:` on a button (or on a `Form`) that posts to the server asks for confirmation in a `<dialog>` and only submits if the user accepts.

```dart
FilledButton(
  onPost: delete.withArg(order.id),
  confirm: const ConfirmSpec('Delete the order?', message: 'This cannot be undone.', confirmLabel: 'Delete'),
  child: const Text('Delete'),
)
```

With JavaScript, Esc and Cancel do not submit, and focus starts on Cancel. Without JavaScript the server asks: it responds with a page containing the question and a button that repeats the submission with the same fields, and only then does the action run. A form with files does not support that question and responds `400`.

## A notice on the next page

`Redirect(…).flash('Order deleted')` leaves a message for the next page that renders: a notice shown once, with or without JavaScript.

```dart
Future<ActionResult?> delete(PageRequest request, int id) async {
  await orders.remove(id);
  return Redirect(ordersRoute.link()).flash('Order deleted', kind: FlashKind.success);
}
```

The message travels in a 2-minute cookie (`HttpOnly`, `SameSite=Lax`) and is deleted once shown. It is plain text, up to 300 characters; `FlashKind` is `info`, `success` or `error`.

> **Difference from Flutter:** A `SnackBar` is shown from the code that acts, on the same screen. In Thor the action ends in a redirect, and the notice travels with it to the next page.

## Paginated lists in the URL

A list's search, page, sort and filters live in the URL: a link, a bookmark and "back" keep them, also without JavaScript. `request.listQuery` reads them already validated, and `Pagination` shows the links.

```dart
@override
Future<Orders> load(PageRequest request) async {
  final list = request.listQuery(
    pageSize: 20,
    sorts: const {'customer', 'total'}, // the only valid sorts
    defaultSort: '-total', // '-' = descending
    filters: const {'status'},
  );
  final page = await repo.orders(q: list.q, offset: list.offset, limit: list.limit,
      sort: list.sort, descending: list.descending, status: list.filter('status'));
  return Orders(page.rows, list.within(page.total), page.total); // past the last page: redirects to it
}

// in build
Pagination(list: data.list, total: data.total)
```

A hand-written URL never breaks the page: `page=abc` or `page=0` is page 1, a sort not in `sorts` uses `defaultSort`, an undeclared filter is ignored, and a page past the last one redirects to the last.

| To build the link for | Use |
|---|---|
| another page | `list.withPage(3)` |
| a search | `list.withSearch('mug')` |
| a sort | `list.withSort('customer')` or `list.toggleSort('total')` |
| a filter | `list.withFilter('status', 'open')` |

Each method keeps the other parameters. `Pagination` is a `<nav>` with real links and shows nothing when there is a single page.

> **Difference from Flutter:** `PaginatedDataTable` keeps the page in memory: it is lost on reload and cannot be linked to.

## Caching and metadata

`cache:` shares a page's HTML between requests for that long; `meta` provides the `<head>` title and description.

```dart
class ProductsPage extends ThorPage<List<Product>> {
  const ProductsPage() : super(cache: const Duration(seconds: 30));

  @override
  PageMeta meta(PageState<List<Product>> state) => PageMeta(
    title: 'Catalog',
    description: '${state.data.length} products available.',
  );
  // load and build…
}
```

- The cache is only shared between requests without their own data (no session in the context).
- Reading a cookie the visitor sent (`request.cookies['store']`) makes the page theirs: it is answered `private, no-cache` and never stored. A visitor without that cookie still gets the shared page; `personalized: false` on the route shares it whatever cookies it reads.
- An action or a command that succeeds clears it in every isolate; one that fails (4xx or 5xx) does not, even if it wrote before failing. If the action writes in several steps, do them in a transaction.
- A cache in front of the server (CDN, proxy) is not notified: purge it yourself when you write.
- A layout can set the title format of the pages it contains: `PageMeta(title: 'Shop', titleTemplate: '%s · Shop')`. Open Graph, JSON-LD and the sitemap are in [SEO](seo.md).
- `cacheControl:` is the other side: what the page tells browsers and CDNs (`public, max-age=60, stale-while-revalidate=600`), for a CDN in front of the server. It only applies to a public page; a personal page, one that sets a cookie, has a CSP nonce or fails stays `private, no-cache`, and a `Cache-Control` set in `request.response.headers` wins. A `load` that could not get its data (the backend was down, and the page drew an empty state with `200`) calls `request.response.noStore()` and that answer is `no-store` and stays out of the page cache (`cache:`), though the page says it is public; `request.response.cacheControl(CacheControl(…))` sets another policy for that response only.

```dart no-check
class ProductsPage extends ThorPage<List<Product>> {
  const ProductsPage()
    : super(
        cache: const Duration(seconds: 30),
        cacheControl: const CacheControl(
          maxAge: Duration(seconds: 60),
          staleWhileRevalidate: Duration(minutes: 10),
        ),
      );
}
```

### Clearing only what changed

`revalidateTag('cart')` deletes, in every isolate, the pages with that tag.

```dart
class CartPage extends ThorPage<Cart> {
  const CartPage() : super(cache: const Duration(minutes: 5), tags: const ['cart']);
}

Future<ActionResult?> add(PageRequest request) async {
  await cart.add(item);
  revalidateTag('cart'); // CartPage renders again
  return null;
}
```

A write that succeeds still clears the whole cache. For an expensive page that only changes with a known event, `invalidateOnWrite: false` makes only its tag or the `cache` expiry clear it.

> **Important:** With `invalidateOnWrite: false`, a write that does not call `revalidateTag` leaves the page with stale data until `cache` expires.

## Data that arrives later

`FutureBuilder` with `defer` shows slow data (recommendations, an external search) without delaying the whole page. Start the call in `load` without `await`, wrap it in `defer` and show it with `FutureBuilder`: the page goes out with a skeleton, and the data replaces it when it arrives, in the same response.

:::flutter
@flutter
```dart no-check
class _HomeState extends State<Home> {
  late final Future<List<Product>> _featured;

  @override
  void initState() {
    super.initState();
    _featured = widget.catalog.featured(); // once, not on every build
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Product>>(
    future: _featured,
    builder: (context, snapshot) => snapshot.hasData
        ? ProductGrid(snapshot.data!)
        : const CircularProgressIndicator(),
  );
}
```
@thor
```dart
class HomePage extends ThorPage<Home> {
  const HomePage();

  @override
  Future<Home> load(PageRequest request) async => Home(
    user: await users.me(request), // the page waits for this
    featured: defer(catalog.featured()), // and this arrives later
  );

  @override
  Widget build(BuildContext context, PageState<Home> state) => Column(
    children: [
      Header(user: state.data.user),
      FutureBuilder<List<Product>>(
        future: state.data.featured,
        builder: (context, snapshot) => snapshot.hasData
            ? ProductGrid(snapshot.data!)
            : snapshot.hasError
            ? Text(snapshot.error!) // the message for the user
            : const Skeleton(height: 240),
      ),
    ],
  );
}
```
:::

`Skeleton` is 16 high by default; `Skeleton.expand()` fills its parent and `Skeleton.circle(diameter: 40)` draws an avatar. As in Flutter, `snapshot.hasData` is `false` when the future completes with `null`: if the type admits `null`, tell waiting apart from completion with `connectionState` ([THOR-R033](../../errores/en/THOR-R033.md)).

| Case | What happens |
|---|---|
| The future fails | `snapshot.hasError`; the message is the one from `ThorApp(serverMessages:)`, never the exception |
| It takes too long | after `RouteHandler(deferTimeout:)` (30 s), the `builder` receives a timeout error |
| The page has `cache:` | the cache stores the finished page, without the skeleton |
| `thor export`, `HEAD` and tests | the page renders in full, with the futures resolved |
| `NotFound` or `Redirect` from the future | the response already went out with `200`: the `builder` receives the error |
| Without JavaScript | the result appears at the end of the page, without a skeleton |

> **Note:** Create the future in `load`, not in `build`. The result cannot be a lone table row: defer the whole table. If the same `FutureBuilder` appears in two variants of a `ResponsiveLayout`, create it once and use it in both: the server sends a single fragment ([THOR-R034](../../errores/en/THOR-R034.md)).

### Head and status with deferred data

The `<head>` goes out before the futures. A product page needs the name in the `<title>` and a `404` if it does not exist: with `head: true`, the server waits for that future before sending the head and the HTTP status.

```dart
Future<ProductData> load(PageRequest request) async => ProductData(
  item: defer(catalog.product(request.param('slug')), head: true),
);

@override
PageMeta meta(PageState<ProductData> state) => PageMeta(
  title: resolvedValue(state.data.item)?.name ?? 'Product',
);
```

If the future throws `NotFound`, `HttpError` or `Redirect`, the response is that `404`, that error or that redirect; any other error is a `500`, and a future that never completes is a `504` after `deferTimeout`. The same URL always yields the same status, regardless of backend latency.

For purely cosmetic head data, `headBudget: const Duration(milliseconds: 300)` sets a cap: when it runs out, the page goes out with `200`, the fallback title and `noindex`. Do not use it for whatever decides the status ([THOR-S038](../../errores/en/THOR-S038.md)).

### Early response

If a group's `load`s wait on a slow API, `earlyHints: true` sends the start of the document right away, and the browser downloads styles, fonts and images in the meantime.

```dart
Group(earlyHints: true, layout: const AppLayout(), children: [reportsRoute])
```

Since the response has already started with `200`, a `load` that fails afterwards shows its error page with `noindex`, and a cookie can no longer be set: set it in the middleware or in an action.

For content that almost nobody opens (a 750-entry menu, a product's reviews), the page does not need to send it: use [`LazyPiece`](live-data.md#on-demand-content).

## HTTP client

`ThorHttpClient` is the service that calls an API from the server; the Repository that uses it is in [Data layer](data-layer.md). `warmUp` opens the TCP and TLS connections when it is created, without blocking startup, so the first request does not pay that cost.

```dart
final api = ThorHttpClient(
  warmUp: ['https://shop.example.com/api/catalog/categories'], // a HEAD: pick a cheap URL
);
```

What HTTP treats as strings is typed:

```dart
final call = await api.send(HttpMethod.post, url, json: {'qty': 2});
if (call.statusCode == StatusCode.conflict) throw const HttpError(StatusCode.conflict);
if (request.method.isRead) { /* GET or HEAD */ }
request.headers[HttpHeader.acceptLanguage];
ThorResponse(StatusCode.ok, headers: {HttpHeader('x-request-id'): id});
```

| Type | What it is |
|---|---|
| `HttpMethod` | an enum (`get`, `post`, `put`, `patch`, `delete`…); a method outside the list responds `501` |
| `StatusCode` | an `int` with names (`notFound`, `tooManyRequests`…): wherever a status is expected, a number still works |
| `HttpHeader` | a header's name: the key of every header map (`Map<HttpHeader, String>`), with constants for the common ones, in lowercase; one the list lacks is `HttpHeader('x-my-header')`. It is a `String`: `headers['cookie']` still reads |

## Next steps

:::cards
- [Forms](forms.md) — controls, validation and files
- [State](state.md) — `query` and `command` from the browser
- [Live data](live-data.md) — server events and on-demand content
:::
