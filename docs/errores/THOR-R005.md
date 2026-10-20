# THOR-R005 · `@keyframes` anidado

**Dónde:** `thor_ui` · hojas de estilo de la app.

## Qué pasó

Una regla `keyframes(...)` quedó dentro de otra (un selector, un `@media`).

## Por qué

CSS solo acepta `@keyframes` en el nivel superior de la hoja.

## Cómo se arregla

```dart
// WRONG
WindowSizeClass.medium.media([css.keyframes('spin', {...})])
```

```dart
// RIGHT
css.keyframes('spin', {...}),              // arriba
WindowSizeClass.medium.media([css('.x').props(...)])
```

[Todos los códigos](README.md)
