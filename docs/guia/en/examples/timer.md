# Timer

A bar that fills up over an adjustable duration, with the elapsed time and a button to reset it.

:::flutter Flutter: `Timer.periodic` in `initState` · Thor: `Timer.periodic` in `onHydrated`

:::bench recipe-timer
:::

`onHydrated` runs when the ViewModel (`ThorState`) starts in the browser, and that's where the `Timer` starts. `LinearProgressIndicator.watch` makes the bar follow `fraction`, and the `Slider` changes the duration without resetting the count.

Related: [State](../state.md) · [Interactivity](../interactivity.md)
