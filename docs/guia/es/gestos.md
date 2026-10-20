# Gestos

Responde a toques, pulsaciones, arrastres, deslizamientos y pellizcos con
`GestureDetector` y `Gesture`: el navegador sigue el dedo y tu método corre al
soltar.

:::flutter Flutter: `GestureDetector`, `InkWell`, `Dismissible`, `Draggable` · Thor: los mismos, con métodos del ViewModel

## Posición del toque

`onTapDown` y `onTapUp` reciben la posición en píxeles desde la esquina
superior izquierda del elemento. Un lienzo es un solo elemento y el método
sabe dónde dibujar.

:::bench bench-tap-position
:::

:::flutter
@flutter
```dart no-check
GestureDetector(
  onTapUp: (details) => addAt(details.localPosition),
  child: const SizedBox(width: 300, height: 180),
)
```
@thor
```dart
Gesture(
  onTapUp: circles.at,                   // void at(double x, double y)
  child: const SizedBox(width: 300, height: 180),
)
```
:::

`onTapDown` se llama al bajar el puntero, aunque el toque termine en un
arrastre. `onTapUp` solo se llama si el toque termina como toque: no tras
moverse más de 8 px, deslizar o mantener. Con el teclado, Enter o Espacio
sobre el elemento enfocado es un toque en su centro.

> **Diferencia con Flutter:** `Gesture` entrega `x` e `y` como dos números;
> `GestureDetector` entrega `TapDownDetails` y `TapUpDetails`. `onTap` se
> llama al instante aunque haya `onDoubleTap`. Los callbacks son métodos de un
> ViewModel (`ThorState`), no closures.

## `Gesture`

`Gesture` reúne todos los gestos y las opciones de arrastre y pellizco. En un
arrastre, tu método recibe `dx` y `dy` al soltar.

:::bench bench-drag
:::

```dart
// A card dragged vertically that stays where you drop it.
Gesture(
  onDragEnd: board.moved,             // void moved(double dx, double dy)
  drag: const Drag(axis: Axis.vertical, snapBack: false),
  child: TaskCard(t),
)

// A photo that zooms with two fingers.
Gesture(
  onScaleEnd: viewer.zoom,            // void zoom(double scale)
  pinch: const Pinch(max: 3),
  child: Image.network(url, width: 800, height: 600),
)
```

| Gesto | Tu método recibe | Con teclado |
|---|---|---|
| `onTap`, `onDoubleTap`, `onLongPress` | nada, o el argumento de `withArg` | Enter o Espacio (`onTap`); tecla de menú (`onLongPress`) |
| `onTapDown`, `onTapUp` | `x`, `y` | Enter, Espacio (en el centro) |
| `onSwipe` | `SwipeDirection` (`start`, `end`, `up`, `down`) | Mayús + flecha |
| `onDragEnd` | `dx`, `dy` | flechas |
| `onScaleEnd` | la escala | `+` / `−` |

`onDoubleTap` cuenta dos toques en menos de 300 ms; `onLongPress`, mantener
unos 500 ms sin moverse o un clic derecho.

| Objeto | Parámetros | Para |
|---|---|---|
| `Swipe` | `axis` (horizontal), `dismiss`, `threshold` (0.4 del ancho) | `onSwipe` |
| `Drag` | `axis` (`null`: libre), `snapBack`, `step` (px por flecha) | `onDragEnd` |
| `Pinch` | `min`, `max`, `snapBack`, `step` (por tecla) | `onScaleEnd` |
| `Press` | `scale`, `opacity` | respuesta visual al presionar |

`Gesture` no agrega elementos: se aplica al elemento de su hijo. Si el hijo no
es un botón ni un enlace, le da el rol de botón y el manejo de teclado. Un
deslizamiento horizontal deja pasar el desplazamiento vertical de la página, y
al revés.

> **Importante:** Mientras dura el arrastre, el desplazamiento y la escala del
> gesto reemplazan los que tenga el elemento. Con movimiento reducido,
> `feedback: Press()` escala sin animar.

### Deslizar

Deslizar es un gesto de trazo, y las pautas de accesibilidad (WCAG 2.5.1)
piden otra forma de hacerlo: `onSwipe` responde también a Mayús + flecha.
Agrega además un botón visible para la misma acción.

:::example gesture-swipe-keys
:::

```dart
Gesture(
  onSwipe: inbox.swiped.withArg(m.id),   // void swiped(int id, SwipeDirection d)
  swipe: const Swipe(dismiss: true),
  feedback: const Press(scale: 0.97),
  child: MessageRow(m),
)
```

