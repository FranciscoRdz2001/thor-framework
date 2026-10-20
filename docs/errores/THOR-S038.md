# THOR-S038 · Una página con `headBudget` respondió 200 y su recurso no existía

**Dónde:** `thor dev` · terminal del servidor, con la ruta de la página.

## Qué pasó

Un `defer(f, head: true, headBudget: …)` agotó su presupuesto, la página salió con `200`, y después el futuro falló con `NotFound`, `HttpError` o `Redirect`. Con un backend más rápido esa misma URL habría respondido `404`.

```dart
product: defer(catalog.product(slug), head: true, headBudget: defaultHeadBudget),
```

## Por qué

El estado HTTP no se puede cambiar cuando ya salió el primer byte. Un presupuesto cambia corrección del estado por latencia: la misma URL da `200` o `404` según lo lento que esté el backend, un buscador puede indexar el «soft 404» y una caché o un monitor ven respuestas distintas.

## Cómo se arregla

```dart
// RIGHT: sin presupuesto, el servidor espera el futuro y el estado es real
product: defer(catalog.product(slug), head: true),

// o espera el dato en load
final product = await catalog.product(slug);
```

Deja `headBudget` solo para datos de cabecera cosméticos (un título que tiene respaldo), nunca para el que decide el estado.

[Todos los códigos](README.md)
