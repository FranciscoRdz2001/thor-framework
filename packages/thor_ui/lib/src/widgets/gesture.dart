import 'package:thor_engine/thor_engine.dart'
    show
        argAttr,
        dragAttr,
        gestureActiveAttr,
        gestureOutAttr,
        scaleAttr,
        swipeAttr;
import 'package:thor_style/thor_style.dart';

import '../core/core.dart' show Widget;
import '../engine/watch.dart' show engineAttributes, gestureAttributes;
import '../foundation/parent_data.dart';
import '../foundation/style_registry.dart'
    show ConditionalCss, CssCondition, ThorStyleRegistry;
import 'native_control.dart';

/// Where a swipe went.
///
/// A horizontal swipe reports [start]/[end]: they follow the element's
/// `direction`, so right-to-left text flips them.
enum SwipeDirection {
  /// Upward.
  up,

  /// Downward.
  down,

  /// Toward the start of the line (left in left-to-right text, right in
  /// right-to-left).
  start,

  /// Toward the end of the line.
  end,
}

/// How an element swipes: along [axis]; past [threshold] (a fraction of
/// its size, or a quick fling) the swipe counts. With [dismiss] the element
/// flies out and fades before `onSwipe` runs, so the state can remove it
/// (swipe to dismiss).
///
/// Keyboard (WCAG 2.5.1, 2.1.1): Shift+arrow along the axis is the swipe
/// (with or without [dismiss]; the element says so in `aria-keyshortcuts`),
/// and Delete/Backspace dismisses when [dismiss] is set. A plain arrow is
/// left to reading and scrolling.
class Swipe {
  /// A swipe setup.
  const Swipe({
    this.axis = Axis.horizontal,
    this.dismiss = false,
    this.threshold = 0.4,
  });

  /// The direction the element follows the pointer.
  final Axis axis;

  /// Whether a counted swipe removes the element (fly out + fade).
  final bool dismiss;

  /// Fraction of the element's size a swipe must cover.
  final double threshold;
}

/// How an element drags: along [axis] (null: freely). With [snapBack] it
/// returns to its place on release; otherwise it stays where it was
/// dropped. The arrow keys move it by [step] pixels.
class Drag {
  /// A drag setup.
  const Drag({this.axis, this.snapBack = true, this.step = 10});

  /// The only direction it moves in, or null for both.
  final Axis? axis;

  /// Whether it goes back to its place on release.
  final bool snapBack;

  /// Pixels per arrow key press.
  final double step;
}

/// How an element pinches (two fingers): between [min] and [max] times its
/// size; `+`/`-` zoom by [step] from the keyboard.
class Pinch {
  /// A pinch setup.
  const Pinch({
    this.min = 1,
    this.max = 4,
    this.snapBack = false,
    this.step = 0.25,
  });

  /// Smallest scale.
  final double min;

  /// Largest scale.
  final double max;

  /// Whether it goes back to scale 1 on release.
  final bool snapBack;

  /// Scale change per `+`/`-` key press.
  final double step;
}

/// Visual feedback while the element is pressed (CSS `:active`, no JS).
class Press {
  /// Scale to [scale] and fade to [opacity] while pressed.
  const Press({this.scale = 0.97, this.opacity});

  /// Scale while pressed.
  final double scale;

  /// Opacity while pressed, if any.
  final double? opacity;
}

