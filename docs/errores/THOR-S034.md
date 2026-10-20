# THOR-S034 · Un método del estado llamado con la clave de la fila al pintar

**Dónde:** `thor_lints` · regla `row_server_read` (en el editor y en `dart analyze`); `thor dev` y `thor build` lo imprimen como aviso.

## Qué pasó

En el constructor de una fila de `Watch.list` (`each: (row) => …`, el `builder` de `row.watch` o una función que recibe el `row`) se llamó a un método de un `ThorState` con la clave de la fila, o se leyó un `.value` cuya cadena menciona la fila:

```dart
Checkbox(value: done, semanticLabel: todos.titleById(row.key), onChanged: …)
Text(todos.selected.value.contains(row.key) ? 'sí' : 'no')
```

Las filas que el servidor pintó se ven bien. Las que **agrega el navegador después** quedan con un valor vacío o equivocado (un checkbox sin nombre accesible, por ejemplo), y nada lo avisa.

## Por qué

El constructor de la fila corre en el servidor: una vez por fila que pinta la página y una vez más para la **plantilla** de la fila, con una clave de relleno. El navegador no vuelve a correrlo: las filas nuevas son clones de esa plantilla y solo se rellenan los textos y atributos ligados (`row.text`, `row.attribute`, `row.bind`, `row.watch`). `todos.titleById(row.key)` escrito directo se evaluó con la clave de relleno y quedó en la plantilla.

No se marca: `row.text`, `row.attribute`, `row.bind`, `todos.remove.withArg(row.key)` (arma el manejador, no lo llama), un callback (`onPressed: () => …`: su regla es [THOR-S011](THOR-S011.md)) ni `untracked(() => …)`.

## Cómo se arregla

```dart
// WRONG
Checkbox(value: done, semanticLabel: todos.titleById(row.key), onChanged: …)
```

```dart
// RIGHT: un método que recibe el elemento, ligado a la fila
String titleOf(Todo t) => t.title;            // en el estado

Checkbox(
  value: done,
  semanticLabel: row.bind(todos.titleOf),     // o row.bind((t) => t.title)
  onChanged: todos.setDone.withArg(row.key),
)
IconButton(tooltip: row.bind(todos.titleOf), icon: …, onPressed: …)

// un texto visible
row.text(todos.titleOf)

// una apariencia que cambia (tachado, color)
row.watch(todos.isDone, builder: (done) => …)
```

Para dejar la foto a propósito, `// ignore: thor_lints/row_server_read` y la razón en la línea de arriba.

[Todos los códigos](README.md)
