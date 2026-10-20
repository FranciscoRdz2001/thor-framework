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

## Siguientes pasos

:::cards
- [Estado](estado.md) — `query`, `command` y `QueryBuilder`
- [Servidor y acciones](red-y-servidor.md) — `FutureBuilder`, caché y acciones
- [Listas largas](listas-largas.md) — cientos de filas que cambian en vivo
:::