/// Every touch and mouse gesture in one widget: tap, double tap, long press
/// (hold), swipe (to dismiss), drag and pinch, plus press feedback.
///
/// ```dart
/// Gesture(
///   onTap: inbox.open.withArg(m.id),
///   onLongPress: inbox.menu.withArg(m.id),
///   onSwipe: inbox.swiped.withArg(m.id),     // void swiped(int id, SwipeDirection d)
///   swipe: const Swipe(dismiss: true),
///   feedback: const Press(),
///   child: MessageTile(m),
/// )
/// ```
///
/// Callbacks are methods of a `ThorState`. While a gesture runs the element
/// follows the pointer through CSS (no Dart per frame); the method runs once
/// on release with the result:
///
/// | Callback | Method gets |
/// |---|---|
/// | `onTap`, `onDoubleTap`, `onLongPress` | nothing (or its `withArg`) |
/// | `onTapDown`, `onTapUp` | `x`, `y` (pixels from the element's top-left corner) |
/// | `onSwipe` | the [SwipeDirection] |
/// | `onDragUpdate` | `dx`, `dy` (pixels moved since the last update) |
/// | `onDragEnd` | `dx`, `dy` (pixels moved) |
/// | `onScaleEnd` | the scale |
///
/// Keyboard: Enter/Space tap (non-native children get `role="button"`), the
/// context-menu key and right click are a long press, Delete dismisses,
/// arrows drag, `+`/`-` zoom.
///
/// **Live drags:** with [onDragUpdate] the state follows the pointer (a
/// column edge bound to a `WatchVariables` width, a splitter): the method
/// gets the movement at most once per animation frame (moves in between
/// add up, like Flutter's `DragUpdateDetails.delta` coalesced per frame),
/// then [onDragEnd] gets the whole displacement. The element itself does
/// not follow the pointer (the state moves what it must). An arrow key is
/// one update of [Drag.step] pixels, then the end.
///
/// **Where it was tapped:** [onTapDown] and [onTapUp] are Flutter's
/// `onTapDown`/`onTapUp` with the `localPosition` of their details as two
/// arguments, so one element can be a canvas (a click adds a circle where it
/// fell) instead of a grid of buttons. The position is in CSS pixels, from
/// the element's top-left corner (its border box), and does not undo a
/// `transform` on it. Enter/Space on the focused element is a tap in its
/// middle; a tap on a native control inside the element is that control's.
///
/// `// web:` a tap fires at once even with [onDoubleTap] (Flutter waits to
/// tell them apart); the element's own `translate`/`scale` are replaced
/// while it drags (without [onDragUpdate]), swipes or pinches. Flutter's
/// `onHorizontalDragUpdate`/`onVerticalDragUpdate` are [onDragUpdate] with
/// `drag: Drag(axis: …)`.
class Gesture extends ParentDataWrapper {
  /// Wraps `child`, handling the given gestures.
  const Gesture({
    super.key,
    this.onTap,
    this.onTapDown,
    this.onTapUp,
    this.onDoubleTap,
    this.onLongPress,
    this.onSwipe,
    this.swipe = const Swipe(),
    this.onDragUpdate,
    this.onDragEnd,
    this.drag = const Drag(),
    this.onScaleEnd,
    this.pinch = const Pinch(),
    this.feedback,
    this.semanticButton = true,
    required super.child,
  });

  /// A tap or click (also Enter/Space).
  final void Function()? onTap;

  /// The pointer went down: its position inside the element (Flutter's
  /// `TapDownDetails.localPosition`).
  // web: it fires on `pointerdown` even if the press then becomes a drag
  // or a long press (Flutter's tap-down fires after a short delay and a
  // drag cancels the tap, not the down).
  final void Function(double x, double y)? onTapDown;

  /// A tap ended: where the pointer was released inside the element
  /// (Flutter's `TapUpDetails.localPosition`). Not called after a drag, a
  /// swipe or a long press.
  final void Function(double x, double y)? onTapUp;

  /// Two taps in a row.
  final void Function()? onDoubleTap;

  /// A press held ~500 ms, a right click or the context-menu key.
  final void Function()? onLongPress;

  /// A swipe past the threshold, with its direction.
  final void Function(SwipeDirection direction)? onSwipe;

  /// How [onSwipe] swipes.
  final Swipe swipe;

  /// The pointer moved while dragging: the pixels since the last update,
  /// at most once per animation frame.
  final void Function(double dx, double dy)? onDragUpdate;

