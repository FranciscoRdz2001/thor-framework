# State

Combine computed values, lists, controllers and server data in a ViewModel (`ThorState`).

:::flutter Flutter: `ChangeNotifier`, `ListenableBuilder`, `FutureBuilder` · Thor: `ThorState`, `Watch`, `query` and `command`

## Computed values

State fields and `Watch` are covered in [Interactivity](interactivity.md). A computed value (`derived`) is recalculated once per change and shared by every `Watch` that reads it; a method that filters a list runs again on every read.

:::bench bench-state-derived
:::

```dart
class Quake {
  const Quake(this.id, this.place, this.mag);
  final String id;
  final String place;
  final double mag;
}

class QuakesViewModel extends ThorState {
  final all = state(<Quake>[]);
  final minMag = state(0.0);

  late final visible = derived(
    () => all.value.where((q) => q.mag >= minMag.value).toList(),
  );

  List<Quake> rows() => visible.value;
  String count() => '${visible.value.length}';
  String keyOf(Quake q) => q.id;
  String placeOf(Quake q) => q.place;
}
```

It is declared as `late final` and read with `.value`. A computed value only reads: writing a field inside it is [THOR-B035](../../errores/en/THOR-B035.md), and the event that changes the data goes in a ViewModel method.

## Lists

`Watch.list` shows one row per item. The key is the data's id, never the index, and each text in the row comes from a ViewModel method or from a property of the item.

```dart
Watch.list(
  todoList.rows,
  itemKey: todoList.idOf,
  each: (row) => Row(
    children: [
      row.watch(todoList.isDone, builder: (done) => Text(done ? '☑' : '☐')),
      Expanded(child: row.text(todoList.title)),
      TextButton(
        onPressed: todoList.remove.withArg(row.key),
        child: const Text('Remove'),
      ),
    ],
  ),
)
```

:::example state-todo
:::

To add, remove or change an item, assign a new list to `.value`: the browser updates only the rows that changed. A list of your own classes with `toJson()` and `factory fromJson` goes in `state<List<Order>>(const [])`; `toJson()` takes no parameters, and the class may live in another workspace package; a class without them needs `encode:` and `decode:` ([THOR-S041](../../errores/en/THOR-S041.md)).

| In the row | You write | Notes |
|---|---|---|
| A text | `row.text(orders.customerOf)` or `row.text((o) => o.customer)` | the function can only read a `String`, `int`, `num`, `double` or `bool` property |
| A variant | `row.watch((o) => o.isOffer, builder: …)` | `bool` or enum; with an `int`, a ViewModel method and `count:` |
| A widget parameter | `semanticLabel: row.bind(todos.titleOf)` | `tooltip:`, `hintText:` and the like |
| A link | `row.link(links.urlOf, child: Text(…))` | an unsafe URL (`javascript:`) is dropped |
| An attribute with no parameter | `row.attribute(AttributeName.data('state'), links.stateOf, child: …)` | `data-*`, `aria-*` |
| A text in your own element | `row.bindText((o) => '${o.id}')` | a cell or a link with no element of its own for the text |
| The text of an option | `DropdownMenuItem(value: …, child: row.text((o) => o.label))` | the `<option>` holds the text, with no `<span>` (an `<option>` only takes text) |
| The text of a field | `row.attribute(AttributeName.value, (o) => o.code, child: TextField(maxLines: 3))` | a one-line field takes `value`; a multi-line one (`<textarea>`) takes it as its content |
| A color | `Container(color: row.color((o) => o.hex))` | `#rrggbb`, `rgb()`, `hsl()` or a keyword (`red`); any other text leaves the color unset. Inside the row; in any `Color` parameter |

`row.key` is the row's id, of the type `itemKey` returns. An operation inside the function (`o.name.trim()`, `o.id > 1`) is not a property: it is [THOR-B030](../../errores/en/THOR-B030.md), and it is solved with a ViewModel method.

> **Important:** `todos.titleById(row.key)` written directly in a parameter is evaluated once, on the server, with the template's key: new rows end up empty, with no error ([THOR-S034](../../errores/en/THOR-S034.md)). Use `row.bind` or `row.text`.

