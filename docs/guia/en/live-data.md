# Live data

Show data that changes while the user reads: events the server sends, data that gets fetched again and content loaded on demand.

:::flutter Flutter: `StreamBuilder` over a `Stream` · Thor: `events()` in a ViewModel and `Watch`

## Server events

`events` is a `query` the server keeps up to date. The page goes out with the value of `initial` and the browser opens a connection to a `ThorRoute.stream` route in the same app; each event updates `data`, with no polling. A hidden tab pauses the stream and resyncs when you return.

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

The server side is a route that emits `ServerEvent`. With an `id` on each event, the browser reconnects on its own and resumes from the last one received (`request.lastEventId`).

```dart no-check
ThorRoute<void>.stream('/markets/stream', (request) async* {
  final since = request.lastEventId; // null on the first connection
  yield* feed.since(since).map((t) => ServerEvent(jsonEncode(t.changed), event: 'tick', id: '${t.n}'));
});
```

| To | Write |
|---|---|
| make each event the new value | `events<T>(url, event: 'x')`; `data` is the decoded JSON |
| make each event carry only what changed | `key: 'field'` with `T = List<X>` |
| not have the page wait for the first value | omit `initial:` (the page goes out in the waiting state) |
| have `initial` read what the page loaded | `initial: () => PageRequest.current.loaded<Doc>().draft` |
| tell the visitor something from the server | `yield ServerEvent.toast('Saved', kind: FlashKind.success)`: any `events()` of the page shows it in the snack bar |
| know whether there is a connection | `feed.connection.value`: `waiting`, `active` or `done` |
| reopen a closed connection | `feed.reconnect()` |

With `key:`, an event carries only the items that changed and the rest keep the same object, so `Watch.list` updates only those rows. The event can be a list (each item replaces the one with its `key`; a new one goes at the end) or `{"upsert": […], "remove": ["S02"], "replace": […]}`. If after a drop the server no longer has what's missing, it sends `{"replace": […]}` with the full list.

