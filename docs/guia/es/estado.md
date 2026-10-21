# Estado

Combina en un ViewModel (`ThorState`) valores calculados, listas, controladores y datos del servidor.

:::flutter Flutter: `ChangeNotifier`, `ListenableBuilder`, `FutureBuilder` · Thor: `ThorState`, `Watch`, `query` y `command`

## Valores calculados

Los campos de estado y `Watch` están en [Interactividad](interactividad.md). Un valor calculado (`derived`) se recalcula una vez por cambio y lo comparten todos los `Watch` que lo leen; un método que filtra una lista se ejecuta de nuevo en cada lectura.

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

Se declara como `late final` y se lee con `.value`. Un valor calculado solo lee: escribir un campo dentro es [THOR-B035](../../errores/THOR-B035.md), y el evento que cambia el dato va en un método del ViewModel.

## Listas

`Watch.list` muestra una fila por elemento. La clave es el id del dato, nunca el índice, y cada texto de la fila sale de un método del ViewModel o de una propiedad del elemento.

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

Para agregar, quitar o cambiar un elemento, asigna una lista nueva a `.value`: el navegador actualiza solo las filas que cambiaron. Una lista de tus clases con `toJson()` y `factory fromJson` va en `state<List<Order>>(const [])`; `toJson()` no recibe parámetros, y la clase puede estar en otro paquete del workspace; una clase sin ellos necesita `encode:` y `decode:` ([THOR-S041](../../errores/THOR-S041.md)).

| En la fila | Escribes | Notas |
|---|---|---|
| Un texto | `row.text(orders.customerOf)` o `row.text((o) => o.customer)` | la función solo puede leer una propiedad `String`, `int`, `num`, `double` o `bool` |
| Una variante | `row.watch((o) => o.isOffer, builder: …)` | `bool` o enum; con un `int`, un método del ViewModel y `count:` |
| Un parámetro de un widget | `semanticLabel: row.bind(todos.titleOf)` | `tooltip:`, `hintText:` y similares |
| Un enlace | `row.link(links.urlOf, child: Text(…))` | una URL insegura (`javascript:`) se descarta |
| Un atributo sin parámetro | `row.attribute(AttributeName.data('state'), links.stateOf, child: …)` | `data-*`, `aria-*` |
| Un texto en tu propio elemento | `row.bindText((o) => '${o.id}')` | una celda o un enlace sin elemento propio para el texto |
| El texto de una opción | `DropdownMenuItem(value: …, child: row.text((o) => o.label))` | el `<option>` lleva el texto, sin `<span>` (un `<option>` solo admite texto) |
| El texto de un campo | `row.attribute(AttributeName.value, (o) => o.code, child: TextField(maxLines: 3))` | un campo de una línea lleva `value`; uno multilínea (`<textarea>`) lo lleva como contenido |
| Un color | `Container(color: row.color((o) => o.hex))` | `#rrggbb`, `rgb()`, `hsl()` o una palabra (`red`); otro texto deja el color sin definir. Dentro de la fila; en cualquier parámetro `Color` |

`row.key` es el id de la fila, del tipo que devuelve `itemKey`. Una operación dentro de la función (`o.name.trim()`, `o.id > 1`) no es una propiedad: es [THOR-B030](../../errores/THOR-B030.md), y se resuelve con un método del ViewModel.

> **Importante:** `todos.titleById(row.key)` escrito directamente en un parámetro se evalúa una vez, en el servidor, con la clave de la plantilla: las filas nuevas quedan vacías y sin error ([THOR-S034](../../errores/THOR-S034.md)). Usa `row.bind` o `row.text`.

`container:` decide el widget que contiene las filas; por omisión es un `Column`, que centra a los hijos como en Flutter. Para filas a todo el ancho: `container: (rows) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows)`. Para cientos de filas, consulta [Listas largas](listas-largas.md).

### Una lista por instancia

Con `withArg`, un método con argumento da una lista distinta a cada instancia de un widget: en un árbol de categorías, cada departamento muestra solo sus ramas.

```dart
List<Category> branchOf(String slug) => branches.value[slug] ?? const [];

Watch.list(
  categories.branchOf.withArg(department.slug),
  itemKey: categories.slugOf,
  each: (row) => row.text(categories.nameOf),
)
```

### Datos fijos: búsqueda, «cargar más» y fila elegida

Una lista que vive en tu app como `const` (importada de un JSON o escrita a mano) no se copia al ViewModel: sus métodos la leen por su nombre, también desde otro archivo. El estado guarda solo lo que cambia (el texto de búsqueda, cuántas filas se ven, la fila elegida) y `Watch.list` muestra el resultado. Las tarjetas son widgets a los que pasas `row.text(...)` o `row.bind(...)`, así siguen reactivas sin una segunda copia de los datos.

