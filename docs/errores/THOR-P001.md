# THOR-P001 · Dos rutas atrapan las mismas URLs

**Dónde:** `thor_server` · `Router` (al arrancar).

## Qué pasó

Dos páginas tienen la misma forma de URL, p. ej. `/item/:id` y `/item/:slug`.

## Por qué

Un parámetro es un comodín: las dos rutas coinciden con exactamente las mismas URLs y una nunca se alcanzaría.

## Cómo se arregla

```dart
// WRONG
ThorRoute('/item/:id', const ItemPage()),
ThorRoute('/item/:slug', const ItemBySlugPage()),
```

```dart
// RIGHT
ThorRoute('/item/:id', const ItemPage()),
ThorRoute('/item/by-slug/:slug', const ItemBySlugPage()),
```

[Todos los códigos](README.md)
