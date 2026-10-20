# Si vienes de Flutter

Escribes los mismos widgets de Flutter; cambian el lugar donde corre `build`, la forma de manejar el estado y la navegación.

:::flutter Flutter: `build` corre en el dispositivo · Thor: `build` corre en el servidor

## Lo que se mantiene

| Área | Igual que en Flutter |
|---|---|
| Layout | `Row`, `Column`, `Container`, `Expanded`, `ListView` |
| Estructura de pantalla | `Scaffold`, `AppBar`, `NavigationBar` |
| Entradas | `Form`, `TextFormField`, `FilledButton`, `onPressed`, `onChanged` |
| Tema | `ThemeData`, `Theme.of(context).colorScheme` y `.textTheme`, que siguen el modo oscuro |

La web agrega enlaces en cualquier widget (`Link`, `FilledButton(href:)`), variantes con `.when()` para el tamaño de pantalla, el puntero y el modo oscuro, e imágenes responsivas con `srcSet`.

## Estado y eventos

Lo que cambia sin recargar vive en un ViewModel (`ThorState`): una clase con campos de estado y métodos. `Watch` muestra un valor y el método se pasa como callback. Un `StatefulWidget` compila, pero `setState` no cambia nada en el navegador ([THOR-S014](../../errores/THOR-S014.md)).

:::bench bench-counter-step
:::

> **Diferencia con Flutter:** Un `ThorState` equivale a un `ChangeNotifier`, no a `State<T>`: pertenece a la pantalla, no a un widget, y vive en una variable de nivel superior. Por eso las clases se llaman `CounterViewModel` u `OrdersViewModel`.

El detalle está en [Interactividad](interactividad.md).

## Navegación y diálogos

Cada pantalla es una ruta y cada diálogo forma parte de la página que lo abre, sin llamadas imperativas como `Navigator.push` o `showDialog`.

### Rutas

Cada pantalla es una URL con su página en la tabla de rutas, como en `go_router`. Se llega a ella con un enlace, no con `push`.

:::flutter
@flutter
```dart no-check
TextButton(
  onPressed: () => context.go('/orders/42'),
  child: const Text('See order'),
)
```
@thor
```dart
Link(
  href: orderRoute.link({'id': 42}),
  child: const Text('See order'),
)
```
:::

Desde un método del ViewModel se navega con `PageNavigator.go(url)`; desde una acción, con `Redirect`. Más en [Rutas y navegación](navegacion.md).

### Diálogos

El diálogo está en la página, cerrado, junto al botón que lo abre. Es un `<dialog>` nativo: el foco y la tecla Escape funcionan sin código.

:::flutter
@flutter
```dart no-check
showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('Charge \$187.00?'),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
    ],
  ),
);
```
@thor
```dart
class ChargeButton extends StatelessWidget {
  const ChargeButton({super.key});

  @override
  Widget build(BuildContext context) => DialogTrigger(
    dialog: AlertDialog(
      title: const Text(r'Charge $187.00?'),
      actions: [DialogClose(child: TextButton(child: const Text('Cancel')))],
    ),
    child: FilledButton(child: const Text('Charge')),
  );
}
```
:::

Desde un método del ViewModel, `await confirm('…')` pide confirmación y `toast('…')` muestra un aviso. Más en [Diálogos y menús](dialogos-y-menus.md).

## Pantalla y puntero

El tamaño de la pantalla y el puntero los resuelve el navegador: el widget declara cada variante y no consulta valores en `build`.

### Tamaño de pantalla

El servidor no conoce la pantalla y el navegador hace el layout. Un valor cambia según la clase de tamaño con `.when()`.

:::flutter
@flutter
```dart no-check
final wide = MediaQuery.sizeOf(context).width >= 600;
return wide
    ? Row(children: items)
    : Column(children: items);
```
@thor
```dart
Grid(
  layout: const GridLayout(columns: 1, gap: 16)
      .when(medium: const GridLayout(columns: 3)),
  children: items,
)
```
:::

