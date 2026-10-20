# THOR-R001 · thor no sabe construir este widget

**Dónde:** `thor_ui` · render en el servidor.

## Qué pasó

Un widget no extiende `StatelessWidget`, `StatefulWidget` ni `InheritedWidget`.

## Por qué

thor construye el árbol en el servidor con las mismas tres familias de Flutter. Un `RenderObjectWidget` o una subclase directa de `Widget` no tiene equivalente: su pintura vive en el renderizador de Flutter, que aquí no existe.

## Cómo se arregla

```dart
// WRONG
class Gauge extends LeafRenderObjectWidget { ... }
```

```dart
// RIGHT
// Componerlo con widgets de thor (CSS y HTML):
class Gauge extends StatelessWidget {
  const Gauge({super.key, required this.value});
  final double value;
  @override
  Widget build(BuildContext context) => LinearProgressIndicator(value: value);
}
```

[Todos los códigos](README.md)
