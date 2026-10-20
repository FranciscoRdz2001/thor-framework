# THOR-L001 · Un `Row` o una `Column` se desborda

**Dónde:** inspector de desarrollo (modo debug, en el navegador).

## Qué pasó

El contenido de un `Row`/`Column` mide más que el propio flex: se marca con un contorno rojo y un aviso en la consola.

## Por qué

Es el "A RenderFlex overflowed" de Flutter. En la web el contenido no se recorta: se sale de la caja y empuja o tapa lo de al lado.

## Cómo se arregla

```dart
// WRONG
Row(children: [Icon(Icons.info), Text(longText)])
```

```dart
// RIGHT
Row(children: [Icon(Icons.info), Expanded(child: Text(longText))])
// o Flexible, o Wrap si los hijos deben bajar de línea.
```

[Todos los códigos](README.md)
