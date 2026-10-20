# THOR-R014 · Dos utilidades de `tw()` fijan la misma propiedad

**Dónde:** `thor_ui/web.dart` · `tw()`.

## Qué pasó

Dos utilidades de la misma variante escriben la misma propiedad CSS
(`p-4 p-8`, `flex hidden`, `w-full size-10`).

## Por qué

En Tailwind gana la que aparece después **en su hoja**, no en el
atributo `class`, así que el resultado depende de un orden que no se ve.
thor prefiere fallar a elegir una. Las excepciones son valores por
defecto que otra utilidad existe para cambiar: el alto de línea de
`text-sm` lo cambia `leading-6`, y la duración de `transition` la cambia
`duration-300`, en cualquier orden.

## Cómo se arregla

```dart
// WRONG
tw('p-4 p-8')
tw('flex hidden')
```

```dart
// RIGHT: una por variante
tw('p-4 md:p-8')
tw('hidden md:flex')
```

[Todos los códigos](README.md)
