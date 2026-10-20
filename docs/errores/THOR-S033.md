# THOR-S033 · Un lambda de fila que hace más que leer una propiedad

**Dónde:** `thor_ui` · `row.text(…)` (y `bind`, `attribute`, `field`, `watch`) al pintar (y THOR-B030 al construir).

## Qué pasó

`row.text` recibió un lambda que no es solo `(o) => o.propiedad` (para `row.watch`, una propiedad `bool` o enum): llama a un método (`o.name.trim()`), interpola, junta dos propiedades, lee algo que no es un `String` (un `int`, `num`, `double` o `bool` sí vale como texto: `'${o.id}'` o `o.id.toString()`) o devuelve una constante.

## Por qué

El lambda corre en el servidor para pintar la fila; el navegador no puede correrlo. Para las filas nuevas y los cambios lee él mismo la propiedad de cada elemento, así que solo entiende «lee esta propiedad y muéstrala tal cual».

## Cómo se arregla

```dart
// WRONG
row.text((o) => o.customer.toUpperCase())
row.text((o) => '${o.first} ${o.last}')
```

```dart
// RIGHT: un método del estado
String customerOf(Order o) => o.customer.toUpperCase();
String fullName(Person p) => '${p.first} ${p.last}';

row.text(orders.customerOf)
row.text(people.fullName)

// o solo la propiedad, tal cual
row.text((o) => o.customer)
row.text((o) => '${o.id}')   // un int como texto
```

[Todos los códigos](README.md)
