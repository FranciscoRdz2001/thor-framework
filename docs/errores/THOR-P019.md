# THOR-P019 · `PageRequest.current` fuera de una query o un comando

**Dónde:** `thor_server` · `PageRequest.current`.

## Qué pasó

El código leyó `PageRequest.current` fuera de una función de query o de comando (`query(fn)` o `command(fn)` en un `ThorState`).

## Por qué

Una función de query o de comando no recibe el request (así cualquier método de un repositorio sirve), y llega a él —la sesión que dejó el middleware, las cookies— con `PageRequest.current`. thor lo pone solo mientras la función corre: al pintar la página, al contestar un `refresh` y al correr un comando que pidió el navegador. Un `load`, una acción o un middleware ya reciben el request como parámetro.

## Cómo se arregla

```dart
// WRONG — in a load
Future<Profile> load(PageRequest request) => repo.forUser(PageRequest.current);
```

```dart
// RIGHT — a load uses its parameter; a query function reads current
Future<Profile> load(PageRequest request) => repo.forUser(request);

Future<Profile> info() async {                     // query(repo.info)
  final user = PageRequest.current.context.get(currentUser);
  return db.profile(user);
}
```

[Todos los códigos](README.md)
