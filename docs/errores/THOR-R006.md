# THOR-R006 · No hay `Localizations` arriba del widget

**Dónde:** `thor_ui` · `Localizations.localeOf`.

## Qué pasó

Un widget pidió el idioma y no hay un `Localizations` en sus ancestros.

## Por qué

`ThorApp` pone uno; un widget renderizado fuera de `ThorApp` (un test, un `Document` sin app) no lo tiene.

## Cómo se arregla

```dart
// WRONG
runApp(Document(body: const Greeting()))
```

```dart
// RIGHT
runApp(Document(body: ThorApp(child: const Greeting())))
// En tests: envolver en ThorApp o usar Localizations.maybeLocaleOf.
```

[Todos los códigos](README.md)
