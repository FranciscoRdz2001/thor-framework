# Contador

Un número y un botón que lo aumenta con cada pulsación.

:::flutter Flutter: `StatefulWidget` y `setState` · Thor: `ThorState` y `Watch`

:::bench recipe-counter
:::

El ViewModel (`ThorState`) guarda la cuenta en un campo de estado, `state(0)`. `Watch` muestra lo que devuelve `label` y se actualiza cuando el campo cambia; el botón recibe el método `increment` como `onPressed`, sin closures. `liveRegion` hace que un lector de pantalla anuncie el número nuevo.

Relacionado: [Interactividad](../interactividad.md) · [Estado](../estado.md)
