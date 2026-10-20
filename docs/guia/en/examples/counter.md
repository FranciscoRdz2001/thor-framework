# Counter

A number and a button that increments it with every press.

:::flutter Flutter: `StatefulWidget` and `setState` · Thor: `ThorState` and `Watch`

:::bench recipe-counter
:::

The ViewModel (`ThorState`) keeps the count in a state field, `state(0)`. `Watch` shows what `label` returns and updates when the field changes; the button receives the `increment` method as `onPressed`, with no closures. `liveRegion` makes a screen reader announce the new number.

Related: [Interactivity](../interactivity.md) · [State](../state.md)
