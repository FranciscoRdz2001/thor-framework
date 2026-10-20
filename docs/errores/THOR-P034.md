# THOR-P034 · Una `query` o un `command` lanzó una excepción que no es `HttpError`

**Dónde:** `thor_server` · la llamada de una `query`/`command` (solo con `thor dev`: primera línea de `detail` en el overlay y línea `[thor]` de la consola del servidor).

## Qué pasó

La función de una `query` o de un `command` lanzó `Exception('Sin conexión')` (o un `StateError`, un error de la base de datos…). La página muestra «Something went wrong» (el mensaje `generic` de la app) y el texto de la excepción no llega al navegador; `thor dev` además lo reporta como error de la página.

## Por qué

Una excepción corriente puede traer rutas, SQL o claves: thor nunca la manda a un visitante. Solo el mensaje de un `HttpError` (o de un `Redirect`) es para quien mira la pantalla. En Flutter un `FutureBuilder` enseña `snapshot.error` tal cual; aquí ese paso es explícito.

## Cómo se arregla

```dart
// WRONG: the page shows "Something went wrong", not this text
Future<List<Product>> fetch(bool fail) async {
  if (fail) throw Exception('Sin conexión');
  ...
}
```

```dart
// RIGHT: an HttpError carries a status and a message for the visitor
Future<List<Product>> fetch(bool fail) async {
  if (fail) throw const HttpError(503, 'Sin conexión');
  ...
}
```

En la página: `QueryError(products)` pinta ese mensaje (y `snapshot.error` en un `QueryBuilder`). Más en [Estado](../guia/es/estado.md#datos-del-servidor).

[Todos los códigos](README.md)
