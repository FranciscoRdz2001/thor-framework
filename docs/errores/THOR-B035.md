# THOR-B035 · Un `derived(...)` que escribe un campo

**Dónde:** `thor_lints` · regla `state_misuse` (en el editor y en `dart analyze`), `thor dev` y `thor build`, con su archivo y línea.

## Qué pasó

La función de un `derived(() => …)` asigna un campo `state(...)` (`x.value = …`, `x.value++`) o llama a `update`, `toggle`, `add`, `remove` o `clear` sobre uno.

## Por qué

Un `derived` corre cuando alguien lee su valor: en medio de dibujar la página o de repartir un cambio, y solo si algo que lee cambió. Una escritura ahí hace que el resultado dependa de quién leyó primero y de cuántas veces, y en el navegador dispara efectos mientras otros aún se calculan.

## Cómo se arregla

La función solo lee. El cambio va en el método del estado que atiende el evento.

```dart
// WRONG
late final visible = derived(() {
  shown.value = rows.value.length; // escribe
  return rows.value.where((r) => r.ok).toList();
});
```

```dart
// RIGHT
late final visible = derived(() => rows.value.where((r) => r.ok).toList());
int shown() => visible.value.length; // lo que se muestra se deriva también
```

Más en [Estado](../guia/es/estado.md#valores-calculados).

[Todos los códigos](README.md)
