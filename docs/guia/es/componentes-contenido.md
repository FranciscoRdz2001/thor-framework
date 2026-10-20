# Contenido

Widgets para mostrar información: texto, íconos, imágenes, tarjetas, listas, tablas y carruseles.

## Text

:::flutter Flutter: `Text`, `TextStyle` · Thor: los mismos

:::bench cat-text
:::

`TextStyle` define tamaño, peso, color y alto de línea; `maxLines` y `overflow` recortan el texto como en Flutter: sin `overflow` el texto se corta sin puntos (`TextOverflow.clip`); pide `TextOverflow.ellipsis` para los puntos suspensivos. Un `DefaultTextStyle(maxLines:, overflow:, softWrap:)` los da por defecto a los `Text` de abajo. Envuelve un título en `Semantics(headingLevel: 2)` para que los lectores de pantalla y los buscadores lo lean como encabezado.

### RichText y SelectableText

:::bench cat-rich-text
:::

`RichText(text: TextSpan(…))` es `Text.rich` con el nombre de Flutter. `SelectableText` se puede seleccionar aunque esté dentro de una tarjeta o un botón.

## Icon

:::flutter Flutter: `Icon(Icons.search)` · Thor: el mismo código

:::bench cat-icon
:::

`Icons` incluye los nombres de Flutter como íconos SVG. La página incluye solo los íconos que renderiza, una vez cada uno.

| Parámetro | Qué hace |
| --- | --- |
| `size` | el lado de la caja; 24 por omisión |
| `color` | el color; sin él, el del texto que lo rodea, como el `IconTheme` de Flutter |
| `semanticLabel` | el texto que anuncia un lector de pantalla; sin él, el ícono es decorativo |

### Variantes

:::bench bench-icons
:::

Cada nombre tiene sus variantes `_outlined`, `_rounded` y `_sharp`, como en Flutter. Los íconos que Flutter refleja (`arrow_back`, `arrow_forward`, `send`, `chevron_left`) se invierten solos en los idiomas de derecha a izquierda.

### Nombres e íconos propios

:::example cat-icons
:::