En horizontal llega `start` o `end`, que siguen la dirección del texto: en
árabe o hebreo, deslizar a la izquierda es `end`. En vertical llega `up` o
`down`. Un campo de texto conserva sus teclas, así que no se desliza con el
teclado.

## `GestureDetector` e `InkWell`

`GestureDetector` e `InkWell` son los widgets de Flutter, construidos sobre
`Gesture`: `GestureDetector` para gestos sin aspecto propio, `InkWell` e
`InkResponse` para un área que se toca y responde al puntero.

```dart
GestureDetector(
  onTap: inbox.open,                  // void open()
  onLongPress: inbox.menu,
  onHorizontalDragEnd: inbox.swiped,  // void swiped(SwipeDirection d)
  child: MessageTile(m),
)

InkWell(
  onTap: inbox.open,
  borderRadius: BorderRadius.circular(12),
  child: MessageTile(m),
)
```

:::example gesture-inkwell
:::

| `GestureDetector` | Recibe |
|---|---|
| `onTap`, `onDoubleTap`, `onLongPress` | lo mismo que en `Gesture` |
| `onTapDown`, `onTapUp` | `TapDownDetails`, `TapUpDetails` (`localPosition`) |
| `onPanUpdate` | `DragUpdateDetails` (`delta`) |
| `onPanEnd` | `DragEndDetails` (`velocity`, `localPosition`, `globalPosition`; `primaryVelocity` es null, como en un pan) |
| `onHorizontalDragEnd`, `onVerticalDragEnd` | `SwipeDirection` en ese eje |
| `onScaleEnd` | la escala |

Los callbacks que el navegador no puede entregar (`onTapCancel`,
`onPanStart`, `onScaleUpdate`…) están marcados `@Deprecated` y fallan al
renderizar con [THOR-R040](../../errores/THOR-R040.md), que indica qué usar.

`InkWell` no dibuja ondas: al pasar el puntero, con foco y al presionar
muestra una capa translúcida (`hoverColor`, `focusColor`, `highlightColor`).
`borderRadius` y `customBorder` la redondean; `InkResponse` la dibuja como
círculo. Sin `onTap`, `onDoubleTap` ni `onLongPress` no responde, como en
Flutter.

| Hijo de `InkWell` | Resultado |
|---|---|
| texto, ícono o imagen | un botón nativo |
| una caja (`Container`, `Row`, `Card`…) | rol de botón, foco, Enter y Espacio |
| un botón (`FilledButton`, `IconButton`…) | el botón del hijo, sin rol nuevo |

> **Importante:** Un control dentro de una caja con `InkWell` sigue siendo su
> propio botón, pero un lector de pantalla anuncia un botón dentro de otro.
> Saca el control del área que se toca.

## `Dismissible`

Una fila que se descarta al arrastrarla, con la API de Flutter. Pasado el
umbral (0.4 de su tamaño, o un lanzamiento rápido), sale, pregunta a
`confirmDismiss`, se pliega y llama a `onDismissed`. Con el teclado, Supr o
Retroceso la descartan.

:::example gesture-dismissible
:::

```dart
Dismissible(
  key: ValueKey(m.id),
  direction: DismissDirection.endToStart,
  onDismissed: inbox.archived.withArg(m.id),   // void archived(int id, DismissDirection d)
  confirmDismiss: inbox.ask.withArg(m.id),     // Future<bool> ask(int id, DismissDirection d)
  background: const ColoredBox(color: Color(0xFF16A34A)),
  child: MessageTile(m),
)
```

| Parámetro | Uso |
|---|---|
| `onDismissed` | método del ViewModel que quita la fila; recibe la `DismissDirection` |
| `confirmDismiss` | devuelve `bool` o `Future<bool>`; `false` devuelve la fila a su lugar |
| `direction` | `horizontal` (por defecto), `vertical`, `startToEnd`, `endToStart`, `up`, `down` o `none` |
| `background`, `secondaryBackground` | el primero para `startToEnd` y `down`; el segundo para `endToStart` y `up` |
| `dismissThresholds` | umbral por dirección (`{DismissDirection.endToStart: 0.7}`) |
| `resizeDuration`, `movementDuration` | el pliegue (`null`: sin pliegue) y el deslizamiento |

> **Diferencia con Flutter:** No existen `onUpdate`, `onResize`,
> `crossAxisEndOffset` ni `dragStartBehavior`. Sin JavaScript la fila es solo
> su hijo: ofrece la misma acción en un botón.

## `Draggable` y `DragTarget`

`feedback` es lo que sigue al puntero y `childWhenDragging` ocupa el lugar del
origen mientras tanto. El destino decide qué acepta.

:::example gesture-draggable
:::

