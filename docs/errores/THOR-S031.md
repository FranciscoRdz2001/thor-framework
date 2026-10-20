# THOR-S031 · Una página sin el diálogo o el aviso que un estado pide

**Dónde:** la consola del navegador.

## Qué pasó

Un método de un estado llamó a `confirm(…)` o a `toast(…)` y la página no trae el `<dialog>` ni el aviso que usan. `confirm` contestó que no (el método sigue por su rama «cancelar») y `toast` no mostró nada.

## Por qué

El servidor escribe el diálogo y el aviso una sola vez por página, solo en las páginas cuyos estados los usan. Lo sabe por el build: sigue desde el archivo del estado las llamadas a funciones y métodos de tu propia app (una función auxiliar de otro archivo, a su vez llamada por otra…) y ve si alguna llama a `confirm(…)` o `toast(…)`. No ve lo que no es una llamada a una función con nombre: un método abstracto implementado en otro archivo y llamado por la interfaz, una función guardada en un campo o una lista, o código de un paquete.

## Cómo se arregla

Llama a `confirm(…)`/`toast(…)` desde una función con nombre de tu app (el build la sigue entre archivos), o pon la llamada en el archivo de la clase del estado.

```dart
// RIGHT: en el mismo archivo que la clase
class OrdersState extends ThorState {
  Future<void> remove(int id) async {
    if (!await confirm('¿Eliminar el pedido?')) return;
    …
    toast('Pedido eliminado', kind: ToastKind.success);
  }
}
```

Más en [Diálogos y menús](../guia/es/dialogos-y-menus.md#preguntar-y-avisar-desde-el-código).

[Todos los códigos](README.md)
