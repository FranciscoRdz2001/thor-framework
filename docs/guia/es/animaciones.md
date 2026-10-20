# Animaciones

Anima con la API de Flutter (`Animated*`, `Curves`, `AnimationController`,
`Hero`); el navegador ejecuta cada cuadro, sin código Dart por cuadro.

:::flutter Flutter: `AnimatedContainer`, `AnimationController`, `Hero` · Thor: los mismos; el navegador lleva el reloj

## Animaciones implícitas

Cambia un valor y el widget anima el cambio, con el `AnimatedContainer` de
Flutter.

:::bench bench-implicit
:::

:::flutter
@flutter
```dart no-check
AnimatedContainer(
  duration: const Duration(milliseconds: 300),
  curve: Curves.easeOut,
  transform: moved
      ? Matrix4.translationValues(184, 0, 0)
      : Matrix4.identity(),
  child: box,
)
```
@thor
```dart
Watch(
  box.isMoved,
  builder: (moved) => AnimatedContainer(
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeOut,
    transform: moved
        ? Matrix4.translationValues(184, 0, 0)
        : Matrix4.identity(),
    child: box,
  ),
)
```
:::

El valor cambia por un campo de estado (dentro de un `Watch`) o por la
interacción, con `.when()`:

```dart
AnimatedContainer(
  duration: const Duration(milliseconds: 150),
  decoration: BoxDecoration(
    color: ThemeColor.surface.when(hover: ThemeColor.surfaceContainer),
    borderRadius: BorderRadius.circular(12),
  ),
  child: content,
)
```

| Widget | Anima |
|---|---|
| `AnimatedOpacity`, `AnimatedScale`, `AnimatedRotation` | opacidad, escala, rotación |
| `AnimatedSlide`, `AnimatedAlign` | desplazamiento, alineación |
| `AnimatedPositioned`, `AnimatedPadding` | posición en un `Stack`, padding |
| `AnimatedContainer` | tamaño, padding, colores, radio, borde, sombra y `transform` |
| `AnimatedDefaultTextStyle` | color, tamaño, peso y espaciado del texto |
| `TweenAnimationBuilder` | lo que devuelve su `builder` |

> **Importante:** Animar `width`, `height` o `padding` recalcula el layout en
> cada cuadro. Para un movimiento fluido, anima `transform` (escala,
> desplazamiento) y la opacidad.

`onEnd` se llama una vez por cambio y no se llama si el cambio se interrumpe,
como en Flutter. Es un método de un ViewModel (`ThorState`).

> **Diferencia con Flutter:** Al revertir una transición a medias, el
> navegador acorta la duración; Flutter la reinicia completa. `Matrix4`
> cubre identidad, traslación, escala, rotación y `*`. El peso de
> `AnimatedDefaultTextStyle` se interpola solo con una fuente variable.

### Mover y alinear

`AnimatedAlign` anima la alineación del hijo; `AnimatedPositioned`, sus
distancias y su tamaño dentro de un `Stack`.

:::bench bench-position
:::

Anima siempre los mismos lados: pasar un lado de fijo a sin fijar salta, como
en Flutter. `AnimatedAlign` necesita un alto acotado para alinear en vertical.

### `TweenAnimationBuilder`

`TweenAnimationBuilder` anima lo que devuelve su `builder` hacia el valor
final del tween.

:::bench bench-tween
:::

> **Diferencia con Flutter:** El `builder` no corre en cada cuadro: recibe el
> valor final (`tween.end`) una vez por estado, y el navegador anima del
> resultado anterior al nuevo. No ramifiques con valores intermedios
> (`value > 0.5`); `begin` se ignora.

## Curvas y duración

Una curva dice cómo avanza la animación en el tiempo; `Curves` tiene las
constantes de Flutter.

:::bench bench-curves
:::

Las cúbicas son exactas; las elásticas, las de rebote e `Interval` se
aproximan con muchos puntos.

| Situación | Curva | Duración |
|---|---|---|
| Algo entra o sale | `Curves.easeOut` | 150–250 ms |
| Algo se desplaza por la pantalla | `Curves.easeInOut` | 200–400 ms |
| Un cambio de color al pasar el puntero | `Curves.ease` | 100–200 ms |
| Progreso constante | `Curves.linear` | lo que dure la tarea |

Una animación de interfaz rara vez pasa de 300 ms, y lo que el usuario repite
muchas veces al día casi no debe animar. `Curves.easeIn` arranca lento, así
que se reserva para lo que sale de la pantalla. Las curvas que se pasan de
largo (`easeOutBack`, `elasticOut`) o rebotan (`bounceOut`) dan peso a un
momento puntual, como una confirmación.

