# THOR-P002 · Exportar un sitio que negocia el idioma

**Dónde:** `thor_server` · `exportSite` (`thor export`).

## Qué pasó

Se exportó a estático un sitio con `LocaleStrategy.negotiate`.

## Por qué

Negociar significa **una URL para todos los idiomas**, elegida por `Accept-Language`/cookie en cada petición. Un hosting estático no puede elegir: sirve un solo archivo por URL.

## Cómo se arregla

```dart
// WRONG
RouteHandler(locales: LocaleRouting(..., strategy: LocaleStrategy.negotiate))
```

```dart
// RIGHT
RouteHandler(locales: LocaleRouting(..., strategy: LocaleStrategy.prefix))
// /es/..., /en/... y una página de elección en /
```

[Todos los códigos](README.md)
