# Testing

Test each layer as in Flutter: the ViewModel in pure Dart, each widget by the HTML it produces, and pages with a test client, with no browser or network.

:::flutter Flutter: `flutter_test`, `testWidgets`, `pumpWidget` · Thor: `thor_test`, `testThor`, `handler.client()`

## Which test to use

| What you test | In Flutter | In Thor |
|---|---|---|
| A ViewModel (`ThorState`) or a repository | unit test | `package:test`, pure Dart |
| A widget: text, labels, semantics | widget test | `testThor` and `find` |
| A page, an action, the session | integration test | `handler.client()` |
| A query or a command | integration test | `app.query(...)` and `app.command(...)` |
| That it looks right in a browser | integration test | `thor render` and a manual review |

## Running tests

A `thor create` project includes `package:test`, `thor_test` and two example tests.

```bash
thor test
thor test test/cart_test.dart -N "empty"      # one file, one test by name
thor test -t slow -j 2 -r expanded            # tags, concurrency, reporter
```

`thor test` registers the app's ViewModels and then runs `dart test`, with the same options. A plain `dart test` works for pure Dart, but a test that renders a page with a ViewModel fails with [THOR-S010](../../errores/en/THOR-S010.md).

## Testing a ViewModel

A ViewModel is a Dart class: call its methods and check its fields.

```dart
test('the counter goes back to zero on reset', () {
  final counter = CounterViewModel();
  counter.increment();
  counter.increment();
  expect(counter.label(), '2');
  counter.reset();
  expect(counter.isZero(), isTrue);
});
```

It's the cheapest test. What the browser does with those methods, such as changing a text or showing a variant, is already tested by Thor.

## Testing a widget

`testThor` and `find` are the ones from `flutter_test`: render the widget and look for what the user sees.

```dart
import 'package:test/test.dart';
import 'package:thor_test/thor_test.dart';

void main() {
  testThor('the card shows the product', (tester) async {
    await tester.pumpWidget(const ProductCard('Cold brew', 4.5));
    expect(find.text('Cold brew'), findsOneWidget);
    expect(find.textContaining('4.50'), findsOneWidget);
    expect(find.bySemanticsLabel('Add to cart'), findsOneWidget);
    expect(find.byRole(SemanticsRole.article), findsOneWidget);
  });

  testThor('the buy button is a real button', (tester) async {
    await tester.pumpWidget(const BuyButton());
    final html = tester.widgetHtml(find.text('Buy'));
    expect(html, startsWith('<button'));
  });
}
```

| Finder | Finds |
|---|---|
| `find.text('Hi')`, `find.textContaining('Hi')` | the element whose text is, or contains, that value |
| `find.bySemanticsLabel('…')`, `find.bySemanticsIdentifier('…')` | `Semantics(label:)`, with exact text or a `RegExp`, and `Semantics(identifier:)` |
| `find.byRole(SemanticsRole.x)` | `Semantics(role:)` |
| `find.byTooltip('…')` | the widget of a `Tooltip(message:)` |
| `find.byKey(const ValueKey('a'))`, `find.byType(ProductCard)` | the element that widget wrote |
| `find.descendant(of:, matching:)`, `.first`, `.last`, `.at(i)` | narrow down or pick |

The matchers are Flutter's: `findsOneWidget`, `findsNothing`, `findsNWidgets(n)`, `findsWidgets`. `tester.widgetHtml(finder)` gives the HTML of the single element found and `tester.html` that of the whole page. To pin today's date, use `withThorNow(date, () => …)` in a test or `THOR_NOW=2026-03-10T12:00:00` for the whole process.

> **Tip:** Compare text, labels and semantics, never class names: they change with any style.

### Forms and links

`tester` acts like a user without JavaScript: `visit` loads a page of the app, `enterText` fills a field and `tap` submits the form or follows the link. The page that responds becomes the `tester`'s page.

```dart
testThor('signing in shows the account', (tester) async {
  await tester.visit(appHandler().client(), '/login');
  await tester.enterText(find.byTag('input').first, 'ana@example.com');
  await tester.enterText(find.byTag('input').last, 'secret');
  await tester.tap(find.text('Sign in'));
  expect(find.text('Welcome, Ana'), findsOneWidget);
});
```

`find.byTag` searches by HTML tag. `tester.response` is the server's last response; `pump` and `pumpAndSettle` exist for porting Flutter tests and do nothing.

> **Important:** `testThor` doesn't run a ViewModel's methods. A `tap` on a button whose `onPressed` is a ViewModel method fails and says so: that logic is tested with a ViewModel test.

## Testing pages and actions

`handler.client()` is a user of the app inside the test: it doesn't open a port, it keeps cookies like a browser and it sends the `Origin` that a `POST` requires.

