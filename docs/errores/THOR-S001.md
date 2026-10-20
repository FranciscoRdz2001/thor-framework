# THOR-S001 · Un `Watch` o un callback recibe un closure

**Dónde:** `thor_ui` · `Watch`, `row.*`, `onPressed`/`onChanged` ligados a un estado.

## Qué pasó

Un `Watch`, un `itemKey` o un binding recibió una función anónima en lugar de un campo o un método de un `ThorState`.

## Por qué

El navegador encuentra lo que tiene que actualizar **por nombre** (`counter.label`): el servidor escribe ese nombre en el HTML y el navegador lo busca. Un closure no tiene nombre que el navegador pueda buscar.

El editor lo marca al escribirlo (`thor_lints`, regla `state_misuse`) cuando el closure es la fuente de un `Watch` y usa un estado, y `thor dev` / `thor build` lo reportan con archivo y línea. Un closure como callback de un botón es [THOR-S011](THOR-S011.md).

## Cómo se arregla

```dart
// WRONG
Watch(() => '${counter.count.value} items')
```

```dart
// RIGHT
// En el estado:
String itemsLabel() => '${count.value} items';

// En el widget:
Watch(counter.itemsLabel)
```

[Todos los códigos](README.md)
