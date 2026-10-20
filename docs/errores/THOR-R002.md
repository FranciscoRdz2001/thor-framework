# THOR-R002 · `Cached` está dentro de un wrapper

**Dónde:** `thor_ui` · `Cached`.

## Qué pasó

`Cached` quedó debajo de un wrapper que decora su primer elemento (`Expanded`, `Semantics`, `Link`, `Opacity`…).

## Por qué

Esos wrappers no emiten un elemento propio: agregan clases o atributos **al primer elemento del hijo**. Si el hijo es `Cached`, el HTML guardado no incluiría esa decoración y otra petición lo serviría sin ella.

## Cómo se arregla

```dart
// WRONG
Expanded(child: Cached(cacheKey: 'list', child: ProductList()))
```

```dart
// RIGHT
Cached(cacheKey: 'list', child: Expanded(child: ProductList()))
// …o un elemento propio entre medio (Container, SizedBox).
```

[Todos los códigos](README.md)
