# THOR-P014 · Una ruta o un enlace mal formado

**Dónde:** `thor_ui/router.dart` · `ThorRoute(…)` y `ThorRouter([…])` al arrancar, y `route.link(…)` al enlazar.

## Qué pasó

- El path de un `ThorRoute` no empieza con `/`, tiene un segmento vacío (`//`), repite un parámetro, pone `*resto` antes del final, usa un tipo que no es `:id:int` o tiene `[ ] ( ) * :` en un segmento fijo.
- `SitemapRoute` o `RobotsRoute` no están en el primer nivel de la tabla.
- `link(…)` recibe un parámetro que la ruta no tiene, le falta uno, o su valor no es del tipo (`:id:int` pide un `int`).

## Por qué

La tabla de rutas es la única definición de cada URL: el router y los enlaces la comparten, así que un error ahí se ve al arrancar o al enlazar, no como un 404 en producción.

## Cómo se arregla

```dart
// WRONG
final itemRoute = ThorRoute('item/:id', const ItemPage());
itemRoute.link({'id': '7', 'extra': 1});
```

```dart
// RIGHT
final itemRoute = ThorRoute('/item/:id:int', const ItemPage());
itemRoute.link({'id': 7});
```

[Todos los códigos](README.md)