`container:` decides the widget that holds the rows; by default it is a `Column`, which centers its children as in Flutter. For full-width rows: `container: (rows) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows)`. For hundreds of rows, see [Long lists](long-lists.md).

### One list per instance

With `withArg`, a method with an argument gives each instance of a widget a different list: in a category tree, each department shows only its branches.

```dart
List<Category> branchOf(String slug) => branches.value[slug] ?? const [];

Watch.list(
  categories.branchOf.withArg(department.slug),
  itemKey: categories.slugOf,
  each: (row) => row.text(categories.nameOf),
)
```

### Trees

`Watch.tree` is a list whose rows hold their children, at any depth: `children` gives an item's children and `each` puts `children` where they go. The browser draws every level with the same template, a tree that arrives later from a `query` too. Keys are unique in the whole tree.

```dart
class Node {
  const Node(this.id, this.label, [this.children = const []]);
  final String id;
  final String label;
  final List<Node> children;
}

List<Node> childrenOf(Node n) => n.children;

Watch.tree(
  editor.roots,
  itemKey: editor.idOf,
  children: editor.childrenOf,
  each: (row, children) => ExpansionTile(
    title: row.text(editor.labelOf),
    children: [children],
  ),
)
```

### Sets and booleans

A `state(false)` field has `toggle()`, and a `state(<String>{})` set has `add`, `remove`, `toggle` and `contains`. Each one assigns a new value.

```dart
final expanded = state(false);
final picked = state(<String>{});

void toggleMore() => expanded.toggle();
void pick(String name) => picked.toggle(name);
bool isPicked(String name) => picked.contains(name);
```

:::example state-set
:::

## Controls and controllers

A control calls the method with its value: a `String` from a `TextField`, a `bool` from a `Checkbox` or a `Switch`, a `double` from a `Slider`. Without `onChanged`, the control is disabled, as in Flutter.

```dart
void setName(String value) => name.value = value;
void setQuantity(double value) => quantity.value = value.round();

TextField(onChanged: order.setName)
Slider(value: 1, min: 1, max: 6, divisions: 5, onChanged: order.setQuantity)
```

:::example state-form
:::

`TextEditingController`, `FocusNode`, `ScrollController`, `PageController` and `DialogController` are ViewModel fields, with Flutter's names. A `Timer` works inside a method. Each controller drives a single view.

```dart
final name = TextEditingController(text: 'Ana');
final nameFocus = FocusNode();
// AlertDialog(controller: profile.confirm, …)
final confirm = DialogController();

void edit() => nameFocus.requestFocus();
void askToSave() => confirm.open();
void save() {
  confirm.close();
  saved.value = true;
  Timer(const Duration(seconds: 2), () => saved.value = false);
}
```

:::example state-controllers
:::

