# THOR-S012 · Un `ThorState` creado fuera del nivel superior

**Dónde:** `thor_lints` · regla `state_misuse` (en el editor y en `dart analyze`), `thor dev` y `thor build`.

## Qué pasó

Un `ThorState` se creó en un campo de un widget, en una variable local de `build` o en cualquier lugar que no es el inicializador de una variable de nivel superior de un archivo de `lib/`.

## Por qué

El navegador solo conoce los estados declarados en el nivel superior de los archivos de la app. Una instancia creada en un widget es otra: el servidor la pinta, pero el navegador no la conoce y sus métodos no hacen nada. Además, un campo de un widget crea un estado nuevo cada vez que el widget se construye.

`thor dev` muestra el aviso en la página con archivo y línea, y `thor build` falla con él. Los tests (`test/`) pueden crear estados donde los necesiten.

## Cómo se arregla

```dart
// WRONG
class CounterWidget extends StatelessWidget {
  final counterState = CounterState();

  @override
  Widget build(BuildContext context) =>
      OutlinedButton(onPressed: counterState.increment, child: const Text('+'));
}
```

```dart
// RIGHT
// lib/state/counter_state.dart, junto a su clase:
final counter = CounterState();

// En el widget:
class CounterWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      OutlinedButton(onPressed: counter.increment, child: const Text('+'));
}
```

[Todos los códigos](README.md)
