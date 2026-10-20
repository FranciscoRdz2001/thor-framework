# Slide to confirm

An action that asks for a deliberate gesture: drag a handle all the way to the end to confirm it.

:::flutter Flutter: `onHorizontalDragEnd` · Thor: `Gesture(onDragEnd:, drag: Drag(…))`

:::bench recipe-slide
:::

While the pointer is down, the browser moves the handle; the ViewModel (`ThorState`) only receives the distance on release, and `Drag` returns the handle to its place if it didn't reach the end. On confirm, the track and the handle change with `AnimatedContainer` and `AnimatedPositioned`.

> **Tip:** Add a button with the same action for people who can't drag.

Related: [Gestures](../gestures.md) · [Animations](../animations.md#move-and-align)
