# Animations

Animate with Flutter's API (`Animated*`, `Curves`, `AnimationController`,
`Hero`); the browser runs every frame, with no Dart code per frame.

:::flutter Flutter: `AnimatedContainer`, `AnimationController`, `Hero` · Thor: the same ones; the browser keeps the clock

## Implicit animations

Change a value and the widget animates the change, with Flutter's
`AnimatedContainer`.

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

The value changes through a state field (inside a `Watch`) or through
interaction, with `.when()`:

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

| Widget | Animates |
|---|---|
| `AnimatedOpacity`, `AnimatedScale`, `AnimatedRotation` | opacity, scale, rotation |
| `AnimatedSlide`, `AnimatedAlign` | offset, alignment |
| `AnimatedPositioned`, `AnimatedPadding` | position in a `Stack`, padding |
| `AnimatedContainer` | size, padding, colors, radius, border, shadow and `transform` |
| `AnimatedDefaultTextStyle` | text color, size, weight and spacing |
| `TweenAnimationBuilder` | whatever its `builder` returns |

> **Important:** Animating `width`, `height` or `padding` recomputes the layout
> on every frame. For smooth motion, animate `transform` (scale, offset) and
> opacity.

`onEnd` is called once per change and is not called if the change is
interrupted, as in Flutter. It is a method of a ViewModel (`ThorState`).

> **Difference from Flutter:** When a transition is reversed halfway, the
> browser shortens the duration; Flutter restarts it in full. `Matrix4`
> covers identity, translation, scale, rotation and `*`. The weight in
> `AnimatedDefaultTextStyle` only interpolates with a variable font.

### Move and align

`AnimatedAlign` animates the child's alignment; `AnimatedPositioned`, its
offsets and size inside a `Stack`.

:::bench bench-position
:::

Always animate the same sides: switching a side from set to unset jumps, as
in Flutter. `AnimatedAlign` needs a bounded height to align vertically.

### `TweenAnimationBuilder`

`TweenAnimationBuilder` animates whatever its `builder` returns toward the
tween's end value.

:::bench bench-tween
:::

> **Difference from Flutter:** The `builder` does not run on every frame: it
> receives the end value (`tween.end`) once per state, and the browser animates
> from the previous result to the new one. Don't branch on intermediate values
> (`value > 0.5`); `begin` is ignored.

## Curves and duration

A curve describes how the animation progresses over time; `Curves` has
Flutter's constants.

:::bench bench-curves
:::

Cubic curves are exact; elastic curves, bounce curves and `Interval` are
approximated with many points.

| Situation | Curve | Duration |
|---|---|---|
| Something enters or leaves | `Curves.easeOut` | 150–250 ms |
| Something moves across the screen | `Curves.easeInOut` | 200–400 ms |
| A color change on hover | `Curves.ease` | 100–200 ms |
| Constant progress | `Curves.linear` | as long as the task takes |

An interface animation rarely goes past 300 ms, and anything the user repeats
many times a day should barely animate. `Curves.easeIn` starts slow, so keep
it for things leaving the screen. Curves that overshoot (`easeOutBack`,
`elasticOut`) or bounce (`bounceOut`) give weight to a single moment, such as
a confirmation.

> **Difference from Flutter:** `elasticOut` imitates a spring with a
> fixed-duration curve. There is no `SpringDescription` or `animateWith`, and
> an interrupted animation does not keep its velocity.

## Explicit animations

For what you control yourself (an entrance on load, a continuous spin, a
pulse), use `AnimationController`, `Tween`, `CurvedAnimation` and the
`*Transition` widgets, as in Flutter.

:::bench bench-explicit
:::

| Widget | Animates |
|---|---|
| `FadeTransition`, `ScaleTransition` | opacity, scale |
| `RotationTransition`, `SlideTransition` | rotation in turns, offset |
| `DecoratedBoxTransition` | color, radius, border and shadows (with `DecorationTween`) |
| `SizeTransition` | height or width |
| `CountTransition` | a number that counts (Thor-specific) |

> **Difference from Flutter:** There is no `AnimatedBuilder`, because the
> `builder` runs on the server. In `DecoratedBoxTransition`, `position:` is
> ignored, and a gradient or an image switches halfway instead of
> interpolating.

### Loops

`..repeat()` repeats forever and `..repeat(reverse: true)` goes back and
forth. `repeat(min:, max:)` limits the loop to a section of the range.

:::bench bench-repeat
:::

### Driven from state

To start it on an event, the controller is a ViewModel field and its methods
drive it: `forward()`, `reverse()`, `repeat()`, `toggle()` and `stop()`.

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

A `Watch` of a method that reads `status` or `isAnimating` updates on its own.
`animateTo`, `animateBack` and `fling` return a `Future` that completes on
arrival, and one controller can drive several widgets.

> **Difference from Flutter:** There is no `vsync` and no per-frame
> `addListener`; to act when it finishes, use `addStatusListener` or a
> `Watch`. While repeating, the status stays `forward`. `animateTo` and
> `animateBack` need a constant curve (`Curves.easeOut`, `Cubic(...)`).

