# Diálogos y menús

Abre diálogos, hojas, cajones y menús sin escribir `onPressed`: son elementos
nativos del navegador que atrapan el foco y se cierran con Esc.

:::flutter Flutter: `showDialog`, `showModalBottomSheet`, `Scaffold.drawer` · Thor: `AlertDialog`, `ModalBottomSheet`, `Drawer` con `DialogTrigger`

## Abrir un diálogo

`DialogTrigger(dialog:)` convierte a su hijo en el botón que abre el diálogo,
y `DialogClose` en el botón que lo cierra. El diálogo ya está en la página,
cerrado, junto a su botón.

:::bench bench-overlay
:::

Sirve con `AlertDialog`, `Dialog`, `ModalBottomSheet` y `Drawer`. El
navegador cierra el diálogo con Esc y, con `barrierDismissible: true` (por
defecto), con un clic fuera; al cerrar, el foco vuelve al botón. Un botón
dentro de `DialogTrigger` o `DialogClose` funciona sin `onPressed`.

> **Diferencia con Flutter:** `showDialog(context)` y `Navigator.pop` compilan,
> pero el editor los marca como obsoletos y, al renderizar, fallan con un error
> que indica el reemplazo ([Si vienes de Flutter](desde-flutter.md#nombres-de-flutter-que-no-existen)).

`dialog:` también acepta un componente tuyo que construye el diálogo (`DialogTrigger(dialog: const CreateDialog(), …)`): un componente por clase, sin un `AlertDialog` largo dentro del botón.

El hijo no tiene que ser un botón: alrededor de una tarjeta tocable
(`DialogTrigger(dialog: …, child: InkWell(child: Card(…)))`) la tarjeta pasa a
ser un `role="button"` con foco y el diálogo se abre con un clic, Enter o
Espacio. `DialogClose` funciona igual.

Agrega `showClose: true` a un `AlertDialog`, `Dialog`, `ModalBottomSheet` o
`Drawer` y trae su propio botón de cerrar en la esquina, con el nombre
«Cerrar» localizado, para no repetir un `DialogClose` en cada panel. Con
`closeLabel: 'Fermer'` el nombre es el tuyo cuando el texto de la página no
está en el idioma de la app.

`dialog:` admite el diálogo envuelto en `Styled`, `Semantics` o
`ElementAttributes` (se funden en su `<dialog>`), para darle un estilo propio
o un `data-*`:

```dart no-check
DialogTrigger(
  dialog: Styled(
    style: StyleProps(maxWidth: 440.px),
    child: Drawer(child: filters),
  ),
  child: const TextButton(child: Text('Filters')),
)
```

## Diálogo que no bloquea

`Dialog(modal: false)` y `AlertDialog(modal: false)` son un `<dialog open>` sin `showModal`: se ven desde el primer pintado, el resto de la página sigue activa y no hay fondo oscuro, ni bloqueo del scroll ni cierre con Esc. Se cierran con `DialogClose` y se colocan como cualquier caja (con `Positioned`). No admiten `controller` ni `DialogTrigger`.

## Un diálogo que el servidor dibuja abierto

`initiallyOpen: true` hace que el servidor dibuje un diálogo modal que ya se está mostrando cuando llega la página: la página decide a partir de la petición (un parámetro de la consulta, una ruta), así que un enlace de producto que recarga la página llega con el diálogo del producto abierto.

```dart no-check
PageRoute<Widget, Product?>(
  path: 'shop',
  load: (request) => products.byId(request.uri.queryParameters['product']),
  build: (state) => Column(
    children: [
      Dialog(
        id: 'product',
        initiallyOpen: state.data != null,
        child: state.data == null ? const SizedBox.shrink() : ProductDetail(state.data!),
      ),
      for (final p in products.all)
        // Sin JS: el enlace recarga con `?product=` y el diálogo abierto.
        Link(href: RouteUrl('/shop?product=${p.id}'), child: ProductCard(p)),
    ],
  ),
)
```

| | Con JavaScript | Sin JavaScript |
|---|---|---|
| Aspecto | un diálogo modal: fondo oscuro, foco atrapado, Esc, página inerte detrás | un `<dialog>` abierto y no modal, centrado en la ventana; sin fondo oscuro |
| Se cierra con | Esc, clic en el fondo, `DialogClose` | solo `DialogClose` |

El HTML lleva `<dialog open data-thor-open>`. El script en línea y pequeño de la página (el mismo que carga las `Region`; no necesita motor) lo cierra y lo vuelve a mostrar con `showModal()` en cuanto corre, así que puede haber un primer pintado de la forma no modal. Cerrarlo no cambia la URL; `AlertDialog`, `Drawer` y `ModalBottomSheet` aceptan la misma opción (un cajón conserva su `side` y su `width`, y entra deslizándose al mejorarse; sin JavaScript queda fijo contra su borde, sobre la página), y un `Dialog(modal: false)` siempre está abierto.

## Diálogo y botón separados

Cuando el botón y el diálogo están lejos (un diálogo por fila, o uno que abre
un método), nombra el diálogo con `controller:` (un `DialogController`, campo
del ViewModel), `key:` o `id:`, y el botón indica cuál con
`DialogTrigger(controller:)` o `DialogTrigger(id:)`.

```dart
class OrderViewModel extends ThorState {
  final confirm = DialogController();
}

final order = OrderViewModel();

class ConfirmOrderPanel extends StatelessWidget {
  const ConfirmOrderPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      DialogTrigger(
        controller: order.confirm,
        child: const FilledButton(child: Text('Open')),
      ),
      AlertDialog(
        controller: order.confirm,
        title: const Text('Confirm order'),
        actions: [DialogClose(child: const TextButton(child: Text('Done')))],
      ),
    ]);
  }
}
```

`DialogClose` cierra el diálogo que lo contiene. Fuera de un diálogo falla al
renderizar y pide el `id:` del diálogo que debe cerrar.

## Preguntar y avisar desde el código

Desde un método del ViewModel, `confirm(…)` pregunta y `toast(…)` avisa. La
página trae un solo diálogo y un solo aviso para todas las llamadas, con el
estilo del tema.

```dart
Future<void> remove(int id) async {
  if (!await confirm('Delete the order?', confirmLabel: 'Delete')) return;
  await orders.remove(id);
  toast('Order deleted', kind: ToastKind.success);
}
```

:::example state-feedback
:::

| Necesitas | Escribe |
|---|---|
| preguntar desde un método | `await confirm('…', message: …)` |
| avisar desde un método | `toast('…', kind: ToastKind.error)`; `hideToast()` y `clearToasts()` los cierran |
| preguntar antes de una acción | `FilledButton(onPost: …, confirm: ConfirmSpec('…'))` ([Servidor y acciones](red-y-servidor.md#preguntar-antes-de-enviar)) |
| avisar en la página siguiente | `Redirect(url).flash('…')` ([Servidor y acciones](red-y-servidor.md#un-aviso-en-la-página-siguiente)) |
| un diálogo con contenido propio | `AlertDialog` o `Dialog` con un `DialogController` |

El aviso se muestra encima de un cajón o un diálogo abierto. Para un aviso que
depende del estado de la página, usa `SnackBar`
([Avisos](componentes-avisos.md#snackbar)).

## Selector de fecha y hora

`DatePickerDialog` se abre como cualquier diálogo, y la fecha llega a un
método del ViewModel al pulsar OK. Cancelar, Esc o un clic fuera descartan la
elección.

```dart
class DeliveryViewModel extends ThorState {
  final picker = DialogController();
  void setDelivery(DateTime d) {}
}

final delivery = DeliveryViewModel();

class DeliveryPicker extends StatelessWidget {
  const DeliveryPicker({super.key});

  @override
  Widget build(BuildContext context) => Column(children: [
    DialogTrigger(
      controller: delivery.picker,
      child: const FilledButton(child: Text('Delivery date')),
    ),
    DatePickerDialog(
      controller: delivery.picker,
      firstDate: DateTime(2026),
      lastDate: DateTime(2027, 12, 31),
      selectableDayPredicate: (d) => d.weekday < DateTime.saturday,
      onDatePicked: delivery.setDelivery,   // void setDelivery(DateTime d)
    ),
  ]);
}
```

En un formulario, `DatePickerFormField(id:, name:, …)` es el campo completo,
con un botón de calendario, y `TimePickerDialog(controller:, initialTime:,
onTimePicked:)` elige la hora ([Entradas](componentes-entradas.md)).

> **Diferencia con Flutter:** `await showDatePicker(context: …)` no existe: el
> valor llega por `onDatePicked` o por el formulario. `selectableDayPredicate`
> corre en el servidor y recibe cada día como fecha UTC: compara sus campos o
> usa `DateUtils.isSameDay`, no `==` con un `DateTime` local.

## Cajón y hoja inferior

`Drawer` es el cajón lateral y `ModalBottomSheet`, la hoja que sube desde
abajo. El cajón de la app va en el `Scaffold`, como en Flutter, y el `AppBar`
agrega el botón de menú.

```dart
Scaffold(
  appBar: AppBar(title: const Text('Orders')),
  drawer: Drawer(child: Menu()),
  endDrawer: Drawer(child: Filters()),
  body: const OrdersList(),
)
```

:::example cat-drawer
:::

`automaticallyImplyLeading: false` quita el botón y `DrawerButton()` lo coloca
en cualquier lugar. Fuera del `Scaffold`, una hoja o un cajón reciben un
`DialogController` y se abren con `DialogTrigger(controller:)`:

```dart
class ShopViewModel extends ThorState {
  final filters = DialogController();
}

final shop = ShopViewModel();

class FilterSheet extends StatelessWidget {
  const FilterSheet({super.key});

  @override
  Widget build(BuildContext context) => Column(children: [
    DialogTrigger(
      controller: shop.filters,
      child: const TextButton(child: Text('Filters')),
    ),
    ModalBottomSheet(controller: shop.filters, child: Filters()),
  ]);
}
```

> **Diferencia con Flutter:** `Scaffold.of(context).openDrawer()` no existe:
> el cajón lo abre su botón.

### Cerrar el cajón al tocar un ítem

En Flutter, el ítem llama a `Navigator.pop(context)`. En Thor, envuélvelo en
`DialogClose`: cierra el cajón y llama al `onTap`.

```dart
Drawer(
  padding: EdgeInsets.zero,
  child: ListView(children: [
    const DrawerHeader(child: Text('Menu')),
    DialogClose(
      child: ListTile(
        leading: const Icon(Icons.settings),
        title: const Text('Settings'),
        onTap: files.openSettings,   // void openSettings() => toast('…')
      ),
    ),
  ]),
)
```

Si el método decide cuándo cerrar, usa el `DialogController` del cajón
(`menu.close()`). Un enlace dentro de un `Drawer` o un `Popover` lo cierra al
navegar; `closeOnNavigate: false` lo evita.

### Cajón fijo desde un breakpoint

`Drawer(permanentFrom:)` es un cajón en el teléfono y un panel lateral fijo
desde el breakpoint indicado. Va en un `Row`, antes del contenido.

```dart
Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Drawer(
      controller: shop.filters,
      permanentFrom: WindowSizeClass.medium,
      width: 320,                              // the modal sheet
      permanentWidth: 200,                     // the sidebar
      label: 'Filters',
      child: Filters(),
    ),
    Expanded(
      child: Column(children: [
        DialogTrigger(
          controller: shop.filters,
          hiddenFrom: WindowSizeClass.medium,           // nothing to open once it is inline
          child: TextButton(child: const Text('Filters')),
        ),
        const Results(),
      ]),
    ),
  ],
)
```

:::example dialog-permanent-drawer
:::

`permanentFrom` también sirve en `Scaffold(drawer:)` y `endDrawer:`. Da
siempre un `label:` al panel fijo: es lo que anuncia el lector de pantalla.

## Popover y menús

`Popover` muestra cualquier contenido junto a su botón. `PopupMenuButton` es
el menú de opciones de Flutter: elegir una opción cierra el menú y
`onSelected` recibe su `value`.

:::example menu
:::

```dart
PopupMenuButton(
  items: const [                // web: a list, not an itemBuilder: no BuildContext on the server
    PopupMenuItem(value: 'price', child: Text('By price')),
    PopupMenuItem(value: 'name', child: Text('By name')),
  ],
  onSelected: catalog.sort,     // void sort(String field)
  child: const Text('Sort'),
)
```

> **Diferencia con Flutter:** `PopupMenuButton` recibe `items:`, la lista ya
> construida, en lugar de `itemBuilder:`: el servidor renderiza los ítems una
> vez, sin el `BuildContext` del usuario.

`PopupMenuButton<T>` y `PopupMenuItem<T>` son genéricos como en Flutter: `value` y `onSelected` usan el mismo `T` (un `String`, un número, un `bool`, un `enum` o un modelo registrado con `registerJsonModel`), y el método del estado lo recibe ya del tipo `T`.

`Popover` recibe el contenido del botón en `trigger:` y el del panel en
`child:`; `label:` nombra el botón cuando `trigger` no tiene texto.

```dart
Popover(
  trigger: const Icon(Icons.person),
  label: 'Account',
  child: AccountSummary(),
)
```

Para una etiqueta breve al pasar el puntero, usa `Tooltip`
([Contenido](componentes-contenido.md#tooltip)).

### `MenuAnchor`

`MenuAnchor` es el menú con ítems de Flutter. El ancla es el botón que
devuelve `builder` y no hace falta `controller`. Un `MenuItemButton` con
`onPressed` cierra el menú y llama al método; con `href`, es un enlace.

```dart
MenuAnchor(
  builder: (context, controller, child) =>
      const OutlinedButton(child: Text('My account')),
  menuChildren: [
    MenuItemButton(onPressed: account.signOut, child: const Text('Sign out')),
    const MenuItemButton(href: '/orders', leadingIcon: Icon(Icons.list), child: Text('My orders')),
    SubmenuButton(
      menuChildren: [MenuItemButton(href: '/help', child: const Text('Help'))],
      child: const Text('More'),
    ),
  ],
)
```

:::example menu-anchor
:::

| Parámetro | Efecto |
|---|---|
| `MenuItemButton.closeOnActivate` | `false` deja el menú abierto al elegir |
| `MenuAnchor.alignmentOffset` | desplaza el menú |
| `MenuAnchor.style`, `MenuItemButton.style` | `MenuStyle` del panel, `ButtonStyle` de cada fila |

En una página con ViewModel, el menú responde a las flechas, Inicio, Fin y la
primera letra de cada ítem, abre submenús con la flecha derecha y cierra con
Esc. Sin JavaScript, Tab recorre los ítems. `PopupMenuButton` se comporta
igual.

> **Diferencia con Flutter:** El ancla debe ser un botón (`IconButton`,
> `TextButton`…). No existen `onOpen`, `onClose` ni los atajos de teclado.

## Acordeón

`ExpansionTile` es un elemento nativo: el navegador lo abre, lo cierra y lo
encuentra con la búsqueda en la página. Para que solo uno quede abierto, dales
el mismo `name` o usa `ExpansionPanelList`.

```dart
ExpansionPanelList(
  name: 'faq',
  children: [
    ExpansionTile(title: const Text('Is it free?'), children: [const Text('Yes, always.')]),
    ExpansionTile(title: const Text('How do I cancel?'), children: [const Text('From your account settings.')]),
  ],
)
```

:::example accordion
:::

### Acordeón en el teléfono, columna en el escritorio

`ExpansionTile(permanentFrom:)` se abre y se cierra debajo del breakpoint;
desde él, muestra su contenido y el encabezado deja de ser un control. Es el
pie de página habitual de una tienda.

```dart
ExpansionTile(
  permanentFrom: WindowSizeClass.medium,
  title: Text('Help'),
  children: [Link(href: RouteUrl('/shipping'), child: Text('Shipping'))],
)
```

Requiere Chrome 131, Safari 18.4 o Firefox 143; en navegadores anteriores
sigue siendo un acordeón a cualquier ancho.

## Siguientes pasos

:::cards
- [Accesibilidad](accesibilidad.md) — nombres, foco y lectores de pantalla
- [Navegación](componentes-navegacion.md) — `AppBar`, `NavigationBar` y pestañas
- [Estado](estado.md) — el ViewModel que llama a `confirm()` y `toast()`
:::