> **Diferencia con Flutter:** `elasticOut` imita un resorte con una curva de
> duración fija. No existen `SpringDescription` ni `animateWith`, y una
> animación interrumpida no conserva su velocidad.

## Animaciones explícitas

Para lo que controlas tú (una entrada al cargar, un giro continuo, un latido),
usa `AnimationController`, `Tween`, `CurvedAnimation` y los widgets
`*Transition`, como en Flutter.

:::bench bench-explicit
:::

| Widget | Anima |
|---|---|
| `FadeTransition`, `ScaleTransition` | opacidad, escala |
| `RotationTransition`, `SlideTransition` | rotación en vueltas, desplazamiento |
| `DecoratedBoxTransition` | color, radio, borde y sombras (con `DecorationTween`) |
| `SizeTransition` | alto o ancho |
| `CountTransition` | una cifra que cuenta (propio de Thor) |

> **Diferencia con Flutter:** No existe `AnimatedBuilder`, porque el `builder`
> corre en el servidor. En `DecoratedBoxTransition`, `position:` se ignora, y
> un degradado o una imagen cambian a mitad de camino en lugar de
> interpolarse.

### Bucles

`..repeat()` repite sin fin y `..repeat(reverse: true)` va y vuelve.
`repeat(min:, max:)` limita el bucle a un tramo del recorrido.

:::bench bench-repeat
:::

### Controlada desde el estado

Para iniciarla con un evento, el controller es un campo del ViewModel y lo
mueven sus métodos: `forward()`, `reverse()`, `repeat()`, `toggle()` y
`stop()`.

```dart
class CardViewModel extends ThorState {
  final reveal = AnimationController(
    duration: const Duration(milliseconds: 350),
    reverseDuration: const Duration(milliseconds: 220),
  );

  String label() => reveal.isCompleted ? 'Visible' : 'Hidden';

  void show() => reveal.forward();
  void hide() => reveal.reverse();
  void toggle() => reveal.toggle();
}

final card = CardViewModel();
```

```dart
FilledButton(onPressed: card.show, child: const Text('Show'))
Watch(card.label)
FadeTransition(
  opacity: card.reveal,
  child: ScaleTransition(
    scale: Tween(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: card.reveal, curve: Curves.easeOutBack),
    ),
    child: panel,
  ),
)
```

Un `Watch` de un método que lee `status` o `isAnimating` se actualiza solo.
`animateTo`, `animateBack` y `fling` devuelven un `Future` que termina al
llegar, y un mismo controller puede mover varios widgets.

> **Diferencia con Flutter:** No hay `vsync` ni `addListener` por cuadro; para
> actuar al terminar, usa `addStatusListener` o un `Watch`. Mientras repite,
> el estado queda en `forward`. `animateTo` y `animateBack` necesitan una
> curva constante (`Curves.easeOut`, `Cubic(...)`).

## Contenido que cambia

`AnimatedSize` anima el alto cuando cambia el de su hijo; el contenido que
cambia va dentro, en un `Watch`. Con `animateWidth: true` (propio de Thor)
anima también el ancho.

```dart
AnimatedSize(
  duration: const Duration(milliseconds: 250),
  curve: Curves.easeOut,
  child: Watch(more.isOpen, builder: (open) => Text(open ? full : short)),
)
```

:::example motion-animated-size
:::

| Widget | Anima | Diferencia con Flutter |
|---|---|---|
| `AnimatedSize` | alto, y ancho con `animateWidth` | `alignment` solo vertical |
| `AnimatedCrossFade` | opacidad y alto entre dos hijos | el hijo oculto sale del foco y del lector de pantalla |
| `SizeTransition` | alto o ancho (`axis`) | sin `fixedCrossAxisSizeFactor` |

> **Importante:** En `AnimatedCrossFade` los dos hijos siguen en la página. Un
> campo `required` vacío en el hijo oculto bloquea el envío del formulario sin
> avisar; si el hijo oculto tiene un formulario, valida en el ViewModel.

### Cambiar de estado con AnimatedSwitcher

`AnimatedSwitcher` funde el contenido anterior con el nuevo cuando cambia un
`Watch`, y cada `Hero` presente en ambos se desplaza a su nueva posición.

:::bench bench-switcher
:::

Si el `AnimatedSwitcher` no está dentro de un `Watch`, su `child` debe ser un
`Watch` con `builder:` sobre un `bool`, un enum o un `int` con `count:`
([THOR-S016](../../errores/THOR-S016.md)). No existen `transitionBuilder` ni
`layoutBuilder`: la animación es siempre el fundido.

