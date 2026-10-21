# Servidor y acciones

Escribe lo que corre en el servidor alrededor de una página: acciones de formulario, listas en la URL, caché, datos diferidos y llamadas HTTP.

:::flutter Flutter: `FutureBuilder` y `package:http` · Thor: acciones, `defer` y `ThorHttpClient`

## Datos del layout

Un `ThorLayout<T>` también tiene `load`, que corre en paralelo con el de la página. La página que necesita ese dato lo espera con `request.parent<T>()`.

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

En `build`, el mismo dato es `state.dataOf<Company>()`. Lo que lanza un `load` termina la petición: `NotFound` y `HttpError` muestran la [página de error](navegacion.md#páginas-de-error) y `Redirect` lleva a otra página. Lo que necesitan todas las páginas, como el usuario con sesión, va en un [middleware](navegacion.md#middleware), no en un layout.

## Acciones de formulario

Una acción es un método de la página que corre en el servidor. El formulario la recibe por su nombre, sin paréntesis, y el compilador comprueba que exista y que acepte ese formulario.

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

El [esquema](formularios.md#un-esquema-para-el-navegador-y-el-servidor) se valida en el navegador y otra vez en el servidor, antes de `send`. Si el envío no pasa, la página vuelve con `422`, lo que el usuario escribió y el mensaje de cada campo:

:::example data-form-failed
:::

| La acción devuelve | Resultado |
|---|---|
| `null` | `303` a la misma página: recargar no reenvía |
| `Redirect(url)` | `303` a otra página |
| `values.fail('Email already in use', ContactForm.email)` | la página otra vez (`422`), con valores y mensaje |
| `ActionResult.success(data)` | la página otra vez, sin redirigir |

Es el patrón Post/Redirect/Get y funciona sin JavaScript. Una página con una sola acción envía a su propia ruta (`POST /login`); con varias, cada formulario lleva el nombre de la suya (`POST /ruta?/signIn`). El middleware y los guards de la página corren antes de la acción, y un formulario enviado desde otro sitio se rechaza.

| Caso | Cómo |
|---|---|
| una acción sin campos | `Future<ActionResult?> favorite(PageRequest r)` y `Form(onPost: favorite)` |
| un botón que envía a otra acción | `FilledButton(onPost: delete)` dentro del formulario |
| la acción de otra página | `Form(action: articleRoute.link({'slug': s}), onPost: const ArticlePage().favorite)` |
| soltar la query de la URL | `Form(preserveQuery: false)`; por omisión se conserva |

> **Importante:** `onPost:` y `onValid:` reciben un método, no un closure: el servidor llama a la acción por su nombre ([THOR-P020](../../errores/THOR-P020.md)).

### Acciones con argumentos

Una acción recibe valores tipados después de la petición. El botón los fija con `withArg` (`withArgs` si son varios), también sin JavaScript.

```dart
Future<ActionResult?> delete(PageRequest request, int id) async {
  await orders.remove(id); // id is an int
  return null;
}

FilledButton(onPost: delete.withArg(o.id), child: const Text('Delete'))
OutlinedButton(onPost: assign.withArgs(o.id, Owner.luis), child: const Text('Assign to Luis'))
```

Admite hasta tres argumentos de tipo `int`, `double`, `num`, `String`, `bool`, `DateTime` o un enum. Un valor de otro tipo, uno que falta o un enum que no existe responde `400`.

> **Cuidado:** El navegador escribe el argumento y el usuario puede cambiarlo: `withArg` garantiza el tipo, no el permiso. Comprueba en la acción que el usuario puede modificar ese `id` (`orders.remove(id, owner: user.id)`), como con un parámetro de la URL.

### Preguntar antes de enviar

`confirm:` en un botón (o en un `Form`) que envía al servidor pide confirmación en un `<dialog>` y solo envía si el usuario acepta.

```dart
FilledButton(
  onPost: delete.withArg(order.id),
  confirm: const ConfirmSpec('Delete the order?', message: 'This cannot be undone.', confirmLabel: 'Delete'),
  child: const Text('Delete'),
)
```

Con JavaScript, Esc y Cancelar no envían y el foco empieza en Cancelar. Sin JavaScript pregunta el servidor: responde una página con la pregunta y un botón que repite el envío con los mismos campos, y la acción corre solo entonces. Un formulario con archivos no admite esa pregunta y responde `400`.

## Un aviso en la página siguiente

`Redirect(…).flash('Order deleted')` deja un mensaje para la próxima página que se renderice: un aviso que se ve una vez, con o sin JavaScript.

```dart
Future<ActionResult?> delete(PageRequest request, int id) async {
  await orders.remove(id);
  return Redirect(ordersRoute.link()).flash('Order deleted', kind: FlashKind.success);
}
```

El mensaje viaja en una cookie de 2 minutos (`HttpOnly`, `SameSite=Lax`) y se borra al mostrarse. Es texto plano, de hasta 300 caracteres; `FlashKind` es `info`, `success` o `error`.

> **Diferencia con Flutter:** Un `SnackBar` se muestra desde el código que actúa, en la misma pantalla. En Thor la acción termina en una redirección, y el aviso viaja con ella hasta la página siguiente.

## Listas paginadas en la URL

La búsqueda, la página, el orden y los filtros de una lista viven en la URL: un enlace, un favorito y «atrás» los conservan, también sin JavaScript. `request.listQuery` los lee ya validados y `Pagination` muestra los enlaces.

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

Una URL escrita a mano nunca rompe la página: `page=abc` o `page=0` es la página 1, un orden que no está en `sorts` usa `defaultSort`, un filtro no declarado se ignora y una página posterior a la última redirige a la última.

| Para armar el enlace de | Usa |
|---|---|
| otra página | `list.withPage(3)` |
| una búsqueda | `list.withSearch('mug')` |
| un orden | `list.withSort('customer')` o `list.toggleSort('total')` |
| un filtro | `list.withFilter('status', 'open')` |

Cada método conserva los demás parámetros. `Pagination` es un `<nav>` con enlaces reales y no muestra nada cuando hay una sola página.

> **Diferencia con Flutter:** `PaginatedDataTable` guarda la página en memoria: se pierde al recargar y no se puede enlazar.

## Caché y metadatos

`cache:` comparte el HTML de una página entre peticiones durante ese tiempo; `meta` da el título y la descripción del `<head>`.

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

- La caché solo se comparte entre peticiones sin datos propios (sin sesión en el contexto).
- Leer una cookie que el visitante envió (`request.cookies['store']`) hace la página suya: sale con `private, no-cache` y nunca se guarda. Un visitante sin esa cookie sigue recibiendo la página compartida; `personalized: false` en la ruta la comparte lea las cookies que lea.
- Una acción o un command que termina bien la vacía en todos los isolates; uno que falla (4xx o 5xx) no, aunque haya escrito antes de fallar. Si la acción escribe en varios pasos, hazlos en una transacción.
- Una caché delante del servidor (CDN, proxy) no se entera: púrgala tú al escribir.
- Un layout puede dar el formato del título de las páginas que contiene: `PageMeta(title: 'Shop', titleTemplate: '%s · Shop')`. Open Graph, JSON-LD y el sitemap están en [SEO](seo.md).
- `cacheControl:` es el otro lado: lo que la página le dice a navegadores y CDN (`public, max-age=60, stale-while-revalidate=600`), para un CDN delante del servidor. Solo se aplica a una página pública; una personal, una que pone una cookie, tiene nonce de CSP o falla sigue con `private, no-cache`, y un `Cache-Control` puesto en `request.response.headers` gana.

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

### Vaciar solo lo que cambió

`revalidateTag('cart')` borra, en todos los isolates, las páginas con esa etiqueta.

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

Una escritura que termina bien sigue vaciando toda la caché. Para una página costosa que solo cambia con un evento conocido, `invalidateOnWrite: false` hace que solo la vacíen su etiqueta o el vencimiento de `cache`.

> **Importante:** Con `invalidateOnWrite: false`, una escritura que no llama a `revalidateTag` deja la página con datos viejos hasta que vence `cache`.

## Datos que llegan después

`FutureBuilder` con `defer` muestra un dato lento (recomendaciones, un buscador externo) sin retrasar toda la página. Inicia la llamada en `load` sin `await`, envuélvela en `defer` y muéstrala con `FutureBuilder`: la página sale con un esqueleto y el dato lo reemplaza al llegar, en la misma respuesta.

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

`Skeleton` mide 16 de alto por omisión; `Skeleton.expand()` llena a su padre y `Skeleton.circle(diameter: 40)` dibuja un avatar. Como en Flutter, `snapshot.hasData` es `false` cuando el futuro termina en `null`: si el tipo admite `null`, distingue la espera del final con `connectionState` ([THOR-R033](../../errores/THOR-R033.md)).

| Caso | Qué pasa |
|---|---|
| El futuro falla | `snapshot.hasError`; el mensaje es el de `ThorApp(serverMessages:)`, nunca la excepción |
| Tarda demasiado | tras `RouteHandler(deferTimeout:)` (30 s), el `builder` recibe un error de tiempo |
| La página tiene `cache:` | la caché guarda la página terminada, sin esqueleto |
| `thor export`, `HEAD` y pruebas | la página se renderiza entera, con los futuros resueltos |
| `NotFound` o `Redirect` desde el futuro | la respuesta ya salió con `200`: el `builder` recibe el error |
| Sin JavaScript | el resultado aparece al final de la página, sin esqueleto |

> **Nota:** Crea el futuro en `load`, no en `build`. El resultado no puede ser una fila de tabla suelta: difiere la tabla entera. Si el mismo `FutureBuilder` aparece en dos variantes de un `ResponsiveLayout`, créalo una vez y úsalo en las dos: el servidor envía un solo fragmento ([THOR-R034](../../errores/THOR-R034.md)).

### Cabecera y estado con datos diferidos

El `<head>` sale antes que los futuros. Una ficha de producto necesita el nombre en el `<title>` y un `404` si no existe: con `head: true`, el servidor espera ese futuro antes de enviar la cabecera y el estado HTTP.

```dart
Future<ProductData> load(PageRequest request) async => ProductData(
  item: defer(catalog.product(request.param('slug')), head: true),
);

@override
PageMeta meta(PageState<ProductData> state) => PageMeta(
  title: resolvedValue(state.data.item)?.name ?? 'Product',
);
```

Si el futuro lanza `NotFound`, `HttpError` o `Redirect`, la respuesta es ese `404`, ese error o esa redirección; otro error es un `500`, y un futuro que no termina, un `504` tras `deferTimeout`. La misma URL da siempre el mismo estado, sin importar la latencia del backend.

Para un dato de cabecera solo cosmético, `headBudget: const Duration(milliseconds: 300)` pone un tope: al agotarse, la página sale con `200`, el título de respaldo y `noindex`. No lo uses en lo que decide el estado ([THOR-S038](../../errores/THOR-S038.md)).

### Respuesta temprana

Si los `load` de un grupo esperan a una API lenta, `earlyHints: true` envía el inicio del documento de inmediato, y el navegador descarga estilos, fuentes e imágenes mientras tanto.

```dart
Group(earlyHints: true, layout: const AppLayout(), children: [reportsRoute])
```

Como la respuesta ya empezó con `200`, un `load` que falla después muestra su página de error con `noindex`, y ya no se puede poner una cookie: ponla en el middleware o en una acción.

Para contenido que casi nadie abre (un menú de 750 entradas, las reseñas de un producto), la página no necesita enviarlo: usa [`LazyPiece`](datos-vivos.md#contenido-bajo-demanda).

## Cliente HTTP

`ThorHttpClient` es el servicio que llama a una API desde el servidor; el repositorio que lo usa está en [Capa de datos](capa-datos.md). `warmUp` abre las conexiones TCP y TLS al crearse, sin bloquear el arranque, para que la primera petición no pague ese costo.

```dart
final api = ThorHttpClient(
  warmUp: ['https://shop.example.com/api/catalog/categories'], // a HEAD: pick a cheap URL
);
```

Lo que en HTTP son cadenas tiene tipo:

```dart
final call = await api.send(HttpMethod.post, url, json: {'qty': 2});
if (call.statusCode == StatusCode.conflict) throw const HttpError(StatusCode.conflict);
if (request.method.isRead) { /* GET or HEAD */ }
request.headers[HttpHeader.acceptLanguage];
ThorResponse(StatusCode.ok, headers: {HttpHeader('x-request-id'): id});
```

| Tipo | Qué es |
|---|---|
| `HttpMethod` | un enum (`get`, `post`, `put`, `patch`, `delete`…); un método fuera de la lista responde `501` |
| `StatusCode` | un `int` con nombres (`notFound`, `tooManyRequests`…): donde se pide un estado, un número sigue sirviendo |
| `HttpHeader` | el nombre de una cabecera: la clave de todo mapa de cabeceras (`Map<HttpHeader, String>`), con constantes para las comunes, en minúsculas; una que falta es `HttpHeader('x-mi-cabecera')`. Es un `String`: `headers['cookie']` sigue leyendo |

## Siguientes pasos

:::cards
- [Formularios](formularios.md) — controles, validación y archivos
- [Estado](estado.md) — `query` y `command` desde el navegador
- [Datos en vivo](datos-vivos.md) — eventos del servidor y contenido bajo demanda
:::
