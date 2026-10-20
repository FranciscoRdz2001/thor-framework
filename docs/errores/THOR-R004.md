# THOR-R004 · `.when()` dentro de una hoja de estilos

**Dónde:** `thor_ui` · reglas de hoja (`css(...).props(...)`).

## Qué pasó

Una regla de hoja de estilos recibió `StyleProps` con variantes (`.when(...)`).

## Por qué

Una hoja ya varía por su selector y sus media queries; `.when()` es para el estilo de **un elemento** (`Styled(style:)`, widgets), donde thor convierte las variantes en condiciones de la misma clase. En una hoja el marcador llegaría como basura al CSS.

## Cómo se arregla

```dart
// WRONG
css('.card').props(const StyleProps(padding: EdgeInsets.all(8)).when(medium: StyleProps(padding: EdgeInsets.all(16))))
```

```dart
// RIGHT
css('.card').props(const StyleProps(padding: EdgeInsets.all(8))),
WindowSizeClass.medium.media([css('.card').props(const StyleProps(padding: EdgeInsets.all(16)))]),

// o mejor, en el widget:
Styled(style: const StyleProps(padding: EdgeInsets.all(8)).when(medium: ...), child: ...)
```

[Todos los códigos](README.md)
