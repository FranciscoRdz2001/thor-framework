# Convertidor de temperatura

Dos campos, Celsius y Fahrenheit, que se actualizan entre sí mientras el texto sea un número.

:::flutter Flutter: dos `TextEditingController` · Thor: los mismos, en un `ThorState`

:::bench recipe-temperature
:::

Los dos `TextEditingController` son campos del ViewModel (`ThorState`), y cada método escribe en el campo contrario. No hace falta `Watch`: si el texto no es un número, el otro campo conserva su valor.

Relacionado: [Formularios](../formularios.md) · [Estado](../estado.md)
