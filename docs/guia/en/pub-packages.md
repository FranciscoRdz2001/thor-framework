# Pub packages

Choose where to use each package: on the server any package for the Dart VM works; in a ViewModel, which runs in the browser, only some do.

## What works where

In `load`, actions and middleware you can use any package that runs on the Dart VM. Inside a ViewModel (`ThorState`) the list is short:

| Package | In a ViewModel | Alternative |
|---|---|---|
| `collection` | partial: `firstWhereOrNull`, `lastWhereOrNull`, `sorted`, `sortedBy`, `groupBy`, `groupListsBy`, `mapIndexed`, `whereIndexed`, `forEachIndexed`, `sum`, `max`, `min` | the rest, on the server |
| `intl` | only the messages from [Languages](localization.md) | `NumberFormat` and `DateFormat` in `load` or `build` |
| `json_serializable` | if the ViewModel doesn't use the generated class | a plain class with `fromJson` and `toJson` |
| `http`, `dio` | no | a `query` or a `command` ([State](state.md#server-data)) |
| `freezed`, `equatable` | no | final fields; compare what matters |
| `uuid`, `crypto`, `markdown`, `yaml`, `path`, `sqlite3` | no | on the server, behind a repository or in `load` |

Dart without packages works inside a ViewModel: a `Map<String, List<Task>>`, sorting with comparators, `DateTime` arithmetic, `Timer.periodic`, `jsonEncode`, `jsonDecode` and `async` methods with `Future.delayed`. The full list is in [State](state.md#what-fits-in-a-viewmodel). You don't need `shelf` or `formz`: Thor has its own `Middleware` and [`FormSchema`](forms.md#one-schema-for-the-browser-and-the-server).

## When a package doesn't fit in the ViewModel

The build stops with [THOR-B012](../../errores/en/THOR-B012.md) and lists each use with its file and line. The fix is one of three:

1. **Move it to the server.** The ViewModel doesn't call the package, but it can ask for its result: the function of a `query` or a `command` runs only on the server.
2. **Format beforehand.** What doesn't change in the browser (a price, a date) is formatted in `load` or in `build`. If the ViewModel shows a number that changes, store the number and build the text with interpolation or with an ARB message.
3. **Pass plain data.** Classes from `json_serializable`, `freezed` or `equatable` work on the server; the ViewModel receives a plain class (final fields, a constructor, `fromJson` and `toJson`) or flat values.

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

For writes, the same with `command`: `final add = commandWith(addToCart);` and `onPressed: cart.add.run.withArg(sku)`.

> **Caution:** The function of a `query` or a `command` must authorize what it reads or writes: anyone who gets past the page's middleware can call it.

```dart
// WRONG (THOR-B012): freezed's equality inside a ViewModel
final line = state(const OrderLine(productId: 'mug', quantity: 1), …);
bool isOne() => line.value == const OrderLine(productId: 'mug', quantity: 1);

// RIGHT: plain fields; compare what matters
final quantity = state(1);
bool isOne() => quantity.value == 1;
```

## A package's public files

A package that ships files for the web (fonts, images) declares them in its `pubspec.yaml`. `thor dev`, `thor build` and `thor test` copy them into the `web/` of every app that depends on it, only what is missing or changed.

```yaml
# the package's pubspec.yaml
thor:
  public:
    fonts: fonts # its fonts/ folder → the app's web/fonts/
```

The key is the destination folder inside `web/` and the value, the package's folder. The app uses them by their URL (`/fonts/…`), and `thor doctor --fix` syncs them. The app's own files go directly in `web/` ([The thor command](cli.md)).

## Services in the context

An HTTP client or a database reaches pages through the request context, so tests can pass in doubles (`MockClient` from `http`, an `HttpClientAdapter` from `dio`).

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

`onRequest` runs after the route's middleware, so a middleware doesn't see what it sets. What a middleware needs, such as a JWT key, is read from the [environment](session-and-security.md#environment-and-secrets).

## JWT as middleware

With `dart_jsonwebtoken`, the middleware verifies the token and leaves its data in the context.

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

A `ContextKey` is personal by default: the page that reads it isn't served from the shared cache.

## Markdown

`markdownToHtml` from `package:markdown` runs on the server. The resulting HTML has no widgets: it's inserted with `html.RawText` and styled with [`Styled(descendants:)`](advanced-styles.md).

> **Caution:** Don't insert HTML written by a user. With `markdown`, add a syntax that escapes the HTML in the source text.

## Generated code

`json_serializable` and `freezed` work with Thor: `thor dev`, `thor build` and `thor test` run `build_runner` when a library in `lib/` has a generated `part` (`x.g.dart`, `x.freezed.dart`). Keep the generated files in the repository, like the messages from [Languages](localization.md).

## Next steps

:::cards
- [State](state.md) — `query` and `command` to call the server
- [Data layer](data-layer.md) — services and repositories
- [Session and security](session-and-security.md) — environment, secrets and session
:::