```dart
// lib/data/catalog.dart
class Shop {
  const Shop(this.id, this.name, this.city);
  final String id;
  final String name;
  final String city;
}

const catalog = [
  Shop('a', 'Alpha', 'Lima'),
  Shop('b', 'Beta', 'Quito'),
  Shop('c', 'Gamma', 'Lima'),
];
```

```dart
// lib/finder_view_model.dart
import 'package:thor_ui/thor_ui.dart';

import 'data/catalog.dart';

class FinderViewModel extends ThorState {
  final query = state('');
  final shown = state(8);
  final selected = state('');

  late final matches = derived(
    () => [
      for (final s in catalog)
        if (s.name.toLowerCase().contains(query.value.toLowerCase())) s,
    ],
  );

  List<Shop> rows() => matches.value.take(shown.value).toList();
  String keyOf(Shop s) => s.id;
  String nameOf(Shop s) => s.name;
  bool hasMore() => matches.value.length > shown.value;

  Shop? get current {
    for (final s in catalog) {
      if (s.id == selected.value) return s;
    }
    return null;
  }

  String currentName() => current?.name ?? '';
  String currentCity() => current?.city ?? '';

  void search(String text) {
    query.value = text;
    shown.value = 8;
  }

  void more() => shown.value += 8;
  void select(String id) => selected.value = id;
}

final finder = FinderViewModel();
```

```dart
Column(children: [
  TextField(onChanged: finder.search),
  Watch.list(
    finder.rows,
    itemKey: finder.keyOf,
    each: (row) => InkWell(
      onTap: finder.select.withArg(row.key),
      child: ListTile(title: row.text(finder.nameOf)),
    ),
  ),
  Watch(
    finder.hasMore,
    builder: (bool more) => more
        ? TextButton(onPressed: finder.more, child: const Text('Cargar más'))
        : const SizedBox.shrink(),
  ),
  Watch(finder.currentName), // the selected row: one place, no copy per row
])
```

### Árboles

`Watch.tree` es una lista cuyas filas llevan a sus hijos, a cualquier profundidad: `children` da los hijos de un item y `each` pone `children` donde van. El navegador dibuja cada nivel con la misma plantilla, también un árbol que llega después de un `query`. Las keys son únicas en todo el árbol.

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

### Conjuntos y booleanos

Un campo `state(false)` tiene `toggle()`, y un conjunto `state(<String>{})` tiene `add`, `remove`, `toggle` y `contains`. Cada uno asigna un valor nuevo.

```dart
final expanded = state(false);
final picked = state(<String>{});

void toggleMore() => expanded.toggle();
void pick(String name) => picked.toggle(name);
bool isPicked(String name) => picked.contains(name);
```

:::example state-set
:::

## Controles y controladores

Un control llama al método con su valor: `String` de un `TextField`, `bool` de un `Checkbox` o un `Switch`, `double` de un `Slider`. Sin `onChanged`, el control queda deshabilitado, como en Flutter.

```dart
void setName(String value) => name.value = value;
void setQuantity(double value) => quantity.value = value.round();

TextField(onChanged: order.setName)
Slider(value: 1, min: 1, max: 6, divisions: 5, onChanged: order.setQuantity)
```

:::example state-form
:::

`TextEditingController`, `FocusNode`, `ScrollController`, `PageController` y `DialogController` son campos del ViewModel, con los nombres de Flutter. Un `Timer` funciona dentro de un método. Cada controlador maneja una sola vista.

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

