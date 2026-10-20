# THOR-B030 · Un lambda de fila que el build no puede dar al navegador

**Dónde:** `thor build`, `thor dev`, `thor test` (el paso de generación) · `row.text((o) => …)` (y `bindText`, `bind`, `attribute`, `field`) y `row.watch((o) => …)`.

## Qué pasó

El build encontró un `row.text(lambda)` sobre una fila de `Watch.list` que no es una propiedad `String` tal cual (`(o) => o.customer`) ni una `int`, `num`, `double` o `bool` como texto (`(o) => '${o.id}'`, `o.id.toString()`; en `row.watch`, una propiedad `bool` o enum: `(o) => o.isOffer`), o cuya fila es una clase que no se puede sondear: privada, con parámetros de tipo, o `final`, `sealed` o `base`.

## Por qué

Ver [THOR-S033](THOR-S033.md): el navegador lee la propiedad, no corre el lambda. Para saber cuál lee, el servidor llama al lambda con una sonda que el build escribe como `implements` de la clase de la fila; una clase que no se puede implementar desde otro archivo no tiene sonda.

## Cómo se arregla

Un método del estado en lugar del lambda (`row.text(orders.customerOf)`), o una clase de fila pública, sin parámetros de tipo y sin `final`/`sealed`/`base`.

[Todos los códigos](README.md)
