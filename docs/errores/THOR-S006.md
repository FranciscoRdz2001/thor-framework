# THOR-S006 · Una página usa un `ThorState` sin `ThorApp`

**Dónde:** `thor_ui` · aviso en modo debug al renderizar.

## Qué pasó

La página tiene widgets ligados a un `ThorState` pero no está dentro de un `ThorApp`.

## Por qué

`ThorApp` es quien agrega al documento el script que da vida a la página y el estado inicial. Sin él la página sale del servidor bien pintada pero **estática**: los botones no hacen nada.

## Cómo se arregla

```dart
// WRONG
runApp(Document(body: Counter()))
```

```dart
// RIGHT
runApp(Document(body: ThorApp(child: Counter())))

// En una app con rutas: WidgetRenderer(app: (page) => ThorApp(child: page))
```

[Todos los códigos](README.md)
