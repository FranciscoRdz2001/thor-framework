# THOR-R038 · Un segmento sin nombre accesible

**Dónde:** `thor_ui` · `SegmentedButton`; `thor_studio` · `StudioSegmentedControl` (solo en debug).

## Qué pasó

Un segmento tiene un `label` que no es un `Text` (un `Icon`, por ejemplo) y no
tiene `tooltip`, o es solo un ícono sin `tooltip`. Un `Text` dentro de un
componente propio, un `Semantics(label:)` o un `Icon(semanticLabel:)` sí lo
nombran.

## Por qué

Cada segmento es un radio nativo. Su nombre sale del texto de un `Text` (o
de la etiqueta de un `Semantics` o de un `Icon`) o del `tooltip`; sin ninguno de los dos el lector de pantalla anuncia un radio
sin nombre. Por eso falla en debug en vez de pintar un control mudo.

## Cómo se arregla

```dart
// WRONG
ButtonSegment(value: View.list, icon: Icon(Icons.list))
```

```dart
// RIGHT
ButtonSegment(value: View.list, icon: Icon(Icons.list), tooltip: 'List')
```

[Todos los códigos](README.md)
