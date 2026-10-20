# THOR-R013 · Una utilidad o variante de `tw()` que thor no conoce

**Dónde:** `thor_ui/web.dart` · `tw()`.

## Qué pasó

`tw('…')` recibió una utilidad (`pd-4`, `space-x-4`) o una variante
(`focus:`, `2xl:`, `md:hover:`) fuera del subconjunto de thor, o un color
por nombre (`text-muted`, `bg-red-500`) que el tema no tiene en
`ThemeData(colorTokens:)` (esto último se revisa al pintar, en debug). El
mensaje dice la más parecida o qué usar en su lugar.

## Por qué

thor resuelve cada utilidad en el servidor a declaraciones de la clase del
elemento; no hay CSS de Tailwind en el navegador que la recoja después. Lo
que no está en la gramática no se escribe: una utilidad inventada fallaría
en silencio y un valor libre (`p-[1px;color:red]`) podría colar CSS. Las
variantes son los estados de thor (`hover:`, `active:`, `focus-visible:`,
`focus-within:`, `group-hover:`, `dark:`), sus cuatro breakpoints y el
ancho del contenedor (`@md:`, `@min-[400px]:`), una por utilidad.

## Cómo se arregla

```dart
// WRONG
tw('space-x-4 focus:ring md:hover:bg-primary')
```

```dart
// RIGHT: gap en el padre, el foco de teclado, una variante por utilidad
tw('flex gap-x-4 focus-visible:border-primary hover:bg-primary')
// Dos condiciones juntas: Style(...).when() o un widget.

// Un color propio: al tema, y por su nombre.
ThemeData(colorTokens: {'muted': Color(0xFF6B7280)})
tw('text-muted')
```

[Todos los códigos](README.md)