```dart
Draggable<String>(
  data: task.id,
  feedback: TaskCard(task),
  childWhenDragging: Opacity(opacity: 0.3, child: TaskCard(task)),
  onDragCompleted: board.picked.withArg(task.id),
  child: TaskCard(task),
)

DragTarget<String>(
  onWillAcceptWithDetails: board.fits.withArg(column.id),   // bool fits(String column, String task)
  onAcceptWithDetails: board.moved.withArg(column.id),      // void moved(String column, String task)
  overStyle: const StyleProps(opacity: 0.8),
  builder: (context, candidates, rejected) => Content(column),
)
```

- **Datos:** llegan al método del destino como `String`, número, `bool` o
  enum; un `Map` o una `List`, como JSON. `onWillAcceptWithDetails` decide si
  caben.
- **Destino:** `builder` corre una vez en el servidor. `overStyle` se aplica
  mientras hay encima algo que cabe y `rejectStyle`, algo que no.
- **`LongPressDraggable`:** espera una pulsación (`delay`, 500 ms) para que
  moverse antes desplace la página. Conviene en listas con desplazamiento.
- **Callbacks:** `onDragStarted`, `onDragCompleted`, `onDraggableCanceled` y
  `onDragEnd` en el origen; `onLeave` y `onMove` en el destino.
- **Bordes:** cerca del borde, la página o el contenedor se desplazan solos.

Con el teclado (WCAG 2.5.7), Espacio o Enter levanta el origen, las flechas
recorren los destinos que lo aceptan, Espacio o Enter lo suelta y Esc
cancela. Un lector de pantalla anuncia cada paso; `labels: DragLabels(...)`
traduce las frases.

> **Diferencia con Flutter:** No existen `onDragUpdate` por cuadro,
> `rootOverlay` ni `ignoringFeedbackSemantics`, y se arrastra un elemento a la
> vez. El `feedback` no toma el tamaño del origen: dale el suyo. Sin
> JavaScript no se arrastra.

## `ReorderableListView`

El usuario arrastra el asa de un elemento para cambiar el orden. `onReorder(oldIndex,
newIndex)` usa los índices de Flutter: `newIndex` cuenta la lista antes de
quitar el elemento, así que al bajar se resta uno.

`header` y `footer` no son elementos: se dibujan junto al elemento `role="list"`, no dentro, así que la lista contiene solo sus elementos. Se desplazan con los elementos, como en Flutter, y `padding` rodea a los tres.

:::example gesture-reorderable
:::

```dart
Watch.list(
  todo.items,
  itemKey: todo.keyOf,
  container: (rows) => ReorderableListView(onReorder: todo.reorder, children: rows),
  each: (row) => TaskCard(row),
)
```

Cada elemento lleva un asa (`buildDefaultDragHandles`);
`ReorderableDragStartListener` la coloca donde quieras y
`ReorderableDelayedDragStartListener` espera una pulsación. Con el teclado,
Espacio o Enter en el asa levanta el elemento, las flechas lo mueven, Espacio
o Enter lo suelta y Esc lo devuelve; Alt + flecha lo mueve un lugar.
`labels: ReorderLabels(...)` traduce las frases.

> **Diferencia con Flutter:** No existe `proxyDecorator`: el elemento
> arrastrado es el mismo, con el aspecto de `draggingStyle: StyleProps(...)`.
> `shrinkWrap` y `physics` se aceptan sin efecto.

## Puntero, foco y acordeón

Tres callbacks de Flutter que reaccionan en el navegador, cada uno un método
del ViewModel.

```dart
MouseRegion(onEnter: card.hover, onExit: card.unhover, child: card)
Focus(canRequestFocus: false, onFocusChange: form.focused, child: fields)
ExpansionTile(title: title, onExpansionChanged: faq.changed, children: body)
```

:::example events-hover-focus
:::

:::example events-expansion
:::

| Widget | Callback | Recibe |
|---|---|---|
| `MouseRegion` | `onEnter`, `onExit` | nada |
| `Focus` | `onFocusChange` | `true` si el foco entra en el elemento o en un descendiente; `false` si sale |
| `ExpansionTile` | `onExpansionChanged` | `true` al abrir, `false` al cerrar |

`MouseRegion` cuenta el mouse y el lápiz, no el dedo. Mover el foco entre dos
campos internos no llama a `onFocusChange`. En un acordeón (`name:` o
`ExpansionPanelList`), `onExpansionChanged` avisa primero al que se cierra y
después al que se abre.

## Siguientes pasos

:::cards
- [Interactividad](interactividad.md) — los métodos de un ViewModel
- [Animaciones](animaciones.md) — el movimiento de un cambio de estado
- [Accesibilidad](accesibilidad.md) — teclado y lectores de pantalla
:::
