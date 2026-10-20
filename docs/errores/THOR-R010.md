# THOR-R010 · `RequestScope.of` fuera de una página

**Dónde:** `thor_ui/router.dart` · `RequestScope.of`.

## Qué pasó

Un widget pidió la petición (`RequestScope.of(context)`) y no se está renderizando una ruta.

## Por qué

Solo las páginas que sirve `RouteHandler` con `WidgetRenderer` publican la petición. Un widget reutilizado en una app estática, un test o un `Cached` compartido no la tiene.

## Cómo se arregla

```dart
// WRONG
final user = RequestScope.of(context).locals['user'];
```

```dart
// RIGHT
// Leerla en el load de la ruta y pasarla por parámetro:
Future<User?> load(PageRequest request) async => request.locals['user'] as User?;
Widget build(BuildContext context, PageState<User?> state) => Header(user: state.data);
```

[Todos los códigos](README.md)
