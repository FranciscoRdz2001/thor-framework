# Círculos con deshacer

Un lienzo donde un clic agrega un círculo o elige uno, y un diálogo cambia su diámetro, con deshacer y rehacer.

:::flutter Flutter: `CustomPaint` y `GestureDetector` · Thor: `Watch.list` y un solo `Gesture`

:::example recipe-circles
:::

## El historial son instantáneas

Cada cambio guarda los círculos como un texto en `snapshots` y avanza `cursor`. Deshacer y rehacer solo mueven el cursor, y un valor calculado lee los círculos de la instantánea actual.

```dart
class HistoryViewModel extends ThorState {
  final snapshots = state(const ['']);
  final cursor = state(0);

  late final current = derived(() => snapshots.value[cursor.value]);

  bool cannotUndo() => cursor.value == 0;
  bool cannotRedo() => cursor.value >= snapshots.value.length - 1;

  void push(String snapshot) => batch(() {
    snapshots.value = [
      ...snapshots.value.sublist(0, cursor.value + 1),
      snapshot,
    ];
    cursor.value = cursor.value + 1;
  });

  void undo() {
    if (!cannotUndo()) cursor.value = cursor.value - 1;
  }

  void redo() {
    if (!cannotRedo()) cursor.value = cursor.value + 1;
  }
}
```

## Un solo elemento para el lienzo

El lienzo es un `Gesture` que recibe dónde cayó el toque (`onTapDown(x, y)`, `onTapUp(x, y)`). Cada círculo es una fila de `Watch.list` cuya posición y tamaño son longitudes de la fila (`row.length`), así el diámetro cambia sin reconstruir nada.

```dart
Watch.list(
  circles.rows,
  itemKey: circles.idOf,
  container: (rows) => Gesture(
    onTapDown: circles.down,
    onTapUp: circles.up,
    onLongPress: circles.adjust,
    child: SizedBox(height: 280, child: Stack(children: rows)),
  ),
  each: (row) {
    final x = row.length(circles.left);
    final y = row.length(circles.top);
    final d = row.length(circles.diameter);
    return Styled(
      style: StyleProps(
        position: BoxPosition.absolute(left: x, top: y),
        minWidth: d,
        minHeight: d,
      ),
      child: const DecoratedBox(
        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.grey),
      ),
    );
  },
)
```

El diálogo es un `AlertDialog(controller:)` con un `Slider` ligado al diámetro del círculo elegido.

> **Diferencia con Flutter:** `onLongPress` no indica dónde ocurrió: el clic derecho o la pulsación larga abren el diálogo del círculo ya elegido. Con el dedo, `onTapDown` lo elige; con el ratón, haz clic izquierdo antes del derecho.

Relacionado: [Gestos](../gestos.md) · [Diálogos y menús](../dialogos-y-menus.md)
