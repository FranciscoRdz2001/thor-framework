# THOR-R022 · Un elemento con dos ids

**Dónde:** `thor_ui` · `Semantics(identifier:)` sobre un hijo que ya tiene
su propio `id`.

## Qué pasó

Un `Semantics(identifier: 'a')` se funde en el elemento de su hijo, y ese
elemento ya traía otro id (otro `Semantics(identifier: 'b')` adentro, o un
widget que pone el suyo en ese mismo elemento).

## Por qué

Un elemento del DOM tiene un solo `id`. Si thor dejara ganar a uno, el otro
desaparecería sin aviso y un enlace a esa ancla (`href="#a"`) dejaría de
llevar a ningún lado.

## Cómo se arregla

```dart
// WRONG
Semantics(
  identifier: 'contacto',
  child: Semantics(identifier: 'formulario', child: form),
)
```

```dart
// RIGHT: un id por elemento; el otro, en otro elemento
Semantics(
  identifier: 'contacto',
  child: Column(children: [
    title,
    Semantics(identifier: 'formulario', child: form),
  ]),
)
```

[Todos los códigos](README.md)
