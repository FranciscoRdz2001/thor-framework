# THOR-S043 · Una key repetida en un `Watch.tree`

**Dónde:** `thor_ui` · `Watch.tree(itemKey: …)`.

## Qué pasó

Dos nodos del árbol devolvieron la misma key, o un nodo aparece entre sus propios descendientes (un ciclo).

## Por qué

El navegador reconcilia cada nivel por key y un callback con `withArg(row.key)` nombra un nodo: con dos nodos de la misma key no sabría a cuál le toca. Un ciclo no termina nunca: el servidor lo corta en la primera key que vuelve a ver.

## Cómo se arregla

```dart
// WRONG: el id del tipo de widget, que se repite
String idOf(Node n) => n.type;
```

```dart
// RIGHT: un id único en todo el árbol
String idOf(Node n) => n.id;
```

Más en [Estado](../guia/es/estado.md#árboles).

[Todos los códigos](README.md)
