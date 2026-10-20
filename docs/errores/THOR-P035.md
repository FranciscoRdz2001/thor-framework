# THOR-P035 · Un `RegExp` con banderas en un `Validator.pattern`

**Dónde:** `thor_ui` · `Validator.pattern(RegExp(...), ...)` (en debug, al pintar el campo).

## Qué pasó

Le pasaste a `Validator.pattern` un `RegExp` con `caseSensitive: false`, `multiLine: true` o `dotAll: true`, y el navegador no puede aplicarlas.

## Por qué

La regla se convierte en el atributo nativo `pattern` del `<input>`: es el texto de una expresión regular de JavaScript, sin banderas. Ignorar la bandera en silencio haría que el navegador aceptara o rechazara distinto de lo que dice tu código.

## Cómo se arregla

Escribe la bandera en el patrón, o deja la regla para el servidor.

```dart
// WRONG
Validator.pattern(RegExp(r'^abc$', caseSensitive: false), 'Escribe abc')
```

```dart
// RIGHT: the flag inside the pattern
Validator.pattern(RegExp(r'^[Aa][Bb][Cc]$'), 'Escribe abc')

// or a rule only the server checks (with a FormSchema)
Validator.custom((v) => v.toLowerCase() == 'abc' ? null : 'Escribe abc')
```

Lo mismo pasa con `\p{..}`, `\P{..}` y `\u{..}` sin `unicode: true`: Dart los lee como texto, el servidor y el navegador como propiedad Unicode. Pon `unicode: true`.

Un `RegExp` sin banderas significa lo mismo que en Flutter (`hasMatch`: una coincidencia en cualquier parte del valor). Más en [Formularios](../guia/es/formularios.md#validar).

[Todos los códigos](README.md)
