# THOR-P020 · Un formulario apunta a algo que no es una acción de la página

**Dónde:** `thor_ui` · `Form(onValid:)`, `Form(onPost:)` y `onPost:`/`onValid:` de los botones, al pintar la página.

## Qué pasó

El formulario recibió una función que thor no encuentra entre las acciones registradas: un closure, un método de una página que no está en el `ThorRouter`, o la app corrió sin `thor` (`dart run` directo).

## Por qué

Una acción es un método público de la página. thor registra esos métodos al preparar la app (`thor dev`, `thor build`, `thor test`); al pintar, thor busca el tear-off (`send` sobre la instancia de la ruta) y escribe `action="?/send"`. Un closure no tiene nombre que el servidor pueda llamar después.

## Cómo se arregla

```dart
// WRONG — a closure
Form(onPost: (request) async => null, child: …)
```

```dart
// RIGHT — a public method of the page, by its tear-off
Future<ActionResult?> favorite(PageRequest request) async { … }

Form(onPost: favorite, child: …)
```

Corre la app con `thor dev` / `thor test`. Para la acción de otra página, dale su URL: `Form(action: articleRoute.link(…), onPost: const ArticlePage().favorite)`.

[Todos los códigos](README.md)
