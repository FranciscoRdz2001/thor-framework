# THOR-S015 · Un estado leído mientras el servidor pinta

**Dónde:** `thor_lints` · regla `frozen_state_read` (en el editor y en `dart analyze`); `thor dev` y `thor build` lo imprimen como aviso.

## Qué pasó

Un `build` (o una función que este llama) leyó el `.value` de un campo `state(...)`, de una `query` (`orders.data.value`), llamó al campo (`counter.count()`) o a un método o getter de un `ThorState` que lee estado (`Text(counter.label())`), o recorrió con `for`, `.map` o `ListView.builder` una lista que devuelve un método o un getter de un `ThorState`. La página se ve bien la primera vez y **no cambia** cuando el estado cambia en el navegador.

## Por qué

`build` corre una vez, en el servidor. Lo que lee ahí es la foto del estado en ese momento y termina escrito en el HTML; el navegador no vuelve a ejecutar `build`. Solo lo que va ligado al estado (`Watch`, `row.text`) se actualiza. Un valor reactivo leído fuera de un ámbito que lo siga no se actualiza.

Es un aviso, no un error: a veces la foto es lo que quieres. No se marca:

- lo que va dentro de un `Watch`, `ValueListenableBuilder`, `QueryBuilder` o `row.watch` (`builder:` y `each:`), ni el código de un `ThorState` (corre en el navegador);
- un closure que es un callback (`onPressed: () => …`: corre después);
- `untracked(() => x.value)` y `x.peek()`: el nombre ya dice que es una foto;
- el valor inicial de un control (`value:`, `groupValue:`, `initialValue:` o `selected:` de un widget con `onChanged:`): desde ahí el control lleva su propio valor;
- un campo que no es `state(...)` (datos que el estado guarda y no cambian).

Para dejar una foto a propósito, `// ignore: thor_lints/frozen_state_read` y la razón en la línea de arriba.

## Cómo se arregla

```dart
// WRONG
Text('Pedidos: ${orders.pending.value}')
ListView(children: [
  for (final o in ordersState.rows()) ListTile(title: Text(o.customer)),
])
```

```dart
// RIGHT: el campo (o un método del estado) va a Watch
Watch(ordersState.pendingLabel)

// una lista: Watch.list, y cada fila lee sus textos con métodos
Watch.list(
  ordersState.rows,
  itemKey: ordersState.rowKey,
  each: (row) => ListTile(title: row.text(ordersState.customerOf)),
)
```

[Todos los códigos](README.md)