To ask or notify from a ViewModel method without declaring a dialog, use `confirm()` and `toast()` ([Dialogs and menus](dialogs-and-menus.md#ask-and-notify-from-code)).

| You want to | You write |
|---|---|
| Scroll with animation | `await list.animateTo(0, duration: …, curve: Curves.easeOut)` |
| Scroll without animation | `list.jumpTo(y)` |
| Start further down | `ScrollController(initialScrollOffset: 120)` |
| Move the cursor or select | `name.selection = TextSelection(baseOffset: 0, extentOffset: 3)` |
| A `select` or a segmented button that follows a field (also a `local:` one, which the browser changes at load) | `DropdownButton(valueWatch: editor.deviceId, …)`, `DropdownButtonFormField(valueWatch: …)`, `SegmentedButton(selectedWatch: …)`; the method returns the value as text (an enum's name) |
| Go to another URL from a method | `PageNavigator.go(url)`, with the URL built on the server ([Routes and navigation](navigation.md)) |
| Submit a form to the server | [Forms](forms.md) |

### `PageView` and `PageController`

`PageController` moves a `PageView` with `jumpToPage` and `animateToPage`, and `page` tells which page it is on. `onPageChanged` receives the index when scrolling ends.

```dart
// PageView(controller: pages, onPageChanged: changed, …)
final pages = PageController();
final shown = state(0);

void changed(int page) => shown.value = page;
void first() => pages.jumpToPage(0);
```

:::example state-pages
:::

> **Difference from Flutter:** `onPageChanged` fires when scrolling ends, not when passing the middle of the page. There is no `viewportFraction`: each page fills the whole view, and `keepPage` is accepted with no effect.

## Instances and lifecycle

Each ViewModel is a top-level `final` instance, and several pages can use the same one. For two instances of one class, give each its own `key`. A field with `cookie:` or `local:` keeps its value across reloads and page changes ([Patterns](patterns.md#preferences)).

```dart
class ScoreViewModel extends ThorState {
  ScoreViewModel({super.key});
}

final home = ScoreViewModel(key: 'home');
final away = ScoreViewModel(key: 'away');
```

:::example state-keyed
:::

### `onHydrated` and `dispose`

`onHydrated()` runs once, when the ViewModel activates in the browser, and `dispose()` when it ends. Start whatever you need there and stop it on the way out.

```dart
class ClockViewModel extends ThorState {
  final seconds = state(0);
  Timer? timer;

  @override
  void onHydrated() {
    timer = Timer.periodic(
      const Duration(seconds: 1),
      (t) => seconds.value = t.tick,
    );
  }

  @override
  void dispose() => timer?.cancel();
}
```

:::example state-lifecycle
:::

Neither of them runs on the server. `dispose()` runs when the ViewModel's last element leaves the page, such as a removed row or a variant that does not come back, and when the page closes. An error in either one goes to the console, and the other ViewModels keep working.

A ViewModel with `onHydrated` activates only on the pages that use it. For one that must run across the whole app, such as a session clock, declare `global` with a literal `true`:

```dart
class SessionClockViewModel extends ThorState {
  @override
  bool get global => true; // wakes on every page
}
```

> **Difference from Flutter:** In Flutter a ViewModel lives as long as the widget tree provides it. The browser loads one page at a time, so a ViewModel lives on the pages that use it, or on all of them with `global`.

## `ValueNotifier` and `ValueListenableBuilder`

A state field is a `ValueNotifier`: `addListener`, `removeListener` and `ValueListenableBuilder` work as in Flutter.

:::example state-notifier
:::

Inside the ViewModel, listen in `onHydrated()` and stop listening in `dispose()`: `open.addListener(_saved)` and `open.removeListener(_saved)`.

| You want to | You write |
|---|---|
| React to a `bool` or an enum | `ValueListenableBuilder<bool>(valueListenable: panel.open, …)` |
| Show a `String` or an `int` | `Watch(panel.label)` or `Watch.field(panel.name)` ([THOR-S013](../../errores/en/THOR-S013.md)) |
| Listen to a change inside the ViewModel | `open.addListener(_f)` |
| Combine two fields (`Listenable.merge`) | a ViewModel method (`String label() => …`) and `Watch` |

A standalone `ValueNotifier` or `ChangeNotifier` as a field does not update in the browser ([THOR-B033](../../errores/en/THOR-B033.md)): turn it into `state(...)`.

## Server data

A ViewModel runs in the browser and cannot use a database or credentials. Declare a `query` field to read or a `command` field to write with a server function: that function runs only on the server and never travels to the browser.

```dart
class CartViewModel extends ThorState {
  // Server functions that ask the request's repository:
  // cartLines(), ordersPage(int page), addToCart(String sku).
  final lines = query(cartLines);
  final page = queryWith(ordersPage, arg: 0);
  final add = commandWith(addToCart);

  bool adding() => add.pending.value;
  void next() => page.setArg(page.arg.value + 1);
}

FilledButton(onPressed: cart.add.run.withArg('mug'), child: const Text('Add'))
OutlinedButton(onPressed: cart.lines.refresh, child: const Text('Reload'))
```

A query has `data`, `loading`, `error`, `errorKind` and `arg`; a command has `pending`, `error`, `errorKind` and `result`. When a command succeeds, the page's queries come back in the same response.

| You want | You write |
|---|---|
| A command to refresh only some queries | `invalidates: (CartViewModel s) => [s.lines]` |
| A read-only command not to clear the page cache | `writes: false` |
| To wait for the result | `final r = await add.run(sku)`: `null` if it failed, never throws |
| A row's pending indicator | `remove.pendingFor(id)` |
| A timeout other than the default 30 s | `timeout: Duration(seconds: 5)`, or `ThorApp(callTimeout:)` |
| An argument with several fields (commands too) | a class with `toJson()` and `fromJson`, or a record of simple values |
| To read in a query or a command what the page loaded | `PageRequest.current.loaded<Doc>()` (while the page and its queries draw; a command or a browser `refresh` is another request and has none) |

Calls to `run` are queued: two taps go out in order and none is lost. A new query call cancels the previous one, so a `setArg` per keystroke leaves a single request in flight; `setArg` with the same value requests nothing and `refresh()` requests again.

> **Caution:** Any user who opens the page can call its queries and commands. The function reads the session with `PageRequest.current` and authorizes what it reads or writes:
>
> ```dart
> Future<List<User>> allUsers() async {
>   final user = PageRequest.current.context.get(currentUser);
>   if (!user.isAdmin) {
>     throw const HttpError(StatusCode.forbidden, 'You do not have access.');
>   }
>   return database.users();
> }
> ```

### Data not needed at render time

A `query` also runs on the server at render time, and navigation waits for it. For data that search engines and the top of the page do not need, `ssr: false` sends the page instantly in a loading state, and the browser requests the data on load. Without JavaScript, the page stays in the loading state: do not put there anything that must always be visible.

```dart
final reviews = query(shop.reviews, ssr: false);
final related = queryWith(shop.related, arg: 'mug', ssr: false);
```

### `QueryBuilder`

`lines.snapshot` is Flutter's `AsyncSnapshot` over the query, and `QueryBuilder` is its `FutureBuilder`.

:::bench bench-state-query
:::

The `builder` runs on the server, once per state (waiting, ready, with error), and the browser switches between them. Whatever depends on the data goes through the ViewModel (`Watch`, `row.text`, `QueryError`), never through `snapshot.data` read in the `builder` ([THOR-S037](../../errores/en/THOR-S037.md)).

`errorKind` tells why it failed (`network`, `timeout`, `aborted`, `unauthorized`, `forbidden`, `validation`, `client`, `server`). Generic texts are written once, in the app's language:

```dart
ThorApp.router(
  routerConfig: router,
  serverMessages: const ServerMessages(
    network: 'No connection',
    timeout: 'The server took too long',
    generic: 'Something went wrong',
    signIn: 'Sign in again',
  ),
);
```

For a custom message, throw `HttpError(503, 'No connection')` in the server function; the text of an ordinary `Exception` never reaches the user. A value that changes without being requested is covered in [Live data](live-data.md).

## What fits in a ViewModel

A ViewModel runs in the browser. The following fits; anything else is rejected by the build with a [THOR-B012](../../errores/en/THOR-B012.md) and its fix.

- state fields, methods, getters, `withArg` and `batch`; computed values with `late final x = derived(() => …)`;
- the ViewModel's `static const` and `static final` fields;
- your data classes, enums and extensions, with dot shorthands (`status.value = .loading`, `case .idle:`, `== .done`, `.make(1)`);
- `DateTime`, `Duration`, `TimeOfDay`, `Set`, `RegExp`, `Uri`, patterns, `async`/`await`, `try`/`catch` (with `FormatException.message`), `jsonEncode`/`jsonDecode`;
- the controllers, `Timer` and the common helpers of `package:collection`.

What does not fit: `==` between records or classes with `operator ==`, generators (`sync*`), and `NumberFormat` or `DateFormat`: format on the server. Which packages work and where: [Pub packages](pub-packages.md).

| Code | Cause |
|---|---|
| [THOR-S001](../../errores/en/THOR-S001.md) | `Watch(() => …)`: a closure instead of a method |
| [THOR-S011](../../errores/en/THOR-S011.md) | a callback that is a closure and uses a ViewModel |
| [THOR-S012](../../errores/en/THOR-S012.md) | a ViewModel created outside the top level |
| [THOR-S030](../../errores/en/THOR-S030.md) | the `Watch.list` key is neither `String` nor `int` |

## Next steps

:::cards
- [Patterns](patterns.md) — commands, errors and optimistic state
- [Live data](live-data.md) — values the server sends without being asked
- [Testing](testing.md) — test a ViewModel without a browser
:::
