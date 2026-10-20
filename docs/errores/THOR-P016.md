# THOR-P016 · Un middleware de la lista falló

**Dónde:** `thor_server` · la cadena de middleware de un `Group` o de un `ThorRoute` (`chainMiddleware`).

## Qué pasó

Un middleware lanzó un error que no es `Redirect` ni `HttpError`, o llamó `next()` dos veces. El mensaje dice cuál: su nombre (el de la función, o el que le diste con `namedMiddleware`), su lugar en la lista y de qué lista es. La pila es la del error original.

## Por qué

Una lista de middleware es una sola cadena; sin el nombre, un 500 no diría cuál de ellos falló. Un error que viene de más abajo (otro middleware, la página) conserva su propio nombre.

## Cómo se arregla

Arregla ese middleware. Para cortar la petición a propósito usa `throw Redirect(...)`, `throw HttpError(...)` o devuelve una respuesta sin llamar a `next()`:

```dart
// WRONG
Future<ThorResponse> requireUser(PageRequest request, Next next) {
  final user = request.context.get(session);   // StateError without a session
  return next();
}
```

```dart
// RIGHT
Future<ThorResponse> requireUser(PageRequest request, Next next) {
  if (request.context.maybeGet(session) == null) {
    throw Redirect.found(loginRoute.link());
  }
  return next();
}
```

Un middleware que devuelve una función (`requireRole('admin')`) se nombra con `namedMiddleware('requireRole(admin)', …)`.

[Todos los códigos](README.md)
