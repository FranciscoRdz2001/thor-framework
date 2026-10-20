# THOR-P037 · `PageRequest.loaded<D>()` sin datos cargados

**Dónde:** `thor_server` · `PageRequest.loaded`.

## Qué pasó

El código llamó a `PageRequest.loaded<D>()` cuando el request no tenía datos de `load` (o ningún nivel cargó un `D`).

## Por qué

`loaded<D>()` devuelve lo que cargaron el `load` de la página y el de sus layouts, para el código que solo llega al request con `PageRequest.current` (la función de una query, el `initial` de un `events()`). Esos datos existen mientras la página se pinta y corre sus queries. Un comando o un `refresh` del navegador es otro request, que no vuelve a cargar la página: ahí no hay nada que leer. Y se busca por el valor: si ningún `load` devolvió un `D`, el mensaje lista los tipos que sí devolvieron.

## Cómo se arregla

```dart
// WRONG — a command runs in its own request: the page was not loaded
Future<void> save() async => repo.save(PageRequest.current.loaded<Doc>());
```

```dart
// RIGHT — the page's own drawing reads it; a command takes it as its argument
final feed = events<String>('/doc/stream', initial: () => PageRequest.current.loaded<Doc>().title);

final save = commandWith(repo.save); // Future<void> save(DocEdit edit)
```

[Todos los códigos](README.md)
