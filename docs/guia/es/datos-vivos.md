# Datos en vivo

Muestra datos que cambian mientras el usuario lee: eventos que envía el servidor, datos que se vuelven a pedir y contenido que se carga bajo demanda.

:::flutter Flutter: `StreamBuilder` sobre un `Stream` · Thor: `events()` en un ViewModel y `Watch`

## Eventos del servidor

`events` es una `query` que el servidor mantiene al día. La página sale con el valor de `initial` y el navegador abre una conexión hacia una ruta `ThorRoute.stream` de la misma app; cada evento actualiza `data`, sin sondeos. Una pestaña oculta pausa el stream y se resincroniza al volver.

:::bench bench-live-feed
:::

:::flutter
@flutter
```dart no-check
StreamBuilder<List<Quote>>(
  stream: market.quotes(),
  builder: (context, snapshot) => switch (snapshot.connectionState) {
    ConnectionState.active => QuoteList(snapshot.data!),
    ConnectionState.waiting => const Text('Reconnecting…'),
    _ => const Text('Closed'),
  },
)
```
@thor
```dart no-check
class MarketViewModel extends ThorState {
  final feed = events<List<Quote>>(
    '/markets/stream', // a route of the app (a single `/` at the start)
    event: 'tick', // ServerEvent(event: 'tick'); unnamed: 'message'
    initial: market.snapshot, // server only: renders the page
    key: 'symbol', // each event carries only the items that changed
  );

  List<Quote> rows() => feed.data.value ?? const [];
  String rowKey(Quote q) => q.symbol;
  String rowText(Quote q) => '${q.symbol}  ${q.price.toStringAsFixed(2)}';

  String status() => switch (feed.connection.value) {
    ConnectionState.active => 'Live',
    ConnectionState.waiting => 'Reconnecting…',
    _ => 'Closed',
  };
}

Watch.list(market.rows, itemKey: market.rowKey, each: (row) => row.text(market.rowText))
```
:::

El servidor es una ruta que emite `ServerEvent`. Con un `id` en cada evento, el navegador se reconecta solo y retoma desde el último recibido (`request.lastEventId`).

```dart no-check
ThorRoute<void>.stream('/markets/stream', (request) async* {
  final since = request.lastEventId; // null on the first connection
  yield* feed.since(since).map((t) => ServerEvent(jsonEncode(t.changed), event: 'tick', id: '${t.n}'));
});
```

| Para | Escribe |
|---|---|
| que cada evento sea el valor nuevo | `events<T>(url, event: 'x')`; `data` es el JSON decodificado |
| que cada evento traiga solo lo que cambió | `key: 'field'` con `T = List<X>` |
| que la página no espere al primer valor | omite `initial:` (la página sale en espera) |
| que `initial` lea lo que cargó la página | `initial: () => PageRequest.current.loaded<Doc>().draft` |
| avisar algo desde el servidor | `yield ServerEvent.toast('Guardado', kind: FlashKind.success)`: cualquier `events()` de la página lo muestra en el snack bar |
| saber si hay conexión | `feed.connection.value`: `waiting`, `active` o `done` |
| reabrir una conexión cerrada | `feed.reconnect()` |

Con `key:`, un evento trae solo los elementos que cambiaron y los demás conservan el mismo objeto, así que `Watch.list` actualiza solo esas filas. El evento puede ser una lista (cada elemento reemplaza al de su `key`; uno nuevo va al final) o `{"upsert": […], "remove": ["S02"], "replace": […]}`. Si el servidor ya no tiene lo que falta tras una caída, envía `{"replace": […]}` con la lista completa.

