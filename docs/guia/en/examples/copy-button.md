# Copy button

A button that copies some text and confirms it with a checkmark that lasts a moment.

:::flutter Flutter: `AnimatedSwitcher` · Thor: an `AnimationController` in a `ThorState`

:::bench recipe-copy
:::

A single `AnimationController` in the ViewModel (`ThorState`) drives the icon, the checkmark and the text on the same timeline, with the change in the first and last 8 %. There is no timer to cancel: pressing again restarts the cycle. With the reduced-motion preference, the change is instant.

Related: [Animations](../animations.md#driven-from-state) · [Interactivity](../interactivity.md)