```dart
import 'package:test/test.dart';
import 'package:thor_test/thor_test.dart';

void main() {
  late ThorTestClient app;
  setUp(() => app = appHandler().client()); // a new user per test

  test('signing in opens the account', () async {
    final login = await app.post('/login?/signin', form: {
      'email': 'ana@example.com',
      'password': 'secret',
    });
    expect(login, redirectsTo('/account'));

    final account = await app.follow(login); // now with the session cookie
    expect(account, hasStatus(200));
    expect(account.html.querySelector('h1')!.text, 'Ana');
  });

  test('a wrong password keeps what was typed', () async {
    final res = await app.post('/login?/signin', form: {
      'email': 'ana@example.com',
      'password': 'nope',
    });
    expect(res, hasStatus(422));
    expect(res.text, contains('value="ana@example.com"'));
  });
}
```

`appHandler()` is your app's function that creates the `RouteHandler` with `router.routes`; use it in the server and in tests to test exactly what is served.

| What | How |
|---|---|
| Request | `get(path)`, `post(path, form:)` or `json:`, `send('PUT', path)`; an action is `?/name` in the path |
| Redirects | not followed automatically: `follow: true` or `app.follow(response)` |
| Cookies | `app.cookie('sid')`, `app.setCookie(…)`, `app.clearCookies()`; two clients never share them |
| Headers | `headers:`; a `null` value removes the header (`{'origin': null}` gives 403 on a `POST`) |
| Response | `status`, `text`, `json`, `headers`, `location` and `html`, which you search with `querySelector` |
| Matchers | `hasStatus(422)` and `redirectsTo('/x')` |

### Queries and commands

The client calls the server like the browser does, session included.

```dart
final app = appHandler().client()..setCookie('session', 'ana');

test('the cart total follows an add', () async {
  await app.get('/cart'); // the page that uses the ViewModel
  final added = await app.command(cart.add, 'mug');
  expect(added.result, 1);
  expect(added.queries['CartViewModel.total'], 120); // the fresh data it brings
  expect((await app.query(cart.total)).data, 120);
});
```

The query must belong to a page that uses it; otherwise the response is a 404, just as in the browser. `app.goTo('/cart')` places the client on a page without requesting it.

## Fake backends

A page that calls a backend with `ThorHttpClient` doesn't go out to the network in a test: the test defines the responses and Thor serves them, without changing the app's code.

```dart
test('/search lists the results', () async {
  final fake = MockTransport.fixtures({
    'GET https://api.shop.example/search?q=shoes': {'items': [{'name': 'A'}]},
    'POST https://api.shop.example/cart': (req) => {'got': req.json()},
    'https://api.shop.example/p/*': ThorHttpFixture.json({}, status: 404),
  });
  final app = appHandler().client(httpOverrides: fake);

  final res = await app.get('/search?q=shoes');
  expect(res.html.querySelectorAll('li'), hasLength(1));
  expect(fake.requests.single.uri.queryParameters['q'], 'shoes');
});
```

| Piece | What it does |
|---|---|
| `MockTransport.fixtures({...})` | key `'METHOD url'` or `'url'` (a trailing `*` matches by prefix); value: JSON (200), a `ThorHttpFixture` or a function of the request |
| `client(httpOverrides: fake)` | that client's `ThorHttpClient`s respond with `fake` |
| `withHttpFixtures({...}, () async {…})` | the same for a block, without a client |
| `fake.requests` | the requests received |
| `MockTransport.recorded('test/fixtures')` | replays what was recorded; `thor test --record` calls the real backend and saves it |

A request without a prepared response fails with `UnmockedHttpRequest`, so there is never network access by accident.

> **Caution:** Recordings don't store headers or URL credentials, but they do store the body of every response. Review `test/fixtures` before committing.

## In the browser

VM tests don't run a browser. Before deploying, check:

- **Without JavaScript:** menus, dialogs, accordions and forms keep working.
- **Keyboard:** everything interactive is reachable with Tab and activates with Enter or Space.
- **Lighthouse:** accessibility and SEO.
- **`thor render /route`:** the accessibility tree and screenshots at 390, 800 and 1440 px, with a warning if the page scrolls horizontally ([The thor command](cli.md#thor-render)).

Thor doesn't include screenshot comparison. If you need it, do it with your browser tool against `thor preview`, with reduced motion, a fixed `THOR_NOW` and references recorded on the same machine.

## Next steps

:::cards
- [The thor command](cli.md) — `thor test`, `thor render` and the rest
- [State](state.md) — what belongs in a ViewModel
- [Build and deploy](build-and-deploy.md) — deploy what you tested
:::