El navegador abre la conexión cuando algún elemento de la página usa el campo, la cierra cuando ya no hay ninguno o al salir de la página, y usa una sola por URL. La ruta que envía los eventos se describe en [Rutas y navegación](navegacion.md#endpoints-y-eventos).

> **Importante:** `url`, `event:`, `key:` y `timeout:` se escriben como literales, y la URL es una ruta de la app, nunca otro origen. Sin JavaScript la página se queda con el valor de `initial`.

## Volver a pedir un dato

Una `query` pide su dato al abrirse la página. Para pedirlo otra vez sin recargar:

```dart
OutlinedButton(onPressed: cart.lines.refresh, child: const Text('Reload'))
```

| Para | Escribe |
|---|---|
| recargar | `lines.refresh()` |
| pedir con otro argumento | `orders.setArg(filter)`; con el mismo valor no pide nada |
| refrescar después de escribir | `commandWith(repo.add, invalidates: (CartViewModel s) => [s.lines])` |

Cada llamada nueva de una query cancela la anterior: un `setArg` por tecla deja una sola petición en curso. `query` y `command` se explican en [Estado](estado.md#datos-del-servidor).

## Contenido bajo demanda

Un `FutureBuilder` envía su dato después de la página, pero siempre lo envía. Para algo que casi nadie abre (un menú de 750 categorías, las reseñas de un producto, el contenido de un diálogo), `LazyPiece` es una parte que el servidor renderiza solo cuando el navegador la pide.

:::bench bench-lazy-piece
:::

```dart
ExpansionTile(
  name: 'departments',
  title: Text(department.name),
  children: [
    LazyPiece<List<Category>>(
      id: 'branch-${department.slug}', // names the piece in the page
      load: (request) => categories.branch(department.slug), // runs only when asked for
      builder: (context, branch) => Column(children: [
        for (final c in branch) Link(href: c.url, child: Text(c.name)),
      ]),
      fallback: Link(href: department.url, child: const Text('See all')),
    ),
  ],
)
```

La página lleva el `fallback`. Cuando ocurre el `trigger`, el navegador pide la misma página con `?thor-piece=branch-food`, el servidor responde solo esa parte y el navegador la pone en lugar del `fallback`.

| `trigger:` | Cuándo se pide |
|---|---|
| `LazyTrigger.open` (por omisión) | al abrir el `ExpansionTile`, el `Dialog` o el `Drawer` que la contiene |
| `LazyTrigger.visible` | cuando se acerca a la pantalla |
| `LazyTrigger.idle` | al terminar de cargar la página |

- Sin JavaScript, o si la petición falla, la página se queda con el `fallback`: haz que sea un enlace a una página con el mismo contenido. La siguiente apertura reintenta.
- El `builder` corre dentro de la página: el tema, el idioma, los ViewModels y los datos de su `load` están disponibles. Por eso el `load` de la página también corre para cada parte; mantenlo ligero (o en [caché](red-y-servidor.md#caché-y-metadatos)) y deja lo costoso en el `load` de la parte.
- Un `Watch` o un botón dentro de la parte funcionan. Un `FutureBuilder` o una `query` dentro se esperan, y un `LazyPiece` anidado se pide por su cuenta.
- No lo pongas dentro de `Watch.list`: las filas se clonan y el `id`, que va en la URL, se repetiría ([THOR-R035](../../errores/THOR-R035.md)).
- Pasa por el mismo middleware y los mismos guards que la página y se sirve con `noindex`. Un `id` que la página no tiene responde `404`, y un `NotFound()` del `load` de la parte responde su estado.

> **Nota:** Un sitio estático no tiene quién responda la petición: conserva el `fallback`.

## Actualizar una parte de la página desde el servidor

`LazyPiece` espera un disparador. Otros tres widgets usan la misma petición (la URL de la página más `thor-piece=<id>`) cuando la parte ya viene con la página y lo que cambia es lo de adentro: las filas siguientes de una lista, los resultados de una búsqueda, el contenido de un diálogo. En todos el `load` de la página lee la query y la página dibuja la parte; la respuesta es solo esa parte, y sin JavaScript cada control es un enlace o un formulario `GET` que carga la página completa.

Una `Region` es la parte: se puede pedir sola.

### Cargar la página siguiente de una lista

`LoadMore` dibuja las filas de la página en que estás y un enlace a la siguiente. El navegador pide la misma página con el cursor siguiente, el servidor responde solo las filas nuevas y el enlace siguiente, y reemplazan al enlace.

```dart
class PeoplePage extends ThorPage<People> {
  const PeoplePage();

  @override
  Future<People> load(PageRequest request) =>
      repo.people(cursor: request.uri.queryParameters['cursor']);

  @override
  Widget build(BuildContext context, PageState<People> state) => Column(
    children: [
      LoadMore(
        id: 'people',
        items: [for (final p in state.data.items) PersonCard(p)],
        next: state.data.next, // null en la última página: sin enlace
        child: const Text('Cargar más'),
      ),
    ],
  );
}
```

Una lectura al backend por clic y sin recargar la página. El enlace es `<a href="?cursor=…" rel="next">`: sin JavaScript, con un clic con modificador, para un buscador y cuando la petición falla, el visitante va a la página siguiente. El resto de la query (`?q=pizza`) se conserva. `trigger: LoadMoreTrigger.visible` carga solo cuando el enlace se acerca a la pantalla (scroll infinito). `items` y el enlace son hermanos en el padre que los contiene: pon el widget en el `Column`, `Grid` o `Wrap` de las filas. `child` es el contenido del enlace (un `Text`, un `Container`), no un botón.

### Una búsqueda que se actualiza al escribir

`Form(live:)` nombra una región. Mientras el visitante escribe (350 ms después de la última tecla, `liveDelay`) o presiona Enter, el navegador le pide a la página esa región con los campos del formulario como query, pone la respuesta en la región y escribe la misma query en la barra de direcciones sin añadir una entrada al historial. El campo no se vuelve a dibujar, así que el cursor y el foco se quedan donde estaban, y la respuesta a una tecla anterior se descarta.

```dart
Column(
  children: [
    Form(
      formMethod: FormMethod.get,
      live: 'results',
      child: TextFormField(name: 'q'),
    ),
    Region(
      id: 'results',
      child: Column(
        children: [
          LoadMore(id: 'people', items: rows, next: next, child: const Text('Cargar más')),
        ],
      ),
    ),
  ],
)
```

Sin JavaScript el formulario se envía y la página carga con `?q=`. Un `LoadMore` dentro de la región sigue funcionando tras cada búsqueda: su enlace lleva la query actual. Deja el formulario fuera de la región.

### Un diálogo para muchos elementos

Una página con un diálogo por producto repite el mismo marcado cientos de veces. Dale a la página un solo `Dialog` con una `Region` vacía, y haz que el enlace de cada producto pida la región propia de ese producto:

```dart
Column(
  children: [
    Dialog(
      id: 'product',
      child: const Region(id: 'product-body', child: SizedBox.shrink()),
    ),
    for (final p in products)
      Link(
        href: RouteUrl('/shop/${p.slug}'),
        fetch: const FragmentFetch(
          piece: 'detail',
          into: 'product-body',
          open: 'product',
        ),
        child: ProductCard(p),
      ),
  ],
)

// la página propia del producto
Region(id: 'detail', child: ProductDetail(product))
```

Un clic pide `/shop/mug?thor-piece=detail`, la región del diálogo la recibe y el diálogo se abre; un segundo clic en el mismo producto solo lo reabre. Sin JavaScript, con un clic con modificador o si la petición falla, el enlace va a la página del producto. La página del catálogo lleva las tarjetas y un diálogo vacío, y el contenido de cada producto llega cuando alguien lo abre.

- El `load` de la página corre también para la petición del fragmento: mantenlo ligero, o dale a la página `cache:` (la caché de páginas guarda también sus fragmentos).
- Un `id` es único en la página y usa letras, dígitos, `-`, `_` y `.`. Una `Region` dentro de una `Region` o de una `LazyPiece` se pide por su ruta completa (`results:people`).
- Un `Watch` o un botón dentro de la parte funcionan; un estado que la parte trae se enlaza cuando llega.
- Un sitio estático no tiene quién responda: `LoadMore` y `Region` dibujan su contenido y los enlaces son enlaces simples.

## Siguientes pasos

:::cards
- [Estado](estado.md) — `query`, `command` y `QueryBuilder`
- [Servidor y acciones](red-y-servidor.md) — `FutureBuilder`, caché y acciones
- [Listas largas](listas-largas.md) — cientos de filas que cambian en vivo
:::