  /// A drag released, with the pixels moved.
  final void Function(double dx, double dy)? onDragEnd;

  /// How [onDragUpdate] and [onDragEnd] drag.
  final Drag drag;

  /// A pinch released, with the element's scale.
  final void Function(double scale)? onScaleEnd;

  /// How [onScaleEnd] pinches.
  final Pinch pinch;

  /// Feedback while pressed.
  final Press? feedback;

  /// Whether a non-native tap target gets button semantics
  /// (`role="button"`, focus, Enter/Space).
  final bool semanticButton;

  @override
  void registerStyles(ThorStyleRegistry registry) => gestureRegisterStyles(
    registry,
    follows: gestureFollows(
      onSwipe: onSwipe,
      onDragUpdate: onDragUpdate,
      onDragEnd: onDragEnd,
    ),
    pinches: onScaleEnd != null,
  );

  @override
  WrapData get wrapData => gestureWrapData(
    onTap: onTap,
    onTapDown: onTapDown,
    onTapUp: onTapUp,
    onDoubleTap: onDoubleTap,
    onLongPress: onLongPress,
    onSwipe: onSwipe,
    swipe: swipe,
    onDragUpdate: onDragUpdate,
    onDragEnd: onDragEnd,
    drag: drag,
    onScaleEnd: onScaleEnd,
    pinch: pinch,
    feedback: feedback,
    semanticButton: semanticButton,
    child: child,
  );
}

/// Whether the element follows the pointer: with an `onDragUpdate` the state
/// moves things and the element stays put. Not exported.
bool gestureFollows({
  Function? onSwipe,
  Function? onDragUpdate,
  Function? onDragEnd,
}) => onSwipe != null || (onDragEnd != null && onDragUpdate == null);

/// Registers the properties a following element animates. Not exported.
void gestureRegisterStyles(
  ThorStyleRegistry registry, {
  required bool follows,
  required bool pinches,
}) {
  // The gesture's variables change on every pointer move: unregistered
  // they inherit, and the browser would re-resolve them in the whole
  // subtree each time. Registered with `inherits: false` only the
  // element's own style is invalidated. (`translate` reads them on this
  // very element, so nothing needs to inherit.)
  if (follows) {
    for (final axis in const ['--tg-x', '--tg-y']) {
      registry.addProperty(
        axis,
        "syntax:'<length>';inherits:false;initial-value:0px",
      );
    }
  }
  if (pinches) {
    registry.addProperty(
      '--tg-s',
      "syntax:'<number>';inherits:false;initial-value:1",
    );
  }
}

