# THOR-S016 · Un `AnimatedSwitcher` sin estados que cambiar

**Dónde:** `thor_lints` · regla `animated_switcher_without_watch` (en el editor y en `dart analyze`) y la generación de código de `thor dev` / `thor build`.

## Qué pasó

El `child` de un `AnimatedSwitcher` no es un `Watch` con estados: es otro widget (`Text`, `Column`…), un `Watch` sin `builder:` o con `each:`, o un `Watch` de un `String`, una lista o un `int` sin `count:`. No anima nada y nada lo dice.

## Por qué

El `AnimatedSwitcher` marca el elemento del `Watch` que envuelve y anima el cambio entre los estados de ese `Watch` (un `bool`, un enum o un `int` con `count:`), dentro de una transición de vista del navegador. Sobre cualquier otra cosa no hay dos estados que intercambiar. Como raíz del `builder:` de un `Watch` sí funciona con cualquier hijo (`Watch(paso.actual, builder: (p) => AnimatedSwitcher(child: Text(titulos[p])))`): el `Watch` cambia su elemento entero y el `AnimatedSwitcher` lo marca; la regla lo deja pasar. Más adentro del árbol del `builder:` (dentro de un `Column`, por ejemplo) marca un elemento que nadie cambia y la regla sí avisa. Los envoltorios que se funden en su hijo (`Padding`, `Expanded`…) se atraviesan; un widget propio o una función que devuelve el `Watch` no se pueden ver y no se marcan.

## Cómo se arregla

```dart
// WRONG
AnimatedSwitcher(
  duration: const Duration(milliseconds: 300),
  child: Text(view.title()),
)
```

```dart
// RIGHT: un Watch con builder sobre un bool, un enum o un int con count:
AnimatedSwitcher(
  duration: const Duration(milliseconds: 300),
  child: Watch(view.isGrid, builder: (grid) => grid ? const GridBody() : const ListBody()),
)
```

Sin cambio de estado no hay nada que animar: quita el `AnimatedSwitcher`. Más en [Animaciones](../guia/es/animaciones.md#cambiar-de-estado-con-animatedswitcher).

[Todos los códigos](README.md)
