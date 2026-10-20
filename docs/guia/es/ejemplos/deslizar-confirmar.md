# Deslizar para confirmar

Una acción que pide un gesto deliberado: arrastrar una manija hasta el final para confirmarla.

:::flutter Flutter: `onHorizontalDragEnd` · Thor: `Gesture(onDragEnd:, drag: Drag(…))`

:::bench recipe-slide
:::

Mientras el puntero está presionado, el navegador mueve la manija; el ViewModel (`ThorState`) solo recibe la distancia al soltar, y `Drag` devuelve la manija a su lugar si no llegó al final. Al confirmar, la pista y la manija cambian con `AnimatedContainer` y `AnimatedPositioned`.

> **Consejo:** Agrega un botón con la misma acción para quien no puede arrastrar.

Relacionado: [Gestos](../gestos.md) · [Animaciones](../animaciones.md#mover-y-alinear)
