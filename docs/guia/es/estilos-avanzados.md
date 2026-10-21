# Estilos avanzados

Aplica lo que ningún widget expresa: posición fija, desplazamiento interno,
unidades de la ventana, clases de tus componentes y HTML que no viene de
widgets.

## Qué usar, en orden

Empieza por arriba y baja un nivel solo cuando el anterior no alcanza.

:::ladder
### Props del widget
Casi todo: `Container(padding:, decoration:)`, `Text(style:)`,
`Row(spacing:)`. Es lo que escribirías en Flutter.
### Wrappers
Para decorar sin agregar elementos: `Padding`, `Opacity`, `Transform`,
`BackdropFilter` (desenfoca lo que hay detrás), `ClipRRect`, `Link`. Se funden en el elemento de su hijo.
### Variantes con `.when()`
Lo que cambia por ancho, estado, tema o tamaño del contenedor:
`EdgeInsets.all(16).when(medium: EdgeInsets.all(32))`. Ver
[Tema y estilos](tema-y-estilos.md#variantes-con-when).
### `StyleProps` en `Styled`
Lo que ningún widget expresa: posición fija, desplazamiento interno,
unidades como `100.dvh` y números que cambian con `.when()`. Ver
[StyleProps en Styled](#styleprops-en-styled).
### Hojas de estilo propias
Las clases de tus componentes y los estados que ningún widget expresa. Ver
[Hojas de estilo propias](#hojas-de-estilo-propias).
### `Styled(descendants:)`
HTML que no construye ningún widget, como markdown o el contenido de un CMS.
Ver [HTML sin widgets](#html-sin-widgets).
:::

Cada nivel tiene tipos: el analizador detecta un error tipográfico, el editor
autocompleta y los valores que vienen de tus datos se escapan antes de llegar
a la página.

## `StyleProps` en `Styled`

`Styled(style:)` aplica un `StyleProps` al elemento de su hijo, sin agregar
otro. En la lista, cada letra queda fija arriba (`BoxPosition.sticky`) hasta
que la siguiente la empuja.

```dart
Styled(
  style: StyleProps(
    position: BoxPosition.sticky(top: 0.px),
    zIndex: 20,
    maxHeight: 100.dvh - 72.px,
    overflowY: Overflow.auto,
  ),
  child: TableOfContents(),
)
```

:::example sticky-list
:::

| Prop | Tipo | Efecto |
|---|---|---|
| `position` | `BoxPosition` | `sticky`, `fixed`, `absolute` o `relative` |
| `overflowX`, `overflowY` | `Overflow` | desplazamiento interno cuando el contenido no cabe |
| `minWidth`, `maxWidth`, `minHeight`, `maxHeight` | `Length` | límites en cualquier unidad |
| `zIndex` | `int` | orden entre elementos superpuestos |
| `backdropFilter` | `ImageFilter` | filtra lo que hay detrás (`ImageFilter.blur(sigmaX: 8)`; también `saturate`, `brightness`, `contrast`, `grayscale`, `invert`, `sepia`, `hueRotate`, `opacity`, encadenados con `ImageFilter.compose`); o `BackdropFilter` |
| `scrollbarWidth`, `scrollbarThumbColor`, `scrollbarTrackColor` | `ScrollbarWidth`, `Color` | la barra de desplazamiento del elemento |
| `opacity`, `scale`, `offset`, `turns` | números | solo con `.when()`; un valor fijo va en `Opacity` o `Transform` |
| `textTransform`, `textOverflow`, `textUnderlineOffset`, `lineClamp` | `TextTransform`, `TextOverflow`, `Length`, `int` | texto de HTML que ningún widget construye; para un `Text`, `maxLines:` y `overflow:` |
| `inset`, `scrollPadding` | `Length`, `EdgeInsetsGeometry` | `inset: 0.px` cubre la caja con `position`; `scrollPadding` deja aire al desplazarse a un hijo |
| `backgroundClip` | `BackgroundClip` | `BackgroundClip.text` muestra el fondo a través de las letras (con texto transparente) |
| `aspectRatio` | `double` | una fracción sale como fracción: `4 / 3` escribe `aspect-ratio: 4 / 3` |

`BoxPosition` recibe sus distancias como `Length`:
`BoxPosition.fixed(bottom: 16.px, right: 16.px)`. Dentro de un `Stack`, usa
`Positioned` como en Flutter.

`Styled` no reemplaza a los widgets. Lo que un widget ya expresa (`padding`,
`decoration`, `color`, un número fijo) va en ese widget; el lint
`widget_props_in_styled` lo señala.

```dart
// WRONG (widget_props_in_styled): padding belongs to a widget
Styled(style: StyleProps(padding: EdgeInsets.all(12)), child: child)

// RIGHT
Padding(padding: EdgeInsets.all(12), child: child)
```

Un número que cambia con `.when()` sí va en `Styled`, y su `duration:`
convierte el cambio en una transición:

:::example hover-effects
:::

La [referencia de la API](../../api/thor_ui.md#estilos) lista el
resto de las props de `StyleProps`.

### Valores por elemento, mezclas y degradados

Un color o un tamaño que viene de un dato (el acento de una tienda) no se
escribe con `raw:`. `ElementVariables` lo pone como variable CSS en el
elemento, una vez por valor distinto, y la hoja de estilo la lee:

```dart no-check
const accent = CssVariable<Color>('--accent');

ElementVariables(
  {accent: Color(store.primaryColor)},
  child: const StoreCard(), // its rules read Color.variable(accent)
)
```

`Color.lerp(a, b, t)` mezcla dos colores (con un color del tema, el
navegador hace un `color-mix`), `color.withOpacity(.22)` lo vuelve
translúcido, y `RadialGradient.ellipse` pone la elipse y el punto como en
CSS:

```dart
BoxDecoration(
  gradient: RadialGradient.ellipse(
    center: Alignment(-0.48, -0.68), // 26% 16%
    radiusX: 1.2,
    radiusY: 1,
    colors: [accent.withOpacity(.22), Colors.transparent],
  ),
)
```

Un margen negativo (`StyleProps(margin: EdgeInsets.symmetric(vertical: -12))`)
va en `Styled`: `Container(margin:)` lo rechaza, como Flutter. En una hoja de
estilo, `css.container('(min-width: 36rem)', […])` escribe un `@container`.

## Unidades

Las props de Flutter miden en píxeles lógicos (`double`): `EdgeInsets.all(16)`
son 16 píxeles. Para lo que se mide de otra forma, como el alto de la ventana
o una fracción del padre, existe `Length`.

```dart
16.px            // 16 logical pixels
50.percent       // half of the parent
1.5.em           // 1.5 × the element's font size
1.rem            // 1 × the page's font size
60.ch            // about 60 characters: a good reading width
100.vw           // the window's width
100.dvh          // the window's height now (follows a phone's bars)
```

:::example units
:::

Las operaciones combinan unidades y los límites se escriben con `min`, `max`
y `clamp`:

```dart
100.dvh - 48.px                          // the window minus a bar
(100.vw - 2.rem) / 3                     // a third of the window, minus margins
Length.min([100.percent, 720.px])        // the parent, at most 720 px
Length.clamp(1.rem, 2.vw + 1.rem, 3.rem) // grows with the window, with limits
card.gap.px * 2                          // follows a state field
```

`Length.px(16)`, `Length.min`, `Length.max` y `Length.clamp` son `const`;
`16.px` es la forma corta.

Un elemento con `containerType: ContainerType.size` es una caja que mide:
adentro, `100.cqw` y `100.cqh` son su ancho y su alto (también `cqi`, `cqb`,
`cqmin`, `cqmax`). Esa caja no crece con su contenido: necesita un alto
propio (`Expanded`, `heightLength`). `Ratio.of(a, b)` es `a` entre `b`
(cuántas veces cabe `b` en `a`), un número que calcula el navegador; con
`StyleProps(scaleRatio:)` escala una caja para que quepa en su contenedor,
sin JS ni puntos de corte:

```dart
Expanded(
  child: Styled(
    style: const StyleProps(containerType: ContainerType.size),
    child: SizedBox.expand( // the stage
      child: Styled(
        style: StyleProps(
          transformOrigin: Alignment.topLeft,
          scaleRatio: Ratio.min([
            Ratio.value(1), // never above 100%
            Ratio.of(100.cqh, 844.px),
            Ratio.of(100.cqw, 390.px),
          ]),
        ),
        child: device, // 390 x 844
      ),
    ),
  ),
)
```

`Styled` se funde en el elemento de su hijo, así que el escenario es un
widget con elemento propio (aquí `SizedBox.expand`): las unidades `cq` miden
un ancestro, nunca al elemento mismo.

> **Diferencia con Flutter:** Flutter calcula el layout en Dart y no necesita
> unidades. En la web lo calcula el navegador, y a veces el valor es «el alto
> de la ventana» o «la mitad del padre». `Length` aparece solo donde Flutter
> no tiene equivalente.

## Hojas de estilo propias

Para las clases de tus componentes, escribe reglas con `css()` y dales valores
con `.props()`, el mismo `StyleProps` de arriba. La hoja de un componente va
con él, en `css.components`:

```dart
import 'package:thor_ui/html.dart' show css;
import 'package:thor_ui/thor_ui.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({super.key});

  static final styles = css.components([
    css('.product-card', [
      css('&').props(const StyleProps(padding: EdgeInsets.all(12))),
      css('&:hover').props(const StyleProps(offset: Offset(0, -2))),
    ]),
  ]);

  @override
  Widget build(BuildContext context) =>
      Styled(classes: const ['product-card'], child: const Text('Cold brew'));
}
```

`Styled(classes:)` agrega la clase al elemento del hijo. Una hoja para toda la
app se pasa una vez en `ThorApp.router(styles:)`, y una que solo usan las rutas
de un grupo va en `Group(styles:)`, para que las demás páginas no la descarguen:

```dart
// lib/styles.dart
import 'package:thor_ui/html.dart' show css;
import 'package:thor_ui/thor_ui.dart';

final List<StyleRule> appStyles = [
  css('.card', [
    css('&').props(StyleProps(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
    )),
    css('&:hover').props(const StyleProps(offset: Offset(0, -2))),
  ]),
  WindowSizeClass.medium.media([
    css('.card').props(const StyleProps(padding: EdgeInsets.all(16))),
  ]),
];
```

Una regla varía con su selector y con `WindowSizeClass.media`; `.when()` es
para los widgets.

Un ancho que no es una clase de tamaño va en una hoja con
`css.minWidth(920, [...])` o `css.maxWidth(919.98, [...])`. Una hoja es un solo
texto para todas las peticiones, así que `WindowSizeClass.media` usa los
anchos por defecto salvo que reciba los de la app: guárdalos en una `const` y
pásala al tema y a la hoja.

```dart no-check
const siteBreakpoints = Breakpoints(medium: 640, expanded: 768, large: 1024);
// ThemeData(breakpoints: siteBreakpoints)
WindowSizeClass.medium.media(breakpoints: siteBreakpoints, [...]);
css.minWidth(920, [css('.card').props(const StyleProps(padding: EdgeInsets.all(20)))]);
```

Los widgets (`.when(...)`) ven las cuatro clases de tamaño del tema; para
cualquier otro ancho de su propia caja usa `.when(container: {920: …})`.

> **Importante:** Las reglas de tus hojas ganan siempre a los estilos de los
> widgets. Úsalas para clases propias, no para cambiar todos los elementos de
> un tipo, y no pongas una transición sobre un elemento que ya anima un
> `Animated*`: la reemplaza.

La hoja de un componente (`css.components`) queda debajo de los props propios
de los elementos: `.fila:hover .nombre` no le gana al `fontWeight` del `Text`
de adentro. Para un descendiente que cambia con el estado de un ancestro
(`:hover`, `:has([aria-current])`, `[open]`) usa `css.states`, que va después:

```dart
import 'package:thor_ui/html.dart' show css;
import 'package:thor_ui/thor_ui.dart';

final styles = css.states([
  css('.tree-row:has(a[aria-current]) .tree-name')
      .props(const StyleProps(textStyle: TextStyle(fontWeight: FontWeight.w600))),
]);
```

### Hojas de estilo por nivel

Cada hoja pertenece a un nivel (tema, componentes, app, módulo o página);
[Compilar y publicar](publicar.md) explica cómo compartirlas entre páginas
para que el navegador las guarde en caché.

## HTML sin widgets

El markdown renderizado o el contenido de un CMS no viene de widgets, así que
no tiene props. `Styled(descendants:)` le da estilo con tipos, limitado al
elemento que lo envuelve.

```dart
Styled(
  descendants: {
    '> * + *': const StyleProps(margin: EdgeInsets.only(top: 14)),
    'h2': const StyleProps(
      textStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
      margin: EdgeInsets.only(top: 36),
    ),
    'a': const StyleProps(
      textStyle: TextStyle(decoration: TextDecoration.underline),
    ),
    'img': StyleProps(maxWidth: 100.percent),
  },
  child: DefaultTextStyle(
    style: const TextStyle(fontSize: 16, height: 1.7),
    child: Container(child: html.RawText(markup)),
  ),
)
```

:::example descendants
:::

Cada clave es un selector dentro del elemento (`h2`, `a:hover`, `pre code`) y
cada valor, un `StyleProps` sin variantes. El texto del contenedor sigue
yendo por su widget (`DefaultTextStyle`).

Sin `raw:` para lo común: `EdgeInsetsGeometry.sides` pone solo los lados
que recibe (los otros quedan como los deja el navegador), y un `Length` en
`em` sigue al texto de alrededor.

```dart
Styled(
  descendants: {
    '> :first-child': StyleProps(
      margin: EdgeInsetsGeometry.sides(top: Length.zero),
    ),
    ':not(pre) > code': StyleProps(
      textStyle: TextStyle(fontSizeLength: 0.9.em, heightLength: 1.25.em),
    ),
    'h2': StyleProps(textStyle: TextStyle(fontWeight: FontWeight(650))),
    'img.right': StyleProps(float: BoxFloat.right),
  },
  child: Container(child: html.RawText(markup)),
)
```

## Patrones con degradados

Un degradado con `tile:` se repite en mosaico: un fondo punteado o a rayas sin
imágenes.

```dart
BoxDecoration(
  color: const Color(0xFFECEEF3),
  gradient: RadialGradient(
    colors: [const Color(0xFF4F46E5).withValues(alpha: 0.16), const Color(0x00000000)],
    stops: const [0.125, 0.125],      // a 1px dot (0.125 of the 8px radius)
    tile: const Size.square(16),      // every 16px
  ),
)
```

:::example patterns
:::

> **Diferencia con Flutter:** En Flutter un patrón así es un `CustomPainter`;
> en Thor es un degradado repetido que dibuja el navegador.

## Siguientes pasos

:::cards
- [Tema y estilos](tema-y-estilos.md) — colores, tipografía y variantes con `.when()`
- [Animaciones](animaciones.md) — transiciones, curvas y movimiento reducido
- [Compilar y publicar](publicar.md) — qué recibe el navegador y cómo se guarda en caché
:::