The browser opens the connection when some element on the page uses the field, closes it when none is left or when leaving the page, and uses a single one per URL. The route that sends the events is described in [Routes and navigation](navigation.md#endpoints-and-events).

> **Important:** `url`, `event:`, `key:` and `timeout:` are written as literals, and the URL is a route of the app, never another origin. Without JavaScript the page keeps the value of `initial`.

## Fetching data again

A `query` fetches its data when the page opens. To fetch it again without reloading:

```dart
OutlinedButton(onPressed: cart.lines.refresh, child: const Text('Reload'))
```

| To | Write |
|---|---|
| reload | `lines.refresh()` |
| fetch with another argument | `orders.setArg(filter)`; with the same value it fetches nothing |
| refresh after writing | `commandWith(repo.add, invalidates: (CartViewModel s) => [s.lines])` |

Each new call of a query cancels the previous one: a `setArg` per keystroke leaves a single request in flight. `query` and `command` are explained in [State](state.md#server-data).

## On-demand content

A `FutureBuilder` sends its data after the page, but it always sends it. For something almost nobody opens (a menu of 750 categories, a product's reviews, the content of a dialog), `LazyPiece` is a part the server renders only when the browser asks for it.

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

The page carries the `fallback`. When the `trigger` fires, the browser requests the same page with `?thor-piece=branch-food`, the server responds with only that part and the browser puts it in place of the `fallback`.

| `trigger:` | When it's requested |
|---|---|
| `LazyTrigger.open` (default) | when the `ExpansionTile`, `Dialog` or `Drawer` containing it opens |
| `LazyTrigger.visible` | when it nears the screen |
| `LazyTrigger.idle` | when the page finishes loading |

- Without JavaScript, or if the request fails, the page keeps the `fallback`: make it a link to a page with the same content. The next opening retries.
- The `builder` runs inside the page: the theme, the language, the ViewModels and the data from its `load` are available. That's why the page's `load` also runs for each part; keep it light (or [cached](server-and-actions.md#caching-and-metadata)) and leave the expensive work in the part's `load`.
- A `Watch` or a button inside the part work. A `FutureBuilder` or a `query` inside are awaited, and a nested `LazyPiece` is requested on its own.
- Don't put it inside `Watch.list`: the rows are cloned and the `id`, which goes in the URL, would repeat ([THOR-R035](../../errores/en/THOR-R035.md)).
- It goes through the same middleware and guards as the page and is served with `noindex`. An `id` the page doesn't have responds `404`, and a `NotFound()` from the part's `load` responds with its status.

> **Note:** A static site has nothing to answer the request: it keeps the `fallback`.

## Update a part of the page from the server

`LazyPiece` waits for a trigger. Three more widgets use the same request (the page's URL plus `thor-piece=<id>`) when the part already comes with the page and what changes is what is inside: the next rows of a list, the results of a search, the content of a dialog. In all of them the page's own `load` reads the query and the page draws the part; the answer is just that part, and without JavaScript every control is a link or a `GET` form that loads the page whole.

A `Region` is the part: it can be asked for alone.

### Load the next page of a list

`LoadMore` draws the rows of the page you are on and a link to the next one. The browser asks for the same page with the next cursor, the server answers only the new rows and the next link, and they replace the link.

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
        next: state.data.next, // null on the last page: no link
        child: const Text('Load more'),
      ),
    ],
  );
}
```

One backend read per click, and no page reload. The link is `<a href="?cursor=…" rel="next">`: without JavaScript, with a modified click, for a search engine and when the request fails, the visitor goes to the next page. The rest of the query (`?q=pizza`) is kept. `trigger: LoadMoreTrigger.visible` loads by itself when the link comes near the screen (infinite scroll). `items` and the link are siblings in the parent that holds them: put the widget in the `Column`, `Grid` or `Wrap` of the rows. `child` is the link's content (a `Text`, a `Container`), not a button.

### A search that updates as you type

`Form(live:)` names a region. As the visitor types (350 ms after the last key, `liveDelay`) or presses Enter, the browser asks the page for that region with the form's fields as the query, puts the answer in the region and writes the same query in the address bar without adding a history entry. The field is not redrawn, so the caret and the focus stay where they are, and an answer to an earlier keystroke is dropped.

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
          LoadMore(id: 'people', items: rows, next: next, child: const Text('Load more')),
        ],
      ),
    ),
  ],
)
```

Without JavaScript the form submits and the page loads with `?q=`. A `LoadMore` inside the region keeps working after each search: its link carries the current query. Keep the form outside the region.

### One dialog for many items

A page with a dialog per product repeats the same markup hundreds of times. Give the page one `Dialog` with an empty `Region`, and make each product's link fetch that product's own region:

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

// the product's own page
Region(id: 'detail', child: ProductDetail(product))
```

A click asks `/shop/mug?thor-piece=detail`, the region of the dialog receives it and the dialog opens; a second click on the same product only reopens it. Without JavaScript, with a modified click or if the request fails, the link goes to the product's page. The catalog page carries the cards and one empty dialog, and each product's content comes when someone opens it.

- The page's `load` runs for the fragment's request too: keep it light, or give the page `cache:` (the page cache also keeps its fragments).
- An `id` is unique in the page and uses letters, digits, `-`, `_` and `.`. A `Region` inside a `Region` or a `LazyPiece` is asked for by the whole path (`results:people`).
- A `Watch` or a button inside the part work; a state the part brings is bound when it arrives.
- A static site has nothing to answer: `LoadMore` and `Region` draw their content, and the links are plain links.

## Next steps

:::cards
- [State](state.md) — `query`, `command` and `QueryBuilder`
- [Server and actions](server-and-actions.md) — `FutureBuilder`, caching and actions
- [Long lists](long-lists.md) — hundreds of rows that change live
:::
