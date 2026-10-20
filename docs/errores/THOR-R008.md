# THOR-R008 · Falta `DefaultTabController`

**Dónde:** `thor_ui` · `TabBar`, `TabBarView`.

## Qué pasó

Un `TabBar` o `TabBarView` sin `DefaultTabController` arriba.

## Por qué

Igual que en Flutter: las pestañas y sus vistas se conectan a través del controlador (en thor, el grupo de radios y el panel que muestran).

## Cómo se arregla

```dart
// WRONG
Column(children: [TabBar(tabs: tabs), TabBarView(children: views)])
```

```dart
// RIGHT
DefaultTabController(
  length: 2,
  child: Column(children: [TabBar(tabs: tabs), Expanded(child: TabBarView(children: views))]),
)
```

[Todos los códigos](README.md)
