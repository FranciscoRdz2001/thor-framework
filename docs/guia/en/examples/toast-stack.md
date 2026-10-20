# Toast stack

Several toasts at once, the newest in front and the older ones behind, entering and leaving through the same edge.

:::flutter Flutter: `AnimatedPositioned` per toast · Thor: `AnimatedSlide`, `AnimatedScale` and `AnimatedOpacity`

:::bench recipe-toasts
:::

Each toast depends only on its depth: how many toasts are in front of it. When a new one arrives, the others change depth and settle at the same time; when one is dismissed, it leaves the way it came in. These are implicit transitions, so a toast that arrives mid-animation doesn't restart it. To make them close on their own, use a `Timer` in the ViewModel (`ThorState`).

Related: [Animations](../animations.md#move-and-align) · [Feedback](../components-feedback.md)
