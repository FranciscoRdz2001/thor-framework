# Layout

Coloca y da tamaño a los widgets con `Row`, `Column`, `Expanded`, `Stack` y `Grid`, como en Flutter. El navegador hace el layout.

:::flutter Flutter: `Row`, `Stack`, `GridView`, `MediaQuery` · Thor: los mismos widgets y `.when()`, sin `MediaQuery`

## `Row` y `Column`

`mainAxisAlignment` reparte el espacio libre a lo largo del eje principal y `spacing` separa a los hijos.

:::bench bench-row-align
:::

En una `Column`, `crossAxisAlignment` decide el ancho de los hijos: con `start` o `center` cada uno mide lo que su contenido; con `stretch`, todos ocupan el ancho completo.

:::bench bench-column-align
:::

## `Expanded` y `Flexible`

Los dos reparten el espacio que sobra en una `Row` o una `Column`. `Expanded` ocupa toda su parte; `Flexible` puede quedarse en el tamaño de su contenido. `Spacer` es un espacio vacío que empuja al hijo siguiente hasta el final.

:::bench bench-flex
:::

### Una columna sin alto

Una `Column` mide lo que su contenido, salvo que su padre le dé un alto. Sin un alto del padre, un `Expanded` conserva el alto de su contenido, así que un `Flex` que es columna en el teléfono y fila en pantallas anchas funciona en los dos casos.

```dart
// No height to share: Expanded keeps its content's height.
Column(
  children: [
    Text('Basic plan'),
    Expanded(child: Text('Sized by its content')),
    Text('Choose'),
  ],
)

// With a height, Expanded fills what the other children leave.
SizedBox(
  height: 170,
  child: Column(
    children: [
      Text('Basic plan'),
      Expanded(child: Text('Fills the leftover height')),
      Text('Choose'),
    ],
  ),
)
```

> **Diferencia con Flutter:** En Flutter, un `Expanded` dentro de una `Column` sin alto es un error. En Thor conserva el alto de su contenido, pero ignora el `height` de su hijo directo: pon el alto en el contenido (`Container(child: SizedBox(height: 120))`) o usa `Flexible`.

## Tamaños

`SizedBox` da un tamaño exacto; `Container` combina tamaño, relleno y color; `ConstrainedBox` fija un mínimo y un máximo; `FractionallySizedBox` mide una fracción del ancho del padre.

`FittedBox(fit:, alignment:, clipBehavior:)` ajusta una imagen a su caja con `BoxFit` (CSS `object-fit`, sin medir). Un hijo que no es medio (un texto, una caja) no se escala: `contain`, `cover` y `fill` lo estiran a la caja, `scaleDown` lo limita a ella y `none` lo deja en su tamaño.

:::example layout-sizes
:::

### Relativo a la ventana

El servidor no conoce la pantalla, así que no hay `MediaQuery`. Un tamaño relativo a la ventana usa unidades en `Styled`: `vw` es un porcentaje del ancho y `dvh`, del alto. `Length.clamp` acota el valor entre un mínimo y un máximo.

:::example layout-screen
:::

### Zonas seguras del teléfono

`SafeArea` separa a su hijo de la muesca y de las barras del sistema. Cada lado usa el mayor valor entre el que indica el dispositivo y `minimum`.

```dart
SafeArea(
  minimum: const EdgeInsets.symmetric(horizontal: 16),
  child: const Text('Clear of the notch'),
)
```

## `Stack` y `Positioned`

El primer hijo sin `Positioned` da el tamaño del `Stack`, y cada `Positioned` se coloca respecto de sus bordes. Como en Flutter, el `Stack` recorta lo que sobresale; `clipBehavior: Clip.none` lo muestra completo.

`alignment` coloca los hijos sin `Positioned`: las nueve posiciones con nombre y cualquier `Alignment(0.5, -0.5)` fraccionario, en `Stack` e `IndexedStack`.

:::bench bench-stack
:::

### Un Stack solo con hijos posicionados

Si todos los hijos son `Positioned`, ninguno le da alto y el `Stack` mide 0. Dale un padre con tamaño, un hijo sin `Positioned` o `StackFit.expand` dentro de un padre con tamaño.

```dart
// Measures 0: no child gives it a height.
Stack(
  children: [
    Positioned(left: 8, top: 4, child: Container(width: 120, height: 40)),
  ],
)

// The SizedBox gives it the height.
SizedBox(
  height: 60,
  child: Stack(
    children: [
      Positioned(left: 8, top: 4, child: Container(width: 120, height: 40)),
    ],
  ),
)
```

> **Diferencia con Flutter:** En Flutter, un `Stack` sin hijos normales ocupa todo el espacio que recibe; en Thor mide 0 de alto.