Para preguntar o avisar desde un método del ViewModel sin declarar un diálogo, usa `confirm()` y `toast()` ([Diálogos y menús](dialogos-y-menus.md#preguntar-y-avisar-desde-el-código)).

| Quieres | Escribes |
|---|---|
| Desplazar con animación | `await list.animateTo(0, duration: …, curve: Curves.easeOut)` |
| Desplazar sin animación | `list.jumpTo(y)` |
| Empezar más abajo | `ScrollController(initialScrollOffset: 120)` |
| Mover el cursor o seleccionar | `name.selection = TextSelection(baseOffset: 0, extentOffset: 3)` |
| Que un `select` o un segmentado siga un campo (también uno `local:`, que el navegador cambia al cargar) | `DropdownButton(valueWatch: editor.deviceId, …)`, `DropdownButtonFormField(valueWatch: …)`, `SegmentedButton(selectedWatch: …)`; el método devuelve el texto del valor (el nombre de un enum) |
| Ir a otra URL desde un método | `PageNavigator.go(url)`, con la URL construida en el servidor ([Rutas y navegación](navegacion.md)) |
| Enviar un formulario al servidor | [Formularios](formularios.md) |

### `PageView` y `PageController`

`PageController` mueve un `PageView` con `jumpToPage` y `animateToPage`, y `page` dice en qué página está. `onPageChanged` recibe el índice cuando el desplazamiento termina.

```dart
// PageView(controller: pages, onPageChanged: changed, …)
final pages = PageController();
final shown = state(0);

void changed(int page) => shown.value = page;
void first() => pages.jumpToPage(0);
```

:::example state-pages
:::

> **Diferencia con Flutter:** `onPageChanged` avisa al terminar el desplazamiento, no al pasar la mitad de la página. No hay `viewportFraction`: cada página ocupa toda la vista, y `keepPage` se acepta sin efecto.

## Instancias y ciclo de vida

Cada ViewModel es una instancia `final` de nivel superior, y varias páginas pueden usar la misma. Para dos instancias de una clase, dale a cada una su `key`. Un campo con `cookie:` o `local:` conserva su valor al recargar y al cambiar de página ([Patrones](patrones.md#preferencias)).

```dart
class ScoreViewModel extends ThorState {
  ScoreViewModel({super.key});
}

final home = ScoreViewModel(key: 'home');
final away = ScoreViewModel(key: 'away');
```

:::example state-keyed
:::

### Con retardo, o cada N segundos

Un `Timer` cabe en lite dentro de un ViewModel, en un método o en `onHydrated`. Guárdalo en un campo para reiniciarlo o cancelarlo: un segundo toque empieza la cuenta otra vez, como haría `clearTimeout`.

```dart
class SupportViewModel extends ThorState {
  final copied = state(false);
  final order = query(orderStatus);
  Timer? _revert, _poll;

  void copy() {
    copied.value = true;
    _revert?.cancel();
    _revert = Timer(const Duration(seconds: 2), () => copied.value = false);
  }

  @override
  void onHydrated() {
    _poll = Timer.periodic(const Duration(seconds: 5), (t) => order.refresh());
  }

  @override
  void dispose() {
    _revert?.cancel();
    _poll?.cancel();
  }
}
```

`Future.delayed` también funciona en un método `async`. Para dejar de sondear cuando se cumple una condición (un pedido llega a su estado final), cancela el timer en el método que lo lee. El servidor nunca corre estos timers. Para un flujo que el servidor empuja, `events()` ([Datos vivos](datos-vivos.md)) no necesita sondeo.

### `onHydrated` y `dispose`

`onHydrated()` se ejecuta una vez, cuando el ViewModel se activa en el navegador, y `dispose()` cuando termina. Inicia ahí lo que necesites y detenlo al salir.

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

Ninguno de los dos se ejecuta en el servidor. `dispose()` se ejecuta cuando el último elemento del ViewModel sale de la página, como una fila quitada o una variante que no vuelve, y al cerrar la página. Un error en cualquiera de los dos va a la consola, y los demás ViewModels siguen funcionando.

Un ViewModel con `onHydrated` se activa solo en las páginas que lo usan. Para uno que debe correr en toda la app, como un reloj de sesión, declara `global` con un literal `true`:

```dart
class SessionClockViewModel extends ThorState {
  @override
  bool get global => true; // wakes on every page
}
```

> **Diferencia con Flutter:** En Flutter un ViewModel vive mientras lo provee el árbol de widgets. El navegador carga una página a la vez, así que un ViewModel vive en las páginas que lo usan, o en todas con `global`.

## `ValueNotifier` y `ValueListenableBuilder`

Un campo de estado es un `ValueNotifier`: `addListener`, `removeListener` y `ValueListenableBuilder` funcionan como en Flutter.

:::example state-notifier
:::

Dentro del ViewModel, escucha en `onHydrated()` y deja de escuchar en `dispose()`: `open.addListener(_saved)` y `open.removeListener(_saved)`.

| Quieres | Escribes |
|---|---|
| Reaccionar a un `bool` o un enum | `ValueListenableBuilder<bool>(valueListenable: panel.open, …)` |
| Mostrar un `String` o un `int` | `Watch(panel.label)` o `Watch.field(panel.name)` ([THOR-S013](../../errores/THOR-S013.md)) |
| Escuchar un cambio dentro del ViewModel | `open.addListener(_f)` |
| Combinar dos campos (`Listenable.merge`) | un método del ViewModel (`String label() => …`) y `Watch` |

Un `ValueNotifier` o un `ChangeNotifier` suelto como campo no se actualiza en el navegador ([THOR-B033](../../errores/THOR-B033.md)): conviértelo en `state(...)`.

## Datos del servidor

Un ViewModel corre en el navegador y no puede usar una base de datos ni credenciales. Declara un campo `query` para leer o `command` para escribir con una función del servidor: esa función se ejecuta solo en el servidor y nunca viaja al navegador.

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

Una query tiene `data`, `loading`, `error`, `errorKind` y `arg`; un command, `pending`, `error`, `errorKind` y `result`. Cuando un command termina bien, las queries de la página vuelven en la misma respuesta.

| Quieres | Escribes |
|---|---|
| Que un command actualice solo algunas queries | `invalidates: (CartViewModel s) => [s.lines]` |
| Que un command que solo lee no vacíe la caché de páginas | `writes: false` |
| Esperar el resultado | `final r = await add.run(sku)`: `null` si falló, nunca lanza |
| El indicador de espera de una fila | `remove.pendingFor(id)` |
| Otro plazo que los 30 s por omisión | `timeout: Duration(seconds: 5)`, o `ThorApp(callTimeout:)` |
| Un argumento con varios datos (también en un comando) | una clase con `toJson()` y `fromJson`, o un record de valores simples |
| Leer en una query o un comando lo que cargó la página | `PageRequest.current.loaded<Doc>()` (al pintar la página y sus queries; un comando o un `refresh` del navegador es otro request y no lo tiene) |

Las llamadas a `run` se encolan: dos toques salen en orden y ninguno se pierde. Una llamada nueva de una query cancela la anterior, así que un `setArg` por tecla deja una sola petición en curso; `setArg` con el mismo valor no pide nada y `refresh()` vuelve a pedir.

> **Cuidado:** Cualquier usuario que abra la página puede llamar a sus queries y commands. La función lee la sesión con `PageRequest.current` y autoriza lo que lee o escribe:
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

### Datos que no hacen falta al renderizar

Una `query` también se ejecuta en el servidor al renderizar, y la navegación la espera. Para un dato que no necesitan los buscadores ni la parte superior de la página, `ssr: false` envía la página al instante en estado de espera, y el navegador pide el dato al cargar. Sin JavaScript, la página se queda en espera: no pongas ahí lo que debe verse siempre.

```dart
final reviews = query(shop.reviews, ssr: false);
final related = queryWith(shop.related, arg: 'mug', ssr: false);
```

### `QueryBuilder`

`lines.snapshot` es el `AsyncSnapshot` de Flutter sobre la query, y `QueryBuilder` es su `FutureBuilder`.

:::bench bench-state-query
:::

El `builder` se ejecuta en el servidor, una vez por estado (esperando, listo, con error), y el navegador cambia entre ellos. Lo que depende del dato va por el ViewModel (`Watch`, `row.text`, `QueryError`), nunca por `snapshot.data` leído en el `builder` ([THOR-S037](../../errores/THOR-S037.md)).

`errorKind` dice por qué falló (`network`, `timeout`, `aborted`, `unauthorized`, `forbidden`, `validation`, `client`, `server`). Los textos genéricos se escriben una vez, en el idioma de la app:

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

Para un mensaje propio, lanza `HttpError(503, 'No connection')` en la función del servidor; el texto de una `Exception` corriente nunca llega al usuario. Un valor que cambia sin pedirlo está en [Datos en vivo](datos-vivos.md).

## Qué cabe en un ViewModel

Un ViewModel se ejecuta en el navegador. Cabe lo siguiente; cualquier otra cosa la rechaza la compilación con un [THOR-B012](../../errores/THOR-B012.md) y su arreglo.

- campos de estado, métodos, getters, `withArg` y `batch`; valores calculados con `late final x = derived(() => …)`;
- campos `static const` y `static final` del ViewModel;
- tus clases de datos, enums y extensiones, con atajos de punto (`status.value = .loading`, `case .idle:`, `== .done`, `.make(1)`);
- `DateTime`, `Duration`, `TimeOfDay`, `Set`, `RegExp`, `Uri`, patrones, `async`/`await`, `try`/`catch` (con `FormatException.message`), `jsonEncode`/`jsonDecode`;
- los controladores, `Timer` y las ayudas comunes de `package:collection`.

No caben `==` entre records o clases con `operator ==`, generadores (`sync*`) ni `NumberFormat` o `DateFormat`: formatea en el servidor. Qué paquetes funcionan y dónde: [Paquetes de pub](paquetes.md).

| Código | Causa |
|---|---|
| [THOR-S001](../../errores/THOR-S001.md) | `Watch(() => …)`: un closure en lugar de un método |
| [THOR-S011](../../errores/THOR-S011.md) | un callback que es un closure y usa un ViewModel |
| [THOR-S012](../../errores/THOR-S012.md) | un ViewModel creado fuera del nivel superior |
| [THOR-S030](../../errores/THOR-S030.md) | la clave de `Watch.list` no es `String` ni `int` |

## Siguientes pasos

:::cards
- [Patrones](patrones.md) — commands, errores y estado optimista
- [Datos en vivo](datos-vivos.md) — valores que el servidor envía sin que se pidan
- [Pruebas](pruebas.md) — probar un ViewModel sin navegador
:::
