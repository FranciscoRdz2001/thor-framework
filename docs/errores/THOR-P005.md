# THOR-P005 · Falta un valor en `request.context`

**Dónde:** `thor_server` · `RequestContext.get`.

## Qué pasó

Un `load`, una acción, un guard o un widget pidió `request.context.get(key)` y ningún middleware de los grupos que contienen la ruta puso esa llave.

## Por qué

La ruta no está en los `children` del `Group` cuyo middleware pone el valor (por ejemplo, quedó al lado del grupo de las páginas con sesión, no dentro), o el middleware solo lo pone en algunos casos (una sesión que puede faltar).

## Cómo se arregla

```dart
// WRONG
// ReportsPage.load lee request.context.get(currentUser)
final ThorRouter router = ThorRouter([
  Group(middleware: [session], children: [panelRoute]),
  reportsRoute,
]);
```

```dart
// RIGHT
final ThorRouter router = ThorRouter([
  Group(middleware: [session], children: [panelRoute, reportsRoute]),
]);

// o, si el valor puede faltar, leerlo como opcional:
final user = request.context.maybeGet(currentUser);
if (user == null) throw Redirect.found(loginRoute.link());
```

[Todos los códigos](README.md)