## `Wrap` y `Grid`

`Wrap` coloca a los hijos en fila y pasa a la línea siguiente cuando no caben.

:::bench bench-wrap
:::

`Grid` reparte a los hijos en columnas iguales, y cada fila mide lo que su celda más alta. `GridItem` hace que un hijo ocupe varias columnas o la fila completa.

:::bench bench-grid
:::

### `GridView`

`GridView.extent(maxCrossAxisExtent:)` calcula las columnas como en Flutter, sin breakpoints; `GridView.count` fija su número y `GridView.builder` acepta los dos `SliverGridDelegate` de Flutter. Con `autoRowHeight: true`, cada fila mide lo que su celda más alta, sin `childAspectRatio`.

:::example layout-grid-extent
:::

> **Diferencia con Flutter:** `GridView.builder` construye todas las celdas en el servidor, así que `itemCount` es obligatorio.

### Columnas de ancho fijo

`GridLayout(columnWidth:)` crea tantas columnas de ese ancho exacto como quepan, con `gap` entre ellas. Se combina con `.when()`: dos columnas fluidas en el teléfono y columnas de 260 desde `medium`.

```dart
Grid(
  layout: GridLayout(columns: 2, gap: 16)
      .when(medium: GridLayout(columnWidth: 260, gap: 24)),
  children: [for (final p in products) ProductCard(p)],
)
```

### Columnas con proporciones

`GridLayout(columnSizes:)` da un tamaño a cada columna, como `Expanded(flex:)` en un `Row`: `GridSize.flex(n)` reparte el espacio libre por proporción, `GridSize.fixed(px)` mide exactamente eso y `GridSize.auto` se ajusta a su contenido. También admite `.when()`.

```dart
Grid(
  layout: GridLayout(columnSizes: [GridSize.flex(1)], gap: 16)
      .when(medium: GridLayout(columnSizes: [GridSize.flex(2), GridSize.flex(1)])),
  children: [main, aside],
)
```

## Scroll

Una vista con scroll necesita un tamaño en su eje: un alto para el scroll vertical y el ancho del padre para el horizontal. `ListView` y `ListView.builder` funcionan como en Flutter.

:::example layout-scroll
:::

### Con el teclado

Una región con scroll sin elementos enfocables recibe el foco con Tab y se desplaza con las flechas. Un `Semantics(label:)` alrededor hace que el lector de pantalla la anuncie; `NeverScrollableScrollPhysics()` la saca del orden de tabulación.

```dart
Semantics(
  label: 'Results',
  child: SizedBox(height: 300, child: ListView(children: rows)),
)
```

### `PageView`

`PageView` muestra páginas del tamaño de la vista que encajan al deslizar, con el dedo, el trackpad o el teclado, sin JavaScript. `pageSnapping: false` desactiva el encaje; para leer o cambiar la página actual, usa un `PageController` en un ViewModel ([Estado](estado.md#pageview-y-pagecontroller)).

```dart
SizedBox(
  height: 120,
  child: PageView(children: const [Text('One'), Text('Two'), Text('Three')]),
)
```

## Responsivo

`.when()` cambia un valor según el ancho de la ventana. El valor base es el del teléfono, y cada clase de tamaño (`medium` 600, `expanded` 840, `large` 1200, `extraLarge` 1600, las `WindowSizeClass` de Material 3) lo reemplaza desde ese ancho.

:::example layout-responsive
:::

`.when()` acepta `EdgeInsets`, `BoxConstraints`, `BorderRadius`, `Color`, `TextStyle`, `BoxDecoration`, `StyleProps`, `FlexLayout` y `GridLayout`. `ResponsiveVisibility(visibleFrom: WindowSizeClass.medium, child: …)` muestra un widget solo desde una clase de tamaño.

### Según el contenedor

Para seguir el ancho de un contenedor y no el de la ventana, como una tarjeta en una barra lateral, envuélvelo en `LayoutScope` y usa `.when(container: {…})`.

:::bench bench-responsive
:::

> **Consejo:** `ResponsiveLayout(mobile:, desktop:)` renderiza todas las variantes y oculta las que no corresponden, así que el contenido viaja dos veces. Si solo cambia la disposición, conserva un árbol y cambia su layout con `.when()`.

Las equivalencias de `MediaQuery` y `LayoutBuilder` están en [Si vienes de Flutter](desde-flutter.md#nombres-de-flutter-que-no-existen).

## Siguientes pasos

:::cards
- [Interactividad](interactividad.md) — lo que cambia sin recargar la página
- [Tema y estilos](tema-y-estilos.md) — colores, tipografía, modo oscuro y unidades
- [Componentes](componentes.md) — cada widget con su ejemplo, su código y sus parámetros
:::
