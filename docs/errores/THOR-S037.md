# THOR-S037 · Un estado de `QueryBuilder` que no se pudo dibujar sin dato

**Dónde:** `thor dev` · consola del navegador; el aviso sale cuando la query llega a un estado que el servidor no dibujó.

## Qué pasó

Un `QueryBuilder` cuyo `builder` lee `snapshot.data!` (o `requireData`) en la rama «con dato», y el servidor pintó sin dato (la query es `ssr: false`, o falló el primer pintado). El dato llegó pero el esqueleto no cambia.

```dart
QueryBuilder<List<Review>>(
  query: reviews,
  builder: (context, snapshot) => snapshot.hasData
      ? Text('${snapshot.data!.length} reseñas')   // el servidor no tiene el dato
      : const Skeleton(height: 24),
)
```

## Por qué

El `builder` corre en el servidor, una vez por estado, y el navegador solo cambia entre ellos. Para tener listo el estado «con dato» el servidor llama al `builder` con un `AsyncSnapshot.placeholder` (`hasData` en `true`; leer `data` lanza): ahí `snapshot.data!`, `data ?? []` o `requireData` lanzan y el estado no se manda (mejor sin él que con un valor inventado, como una lista vacía). El navegador no vuelve a ejecutar el `builder`: el valor tiene que ir ligado, no leído.

En producción (sin `thor dev`) la página es la misma, pero un error que **no** es una lectura del dato (un cast que falla, un índice fuera de rango: un bug de verdad, que el estado vivo también tendría) llega al `onError` del servidor, una vez por `builder`. Un `data!`, una llamada sobre null o `requireData` son lecturas esperadas y no se reportan.

## Cómo se arregla

```dart
// RIGHT: lo que cambia con el dato va por el estado
QueryBuilder<List<Review>>(
  query: reviews,
  builder: (context, snapshot) => snapshot.hasData
      ? Watch(shop.reviewCount)            // String reviewCount() => '${reviews.data.value?.length ?? 0} reseñas';
      : const Skeleton(height: 24),
)

// o: un dato de relleno, si de verdad lo necesitas en el builder
QueryBuilder<List<Review>>(query: reviews, initialData: const [], builder: …)
```

[Todos los códigos](README.md)
