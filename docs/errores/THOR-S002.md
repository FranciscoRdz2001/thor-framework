# THOR-S002 · Un método por fila no recibe el ítem

**Dónde:** `thor_ui` · `row.text`, `row.watch`, `row.attributes` dentro de `Watch.list`.

## Qué pasó

Un binding por fila apunta a un método que no toma el ítem de la lista (o que no acepta el argumento fijo de `withArg`).

## Por qué

En una lista con clave el navegador clona la fila y calcula cada valor llamando al método **con el ítem** de esa fila. El método tiene que recibirlo: `String f(Item item)`, o un argumento fijo primero y el ítem después.

## Cómo se arregla

```dart
// WRONG
String lineName() => ...;          // no recibe la fila
row.text(state.lineName)
```

```dart
// RIGHT
String lineName(Line line) => line.name;
row.text(state.lineName)

// Con un argumento fijo (columna) y luego el ítem:
String cellLabel(int column, Line line) => ...;
row.text(state.cellLabel.withArg(3))
```

[Todos los códigos](README.md)
