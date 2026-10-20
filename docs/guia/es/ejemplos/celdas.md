# Hoja de cálculo

Una cuadrícula de celdas editables que aceptan fórmulas con referencias (`=A1*2`, `=SUM(A1:A3)`) y se recalculan solas.

:::flutter Flutter: `Table` y un `TextField` por celda · Thor: un valor calculado que evalúa la hoja

:::example recipe-cells
:::

## Una evaluación por cambio

El ViewModel (`ThorState`) guarda el texto de cada celda. Un valor calculado (`derived`) evalúa la hoja entera una vez por cambio y devuelve lo que muestra cada celda; un ciclo muestra `#CYCLE`, una división entre cero `#DIV/0` y una fórmula incorrecta `#ERROR`.

Cada celda lee su resultado con `withArg`, y su `Gesture` elige la celda con un toque y la edita con dos:

```dart
class SheetCell extends StatelessWidget {
  const SheetCell(this.index, {super.key});

  final int index;

  @override
  Widget build(BuildContext context) => Gesture(
    onTap: sheet.select.withArg(index),
    onDoubleTap: sheet.edit.withArg(index),
    child: SizedBox(height: 28, child: Watch(sheet.text.withArg(index))),
  );
}
```

## Un solo campo para editar

Un único `TextField` se coloca sobre la celda que se edita, en lugar de un campo por celda. Las flechas mueven la selección con un `CallbackShortcuts`; Enter o F2 empiezan a editar, Enter confirma y Esc cancela.

Relacionado: [Gestos](../gestos.md) · [Estado](../estado.md)
