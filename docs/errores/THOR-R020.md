# THOR-R020 · Un árbol de widgets demasiado profundo para la pila

**Dónde:** `thor_ui` · el render de la página (`PageBuild.buildRoot`).

## Qué pasó

La página anida tantos widgets que la construcción se quedó sin pila. El
mensaje dice cuántos elementos había arriba del que falló y los dos
extremos de la cadena (los primeros y los últimos seis), para ver qué se
repite.

## Por qué

El render de thor es recursivo: cada nivel del árbol usa unos marcos de la
pila. Unos 2400 `Container` anidados agotan la pila en release (menos de
2000 en debug o en `thor test`). Antes de este código la página respondía
500 con miles de marcos repetidos en el log; ahora falla con este mensaje
y la ruta muestra su página de error, como cualquier otra excepción.

Ninguna interfaz real necesita esa profundidad: suele ser una recursión que
anida en vez de listar.

## Cómo se arregla

```dart
// WRONG: cada elemento envuelve al siguiente; 3000 elementos = 3000 niveles
Widget chain(List<Item> items) => items.isEmpty
    ? const SizedBox.shrink()
    : Container(child: Column(children: [Text(items.first.name), chain(items.skip(1).toList())]));
```

```dart
// RIGHT: los elementos son hermanos; la profundidad no crece con la lista
Column(children: [for (final item in items) Text(item.name)])
```

[Todos los códigos](README.md)
