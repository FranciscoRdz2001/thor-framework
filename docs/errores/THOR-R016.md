# THOR-R016 · Un `unicodeRange` de `FontFace` que no es un rango

**Dónde:** `thor_ui` · `FontFace.css` (al escribir el `@font-face` del tema).

## Qué pasó

`FontFace(unicodeRange:)` no tiene la forma de `unicode-range` de CSS (`U+0000-00FF, U+2013`, `U+4??`).

## Por qué

El valor va tal cual a la hoja: uno mal formado haría que el navegador descarte la regla (la fuente nunca se usa) o, con `;` y `}`, abriría otra regla.

## Cómo se arregla

```dart
// WRONG
FontFace('Inter', url: '/fonts/inter-latin.woff2', unicodeRange: 'latin')
```

```dart
// RIGHT: el que imprime `thor fonts subset`
FontFace('Inter', url: '/fonts/inter-latin.woff2',
    unicodeRange: 'U+0000-00FF,U+0131,U+2000-206F')
```

[Todos los códigos](README.md)
