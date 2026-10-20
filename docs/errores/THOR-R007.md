# THOR-R007 · Un delegado de traducciones carga de forma asíncrona

**Dónde:** `thor_ui` · `LocalizationsDelegate.load`.

## Qué pasó

`load(locale)` devolvió un `Future` normal.

## Por qué

thor renderiza una página en **una pasada síncrona**; no puede esperar un `Future` a mitad del build. Los textos tienen que estar listos: `SynchronousFuture`.

## Cómo se arregla

```dart
// WRONG
Future<Strings> load(Locale l) async => Strings(await fetch(l));
```

```dart
// RIGHT
Future<Strings> load(Locale l) => SynchronousFuture(Strings.forLocale(l));
// Lo asíncrono va en el load de la ruta (datos), no en el delegado.
```

[Todos los códigos](README.md)
