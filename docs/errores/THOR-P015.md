# THOR-P015 · `request.param` de un parámetro que la ruta no tiene

**Dónde:** `thor_server` · `PageRequest.param` / `paramInt`.

## Qué pasó

La página pidió `request.param('nombre')`, pero su `ThorRoute` no tiene `:nombre` en el path.

## Por qué

Los parámetros vienen del path de la ruta (`/article/:slug` → `param('slug')`); un nombre que no está es un error de la app, no un dato que falte.

## Cómo se arregla

```dart
// WRONG
final articleRoute = ThorRoute('/article/:slug', const ArticlePage());
request.param('id');
```

```dart
// RIGHT
request.param('slug');
```

[Todos los códigos](README.md)
