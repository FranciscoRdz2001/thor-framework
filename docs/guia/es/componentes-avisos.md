# Avisos

Diálogos, mensajes breves, indicadores de progreso y menús emergentes.

## AlertDialog

:::flutter Flutter: `showDialog(AlertDialog(…))` · Thor: `DialogTrigger(dialog: AlertDialog(…))`

:::bench cat-alert-dialog
:::

Un diálogo con título, contenido y acciones. `DialogTrigger(dialog:)` lo coloca junto al botón que lo abre y `DialogClose` cierra el diálogo desde una acción. Se cierra con Esc y, con `barrierDismissible: true`, con un toque fuera.

> **Diferencia con Flutter:** No existe `showDialog(context)`: el diálogo está en la página desde que se renderiza, cerrado, junto al `DialogTrigger` que lo abre.

## Dialog

:::bench cat-dialog-controller
:::

`Dialog` acepta cualquier contenido. Para abrirlo o cerrarlo desde un método, el ViewModel (`ThorState`) declara un `DialogController` y el diálogo lo recibe en `controller`; `AlertDialog`, `Drawer` y `ModalBottomSheet` aceptan el mismo parámetro.

## SnackBar

:::flutter Flutter: `ScaffoldMessenger.showSnackBar` · Thor: `toast()` o `SnackBar(visible:)`

:::bench cat-snackbar
:::

Un mensaje breve en la parte inferior, que los lectores de pantalla anuncian. `SnackBarBehavior.fixed`, el valor por omisión, ocupa todo el ancho; `SnackBarBehavior.floating` es una tarjeta centrada. Se oculta después de `duration`, y la cuenta se pausa mientras tiene el puntero o el foco.

Para mostrar un mensaje desde un método, llama a `toast()`: no necesita `BuildContext`, se oculta solo y forma una cola.

```dart
void save() {
  // …
  toast('Changes saved', duration: const Duration(seconds: 3));
}
```

> **Diferencia con Flutter:** No existe `ScaffoldMessenger`. `toast()`, `hideToast()` y `clearToasts()` reemplazan a `showSnackBar`, `hideCurrentSnackBar` y `clearSnackBars`; para un mensaje en la página siguiente, usa `Redirect(url).flash('…')`.

## Indicadores de progreso

:::bench cat-progress
:::

`LinearProgressIndicator` y `CircularProgressIndicator` giran sin fin cuando no tienen `value`; con un `value` entre 0 y 1 muestran el avance.

| Parámetro | Qué hace |
| --- | --- |
| `value` | de 0 a 1; `null` para el indicador sin fin |
| `color` | el color del avance |
| `semanticsLabel` | su nombre para los lectores de pantalla |
| `size`, `strokeWidth` | el tamaño y el grosor del circular |
| `minHeight` | el alto de la barra lineal |

## PopupMenuButton

:::bench cat-popup-menu
:::

Un botón que abre un menú. `onSelected` recibe el `value` de la opción elegida, y Esc o un toque fuera lo cierran. Para un panel con cualquier contenido, como filtros o un formulario, usa `Popover` ([Diálogos y menús](dialogos-y-menus.md)).
