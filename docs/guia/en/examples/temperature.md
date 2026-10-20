# Temperature converter

Two fields, Celsius and Fahrenheit, that update each other as long as the text is a number.

:::flutter Flutter: two `TextEditingController` · Thor: the same ones, in a `ThorState`

:::bench recipe-temperature
:::

The two `TextEditingController` are fields of the ViewModel (`ThorState`), and each method writes to the opposite field. No `Watch` is needed: if the text isn't a number, the other field keeps its value.

Related: [Forms](../forms.md) · [State](../state.md)
