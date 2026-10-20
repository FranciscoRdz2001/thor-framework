# THOR-L002 · `Expanded`/`Flexible` fuera de un flex

**Dónde:** inspector de desarrollo (modo debug, en el navegador).

## Qué pasó

Un `Expanded` o `Flexible` quedó en un elemento cuyo padre no es un `Row`, `Column` o `Flex`.

## Por qué

Es el "Incorrect use of ParentDataWidget" de Flutter: `flex: 1` solo significa algo dentro de un contenedor flex. Suele pasar al envolver el hijo de un `Row` en un `Padding`/`Container` que queda en medio.

## Cómo se arregla

```dart
// WRONG
Row(children: [Padding(padding: p, child: Expanded(child: field))])
```

```dart
// RIGHT
Row(children: [Expanded(child: Padding(padding: p, child: field))])
```

[Todos los códigos](README.md)
