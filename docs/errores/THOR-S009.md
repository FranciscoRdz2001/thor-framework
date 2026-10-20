# THOR-S009 · Nombre inválido de un campo persistido (`cookie:` o `local:`)

**Dónde:** `thor_ui` · `state(…, cookie:)` y `state(…, local:)` (también lo revisa `thor build`).

## Qué pasó

Un campo persistido usa un `cookie:` o un `local:` vacío, de más de 40 caracteres, con caracteres fuera de letras, dígitos, `_` o `-`, o que no es un texto literal. O usa los dos a la vez: un campo persiste en un solo lugar.

## Por qué

El nombre termina en el nombre de la cookie o en la clave de `localStorage` (`thor-s.<nombre>`) y en el código que corre en el navegador: un espacio, un `;` o un `=` romperían la cookie, y un nombre calculado no se puede revisar al compilar. Con `cookie:` y `local:` juntos no habría un valor que mande.

## Cómo se arregla

```dart
// WRONG
final collapsed = state(false, cookie: 'menú lateral');
```

```dart
// RIGHT
final collapsed = state(false, cookie: 'sidebar');
final draft = state('', local: 'draft');
```

[Todos los códigos](README.md)