Más en [Layout](layout.md#responsivo).

### Al pasar el puntero

El cambio al pasar el puntero es una variante del valor: no necesita estado y el navegador la aplica sin JavaScript.

:::flutter
@flutter
```dart no-check
MouseRegion(
  onEnter: (_) => setState(() => hover = true),
  onExit: (_) => setState(() => hover = false),
  child: Container(color: hover ? Colors.indigo.shade50 : Colors.white),
)
```
@thor
```dart
Container(
  decoration: BoxDecoration(
    color: const Color(0xFFFFFFFF).when(hover: const Color(0xFFEEF0FF)),
  ),
)
```
:::

## Formularios y datos

La validación corre en el navegador y los datos de la página se cargan en el servidor antes de renderizar.

### Validación

Cada regla es un `Validator` que el navegador comprueba sin recargar; `onSubmit` se ejecuta cuando todos los campos son válidos.

:::flutter
@flutter
```dart no-check
TextFormField(
  validator: (value) =>
      value == null || value.isEmpty ? 'Add a name.' : null,
)
```
@thor
```dart
TextFormField(
  name: 'name',
  validators: const [Validator.required('Add a name.')],
)
```
:::

Más en [Formularios](formularios.md).

### Datos de la página

Los datos se cargan en el servidor, en `load`, antes de renderizar. Un dato lento se envía después con `defer`, en la misma respuesta, y `FutureBuilder` lo muestra al llegar.

:::flutter
@flutter
```dart no-check
// in initState: _featured = widget.repo.featured();
FutureBuilder<List<Product>>(
  future: _featured,
  builder: (context, snapshot) => snapshot.hasData
      ? ProductGrid(snapshot.data!)
      : const CircularProgressIndicator(),
)
```
@thor
```dart
FutureBuilder<List<Product>>(
  future: state.data.featured, // defer(repo.featured()) in load
  builder: (context, snapshot) => snapshot.hasData
      ? ProductGrid(snapshot.data!)
      : const Skeleton(height: 240),
)
```
:::

Más en [Leer datos](leer-datos.md).

## Nombres de Flutter que no existen

Estos nombres compilan, pero el editor los tacha con la alternativa en el mensaje. Si el código se ejecuta, falla con ese mismo mensaje y un enlace a esta tabla.

| En Flutter | En Thor |
|---|---|
| `MediaQuery.of(context)` | `.when(medium: …)` en el valor; `ResponsiveVisibility` para mostrar u ocultar; `100.dvh` en `Styled` para el alto de la ventana |
| `LayoutBuilder`, `OrientationBuilder` | `LayoutScope` con `.when(container: {…})` |
| `showDialog(…)` | un `AlertDialog` en la página, abierto con `DialogTrigger` o `DialogController`; `await confirm('…')` desde un ViewModel |
| `showModalBottomSheet(…)` | un `ModalBottomSheet` en la página, abierto con `DialogTrigger` o `DialogController` |
| `showDatePicker(…)`, `showTimePicker(…)` | `DatePickerFormField`, `DatePickerDialog` o `TimePickerDialog` ([Entradas](componentes-entradas.md)) |
| `Navigator.push(…)`, `Navigator.pop(…)` | `Link(href: route.link())`; `PageNavigator.go(url)` desde un ViewModel; `Redirect` desde una acción |
| `Navigator.pop(context)` al tocar un ítem del cajón | `DialogClose(child: ListTile(onTap: viewModel.method))`: cierra y ejecuta el método |
| `ScaffoldMessenger.of(context).showSnackBar(…)` | `toast('…')` desde un ViewModel; `Redirect(url).flash('…')` para la página siguiente |
| `StreamBuilder` | un campo de un ViewModel mostrado con `Watch` ([Estado](estado.md)) |
| `BottomNavigationBar` | `NavigationBar` en `Scaffold(bottomNavigationBar:)` |
| `CustomPaint` | no existe: usa SVG o una imagen |

## Diferencias de comportamiento

| En Flutter | En Thor |
|---|---|
| `ListView.builder` sobre una lista que cambia | `Watch.list(viewModel.rows, itemKey: viewModel.idOf, each: …)`, con `row.key` tipado ([Estado](estado.md)) |
| `Expanded` en una `Column` sin alto | conserva el alto de su contenido ([Layout](layout.md)) |
| `Stack` solo con hijos `Positioned` | mide 0 de alto; necesita un padre con tamaño o un hijo sin `Positioned` |
| `GestureDetector` con un closure | `GestureDetector` o `Gesture` con un método de un ViewModel ([Gestos](gestos.md)) |
| `EdgeInsetsDirectional`, `AlignmentDirectional` | el navegador aplica la dirección del texto; si el servidor necesita conocerla, falla con [THOR-R037](../../errores/THOR-R037.md) |
| `Scaffold.of(context).openDrawer()` | `Scaffold(drawer:)` agrega su botón de menú al `AppBar` |
| un canal de un color del tema (`.red`, `.value`) | falla con [THOR-R023](../../errores/THOR-R023.md); `withValues(alpha:)` funciona |
| tocar un control antes de que cargue el JavaScript | responde lo nativo (enlaces, diálogos, formularios); los demás toques se repiten al cargar |

## Siguientes pasos

:::cards
- [Tu primera app](primera-app.md) — una tienda con carrito, formulario y rutas, paso a paso
- [Layout](layout.md) — `Row`, `Column`, `Stack`, cuadrículas y responsivo
- [Componentes](componentes.md) — cada widget con su ejemplo, su código y sus parámetros
:::
