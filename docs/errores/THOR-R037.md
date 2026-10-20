# THOR-R037 · Un valor que depende de la dirección del texto llegó a un lugar que necesita el lado físico

**Dónde:** `thor_style` · `EdgeInsetsGeometry` (`add`, `+`, `cssLeft`, `cssRight`),
`EdgeInsetsDirectional`, `AlignmentDirectional`; y `SafeArea` cuando su
`Padding` es direccional.

## Qué pasó

Se pidió el lado izquierdo o derecho de algo que se da como `start`/`end`
(`EdgeInsetsDirectional`, `AlignmentDirectional`), o se sumó un
`EdgeInsets.only(left: …)` a un `EdgeInsetsDirectional.only(start: …)`, o se
usó un `AlignmentDirectional` fraccionario (`AlignmentDirectional(0.5, 0)`).

## Por qué

`start` es la izquierda en un texto de izquierda a derecha y la derecha en
uno de derecha a izquierda; eso lo decide el navegador. El CSS no puede
sumar `padding-left` con `padding-inline-start` (el segundo gana, no se
suman), ni mover un hijo una fracción «hacia el final» sin saber el sentido.
Por eso falla el render con este código en vez de pintar un lado equivocado.

## Cómo se arregla

```dart
// WRONG: dos formas del mismo lado, no se pueden sumar en CSS
Padding(
  padding: EdgeInsets.only(left: 4).add(EdgeInsetsDirectional.only(start: 8)),
  child: child,
)
```

```dart
// RIGHT: una sola forma, o fija la dirección con resolve
Padding(
  padding: EdgeInsetsDirectional.only(start: 12),
  child: child,
)
Padding(
  padding: EdgeInsets.only(left: 4)
      .add(EdgeInsetsDirectional.only(start: 8))
      .resolve(TextDirection.ltr),
  child: child,
)
```

Un `AlignmentDirectional` con `start` en −1, 0 o 1 (`topStart`, `centerEnd`…)
no necesita dirección; uno fraccionario sí: usa `Alignment` o
`alignment.resolve(TextDirection.ltr)`.

[Todos los códigos](README.md)
