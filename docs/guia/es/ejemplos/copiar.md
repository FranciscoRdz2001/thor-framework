# Botón de copiar

Un botón que copia un texto y lo confirma con una marca de verificación que dura un momento.

:::flutter Flutter: `AnimatedSwitcher` · Thor: un `AnimationController` en un `ThorState`

:::bench recipe-copy
:::

Un solo `AnimationController` del ViewModel (`ThorState`) mueve el ícono, la marca y el texto sobre la misma línea de tiempo, con el cambio en el primer y el último 8 %. No hay un temporizador que cancelar: pulsar otra vez reinicia el ciclo. Con la preferencia de reducir el movimiento, el cambio es instantáneo.

Relacionado: [Animaciones](../animaciones.md#controlada-desde-el-estado) · [Interactividad](../interactividad.md)
