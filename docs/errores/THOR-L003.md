# THOR-L003 · `LayoutScope` de ancho cero

**Dónde:** inspector de desarrollo (modo debug, en el navegador).

## Qué pasó

Un `LayoutScope` (container queries, el `LayoutBuilder` de thor) mide 0 px de ancho.

## Por qué

Un contenedor de consulta no puede medirse por su contenido (el CSS lo obliga a `inline-size`): dentro de un `Row` sin límite, o como hijo de algo que se ajusta al contenido, colapsa.

## Cómo se arregla

```dart
// WRONG
Row(children: [LayoutScope(child: Cards())])
```

```dart
// RIGHT
Row(children: [Expanded(child: LayoutScope(child: Cards()))])
```

[Todos los códigos](README.md)
