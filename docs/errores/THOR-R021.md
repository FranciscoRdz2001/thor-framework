# THOR-R021 · Un color del tema declarado dos veces

**Dónde:** `thor_ui` · `ThemeData(colorTokens:, tokens:)`.

## Qué pasó

El mismo nombre aparece dos veces en los colores propios del tema: en el
mapa `colorTokens` y en la lista tipada `tokens`, o dos veces en `tokens`.

## Por qué

Cada nombre es una variable (`--t-<nombre>`) con un solo valor por tema.
Si thor dejara ganar a uno, el otro desaparecería sin aviso y el color de
la página dependería del orden en que se escribieron.

## Cómo se arregla

```dart
// WRONG
ThemeData(
  colorTokens: {'band': Color(0xFFF7F6F2)},
  tokens: [AppColors.band],          // ColorToken('band', …)
)
```

```dart
// RIGHT: cada color en un solo lugar; los tipados llevan claro y oscuro
ThemeData(tokens: AppColors.values)
```

[Todos los códigos](README.md)
