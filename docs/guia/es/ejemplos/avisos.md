# Pila de avisos

Varios avisos a la vez, el más reciente delante y los anteriores detrás, que entran y salen por el mismo borde.

:::flutter Flutter: `AnimatedPositioned` por aviso · Thor: `AnimatedSlide`, `AnimatedScale` y `AnimatedOpacity`

:::bench recipe-toasts
:::

Cada aviso depende solo de su profundidad: cuántos avisos tiene delante. Al llegar uno nuevo, los demás cambian de profundidad y se acomodan a la vez; al descartarlo, vuelve por donde entró. Son transiciones implícitas, así un aviso que llega a mitad de una animación no la reinicia. Para que se cierren solos, usa un `Timer` en el ViewModel (`ThorState`).

Relacionado: [Animaciones](../animaciones.md#mover-y-alinear) · [Avisos](../componentes-avisos.md)
