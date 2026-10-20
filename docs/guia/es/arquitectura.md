# Arquitectura de una app

Organiza tu app en View, ViewModel, Repository y Service, como en la guía de arquitectura de Flutter; el repositorio y el servicio corren en el servidor.

:::flutter Flutter: `ChangeNotifier`, `Provider`, `go_router` · Thor: `ThorState`, middleware, `ThorRouter`

El ejemplo es una lista de pedidos que se pueden cancelar, escrita capa por capa en Flutter y en Thor.

:::layers orders
:::

## Las capas

Cada capa de la [guía de arquitectura de Flutter](https://docs.flutter.dev/app-architecture/concepts) tiene su equivalente en Thor. La vista solo habla con su ViewModel, y el ViewModel con el repositorio.

| Capa | En Flutter | En Thor |
|---|---|---|
| View | un widget | un `StatelessWidget` |
| ViewModel | un `ChangeNotifier` | un ViewModel (`ThorState`) en el navegador; `load` y las acciones de la página en el servidor |
| Repository | una clase con interfaz | la misma clase, en el servidor |
| Service | un cliente HTTP envuelto en una clase | `ThorHttpClient` envuelto en una clase, en el servidor |
| Dominio (opcional) | casos de uso | funciones o clases de Dart, cuando un ViewModel combina varios repositorios |

Las tablas de recomendaciones usan los niveles de Flutter: muy recomendado, recomendado o condicional.

## Separación de responsabilidades

La vista muestra datos y avisa de los eventos; el ViewModel decide qué ocurre.

```dart
// WRONG (THOR-S011): the view decides, and the closure never reaches the browser
TextButton(
  onPressed: () async {
    await cancelOrder(order.id);
    orders.list.refresh();
  },
  child: const Text('Cancel'),
)

// RIGHT: the view calls a method of its ViewModel
TextButton(
  onPressed: viewModel.cancel.run.withArg(order.id),
  child: const Text('Cancel'),
)
```

En Thor la separación es obligatoria: un closure que usa un ViewModel no llega al navegador ([THOR-S011](../../errores/THOR-S011.md)).

| Recomendación | Nivel | En Thor |
|---|---|---|
| Capas de datos y de interfaz bien definidas | Muy recomendado | la vista y el ViewModel solo usan las funciones públicas de la capa de datos ([Capa de datos](capa-datos.md)) |
| El patrón repository | Muy recomendado | un repositorio por tipo de dato |
| Views y ViewModels | Muy recomendado | un `StatelessWidget` y un `ThorState` por pantalla ([Capa de interfaz](capa-ui.md)) |
| Nada de lógica en los widgets | Muy recomendado | cada callback es un método del ViewModel |
| `ChangeNotifier` y `Listenable` | Condicional | no aplica: el navegador actualiza lo que lee `Watch` ([Estado](estado.md)) |
| Una capa de dominio | Condicional | funciones o clases de Dart, solo si un ViewModel combina varios repositorios |

## Fuente única de verdad

Cada dato tiene un dueño, el repositorio. El ViewModel no guarda una copia que editar: guarda la respuesta de una `query` y calcula lo demás con un valor calculado (`derived`).

```dart
class OrdersViewModel extends ThorState {
  // The browser's only copy is the repository's last answer.
  final list = query(listOrders);

  // Computed from it, never a second list to keep in sync.
  late final count = derived(() => list.data.value?.length ?? 0);

  String countText() => '${count.value} orders';
}

final orders = OrdersViewModel();
```

| Recomendación | Nivel | En Thor |
|---|---|---|
| Modelos de datos inmutables | Muy recomendado | clases con campos `final` y constructor `const` |
| `freezed` o `built_value` | Recomendado | cualquier paquete en el servidor; lo que llega a un ViewModel es JSON con `toJson` y `fromJson` ([Paquetes de pub](paquetes.md)) |
| Modelos de API y de dominio separados | Condicional | un `fromJson` en el repositorio que convierte uno en otro |
| El estado de una lista en la URL (solo Thor) | Recomendado | la búsqueda, la página y los filtros funcionan con enlaces y sin JavaScript ([Servidor y acciones](red-y-servidor.md#listas-paginadas-en-la-url)) |

## Flujo de datos unidireccional

Los datos bajan del repositorio a la vista por una `query` y `Watch`; los eventos suben de la vista al repositorio por un método del ViewModel y un `command`.

:::bench bench-command
:::

Cuando el `command` termina bien, el servidor ejecuta de nuevo las queries de `invalidates:` y las devuelve en la misma respuesta. Ningún dato se actualiza a mano.

| Recomendación | Nivel | En Thor |
|---|---|---|
| Flujo de datos unidireccional | Muy recomendado | `query` y `Watch` hacia la vista; métodos del ViewModel y `command` hacia el repositorio |
| Commands para los eventos del usuario | Recomendado | `command` y `commandWith`, con `pending` y `error` ([Patrones](patrones.md)) |
| Una acción como base y un `command` como mejora (solo Thor) | Recomendado | sin JavaScript solo se ejecuta la acción ([Servidor y acciones](red-y-servidor.md)) |

## La interfaz es función del estado

`build` se ejecuta una vez, en el servidor. Un valor que cambia no se lee en `build`: se pasa a `Watch`, y el navegador actualiza ese texto.

:::flutter
@flutter
```dart no-check
ListenableBuilder(
  listenable: viewModel,
  builder: (context, _) => Text('${viewModel.orders.length} orders'),
)
```
@thor
```dart
Watch(orders.countText)
```
:::

> **Diferencia con Flutter:** El `builder` de Flutter se ejecuta en cada cambio. En Thor, `build` se ejecuta en el servidor, y leer `.value` ahí deja fijo el valor con el que el servidor renderizó la página ([THOR-S015](../../errores/THOR-S015.md)).

| Recomendación | Nivel | En Thor |
|---|---|---|
| Lee `.value` solo en métodos del ViewModel (solo Thor) | Muy recomendado | `build` se ejecuta una vez, en el servidor |
| Una instancia `final` de nivel superior por ViewModel (solo Thor) | Muy recomendado | el navegador arranca con esas instancias ([THOR-S012](../../errores/THOR-S012.md)) |

## Extensibilidad y pruebas

El repositorio es una interfaz y un middleware lo entrega a cada petición, como un `Provider` en Flutter. Cambiar de backend, o usar uno falso en una prueba, es cambiar el argumento del middleware.

```dart
final production = provideOrders(HttpOrdersRepository(OrdersService(apiBase)));
final inTests = provideOrders(FakeOrdersRepository());
```

Ni la vista ni el ViewModel saben cuál reciben. El middleware se escribe en [Capa de datos](capa-datos.md) y las pruebas en [Pruebas](pruebas.md).

| Recomendación | Nivel | En Thor |
|---|---|---|
| Inyección de dependencias | Muy recomendado | un middleware y un `ContextKey` |
| Repositorios abstractos | Muy recomendado | `abstract interface class OrdersRepository` y una implementación por entorno |
| Un router declarativo | Recomendado | `ThorRouter`: cada página es una URL ([Rutas y navegación](navegacion.md)) |
| Nombres por componente | Recomendado | `OrdersPage`, `OrdersViewModel`, `OrdersRepository`, `OrdersService` |
| Probar cada capa sola y todas juntas | Muy recomendado | `test` para ViewModels y repositorios; el cliente de pruebas para las páginas |
| Usar fakes | Muy recomendado | `provideOrders(FakeOrdersRepository())` o `MockTransport` para el backend |

## Autorización

Esta recomendación no existe en Flutter, porque allí el código corre en el dispositivo del usuario. En Thor, `load`, las acciones y las funciones de una `query` o un `command` corren en el servidor, y cualquier usuario que abra la página puede llamarlos.

```dart
Future<List<Order>> myOrders() async {
  final context = PageRequest.current.context;
  if (context.maybeGet(currentUser) == null) {
    throw const HttpError(StatusCode.unauthorized);
  }
  return context.get(ordersKey).list();
}
```

> **Cuidado:** Autoriza dentro de cada `load`, acción, `query` y `command`, con el usuario de la petición ([Sesión y seguridad](sesion-y-seguridad.md)).

## Siguientes pasos

:::cards
- [Estructura del proyecto](estructura.md) — en qué carpeta va cada archivo
- [Capa de interfaz](capa-ui.md) — la vista y las dos mitades del ViewModel
- [Capa de datos](capa-datos.md) — repositorios, servicios e inyección
:::
