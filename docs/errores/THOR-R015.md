# THOR-R015 · `8.px` dentro de un `const`

**Dónde:** `thor_lints` · regla `length_unit_in_const` (en `dart analyze` y el IDE).

## Qué pasó

Una longitud escrita con la extensión de unidades (`8.px`, `1.5.rem`, `50.percent`) está dentro de una expresión `const`.

## Por qué

`8.px` es un getter de una extensión de `num`, y Dart no ejecuta getters en una constante. El compilador solo dice "Extension methods can't be used in constant expressions", sin nombrar el arreglo. Pasa sobre todo al escribir `const Style(gap: 8.px)` o `const [Box(style: Style(padding: 16.px))]` por costumbre de Flutter.

## Cómo se arregla

```dart
// WRONG
const card = Style(gap: 8.px, padding: 16.px);
```

```dart
// RIGHT: el constructor const de Length
const card = Style(gap: Length.px(8), padding: Length.px(16));

// o sin const
final card = Style(gap: 8.px, padding: 16.px);
```

[Todos los códigos](README.md)
