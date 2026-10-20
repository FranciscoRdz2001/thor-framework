# THOR-S011 · Un callback es un closure que usa un `ThorState`

**Dónde:** `thor_lints` · regla `state_misuse` (en el editor y en `dart analyze`), `thor dev` y `thor build`.

## Qué pasó

Un widget recibió como callback (`onPressed`, `onChanged`, `onTap`, `onSelected`…) una función anónima que llama o lee un miembro de un `ThorState`. En el navegador el botón no hace nada: el elemento se pinta sin manejador y ningún error lo avisa.

## Por qué

El código de un widget corre una sola vez, en el servidor. En el navegador solo existen los miembros propios de un `ThorState`, y el navegador los encuentra **por nombre** (`counter.increment`). Un closure no se traduce y no tiene nombre: el navegador no puede ejecutarlo. Un closure vacío (`() {}`, el botón que envía un formulario) o uno que no toca ningún estado son válidos y no se marcan.

`thor dev` muestra el aviso en la página con archivo y línea, y `thor build` falla con él. En el editor, la corrección rápida cambia el closure por el miembro cuando es una sola llamada.

## Cómo se arregla

```dart
// WRONG
OutlinedButton(onPressed: () { counter.decrement(); }, child: const Text('-'))
IconButton(onPressed: () => todos.remove(id), icon: const Icon(Icons.delete))
TextButton(onPressed: () { counter.reset(); log.clear(); }, child: const Text('Reiniciar'))
```

```dart
// RIGHT
OutlinedButton(onPressed: counter.decrement, child: const Text('-'))
IconButton(onPressed: todos.remove.withArg(id), icon: const Icon(Icons.delete))

// Varias acciones: un método del estado.
void resetAll() {
  reset();
  log.clear();
}
TextButton(onPressed: counter.resetAll, child: const Text('Reiniciar'))
```

[Todos los códigos](README.md)