/// What the gesture handlers add to their element: [Gesture] and
/// `GestureDetector` (whose callbacks take Flutter's details objects, so
/// here they are plain functions). With [dragEndDetails] the drag's end
/// reports Flutter's `DragEndDetails` (velocity and positions) instead of
/// `dx`, `dy`. Not exported.
WrapData gestureWrapData({
  Function? onTap,
  Function? onTapDown,
  Function? onTapUp,
  Function? onDoubleTap,
  Function? onLongPress,
  Function? onSwipe,
  Swipe swipe = const Swipe(),
  Function? onDragUpdate,
  Function? onDragEnd,
  bool dragEndDetails = false,
  Drag drag = const Drag(),
  Function? onScaleEnd,
  Pinch pinch = const Pinch(),
  Press? feedback,
  bool semanticButton = true,
  required Widget child,
}) {
  // The child (or what an app component around it builds) is a control
  // with its own role and focus: a `role="button"` over it would replace
  // what a screen reader announces (a checkbox is not a button).
  final childIsNative = childIsNativeControl(child);
  final g = gestureAttributes({
    'tapd': onTapDown,
    'tapu': onTapUp,
    'dtap': onDoubleTap,
    'long': onLongPress,
    'swipe': onSwipe,
    'dragu': onDragUpdate,
    'drag': onDragEnd,
    'scale': onScaleEnd,
  });
  final drags = onDragEnd != null || onDragUpdate != null;
  final moves = onSwipe != null || drags;
  final follows = gestureFollows(
    onSwipe: onSwipe,
    onDragUpdate: onDragUpdate,
    onDragEnd: onDragEnd,
  );
  final pinches = onScaleEnd != null;
  final pans = onSwipe != null && !drags && !pinches
      ? (swipe.axis == Axis.horizontal ? 'pan-y' : 'pan-x')
      : drags && drag.axis != null && !pinches && onSwipe == null
      ? (drag.axis == Axis.horizontal ? 'pan-y' : 'pan-x')
      : 'none';
  final focusable =
      (onTap != null || g.attributes.isNotEmpty) &&
      semanticButton &&
      !childIsNative;
  // The transitions are longhands, so they merge with the ones of the
  // widgets fused into the same element (an `AnimatedPositioned` around the
  // handle keeps animating `left`): a `transition` shorthand here replaced
  // them, and the handle jumped. The way back after a release (translate,
  // scale, opacity) is always declared: while the finger holds the element
  // nothing transitions (`[$gestureActiveAttr]`), and nothing else moves
  // those properties.
  final css = mergeCss(
    {
      if (follows) 'translate': 'var(--tg-x, 0px) var(--tg-y, 0px)',
      if (pinches) 'scale': 'var(--tg-s, 1)',
      if (moves || pinches) 'touch-action': pans,
      if (moves) 'cursor': 'grab',
      if (moves || pinches)
        ...cssTransition(
          const ['translate', 'scale', 'opacity'],
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        ),
    },
    feedback == null
        ? const {}
        : cssTransition(
            const ['scale'],
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
          ),
  );
  return WrapData(
    css: css,
    conditions: [
      if (moves || pinches) ...[
        const ConditionalCss(CssCondition.selector('[$gestureActiveAttr]'), {
          'transition': 'none',
          'user-select': 'none',
          'cursor': 'grabbing',
        }),
        const ConditionalCss(CssCondition.selector('[$gestureOutAttr]'), {
          'opacity': '0',
        }),
        const ConditionalCss(CssCondition.reducedMotion, {
          'transition-duration': '1ms',
        }),
      ],
      // web: the press scale is a motion: with reduced motion it is
      // instant (1ms, so the change still lands).
      if (feedback != null)
        const ConditionalCss(CssCondition.reducedMotion, {
          'transition-duration': '1ms',
        }),
      if (feedback case final f?)
        ConditionalCss(CssCondition.pressed, {
          'scale': cssNum(f.scale),
          if (f.opacity != null) 'opacity': cssNum(f.opacity!),
        }),
    ],
    attributes: {
      if (focusable) ...{'role': 'button', 'tabindex': '0'},
      if (onSwipe != null)
        'aria-keyshortcuts': swipe.axis == Axis.horizontal
            ? 'Shift+ArrowLeft Shift+ArrowRight'
            : 'Shift+ArrowUp Shift+ArrowDown',
      ...engineAttributes({'click': onTap}),
      ...g.attributes,
      argAttr: ?g.fixed,
      if (onSwipe != null)
        swipeAttr:
            '${swipe.axis == Axis.horizontal ? 'h' : 'v'}|'
            '${swipe.dismiss ? 1 : 0}|${cssNum(swipe.threshold)}',
      if (drags)
        dragAttr:
            '${switch (drag.axis) {
              Axis.horizontal => 'h',
              Axis.vertical => 'v',
              null => 'f',
            }}|${drag.snapBack ? 1 : 0}|${cssNum(drag.step)}'
            '${dragEndDetails ? '|1' : ''}',
      if (onScaleEnd != null)
        scaleAttr:
            '${cssNum(pinch.min)}|${cssNum(pinch.max)}|'
            '${pinch.snapBack ? 1 : 0}|${cssNum(pinch.step)}',
    },
  );
}
