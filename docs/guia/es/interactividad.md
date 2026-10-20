# Interactividad

Lo que cambia sin recargar la página vive en un ViewModel (`ThorState`). Los widgets lo leen con `Watch` y llaman a sus métodos como callbacks.

:::flutter Flutter: `StatefulWidget` y `setState` · Thor: un ViewModel, `Watch` y sus métodos

## Un ViewModel y sus métodos

Un ViewModel es una clase con campos de estado, `state(valorInicial)`, y métodos que leen y asignan `.value`. Su instancia es una variable `final` de nivel superior, con la que arranca el navegador.

:::bench bench-counter-step
:::

:::flutter
@flutter
```dart no-check
class _CounterState extends State<Counter> {
  int count = 0;

  void increment() => setState(() => count++);

  @override
  Widget build(BuildContext context) =>
      FilledButton(onPressed: increment, child: Text('$count'));
}
```
@thor
```dart {1-8,15}
class CounterViewModel extends ThorState {
  final count = state(0);

  String label() => '${count.value}';
  void increment() => count.value++;
}

final counter = CounterViewModel();

class CounterButton extends StatelessWidget {
  const CounterButton({super.key});

  @override
  Widget build(BuildContext context) =>
      FilledButton(onPressed: counter.increment, child: Watch(counter.label));
}
```
:::

> **Importante:** Un ViewModel creado dentro de un widget o de `build` es otro objeto que el navegador no conoce. El editor lo marca con [THOR-S012](../../errores/THOR-S012.md).

## Mostrar valores

`Watch(counter.label)` muestra un texto que el navegador mantiene actualizado; conserva sus saltos de línea (`\n`) aunque el servidor lo haya dibujado en una sola línea. Con `builder`, `Watch` construye un widget por cada valor posible de un `bool` o un enum: el servidor renderiza todos y el navegador muestra el que corresponde.

:::example state-bool
:::

`Watch(favorite.isSaved, builder: (saved) => …)` recibe el valor de un método; `Watch.field(favorite.saved, builder: …)` lee el campo directamente, sin un método. Un `int` necesita `count:`, con valores de `0` a `count - 1`.

> **Diferencia con Flutter:** El `builder` se ejecuta solo en el servidor, una vez por valor, y no en cada cambio. Todo lo que varía debe salir del valor que recibe o de otro `Watch`.

## Eventos

Pasa el método del ViewModel donde Flutter espera un callback: `onPressed: counter.increment`. Para fijar un argumento, usa `withArg`.

:::example state-enum
:::

Un closure no llega al navegador: el código del widget corre en el servidor y el botón queda sin evento. Si un botón hace varias cosas, escribe un método que las haga.

```dart
// WRONG (THOR-S011): the button does nothing in the browser
OutlinedButton(onPressed: () => counter.increment(), child: const Text('+'))

// RIGHT
OutlinedButton(onPressed: counter.increment, child: const Text('+'))
```

## Campos de texto y controles

Cada control llama al método con su valor: un `String` desde un `TextField`, un `bool` desde un `Checkbox` o un `Switch`, un `double` desde un `Slider`.

:::bench bench-greeting
:::

Como en Flutter, un control sin `onChanged` queda deshabilitado. Los formularios que se envían al servidor están en [Formularios](formularios.md).

## Valores que no se actualizan

`build` corre una vez, en el servidor: leer `.value` ahí deja en el HTML el valor con el que el servidor renderizó la página, y el navegador no lo actualiza. Pasa a `Watch` un método del ViewModel, no su valor.

```dart
// WRONG (THOR-S015): looks right and never changes
Text('Pending: ${orders.pending.value}')

// RIGHT
Watch(orders.pendingLabel)
```

El editor lo marca y `thor dev` lo muestra en la consola.

## Siguientes pasos

:::cards
- [Estado](estado.md) — valores calculados, listas con clave, controladores y ciclo de vida
- [Leer datos](leer-datos.md) — los datos de la página, cargados en el servidor
- [Formularios](formularios.md) — controles, validación y acciones
:::
