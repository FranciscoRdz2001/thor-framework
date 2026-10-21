# Patrones

Escribe en Thor los patrones de la guía de arquitectura de Flutter: commands, errores como resultado, estado optimista, cachés y preferencias.

| Patrón de Flutter | En Thor |
|---|---|
| Command | `command` y `commandWith`, con `pending`, `error` y `result` |
| Result | lo que lanza el repositorio, y `errorKind` en un `command` |
| Optimistic state | un método del ViewModel |
| Key-value data | `state(value, cookie: 'name')` o `state(value, local: 'name')` |
| SQL | tu repositorio, en el servidor, con cualquier base de datos |
| Offline-first | no existe en Thor |

El estado de una lista en la URL está en [Servidor y acciones](red-y-servidor.md#listas-paginadas-en-la-url), y las listas de cientos de filas en [Listas largas](listas-largas.md).

## Commands

Un `command` es una función del servidor con su propio estado: `pending` mientras espera, `error` si falla y `result` con lo que devolvió. Un segundo `run` mientras el primero espera se pone en cola y sale cuando termina el anterior.

:::bench bench-command
:::

:::flutter
@flutter
```dart no-check
ListenableBuilder(
  listenable: viewModel.cancel,
  builder: (context, _) => viewModel.cancel.running
      ? const Text('Cancelling…')
      : FilledButton(
          onPressed: () => viewModel.cancel.execute(order.id),
          child: const Text('Cancel'),
        ),
)
```
@thor
```dart
// lib/modules/orders/widgets/cancel_button.dart
import 'package:thor_ui/thor_ui.dart';

import '../state/orders_view_model.dart';

class CancelButton extends StatelessWidget {
  const CancelButton({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) => Watch(
    orders.cancelling.withArg(id),
    builder: (busy) => busy
        ? const Text('Cancelling…')
        : FilledButton(
            onPressed: orders.cancel.run.withArg(id),
            child: const Text('Cancel'),
          ),
  );
}
```
:::

> **Diferencia con Flutter:** El `Command` de la guía de Flutter ignora `execute` mientras corre; el de Thor encola la llamada. Para impedir una segunda pulsación, oculta el botón mientras espera, como en el código anterior.

`cancelling` es un método del ViewModel que pregunta si esa fila espera: `bool cancelling(String id) => cancel.pendingFor(id);`. Con `cancel.pending`, cancelar una fila bloquearía todas.

> **Importante:** Un `command` necesita JavaScript. Si la página debe funcionar sin él, la base es una acción con su formulario ([Servidor y acciones](red-y-servidor.md)) y el `command` es la mejora.

## Errores como resultado

Un `command` nunca lanza: `run` devuelve `null` si falló y `error` dice por qué. Para decidir según el tipo de fallo, `errorKind` es un enum.

```dart
// lib/modules/orders/state/cancel_failure_view_model.dart
import 'package:thor_ui/thor_ui.dart';

import '../data/orders_scope.dart';

class CancelFailureViewModel extends ThorState {
  final cancel = commandWith(cancelOrder);

  bool needsSignIn() => cancel.errorKind.value == ServerErrorKind.unauthorized;
  bool offline() => cancel.errorKind.value == ServerErrorKind.network;
  String message() => cancel.error.value ?? '';
}

final cancelFailure = CancelFailureViewModel();
```

| `errorKind` | Cuándo |
|---|---|
| `network`, `timeout` | sin respuesta, o fuera del plazo (30 s por omisión) |
| `aborted` | algo fuera del ViewModel canceló la petición |
| `unauthorized`, `forbidden` | 401 y 403 |
| `validation`, `client` | 400 y 422; cualquier otro 4xx |
| `server` | 5xx |

El texto de `error` lo escribes tú: un `HttpError(409, 'The order has already shipped.')` del repositorio llega tal cual, y los textos genéricos salen de `ThorApp(serverMessages:)`. Cómo lanzarlos: [Capa de datos](capa-datos.md#errores-del-backend-a-la-página).

> **Diferencia con Flutter:** No hay una clase `Result`. En `load`, lo que se lanza (`NotFound`, `Redirect`, `HttpError`) decide la página; en un `command`, el resultado son `error`, `errorKind` y `result`.

## Estado optimista

La interfaz cambia antes de que el servidor responda y vuelve atrás si falla. Thor no incluye una ayuda para esto: es un método del ViewModel de tres líneas.

:::bench bench-optimistic
:::

La vista lee `starred` con `Watch.field` y el botón llama a `toggle.withArg(id)`. Úsalo solo cuando el fallo es raro y reversible; un pago o un borrado nunca se muestran como hechos antes de serlo.

> **Consejo:** Un segundo toque mientras espera sale después del primero. Si no quieres dos peticiones, deshabilita el botón mientras `star.pending` es `true`.

## Cachés por etiqueta

Una página puede compartir su HTML entre usuarios durante un tiempo. Con `tags:`, una escritura invalida solo las páginas que dependen de ese dato.

```dart
// lib/modules/orders/pages/orders_summary_page.dart
import 'package:thor_server/thor_server.dart';
import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

import '../data/orders_scope.dart';

class OrdersSummaryPage extends ThorPage<int> {
  const OrdersSummaryPage()
    : super(cache: const Duration(minutes: 5), tags: const ['orders']);

  @override
  Future<int> load(PageRequest request) async =>
      (await request.context.get(ordersKey).list()).length;

  Future<ActionResult?> cancel(PageRequest request) async {
    await request.context.get(ordersKey).cancel(request.param('id'));
    revalidateTag('orders'); // only the pages tagged 'orders' render again
    return null;
  }

  @override
  Widget build(BuildContext context, PageState<int> state) =>
      Text('${state.data} orders');
}
```

La caché solo se comparte entre peticiones sin datos personales, y una escritura correcta ya vacía toda la caché. Con `invalidateOnWrite: false`, solo las etiquetas deciden qué se vacía ([Servidor y acciones](red-y-servidor.md)).

## Preferencias

Un campo de estado con `cookie:` conserva su valor entre páginas y recargas, como `SharedPreferences` en Flutter.

:::flutter
@flutter
```dart no-check
class ThemeViewModel extends ChangeNotifier {
  ThemeViewModel(this._preferences)
    : dark = _preferences.getBool('dark') ?? false;

  final SharedPreferences _preferences;

  bool dark;

  Future<void> toggle() async {
    dark = !dark;
    await _preferences.setBool('dark', dark);
    notifyListeners();
  }
}
```
@thor
```dart
class ThemeViewModel extends ThorState {
  final dark = state(false, cookie: 'theme');

  void toggle() => dark.value = !dark.value;
}

final theme = ThemeViewModel();
```
:::

> **Cuidado:** El usuario puede escribir esa cookie. Úsala para la apariencia de la página, nunca para permisos.

Lo que el servidor no necesita (un borrador, el último filtro) va en `localStorage` con `local:`. No viaja en cada petición ni tiene el límite de una cookie, y las otras pestañas del sitio reciben el cambio.

```dart
class NoteViewModel extends ThorState {
  final draft = state('', local: 'note-draft');

  void edit(String text) => draft.value = text;
}

final note = NoteViewModel();
```

El servidor pinta el valor del código y el navegador pone el guardado al arrancar, así que en Chromium y Firefox se ve un instante el valor inicial. Para lo que se ve al cargar (tema, panel plegado), usa `cookie:`. Si el navegador bloquea el almacenamiento, el valor solo dura mientras la página está abierta, sin errores.

Un ViewModel puede guardar un valor distinto por tienda, documento o cuenta: `localScope:` nombra un campo que el servidor llena para la página, y la clave de almacenamiento es `thor-s.<local>:<su valor>`.

```dart
class CartViewModel extends ThorState {
  final store = state('');                       // la página lo fija al slug de la tienda
  late final items = state(<String>[], local: 'cart', localScope: store);
}

final cart = CartViewModel();
```

La página o el layout lo fija al construirse (`cart.store.value = slug;`, como la localización en [Idiomas](idiomas.md)). El navegador lee el alcance cuando el estado arranca, así que la página de otra tienda parte de su propia clave. Un alcance vacío deja el valor solo en memoria. Declara el campo de alcance antes del que lo usa, en la misma clase, y el que lo usa como `late final` (un inicializador normal no puede leer otro campo).

## Lo que Thor no hace

- **Offline-first.** No hay base de datos en el navegador ni sincronización: una `query` o un `command` sin conexión terminan con `errorKind` en `network`, y `data.value` conserva el último dato recibido.
- **Estado optimista incluido.** Se escribe como un método del ViewModel.
- **Un tipo `Result`.** Los errores se lanzan, o llegan por `error` y `errorKind`.

## Siguientes pasos

:::cards
- [Estado](estado.md) — `query`, `command` y todo lo que cabe en un ViewModel
- [Servidor y acciones](red-y-servidor.md) — `load`, acciones, listas y caché
- [Pruebas](pruebas.md) — el cliente de pruebas y los backends falsos
:::