Están todos los nombres de `Icons` de Flutter, unos 8 700 con sus variantes, y un nombre que no existe es un error de compilación. Las formas son las del [catálogo de Flutter](https://api.flutter.dev/flutter/material/Icons-class.html), con licencia Apache-2.0.

Un ícono que no está en la lista, o un logotipo de marca (`Icons.paypal`, `Icons.apple`), se declara con `IconData.svg`:

```dart
const bolt = IconData.svg('my-bolt', '<path d="M13 2 3 14h9l-1 8 10-12h-9z"/>');
```

## Imágenes y HTML

`Image` muestra una imagen de la app o de una URL; `HtmlWidget`, un HTML que llega como dato.

### Image.asset

:::bench cat-image
:::

Una imagen de la carpeta `web/` de la app; `Image.network` toma una URL. Indica `width` y `height` para que la página no se desplace al cargarla; las imágenes de `web/images/` se publican además en tamaños optimizados.

Mientras la imagen carga, o si falla, se muestra otro widget:

:::bench cat-image-builders
:::

`errorBuilder` y `loadingBuilder` tienen la firma de Flutter. El servidor renderiza el reemplazo junto a la imagen y el navegador lo muestra si la imagen no carga.

> **Diferencia con Flutter:** `error` es un `ImageLoadError` con la URL, sin `stackTrace`, y `loadingBuilder` se llama una sola vez, sin progreso. Sin JavaScript, el navegador muestra su imagen rota con el texto alternativo.

### HtmlWidget

:::bench cat-html-widget
:::

Muestra como contenido seguro un HTML que no escribiste, como la descripción de un producto o un comentario. El servidor lo limpia con una lista permitida y lo renderiza con la tipografía del tema; `sanitizeHtml(html, policy:)` hace la misma limpieza y devuelve un `String`.

| `HtmlPolicy` | Qué hace |
| --- | --- |
| `tags`, `attributes` | la lista permitida: texto, listas, enlaces, imágenes y tablas por omisión |
| `schemes` | los esquemas permitidos en los enlaces: `http`, `https`, `mailto`, `tel` |
| `linkTarget`, `nofollow` | el destino y el `rel` de todos los enlaces |
| `allowDataImages` | permite imágenes incrustadas, nunca SVG |
| `maxLength`, `maxTags`, `maxDepth` | límites contra entradas hostiles |

> **Cuidado:** Scripts, estilos, marcos, eventos y enlaces `javascript:` se eliminan siempre. Si permites `class`, cada clase recibe el prefijo `user-` para que el contenido no use las clases de la app.

## Superficies

`Card` agrupa contenido relacionado y `Divider` lo separa.

### Card

:::bench cat-card
:::

Una superficie con sombra que agrupa contenido relacionado.

### Divider

:::bench cat-divider
:::

Una línea horizontal. `indent` y `endIndent` la separan de los bordes.

## Filas

`ListTile` es la fila de una lista y `ExpansionTile`, una fila que se abre.

### ListTile

:::bench cat-list-tile
:::

Una fila con `leading`, `title`, `subtitle` y `trailing`. Con `href` es un enlace y con `onTap`, un botón; `selected` marca la fila actual.

`minTileHeight` fija el alto mínimo de la fila (en lugar de 48 o 56) y `minVerticalPadding`, el espacio mínimo arriba y abajo; `ListTileThemeData` los da a todas las filas.

### ExpansionTile

:::bench cat-expansion-tile
:::

Una fila que se abre para mostrar más contenido. Varios con el mismo `name`, o dentro de un `ExpansionPanelList(name:)`, forman un acordeón: abrir uno cierra los demás.

`controlAffinity: ListTileControlAffinity.leading` pone la flecha antes del título; `showTrailingIcon: false` la quita (también un `trailing:`, como en Flutter) y `trailing:` pone otro widget en su lugar. `dense` y `minTileHeight` acortan la cabecera. `iconSize`, `iconTurns` y `collapsedIconTurns` cambian el tamaño de la flecha y cuánto gira abierta y cerrada (una cabecera densa que gira −90° cerrada: `iconSize: 13, iconTurns: 0, collapsedIconTurns: -0.25`). Para que otra pieza cambie con la sección abierta, `.when(open: …)` en su estilo (`Text('12', style: TextStyle(color: gris).when(open: azul))`).

## Chips y distintivos

Etiquetas pequeñas que acompañan a otro contenido.

### CircleAvatar y Badge

:::bench cat-avatar-badge
:::

`CircleAvatar` muestra iniciales, un ícono o una foto (`backgroundImage`). `Badge` agrega un número o un punto en la esquina de su hijo, y `Badge.count` muestra `999+` a partir de `maxCount`.

| Parámetro de `Badge` | Qué hace |
| --- | --- |
| `backgroundColor`, `textColor` | los colores; por omisión, los de error del tema |
| `smallSize`, `largeSize` | el tamaño del punto y el alto con número |
| `alignment`, `offset` | la esquina y el desplazamiento |
| `isLabelVisible` | `false` deja solo el hijo |

### Chip y ActionChip

:::bench cat-chip
:::

`Chip` es una etiqueta y `ActionChip`, una etiqueta que se pulsa. `Chip(onDeleted:)` agrega una equis; los chips que se eligen están en [Selección](componentes-seleccion.md#inputchip).

## Tooltip

:::bench cat-tooltip
:::

`Tooltip(message:, child:)` muestra una burbuja al pasar el puntero o al enfocar el hijo con el teclado, y los lectores de pantalla la leen como descripción del hijo. Puede ser la raíz de un estado de `Watch`: la marca del estado queda en su caja y los demás estados son sus hermanos. El id de la burbuja es el mismo en cada estado de un `Watch` (se cuenta por posición), así que cambiar de estado no lo reescribe.

> **Diferencia con Flutter:** En una pantalla táctil no aparece con una pulsación larga y no se cierra con Esc. Si el texto es importante, muéstralo en la página.

## Tablas y carruseles

`DataTable` ordena datos en filas y columnas; `CarouselView` los muestra uno tras otro.

### DataTable

:::bench cat-data-table
:::

Una tabla con encabezados. `numeric` alinea una columna a la derecha y `sortColumnIndex` muestra la flecha de orden; `DataColumn(onSort:)` ordena desde el ViewModel y `DataRow(onSelectChanged:)` agrega una casilla por fila.

### CarouselView

:::example carousel
:::

Un carrusel que se desliza con el dedo, la rueda, el trackpad o el teclado, sin JavaScript. Las flechas y los indicadores se configuran con parámetros.

| Parámetro | Qué hace |
| --- | --- |
| `showArrows`, `arrowStyle`, `arrowPosition` | las flechas: visibles por omisión, dentro o fuera |
| `showIndicators`, `indicatorStyle` | un punto por ítem; con `activeSize` mayor, el activo es una píldora |
| `layout` | ítems por vista y espacio entre ellos, con variantes por clase de tamaño |
| `previousLabel`, `nextLabel`, `slideLabel` | los nombres accesibles, para traducirlos |
| `autoPlay` | avanza solo; se pausa con el puntero o el foco y no corre con movimiento reducido |
