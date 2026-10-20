# THOR-R035 · El `id` de un `LazyPiece` no cabe en una URL

**Dónde:** `thor_ui` · `LazyPiece(id: …)`.

## Qué pasó

El `id` de un `LazyPiece` tiene un carácter que no es letra, dígito, `-`, `_`
ni `.` (un espacio, una barra, un acento).

## Por qué

El `id` es parte de la URL del trozo: la página pide `?thor-piece=<id>` y el
servidor busca el `LazyPiece` con ese nombre al dibujar la página otra vez. Un
`id` con caracteres de URL se leería distinto en cada lado.

## Cómo se arregla

Usa un nombre simple y único en la página; si sale de un dato, conviértelo en
un slug.

```dart
// WRONG
LazyPiece<List<Category>>(id: 'branch of ${department.name}', …)

// RIGHT
LazyPiece<List<Category>>(id: 'branch-${department.slug}', …)
```

[Todos los códigos](README.md)
