# Tabs with indicator

A tab bar whose indicator slides from one tab to another.

:::flutter Flutter: `TabBar(indicator:)` · Thor: `AnimatedSlide` inside a `Watch`

:::bench recipe-tabs
:::

The indicator is a single element as wide as one tab. `AnimatedSlide` moves it in multiples of its own width, so tab `i` sits at `Offset(i, 0)` regardless of the text. The color of each label changes with `AnimatedDefaultTextStyle`.

> **Note:** If you don't need a custom indicator, `TabBar` includes its own.

Related: [Animations](../animations.md#move-and-align) · [Navigation](../components-navigation.md#tabbar-and-tabbarview)
