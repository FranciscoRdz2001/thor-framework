# THOR-R036 · Un widget que suma rellenos recibió uno dado como `Length`

**Dónde:** `thor_ui` · `InputDecoration.contentPadding` (`TextField`,
`DropdownButtonFormField`), `DropdownMenu(inputDecorationTheme:)`,
`ExpansionTile.tilePadding` y `GridView.padding`.

## Qué pasó

El relleno se dio con `EdgeInsetsGeometry.allLength`, `symmetricLength` u
`onlyLength` (por ejemplo, una variable CSS: `Length.variable(CssVariable('--gap'))`) y
el widget necesita los números de cada lado.

## Por qué

Un `Length` lo resuelve el navegador, así que no tiene números que leer: un
`EdgeInsetsGeometry.allLength` ni siquiera es un `EdgeInsets` (los widgets
que suman toman `EdgeInsets` y no lo aceptan al compilar). Estos
widgets suman a esos lados algo propio (el espacio de un ícono, la flecha
del selector) o los reparten en varias cajas; con un `Length` el relleno
saldría en cero sin avisar. Por eso falla con este código en vez de pintar
mal.

`SafeArea` y `Padding` sí aceptan un `EdgeInsetsGeometry` con `Length`: lo
suman al área segura o lo escriben tal cual en el CSS.

## Cómo se arregla

```dart
// WRONG: el relleno es una variable; el campo no puede sumarle su ícono
// (ni compila: contentPadding toma EdgeInsets)
TextField(
  decoration: InputDecoration(
    contentPadding: EdgeInsetsGeometry.symmetricLength(
      horizontal: Length.variable(CssVariable('--field-x')),
    ),
  ),
)
```

```dart
// RIGHT: números en estos widgets; el Length va en un Padding alrededor
Padding(
  padding: EdgeInsetsGeometry.symmetricLength(
    horizontal: Length.variable(CssVariable('--field-x')),
  ),
  child: TextField(
    decoration: InputDecoration(
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
    ),
  ),
)
```

[Todos los códigos](README.md)
