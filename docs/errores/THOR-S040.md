# THOR-S040 · Una lista virtual sin la altura de sus filas

**Dónde:** `thor_ui` · `Watch.list(virtual: true)`.

## Qué pasó

`Watch.list` recibió `virtual: true` sin `itemExtent`.

## Por qué

Una lista virtual deja en la página solo las filas cercanas a la pantalla. El navegador sabe cuáles son sumando alturas: con filas de la misma altura es una división sobre la posición del scroll, sin medir ninguna fila. Sin esa altura no hay forma de saber qué fila va en qué lugar.

## Cómo se arregla

```dart
// WRONG
Watch.list(market.rows.call, itemKey: market.keyOf, virtual: true, each: …)
```

```dart
// RIGHT: la altura de cada fila, en px
Watch.list(market.rows.call, itemKey: market.keyOf, itemExtent: 34, virtual: true, each: …)
```

Más en [Listas largas](../guia/es/listas-largas.md).

[Todos los códigos](README.md)
