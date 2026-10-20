# THOR-S035 · `row.bind` en un atributo que un binding no puede escribir

**Dónde:** `thor_ui` · `row.bind(…)` al pintar.

## Qué pasó

El `String` que devolvió `row.bind(…)` terminó en un atributo que el navegador no puede rellenar por fila: un manejador (`on*`), `style`, `class` o un atributo interno de Thor.

## Por qué

`row.bind` no escribe nada por sí mismo: el widget que recibe el `String` (`semanticLabel:`, `tooltip:`, `Semantics(label:)`…) lo escribe como atributo, y Thor lo convierte en un atributo ligado a la fila (`row.attribute`). Por seguridad el navegador solo escribe `aria-*`, `data-*` y un conjunto fijo de atributos simples (`alt`, `title`, `href`, `value`, `placeholder`…).

## Cómo se arregla

```dart
// WRONG: un parámetro que termina en `class`, `style` o un handler
Styled(className: row.bind(todos.titleOf), child: …)
```

```dart
// RIGHT: un parámetro de accesibilidad o de contenido
Checkbox(value: done, semanticLabel: row.bind(todos.titleOf), onChanged: …)
IconButton(tooltip: row.bind(todos.titleOf), icon: …, onPressed: …)

// un texto visible: row.text
row.text(todos.titleOf)

// una variante de apariencia: row.watch
row.watch(todos.isDone, builder: (done) => …)
```

[Todos los códigos](README.md)
