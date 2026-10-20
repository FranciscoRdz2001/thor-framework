# THOR-R033 · Un `FutureBuilder` deja el esqueleto cuando su futuro termina en `null`

**Dónde:** `thor_ui` · `FutureBuilder<T?>`; la terminal de `thor dev` y el
lint `future_builder_nullable_has_data` del editor.

## Qué pasó

El futuro de un `FutureBuilder` terminó con `null` (por ejemplo «no existe ese
producto») y el `builder` pintó lo mismo que pinta mientras espera: la persona
se queda viendo el esqueleto para siempre.

## Por qué

Como en Flutter, `snapshot.hasData` es `false` cuando el dato es `null`. Un
`builder` que solo mira `hasData` no distingue «todavía no llega» de «llegó y
no hay nada».

## Cómo se arregla

Cuando `T` puede ser `null`, pregunta primero por `connectionState`.

```dart
// WRONG: con Future<Product?> el esqueleto no se va si no hay producto
FutureBuilder<Product?>(
  future: data.product,
  builder: (context, snapshot) =>
      snapshot.hasData ? ProductCard(snapshot.data!) : const Skeleton(height: 240),
)
```

```dart
// RIGHT: esperando, esqueleto; terminó, con dato o sin él
FutureBuilder<Product?>(
  future: data.product,
  builder: (context, snapshot) =>
      snapshot.connectionState != ConnectionState.done
      ? const Skeleton(height: 240)
      : snapshot.hasData
      ? ProductCard(snapshot.data!)
      : const Text('Producto no encontrado'),
)
```

Si el `null` es un error de verdad (un `404`), espera el dato en `load` y lanza
`NotFound()`: la respuesta sale con su `404`.

Si el `builder` le pasa el `snapshot` a otra función, el lint no lo juzga; el
aviso de `thor dev` sí, porque compara lo que se pinta.

[Todos los códigos](README.md)