### `AnimatedList`

Las filas entran al agregarse y salen al quitarse. La lista es la del
ViewModel: agregar o quitar un elemento reemplaza a `insertItem` y
`removeItem`, sin `GlobalKey`.

:::bench bench-animated-list
:::

> **Diferencia con Flutter:** El `itemBuilder` recibe la fila (`row`, con su
> `key` y `row.text`) en lugar del índice, corre una vez en el servidor y
> sirve para la entrada y la salida. Las filas de la primera carga no se
> animan.

## Coreografía

Varias animaciones que se leen como una: un controller con un `Interval` por
elemento, o controllers que esperan a que el elemento sea visible.

### Entrada escalonada

Cada fila entra un poco después de la anterior. Entre 20 y 80 ms de
diferencia se percibe como una cascada; más, como una espera.

:::bench bench-stagger
:::

### Al entrar en la pantalla

`AnimationController.inView()` avanza con el desplazamiento de la página en
lugar del tiempo: el elemento aparece mientras entra en la pantalla.

:::bench bench-scroll-reveal
:::

El HTML trae el valor final, así que el elemento nunca queda oculto: sin
soporte del navegador o con movimiento reducido, aparece sin animar. Al
volver hacia arriba la animación se revierte. `AnimationController.onVisible(duration:)`
corre una sola vez, a su ritmo, cuando el elemento entra en la pantalla:

```dart
final visible = AnimationController.onVisible(
  duration: const Duration(milliseconds: 700),
);

CountTransition(
  count: IntTween(begin: 0, end: 96).animate(
    CurvedAnimation(parent: visible, curve: Curves.easeOutCubic),
  ),
  suffix: '%',
  style: const TextStyle(
    fontWeight: FontWeight.w700,
    fontFeatures: [FontFeature.tabularFigures()],
  ),
)
```

## Transiciones entre páginas

Al navegar, la página nueva puede entrar con un fundido o deslizándose. Cada
página sigue siendo un documento completo; el navegador anima el paso de una a
otra.

:::bench bench-page-transition
:::

| Transición | Efecto |
|---|---|
| `PageTransition.fade()` | fundido; `duration` y `curve` son opcionales |
| `PageTransition.slide()` | la página nueva entra desde el costado |
| `PageTransition.fadeUp()` | la nueva sube y aparece encima, como `FadeUpwardsPageTransitionsBuilder` |
| `PageTransition.none` | sin transición |

Una página o un layout elige la suya con `PageTransitionScope`; manda la de la
página a la que se llega.

```dart
// The article page: it enters rising over the list.
Widget build(BuildContext context, PageState<Article> state) =>
    PageTransitionScope(
      transition: const PageTransition.fadeUp(),
      child: ArticleView(state.data),
    );
```

Funciona en Chrome, Edge y Safari recientes; en los demás navegadores, y sin
JavaScript, la navegación no se anima. `slide` se invierte al volver atrás en
Chrome y Edge.

### `Hero`

Como en Flutter, envuelve el elemento con `Hero` y el mismo `tag` en las dos
páginas: durante la transición, el elemento viaja de un lugar al otro.

```dart
// In the list
Hero(tag: 'article-${a.slug}', child: Text(a.title))
// In the article page
Hero(tag: 'article-${a.slug}', child: Text(a.title, style: titleStyle))
```

El `tag` es único dentro de cada página: un tag por artículo, el mismo en la
lista y en el artículo. Dos `Hero` con el mismo `tag` en una página son el
error [THOR-R019](../../errores/THOR-R019.md).

> **Diferencia con Flutter:** El navegador anima capturas de los dos
> documentos, no dos árboles de widgets. No existen `flightShuttleBuilder` ni
> `createRectTween`.

## Movimiento reducido

Con la preferencia del sistema «reducir movimiento», cada animación termina al
instante y `onEnd` se sigue llamando, como `MediaQuery.disableAnimations` en
Flutter. Los bucles quedan en su valor final, `inView` y `onVisible` no animan
y no hay transición entre páginas. No requiere código.

## Siguientes pasos

:::cards
- [Gestos](gestos.md) — tocar, arrastrar y deslizar
- [Ejemplos](ejemplos.md#patrones-de-interacción) — deslizar para confirmar, copiar, pestañas y avisos
- [Tema y estilos](tema-y-estilos.md) — variantes con `.when()` al pasar el puntero
:::
