# THOR-S036 · `row.bind` usado como texto o transformado

**Dónde:** `thor_ui` · `row.bind(…)` al pintar.

## Qué pasó

El `String` que devolvió `row.bind(…)` terminó en un texto visible (`Text(row.bind(…))`, `Chip(label:)`, `labelText:`, `Tooltip(message:)`) o se transformó antes de llegar a un atributo: interpolado (`'Tarea ${row.bind(…)}'`), concatenado, con `.toUpperCase()` o con un sufijo.

## Por qué

`row.bind` no es el valor: es una marca que el elemento que escribe el atributo convierte en un atributo ligado a la fila. Si se muestra o se calcula sobre ella, el navegador no puede mantener el resultado al día y la marca llegaría a la página. Thor falla al pintar en vez de publicarla. El texto de un usuario con los mismos caracteres privados no es una marca (lleva una etiqueta aleatoria por proceso) y se escribe como dato.

## Cómo se arregla

```dart
// WRONG
Text(row.bind(todos.titleOf))
Checkbox(semanticLabel: 'Tarea ${row.bind(todos.titleOf)}', …)
```

```dart
// RIGHT: un texto visible, row.text
row.text(todos.titleOf)

// una etiqueta calculada: un método del estado que la devuelve
String labelOf(Todo t) => 'Tarea ${t.title}';
Checkbox(semanticLabel: row.bind(todos.labelOf), …)
```

[Todos los códigos](README.md)
