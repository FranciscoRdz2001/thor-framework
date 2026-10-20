# THOR-S014 · `setState` en un `StatefulWidget`

**Dónde:** `thor_lints` · regla `stateful_set_state` (en el editor y en `dart analyze`) y la generación de código de `thor dev` / `thor build`.

## Qué pasó

Un `State` de un `StatefulWidget` llamó a `setState`. Compila y no cambia nada en el navegador; en `debug` falla un `assert`.

## Por qué

`build` corre una sola vez, en el servidor, y produce HTML. El `State` vive solo ese rato: nunca llega al navegador, así que no hay nada que reconstruir cuando cambia. Lo que cambia en el navegador es un [`ThorState`](../guia/es/estado.md): campos `state(...)` y métodos que el navegador ejecuta.

No hay un lugar donde `setState` sea correcto (tampoco en `initState`: el servidor pinta una vez y el `assert` falla igual), así que se marca cada uso en `lib/`. Un `StatefulWidget` que solo lee sus campos al pintar sigue funcionando.

`thor build` falla con el archivo, la línea y un recuadro del código; `thor dev` lo muestra en la página y en la consola.

## Cómo se arregla

```dart
// WRONG
class _CounterState extends State<Counter> {
  int count = 0;

  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: () => setState(() => count++),
    child: Text('$count'),
  );
}
```

```dart
// RIGHT: el estado es un ThorState y el botón recibe su método
class CounterState extends ThorState {
  final count = state(0);
  void increment() => count.value++;
}

final counter = CounterState();

class Counter extends StatelessWidget {
  const Counter({super.key});

  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: counter.increment,
    child: Watch(counter.count),
  );
}
```

Más en [Si vienes de Flutter](../guia/es/desde-flutter.md) y en [Estado](../guia/es/estado.md).

[Todos los códigos](README.md)
