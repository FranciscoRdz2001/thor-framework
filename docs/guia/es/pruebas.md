# Pruebas

Prueba cada capa como en Flutter: el ViewModel en Dart puro, cada widget por el HTML que produce y las páginas con un cliente de pruebas, sin navegador ni red.

:::flutter Flutter: `flutter_test`, `testWidgets`, `pumpWidget` · Thor: `thor_test`, `testThor`, `handler.client()`

## Qué prueba usar

| Qué pruebas | En Flutter | En Thor |
|---|---|---|
| Un ViewModel (`ThorState`) o un repositorio | unit test | `package:test`, Dart puro |
| Un widget: texto, etiquetas, semántica | widget test | `testThor` y `find` |
| Una página, una acción, la sesión | integration test | `handler.client()` |
| Una query o un command | integration test | `app.query(...)` y `app.command(...)` |
| Que se vea bien en un navegador | integration test | `thor render` y una revisión manual |

## Ejecutar las pruebas

Un proyecto de `thor create` incluye `package:test`, `thor_test` y dos pruebas de ejemplo.

```bash
thor test
thor test test/cart_test.dart -N "empty"      # one file, one test by name
thor test -t slow -j 2 -r expanded            # tags, concurrency, reporter
```

`thor test` registra los ViewModels de la app y después ejecuta `dart test`, con las mismas opciones. Un `dart test` directo sirve para Dart puro, pero una prueba que renderiza una página con un ViewModel falla con [THOR-S010](../../errores/THOR-S010.md).

## Probar un ViewModel

Un ViewModel es una clase de Dart: llama a sus métodos y comprueba sus campos.

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

Es la prueba más barata. Lo que el navegador hace con esos métodos, como cambiar un texto o mostrar una variante, ya lo prueba Thor.

## Probar un widget

`testThor` y `find` son los de `flutter_test`: renderiza el widget y busca lo que el usuario ve.

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

| Finder | Encuentra |
|---|---|
| `find.text('Hi')`, `find.textContaining('Hi')` | el elemento cuyo texto es, o contiene, ese valor |
| `find.bySemanticsLabel('…')`, `find.bySemanticsIdentifier('…')` | `Semantics(label:)`, con texto exacto o `RegExp`, y `Semantics(identifier:)` |
| `find.byRole(SemanticsRole.x)` | `Semantics(role:)` |
| `find.byTooltip('…')` | el widget de un `Tooltip(message:)` |
| `find.byKey(const ValueKey('a'))`, `find.byType(ProductCard)` | el elemento que escribió ese widget |
| `find.descendant(of:, matching:)`, `.first`, `.last`, `.at(i)` | acotar o elegir |

Los matchers son los de Flutter: `findsOneWidget`, `findsNothing`, `findsNWidgets(n)`, `findsWidgets`. `tester.widgetHtml(finder)` da el HTML del único elemento encontrado y `tester.html` el de toda la página. Para fijar la fecha de hoy, usa `withThorNow(date, () => …)` en una prueba o `THOR_NOW=2026-03-10T12:00:00` en todo el proceso.

> **Consejo:** Compara textos, etiquetas y semántica, nunca nombres de clase: cambian con cualquier estilo.

### Formularios y enlaces

`tester` actúa como un usuario sin JavaScript: `visit` carga una página de la app, `enterText` llena un campo y `tap` envía el formulario o sigue el enlace. La página que responde pasa a ser la del `tester`.

```dart
testThor('signing in shows the account', (tester) async {
  await tester.visit(appHandler().client(), '/login');
  await tester.enterText(find.byTag('input').first, 'ana@example.com');
  await tester.enterText(find.byTag('input').last, 'secret');
  await tester.tap(find.text('Sign in'));
  expect(find.text('Welcome, Ana'), findsOneWidget);
});
```

`find.byTag` busca por etiqueta HTML. `tester.response` es la última respuesta del servidor; `pump` y `pumpAndSettle` existen para portar pruebas de Flutter y no hacen nada.

> **Importante:** `testThor` no ejecuta los métodos de un ViewModel. Un `tap` sobre un botón cuyo `onPressed` es un método del ViewModel falla y lo indica: esa lógica se prueba con una prueba de ViewModel.

## Probar páginas y acciones

`handler.client()` es un usuario de la app dentro de la prueba: no abre un puerto, guarda las cookies como un navegador y envía el `Origin` que exige un `POST`.

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

`appHandler()` es la función de tu app que crea el `RouteHandler` con `router.routes`; úsala en el servidor y en las pruebas para probar exactamente lo que se sirve.

| Qué | Cómo |
|---|---|
| Pedir | `get(path)`, `post(path, form:)` o `json:`, `send('PUT', path)`; una acción es `?/name` en la ruta |
| Redirecciones | no se siguen solas: `follow: true` o `app.follow(response)` |
| Cookies | `app.cookie('sid')`, `app.setCookie(…)`, `app.clearCookies()`; dos clientes nunca las comparten |
| Cabeceras | `headers:`; un valor `null` quita la cabecera (`{'origin': null}` da 403 en un `POST`) |
| Respuesta | `status`, `text`, `json`, `headers`, `location` y `html`, donde buscas con `querySelector` |
| Matchers | `hasStatus(422)` y `redirectsTo('/x')` |

### Queries y commands

El cliente llama al servidor como el navegador, con la sesión incluida.

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

La query debe pertenecer a una página que la use; si no, la respuesta es un 404, igual que en el navegador. `app.goTo('/cart')` sitúa al cliente en una página sin pedirla.

## Backends falsos

Una página que llama a un backend con `ThorHttpClient` no sale a la red en una prueba: la prueba define las respuestas y Thor las sirve, sin cambiar el código de la app.

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

| Pieza | Qué hace |
|---|---|
| `MockTransport.fixtures({...})` | clave `'METHOD url'` o `'url'` (`*` al final compara por prefijo); valor: JSON (200), `ThorHttpFixture` o una función de la petición |
| `client(httpOverrides: fake)` | los `ThorHttpClient` de ese cliente responden con `fake` |
| `withHttpFixtures({...}, () async {…})` | lo mismo para un bloque, sin cliente |
| `fake.requests` | las peticiones recibidas |
| `MockTransport.recorded('test/fixtures')` | repite lo grabado; `thor test --record` llama al backend real y lo guarda |

Una petición sin respuesta preparada falla con `UnmockedHttpRequest`, así que nunca hay red por accidente.

> **Cuidado:** Lo grabado no guarda cabeceras ni credenciales de la URL, pero sí el cuerpo de cada respuesta. Revisa `test/fixtures` antes de hacer commit.

## En el navegador

Las pruebas de la VM no ejecutan un navegador. Antes de publicar, revisa:

- **Sin JavaScript:** los menús, diálogos, acordeones y formularios siguen funcionando.
- **Teclado:** todo lo interactivo se alcanza con Tab y se activa con Enter o Espacio.
- **Lighthouse:** accesibilidad y SEO.
- **`thor render /ruta`:** el árbol de accesibilidad y capturas a 390, 800 y 1440 px, con aviso si la página se desplaza en horizontal ([El comando thor](cli.md#thor-render)).

Thor no incluye comparación de capturas. Si la necesitas, hazla con tu herramienta de navegador sobre `thor preview`, con movimiento reducido, `THOR_NOW` fijo y referencias grabadas en la misma máquina.

## Siguientes pasos

:::cards
- [El comando thor](cli.md) — `thor test`, `thor render` y el resto
- [Estado](estado.md) — lo que cabe en un ViewModel
- [Compilar y publicar](publicar.md) — publicar lo que probaste
:::