## Changing content

`AnimatedSize` animates the height when its child's height changes; the
changing content goes inside, in a `Watch`. With `animateWidth: true`
(Thor-specific) it animates the width too.

```dart
AnimatedSize(
  duration: const Duration(milliseconds: 250),
  curve: Curves.easeOut,
  child: Watch(more.isOpen, builder: (open) => Text(open ? full : short)),
)
```

:::example motion-animated-size
:::

| Widget | Animates | Difference from Flutter |
|---|---|---|
| `AnimatedSize` | height, and width with `animateWidth` | `alignment` vertical only |
| `AnimatedCrossFade` | opacity and height between two children | the hidden child leaves focus and the screen reader |
| `SizeTransition` | height or width (`axis`) | no `fixedCrossAxisSizeFactor` |

> **Important:** In `AnimatedCrossFade` both children stay on the page. An
> empty `required` field in the hidden child blocks the form submission
> silently; if the hidden child has a form, validate in the ViewModel.

### Switching state with AnimatedSwitcher

`AnimatedSwitcher` cross-fades the old content with the new one when a
`Watch` changes, and each `Hero` present in both moves to its new position.

:::bench bench-switcher
:::

If the `AnimatedSwitcher` is not inside a `Watch`, its `child` must be a
`Watch` with `builder:` over a `bool`, an enum or an `int` with `count:`
([THOR-S016](../../errores/en/THOR-S016.md)). There is no `transitionBuilder` or
`layoutBuilder`: the animation is always the cross-fade.

### `AnimatedList`

Rows enter when added and leave when removed. The list is the ViewModel's:
adding or removing an item replaces `insertItem` and `removeItem`, with no
`GlobalKey`.

:::bench bench-animated-list
:::

> **Difference from Flutter:** The `itemBuilder` receives the row (`row`, with
> its `key` and `row.text`) instead of the index, runs once on the server and
> serves both the entrance and the exit. Rows from the initial load are not
> animated.

## Choreography

Several animations that read as one: a single controller with an `Interval`
per element, or controllers that wait for the element to be visible.

### Staggered entrance

Each row enters slightly after the previous one. A gap of 20 to 80 ms reads
as a cascade; more, as a wait.

:::bench bench-stagger
:::

### On entering the screen

`AnimationController.inView()` advances with the page scroll instead of time:
the element appears as it enters the screen.

:::bench bench-scroll-reveal
:::

The HTML ships the end value, so the element is never left hidden: without
browser support or with reduced motion, it appears without animating.
Scrolling back up reverses the animation. `AnimationController.onVisible(duration:)`
runs only once, at its own pace, when the element enters the screen:

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

## Page transitions

When navigating, the new page can enter with a fade or a slide. Each page is
still a complete document; the browser animates the step from one to the
other.

:::bench bench-page-transition
:::

| Transition | Effect |
|---|---|
| `PageTransition.fade()` | fade; `duration` and `curve` are optional |
| `PageTransition.slide()` | the new page enters from the side |
| `PageTransition.fadeUp()` | the new page rises and fades in on top, like `FadeUpwardsPageTransitionsBuilder` |
| `PageTransition.none` | no transition |

A page or a layout picks its own with `PageTransitionScope`; the destination
page's choice wins.

```dart
// The article page: it enters rising over the list.
Widget build(BuildContext context, PageState<Article> state) =>
    PageTransitionScope(
      transition: const PageTransition.fadeUp(),
      child: ArticleView(state.data),
    );
```

It works in recent Chrome, Edge and Safari; in other browsers, and without
JavaScript, navigation is not animated. `slide` is reversed when going back in
Chrome and Edge.

### `Hero`

As in Flutter, wrap the element in a `Hero` with the same `tag` on both
pages: during the transition, the element travels from one place to the
other.

```dart
// In the list
Hero(tag: 'article-${a.slug}', child: Text(a.title))
// In the article page
Hero(tag: 'article-${a.slug}', child: Text(a.title, style: titleStyle))
```

The `tag` is unique within each page: one tag per article, the same in the
list and in the article. Two `Hero` widgets with the same `tag` on one page
are error [THOR-R019](../../errores/en/THOR-R019.md).

> **Difference from Flutter:** The browser animates snapshots of the two
> documents, not two widget trees. There is no `flightShuttleBuilder` or
> `createRectTween`.

## Reduced motion

With the system's "reduce motion" preference, every animation finishes
instantly and `onEnd` is still called, like `MediaQuery.disableAnimations` in
Flutter. Loops stay at their end value, `inView` and `onVisible` don't
animate, and there is no transition between pages. No code required.

## Next steps

:::cards
- [Gestures](gestures.md) — tap, drag and swipe
- [Examples](examples.md#interaction-patterns) — swipe to confirm, copy, tabs and toasts
- [Theme and styles](theme-and-styles.md) — hover variants with `.when()`
:::
