# THOR-P006 · `request.parent<T>()` sin un layout que cargue `T`

**Dónde:** `thor_server` · `PageRequest.parent`.

## Qué pasó

Un `load` pidió `request.parent<T>()` y ningún layout de arriba carga un `T`, o se llamó fuera de un `load`.

## Por qué

`parent<T>()` espera el `load` del layout más cercano que devuelve un `T` (su tipo declarado). Si ninguno lo hace, no hay qué esperar; fuera de un `load` (en una acción, un guard o un widget) no hay layouts cargando.

## Cómo se arregla

```dart
// WRONG
// el layout del Group (AppLayout) carga un Company, la página pide un User
final user = await r.parent<User>();
```

```dart
// RIGHT
// Pedir el tipo que el layout carga (el mensaje lista cuáles hay)…
final company = await r.parent<Company>();
// …o, en una acción, leer lo que ponga un middleware en request.context.
```

[Todos los códigos](README.md)
