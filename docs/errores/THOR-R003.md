# THOR-R003 · `Cached` contiene el `<head>` o el documento

**Dónde:** `thor_ui` · `Cached`.

## Qué pasó

Un subárbol dentro de `Cached` escribe en `Document.head` o contiene `<html>`, `<head>` o `<body>`.

## Por qué

El documento mueve esos nodos a su lugar al terminar el render; un fragmento guardado no puede llevarlos.

## Cómo se arregla

```dart
// WRONG
Cached(cacheKey: 'page', child: Document(title: 'x', body: ...))
```

```dart
// RIGHT
Document(title: 'x', body: Cached(cacheKey: 'body', child: ...))
```

[Todos los códigos](README.md)
