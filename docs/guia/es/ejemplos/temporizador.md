# Temporizador

Una barra que se llena durante una duración ajustable, con el tiempo transcurrido y un botón para reiniciarla.

:::flutter Flutter: `Timer.periodic` en `initState` · Thor: `Timer.periodic` en `onHydrated`

:::bench recipe-timer
:::

`onHydrated` se ejecuta cuando el ViewModel (`ThorState`) arranca en el navegador, y ahí empieza el `Timer`. `LinearProgressIndicator.watch` hace que la barra siga a `fraction`, y el `Slider` cambia la duración sin reiniciar la cuenta.

Relacionado: [Estado](../estado.md) · [Interactividad](../interactividad.md)
