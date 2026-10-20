# THOR-R040 · Un callback de `GestureDetector` o `InkWell` que el navegador no puede dar

**Dónde:** `thor_ui` · `GestureDetector`, `InkWell` e `InkResponse` (al renderizar).

## Qué pasó

Le pasaste a `GestureDetector`, `InkWell` o `InkResponse` un callback de Flutter que no tiene equivalente en el navegador (`onTapCancel`, `onPanStart`, `onScaleUpdate`, `onHover`…), o pediste a la vez `onHorizontalDragEnd` y `onVerticalDragEnd`.

## Por qué

El movimiento del dedo lo hace el navegador en el compositor y tu método corre una vez, al soltar. Un callback por evento (bajar el dedo, cada cuadro del pellizco) obligaría a mandar cada evento al estado. Dejarlo pasar sin efecto haría que el gesto no funcionara sin decir por qué; por eso falla, y el mensaje nombra cada callback y qué usar en su lugar.

## Cómo se arregla

```dart
// WRONG
GestureDetector(onTapCancel: () => cancelled(), onPanStart: (_) => started(), child: tile)
InkWell(onHover: (h) => hovering(h), onTap: open, child: tile)
```

```dart
// RIGHT
GestureDetector(onTap: state.open, onPanUpdate: state.moved, child: tile)
Gesture(onTap: state.open, feedback: const Press(), child: tile) // aspecto al pulsar
InkWell(onTap: state.open, hoverColor: const Color(0x14000000), child: tile)
MouseRegion(onEnter: state.enter, onExit: state.leave, child: tile) // un método al pasar el puntero
```

Para un solo eje de deslizamiento, un `GestureDetector` por eje o `Gesture(onSwipe:, swipe: Swipe(axis: …))`.

[Todos los códigos](README.md)
