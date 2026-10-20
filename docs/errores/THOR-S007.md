# THOR-S007 · `Cached` contiene widgets ligados a un `ThorState`

**Dónde:** `thor_ui` · `Cached`.

## Qué pasó

Un subárbol dentro de `Cached` usa un `ThorState` (`Watch`, `onPressed: state.metodo`…).

## Por qué

`Cached` guarda el HTML y lo reutiliza en otras peticiones. Un widget ligado al estado lleva valores de **esta** petición (el contador en 3, la sesión de alguien), que se servirían a otros visitantes.

## Cómo se arregla

```dart
// WRONG
Cached(cacheKey: 'header', child: Row(children: [Logo(), Watch(cart.count)]))
```

```dart
// RIGHT
Row(children: [
  const Cached(cacheKey: 'logo', child: Logo()),
  Watch(cart.count), // fuera de Cached
])
```

[Todos los códigos](README.md)
