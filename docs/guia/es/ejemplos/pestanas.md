# Pestañas con indicador

Una barra de pestañas cuyo indicador se desliza de una pestaña a otra.

:::flutter Flutter: `TabBar(indicator:)` · Thor: `AnimatedSlide` dentro de un `Watch`

:::bench recipe-tabs
:::

El indicador es un solo elemento del ancho de una pestaña. `AnimatedSlide` lo desplaza en múltiplos de su propio ancho, así la pestaña `i` está en `Offset(i, 0)` sin importar el texto. El color de cada etiqueta cambia con `AnimatedDefaultTextStyle`.

> **Nota:** Si no necesitas un indicador propio, `TabBar` incluye el suyo.

Relacionado: [Animaciones](../animaciones.md#mover-y-alinear) · [Navegación](../componentes-navegacion.md#tabbar-y-tabbarview)
