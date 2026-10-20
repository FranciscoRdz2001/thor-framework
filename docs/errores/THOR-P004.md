# THOR-P004 · `next()` dos veces en un middleware

**Dónde:** `thor_server` · un middleware de un grupo (`Group(middleware:)`).

## Qué pasó

Un middleware (`(request, next)`, en `Group(middleware: [...])`) llamó a `next()` más de una vez en el mismo request.

## Por qué

`next()` corre todo lo de abajo (caché, guards, acción, loads y render). Llamarlo dos veces renderizaría la página dos veces, correría la acción dos veces y mezclaría dos respuestas; el servidor lo corta con un 500.

## Cómo se arregla

```dart
// WRONG
Future<ThorResponse> handle(PageRequest r, Next next) async {
  await next(); // para medir
  return next();
}
```

```dart
// RIGHT
Future<ThorResponse> handle(PageRequest r, Next next) async {
  final response = await next(); // una vez; guarda la respuesta
  return response.withHeaders({'server-timing': 'app'});
}
```

[Todos los códigos](README.md)
