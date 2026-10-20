# THOR-R009 · El largo del `DefaultTabController` no coincide

**Dónde:** `thor_ui` · `TabBar`, `TabBarView`.

## Qué pasó

`length` del controlador es distinto del número de pestañas o de vistas.

## Por qué

Cada pestaña controla la vista de su mismo índice; con largos distintos alguna quedaría sin pareja (Flutter también falla).

## Cómo se arregla

```dart
// WRONG
DefaultTabController(length: 3, child: TabBar(tabs: [a, b]))
```

```dart
// RIGHT
DefaultTabController(length: 2, child: TabBar(tabs: [a, b]))
```

[Todos los códigos](README.md)
