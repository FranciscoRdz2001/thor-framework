import 'package:thor_style/thor_style.dart';

import '../core/core.dart';
import '../foundation/errors.dart';
import '../foundation/parent_data.dart';
import '../foundation/style_registry.dart'
    show ConditionalCss, CssCondition, ThorStyleRegistry;
import '../foundation/theme_tokens.dart';
import '../foundation/transparent.dart' show resolveLeaf;
import 'basic.dart' show buttonResetCss;
import 'gesture.dart';
import 'gesture_details.dart';
import 'icon.dart' show Icon;
import 'image.dart' show Image;
import 'interaction.dart' show SystemMouseCursors, MouseCursor;
import 'text.dart' show Text;
import 'tombstones.dart' show Tombstone;

// Flutter's GestureDetector and InkWell/InkResponse, as thin wrappers over
// `Gesture` (the one widget that does every touch and mouse gesture): they
// keep Flutter's names for the callbacks the browser can do, and fail at
// build time, naming what to use instead, for the ones it can't.

/// Flutter's `HitTestBehavior`. web: accepted and not used: the element
/// the gesture wraps is the hit target, as with [opaque].
enum HitTestBehavior {
  /// Targets that defer to their child.
  deferToChild,

  /// Opaque targets can be hit by hit tests.
  opaque,

  /// Translucent targets both receive events and let the ones behind them.
  translucent,
}

/// The build-time error of a callback the web can't do: [names] are the
/// ones the widget got, [advice] says what to use for each.
Never _unsupported(
  String widget,
  Map<String, String> advice,
  Iterable<String> names,
  String supported,
) => throw ArgumentError.value(
  names.join(', '),
  '$widget callbacks',
  thorError(
    'THOR-R040',
    '$widget: ${names.map((n) => '`$n`').join(', ')} '
        '${names.length == 1 ? 'has' : 'have'} no equivalent in the browser.\n'
        '${[for (final n in names) '  - $n: use ${advice[n]}'].join('\n')}\n'
        'It handles: $supported. For more control use `Gesture` directly.',
  ),
);

const _gestureDetectorAdvice = <String, String>{
  'onTapCancel':
      'onTap; a tap that leaves the element is not a click in the browser',
  'onDoubleTapDown': 'onDoubleTap',
  'onSecondaryTap':
      'onLongPress (a right click and the context-menu key are a long press)',
  'onSecondaryTapDown': 'onLongPress (a right click is a long press)',
  'onSecondaryTapUp': 'onLongPress (a right click is a long press)',
  'onLongPressStart': 'onLongPress (it fires once the press has been held)',
  'onLongPressEnd': 'onLongPress',
  'onLongPressUp': 'onLongPress',
  'onLongPressMoveUpdate':
      'Gesture(onDragUpdate:) after a hold is not supported; use onLongPress',
  'onPanDown': 'onPanUpdate or onPanEnd',
  'onPanStart': 'onPanUpdate (it reports the movement since the last frame)',
  'onPanCancel': 'onPanEnd',
  'onHorizontalDragStart':
      'onHorizontalDragEnd (the swipe) or Gesture(onDragUpdate:, drag: Drag(axis: Axis.horizontal))',
  'onHorizontalDragUpdate':
      'Gesture(onDragUpdate:, drag: Drag(axis: Axis.horizontal))',
  'onVerticalDragStart':
      'onVerticalDragEnd (the swipe) or Gesture(onDragUpdate:, drag: Drag(axis: Axis.vertical))',
  'onVerticalDragUpdate':
      'Gesture(onDragUpdate:, drag: Drag(axis: Axis.vertical))',
  'onScaleStart': 'onScaleEnd (the final scale of a pinch)',
  'onScaleUpdate': 'onScaleEnd (the final scale of a pinch)',
};

const _inkAdvice = <String, String>{
  'onTapDown':
      'onTap (it fires on the click); the pressed look is highlightColor / splashColor',
  'onTapUp': 'onTap (it fires on the click)',
  'onTapCancel':
      'onTap; a tap that leaves the element is not a click in the browser',
  'onSecondaryTap':
      'onLongPress (a right click and the context-menu key are a long press)',
  'onSecondaryTapDown': 'onLongPress (a right click is a long press)',
  'onSecondaryTapUp': 'onLongPress (a right click is a long press)',
  'onSecondaryTapCancel': 'onLongPress',
  'onLongPressUp': 'onLongPress',
  'onHighlightChanged': 'highlightColor (the pressed look is CSS :active)',
  'onHover':
      'hoverColor (the hover look is CSS :hover); MouseRegion(onEnter:, onExit:) to run a state method',
  'onFocusChange': 'focusColor (the focus look is CSS :focus-visible)',
};

/// Flutter's `GestureDetector`: a thin wrapper over [Gesture] with Flutter's
/// names.
///
/// ```dart
/// GestureDetector(
///   onTap: inbox.open,                 // void open()
///   onLongPress: inbox.menu,
///   onHorizontalDragEnd: inbox.swiped, // void swiped(SwipeDirection d)
///   child: MessageTile(m),
/// )
/// ```
///
/// | Flutter | Here |
/// |---|---|
/// | `onTap`, `onDoubleTap`, `onLongPress` | the same ([Gesture.onTap]…) |
/// | `onTapDown`, `onTapUp` | the same: [TapDownDetails], [TapUpDetails] with `localPosition` |
/// | `onPanUpdate` | the same: [DragUpdateDetails] with `delta` |
/// | `onPanEnd` | the same: [DragEndDetails] with `velocity`, `localPosition` and `globalPosition` |
/// | `onHorizontalDragEnd`, `onVerticalDragEnd` | [Gesture.onSwipe] along that axis, [SwipeDirection] (`start`/`end` for horizontal) |
/// | `onScaleEnd` | [Gesture.onScaleEnd]: the scale |
///
/// web: like everywhere in thor, a callback is a method of a `ThorState`
/// (not a closure). The details objects carry what the browser reports
/// (see [Gesture]); the fields it can't know are left out. Callbacks the
/// browser can't do (`onTapCancel`, `onPanStart`, `onScaleUpdate`…) fail when
/// the page renders, naming what to use; they are `@Deprecated` in the IDE.
/// With `onPanEnd` alone the element follows the pointer and returns on
/// release (`Drag(snapBack: true)`); with `onPanUpdate` it stays put and
/// the state moves what it must. [behavior] is accepted and not used.
class GestureDetector extends ParentDataWrapper {
  /// Wraps [child], handling the given gestures.
  const GestureDetector({
    super.key,
    this.onTap,
    this.onTapDown,
    this.onTapUp,
    this.onDoubleTap,
    this.onLongPress,
    this.onPanUpdate,
    this.onPanEnd,
    this.onHorizontalDragEnd,
    this.onVerticalDragEnd,
    this.onScaleEnd,
    this.behavior,
    this.excludeFromSemantics = false,
    @Deprecated('Use onTap: this does not exist on the web') this.onTapCancel,
    @Deprecated('Use onDoubleTap: this does not exist on the web')
    this.onDoubleTapDown,
    @Deprecated(
      'Use onLongPress (a right click and the context-menu key are a long press): this does not exist on the web',
    )
    this.onSecondaryTap,
    @Deprecated(
      'Use onLongPress (a right click is a long press): this does not exist on the web',
    )
    this.onSecondaryTapDown,
    @Deprecated(
      'Use onLongPress (a right click is a long press): this does not exist on the web',
    )
    this.onSecondaryTapUp,
    @Deprecated(
      'Use onLongPress (it fires once the press has been held): this does not exist on the web',
    )
    this.onLongPressStart,
    @Deprecated('Use onLongPress: this does not exist on the web')
    this.onLongPressEnd,
    @Deprecated('Use onLongPress: this does not exist on the web')
    this.onLongPressUp,
    @Deprecated(
      'Use Gesture(onDragUpdate:) after a hold is not supported: this does not exist on the web',
    )
    this.onLongPressMoveUpdate,
    @Deprecated('Use onPanUpdate or onPanEnd: this does not exist on the web')
    this.onPanDown,
    @Deprecated(
      'Use onPanUpdate (it reports the movement since the last frame): this does not exist on the web',
    )
    this.onPanStart,
    @Deprecated('Use onPanEnd: this does not exist on the web')
    this.onPanCancel,
    @Deprecated(
      'Use onHorizontalDragEnd (the swipe) or Gesture(onDragUpdate:, drag: Drag(axis: Axis.horizontal)): this does not exist on the web',
    )
    this.onHorizontalDragStart,
    @Deprecated(
      'Use Gesture(onDragUpdate:, drag: Drag(axis: Axis.horizontal)): this does not exist on the web',
    )
    this.onHorizontalDragUpdate,
    @Deprecated(
      'Use onVerticalDragEnd (the swipe) or Gesture(onDragUpdate:, drag: Drag(axis: Axis.vertical)): this does not exist on the web',
    )
    this.onVerticalDragStart,
    @Deprecated(
      'Use Gesture(onDragUpdate:, drag: Drag(axis: Axis.vertical)): this does not exist on the web',
    )
    this.onVerticalDragUpdate,
    @Deprecated(
      'Use onScaleEnd (the final scale of a pinch): this does not exist on the web',
    )
    this.onScaleStart,
    @Deprecated(
      'Use onScaleEnd (the final scale of a pinch): this does not exist on the web',
    )
    this.onScaleUpdate,
    required super.child,
  });

  /// A tap or click (also Enter/Space).
  final void Function()? onTap;

  /// The pointer went down: [TapDownDetails.localPosition] is where, inside
  /// the element, in pixels from the top-left corner. See
  /// [Gesture.onTapDown].
  final void Function(TapDownDetails details)? onTapDown;

  /// A tap ended: [TapUpDetails.localPosition] is where the pointer was
  /// released inside the element. See [Gesture.onTapUp].
  final void Function(TapUpDetails details)? onTapUp;

  /// Two taps in a row.
  final void Function()? onDoubleTap;

  /// A press held ~500 ms, a right click or the context-menu key.
  final void Function()? onLongPress;

  /// The pointer moved while dragging: [DragUpdateDetails.delta] is the
  /// pixels since the last update.
  final void Function(DragUpdateDetails details)? onPanUpdate;

  /// A drag released: [DragEndDetails.velocity] is the pointer's speed when
  /// it let go (the last 100 ms, at most 8000 px/s like Flutter's), and
  /// `localPosition` / `globalPosition` where. The pixels moved are what
  /// [onPanUpdate] added up (or `Gesture.onDragEnd`'s `dx`, `dy`).
  // web: `primaryVelocity` is null, as Flutter's is for a pan; a keyboard
  // drag (arrows) ends with zero velocity at the element's center.
  final void Function(DragEndDetails details)? onPanEnd;

  /// A horizontal swipe released: [SwipeDirection.start] or `end`.
  final void Function(SwipeDirection direction)? onHorizontalDragEnd;

  /// A vertical swipe released: [SwipeDirection.up] or `down`.
  final void Function(SwipeDirection direction)? onVerticalDragEnd;

  /// A pinch released, with the element's scale.
  final void Function(double scale)? onScaleEnd;

  /// Accepted; the element is the hit target.
  final HitTestBehavior? behavior;

  /// Whether the element gets no button semantics (`role="button"`,
  /// focus, Enter/Space).
  final bool excludeFromSemantics;

  /// Not supported on the web: use onTap; a tap that leaves the element is not a click in the browser.
  @Deprecated('Use onTap: this does not exist on the web')
  @Tombstone()
  final Function? onTapCancel;

  /// Not supported on the web: use onDoubleTap.
  @Deprecated('Use onDoubleTap: this does not exist on the web')
  @Tombstone()
  final Function? onDoubleTapDown;

  /// Not supported on the web: use onLongPress (a right click and the context-menu key are a long press).
  @Deprecated(
    'Use onLongPress (a right click and the context-menu key are a long press): this does not exist on the web',
  )
  @Tombstone()
  final Function? onSecondaryTap;

  /// Not supported on the web: use onLongPress (a right click is a long press).
  @Deprecated(
    'Use onLongPress (a right click is a long press): this does not exist on the web',
  )
  @Tombstone()
  final Function? onSecondaryTapDown;

  /// Not supported on the web: use onLongPress (a right click is a long press).
  @Deprecated(
    'Use onLongPress (a right click is a long press): this does not exist on the web',
  )
  @Tombstone()
  final Function? onSecondaryTapUp;

  /// Not supported on the web: use onLongPress (it fires once the press has been held).
  @Deprecated(
    'Use onLongPress (it fires once the press has been held): this does not exist on the web',
  )
  @Tombstone()
  final Function? onLongPressStart;

  /// Not supported on the web: use onLongPress.
  @Deprecated('Use onLongPress: this does not exist on the web')
  @Tombstone()
  final Function? onLongPressEnd;

  /// Not supported on the web: use onLongPress.
  @Deprecated('Use onLongPress: this does not exist on the web')
  @Tombstone()
  final Function? onLongPressUp;

  /// Not supported on the web: use Gesture(onDragUpdate:) after a hold is not supported; use onLongPress.
  @Deprecated(
    'Use Gesture(onDragUpdate:) after a hold is not supported: this does not exist on the web',
  )
  @Tombstone()
  final Function? onLongPressMoveUpdate;

  /// Not supported on the web: use onPanUpdate or onPanEnd.
  @Deprecated('Use onPanUpdate or onPanEnd: this does not exist on the web')
  @Tombstone()
  final Function? onPanDown;

  /// Not supported on the web: use onPanUpdate (it reports the movement since the last frame).
  @Deprecated(
    'Use onPanUpdate (it reports the movement since the last frame): this does not exist on the web',
  )
  @Tombstone()
  final Function? onPanStart;

  /// Not supported on the web: use onPanEnd.
  @Deprecated('Use onPanEnd: this does not exist on the web')
  @Tombstone()
  final Function? onPanCancel;

  /// Not supported on the web: use onHorizontalDragEnd (the swipe) or Gesture(onDragUpdate:, drag: Drag(axis: Axis.horizontal)).
  @Deprecated(
    'Use onHorizontalDragEnd (the swipe) or Gesture(onDragUpdate:, drag: Drag(axis: Axis.horizontal)): this does not exist on the web',
  )
  @Tombstone()
  final Function? onHorizontalDragStart;

  /// Not supported on the web: use Gesture(onDragUpdate:, drag: Drag(axis: Axis.horizontal)).
  @Deprecated(
    'Use Gesture(onDragUpdate:, drag: Drag(axis: Axis.horizontal)): this does not exist on the web',
  )
  @Tombstone()
  final Function? onHorizontalDragUpdate;

  /// Not supported on the web: use onVerticalDragEnd (the swipe) or Gesture(onDragUpdate:, drag: Drag(axis: Axis.vertical)).
  @Deprecated(
    'Use onVerticalDragEnd (the swipe) or Gesture(onDragUpdate:, drag: Drag(axis: Axis.vertical)): this does not exist on the web',
  )
  @Tombstone()
  final Function? onVerticalDragStart;

  /// Not supported on the web: use Gesture(onDragUpdate:, drag: Drag(axis: Axis.vertical)).
  @Deprecated(
    'Use Gesture(onDragUpdate:, drag: Drag(axis: Axis.vertical)): this does not exist on the web',
  )
  @Tombstone()
  final Function? onVerticalDragUpdate;

  /// Not supported on the web: use onScaleEnd (the final scale of a pinch).
  @Deprecated(
    'Use onScaleEnd (the final scale of a pinch): this does not exist on the web',
  )
  @Tombstone()
  final Function? onScaleStart;

  /// Not supported on the web: use onScaleEnd (the final scale of a pinch).
  @Deprecated(
    'Use onScaleEnd (the final scale of a pinch): this does not exist on the web',
  )
  @Tombstone()
  final Function? onScaleUpdate;

  Map<String, Function?> get _unsupportedGiven => {
    'onTapCancel': onTapCancel,
    'onDoubleTapDown': onDoubleTapDown,
    'onSecondaryTap': onSecondaryTap,
    'onSecondaryTapDown': onSecondaryTapDown,
    'onSecondaryTapUp': onSecondaryTapUp,
    'onLongPressStart': onLongPressStart,
    'onLongPressEnd': onLongPressEnd,
    'onLongPressUp': onLongPressUp,
    'onLongPressMoveUpdate': onLongPressMoveUpdate,
    'onPanDown': onPanDown,
    'onPanStart': onPanStart,
    'onPanCancel': onPanCancel,
    'onHorizontalDragStart': onHorizontalDragStart,
    'onHorizontalDragUpdate': onHorizontalDragUpdate,
    'onVerticalDragStart': onVerticalDragStart,
    'onVerticalDragUpdate': onVerticalDragUpdate,
    'onScaleStart': onScaleStart,
    'onScaleUpdate': onScaleUpdate,
  };

  @override
  WrapData get wrapData {
    final given = [
      for (final e in _unsupportedGiven.entries)
        if (e.value != null) e.key,
    ];
    if (given.isNotEmpty) {
      _unsupported(
        'GestureDetector',
        _gestureDetectorAdvice,
        given,
        'onTap, onTapDown, onTapUp, onDoubleTap, onLongPress, onPanUpdate, onPanEnd, '
            'onHorizontalDragEnd, onVerticalDragEnd, onScaleEnd',
      );
    }
    if (onHorizontalDragEnd != null && onVerticalDragEnd != null) {
      throw ArgumentError.value(
        'onHorizontalDragEnd, onVerticalDragEnd',
        'GestureDetector callbacks',
        thorError(
          'THOR-R040',
          'GestureDetector: `onHorizontalDragEnd` and `onVerticalDragEnd` '
              'together: one element swipes along one axis. Wrap it in a second '
              '`Gesture(onSwipe:, swipe: Swipe(axis: Axis.vertical))`, or use '
              '`Gesture` directly.',
        ),
      );
    }
    final horizontal = onHorizontalDragEnd != null;
    return gestureWrapData(
      onTap: onTap,
      onTapDown: onTapDown,
      onTapUp: onTapUp,
      onDoubleTap: onDoubleTap,
      onLongPress: onLongPress,
      onSwipe: onHorizontalDragEnd ?? onVerticalDragEnd,
      // web: `start`/`end` follow the text direction.
      swipe: Swipe(axis: horizontal ? Axis.horizontal : Axis.vertical),
      onDragUpdate: onPanUpdate,
      onDragEnd: onPanEnd,
      dragEndDetails: true,
      onScaleEnd: onScaleEnd,
      semanticButton: !excludeFromSemantics,
      child: child,
    );
  }

  @override
  void registerStyles(ThorStyleRegistry registry) => gestureRegisterStyles(
    registry,
    follows: gestureFollows(
      onSwipe: onHorizontalDragEnd ?? onVerticalDragEnd,
      onDragUpdate: onPanUpdate,
      onDragEnd: onPanEnd,
    ),
    pinches: onScaleEnd != null,
  );
}

/// Flutter's `InkResponse`: a tap target with hover, focus and pressed
/// feedback.
///
/// web: the feedback is CSS of the child's own element, never a new element
/// or a ripple: a translucent state layer over its background (`:hover`
/// only where there is a pointer, `:focus-visible`, `:active`), under its
/// content. An element with its own `background-image` loses it while a
/// state shows. Without a tap, double tap or long press it is inert.
///
/// The child's element is the tap target. When the child is just text, an
/// icon or an image, that element is a native `<button>` (keyboard, focus
/// and semantics for free); otherwise it is a `role="button"` element with
/// `tabindex="0"` (Enter/Space tap with the engine), because a `<button>`
/// may only hold text-like content. A child that is a button already keeps
/// its own semantics. A control inside a boxed child (a `Row` with an
/// `IconButton`) stays its own `<button>`: thor never nests a `<button>` in
/// a `<button>`; keep such a control out of the tap target, or expect a
/// screen reader to announce a button in a button.
class InkResponse extends ParentDataWrapper {
  /// Creates a tap target around [child].
  const InkResponse({
    super.key,
    required super.child,
    this.onTap,
    this.onDoubleTap,
    this.onLongPress,
    this.mouseCursor,
    this.containedInkWell = false,
    this.highlightShape = BoxShape.circle,
    this.radius,
    this.borderRadius,
    this.customBorder,
    this.focusColor,
    this.hoverColor,
    this.highlightColor,
    this.splashColor,
    this.excludeFromSemantics = false,
    this.canRequestFocus = true,
    this.autofocus = false,
    @Deprecated(
      'Use onTap (it fires on the click): this does not exist on the web',
    )
    this.onTapDown,
    @Deprecated(
      'Use onTap (it fires on the click): this does not exist on the web',
    )
    this.onTapUp,
    @Deprecated('Use onTap: this does not exist on the web') this.onTapCancel,
    @Deprecated(
      'Use onLongPress (a right click and the context-menu key are a long press): this does not exist on the web',
    )
    this.onSecondaryTap,
    @Deprecated(
      'Use onLongPress (a right click is a long press): this does not exist on the web',
    )
    this.onSecondaryTapDown,
    @Deprecated(
      'Use onLongPress (a right click is a long press): this does not exist on the web',
    )
    this.onSecondaryTapUp,
    @Deprecated('Use onLongPress: this does not exist on the web')
    this.onSecondaryTapCancel,
    @Deprecated('Use onLongPress: this does not exist on the web')
    this.onLongPressUp,
    @Deprecated(
      'Use highlightColor (the pressed look is CSS :active): this does not exist on the web',
    )
    this.onHighlightChanged,
    @Deprecated(
      'Use hoverColor (the hover look is CSS :hover): this does not exist on the web',
    )
    this.onHover,
    @Deprecated(
      'Use focusColor (the focus look is CSS :focus-visible): this does not exist on the web',
    )
    this.onFocusChange,
  });

  /// A tap or click (also Enter/Space).
  final void Function()? onTap;

  /// Two taps in a row.
  final void Function()? onDoubleTap;

  /// A press held ~500 ms, a right click or the context-menu key.
  final void Function()? onLongPress;

  /// The pointer over the element (`cursor`); `pointer` by default.
  final MouseCursor? mouseCursor;

  /// Whether the feedback fills the element ([InkWell]) or is a circle
  /// inside it.
  final bool containedInkWell;

  /// The shape of the feedback when it is not contained: a circle (a
  /// radial state layer; the element keeps its own shape) or a rectangle.
  final BoxShape highlightShape;

  /// Accepted, not used: the circle takes the size of the element.
  final double? radius;

  /// Rounds the element's corners, and so the feedback with them.
  final BorderRadius? borderRadius;

  /// Rounds like this shape (`StadiumBorder`, `RoundedRectangleBorder`);
  /// over [borderRadius].
  final OutlinedBorder? customBorder;

  /// The state layer while focused with the keyboard (default: the text
  /// color at 12 %).
  final Color? focusColor;

  /// The state layer while the pointer is over it (8 %).
  final Color? hoverColor;

  /// The state layer while pressed (12 %); over [splashColor].
  final Color? highlightColor;

  /// The state layer while pressed when there is no [highlightColor].
  final Color? splashColor;

  /// Whether the element gets no button semantics (`role="button"`,
  /// focus, Enter/Space; a native `<button>`).
  final bool excludeFromSemantics;

  /// Whether the keyboard can focus it (`tabindex`).
  final bool canRequestFocus;

  /// Whether it takes the focus when the page loads.
  final bool autofocus;

  /// Not supported on the web: use onTap (it fires on the click); the pressed look is highlightColor / splashColor.
  @Deprecated(
    'Use onTap (it fires on the click): this does not exist on the web',
  )
  @Tombstone()
  final Function? onTapDown;

  /// Not supported on the web: use onTap (it fires on the click).
  @Deprecated(
    'Use onTap (it fires on the click): this does not exist on the web',
  )
  @Tombstone()
  final Function? onTapUp;

  /// Not supported on the web: use onTap; a tap that leaves the element is not a click in the browser.
  @Deprecated('Use onTap: this does not exist on the web')
  @Tombstone()
  final Function? onTapCancel;

  /// Not supported on the web: use onLongPress (a right click and the context-menu key are a long press).
  @Deprecated(
    'Use onLongPress (a right click and the context-menu key are a long press): this does not exist on the web',
  )
  @Tombstone()
  final Function? onSecondaryTap;

  /// Not supported on the web: use onLongPress (a right click is a long press).
  @Deprecated(
    'Use onLongPress (a right click is a long press): this does not exist on the web',
  )
  @Tombstone()
  final Function? onSecondaryTapDown;

  /// Not supported on the web: use onLongPress (a right click is a long press).
  @Deprecated(
    'Use onLongPress (a right click is a long press): this does not exist on the web',
  )
  @Tombstone()
  final Function? onSecondaryTapUp;

  /// Not supported on the web: use onLongPress.
  @Deprecated('Use onLongPress: this does not exist on the web')
  @Tombstone()
  final Function? onSecondaryTapCancel;

  /// Not supported on the web: use onLongPress.
  @Deprecated('Use onLongPress: this does not exist on the web')
  @Tombstone()
  final Function? onLongPressUp;

  /// Not supported on the web: use highlightColor (the pressed look is CSS :active).
  @Deprecated(
    'Use highlightColor (the pressed look is CSS :active): this does not exist on the web',
  )
  @Tombstone()
  final Function? onHighlightChanged;

  /// Not supported on the web: use hoverColor (the hover look is CSS :hover); MouseRegion(onEnter:, onExit:) to run a state method.
  @Deprecated(
    'Use hoverColor (the hover look is CSS :hover): this does not exist on the web',
  )
  @Tombstone()
  final Function? onHover;

  /// Not supported on the web: use focusColor (the focus look is CSS :focus-visible).
  @Deprecated(
    'Use focusColor (the focus look is CSS :focus-visible): this does not exist on the web',
  )
  @Tombstone()
  final Function? onFocusChange;

  Map<String, Function?> get _unsupportedGiven => {
    'onTapDown': onTapDown,
    'onTapUp': onTapUp,
    'onTapCancel': onTapCancel,
    'onSecondaryTap': onSecondaryTap,
    'onSecondaryTapDown': onSecondaryTapDown,
    'onSecondaryTapUp': onSecondaryTapUp,
    'onSecondaryTapCancel': onSecondaryTapCancel,
    'onLongPressUp': onLongPressUp,
    'onHighlightChanged': onHighlightChanged,
    'onHover': onHover,
    'onFocusChange': onFocusChange,
  };

  static const _supported =
      'onTap, onDoubleTap, onLongPress, mouseCursor, borderRadius, '
      'customBorder, focusColor, hoverColor, highlightColor, splashColor';

  bool get _isCircle => !containedInkWell && highlightShape == BoxShape.circle;

  @override
  WrapData get wrapData {
    final given = [
      for (final e in _unsupportedGiven.entries)
        if (e.value != null) e.key,
    ];
    if (given.isNotEmpty) {
      _unsupported(
        runtimeType == InkWell ? 'InkWell' : 'InkResponse',
        _inkAdvice,
        given,
        _supported,
      );
    }
    if (onTap == null && onDoubleTap == null && onLongPress == null) {
      // Flutter paints no ink without a callback.
      return const WrapData();
    }
    final base = Gesture(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      onLongPress: onLongPress,
      semanticButton: !excludeFromSemantics,
      child: child,
    ).wrapData;
    final attributes = {...base.attributes};
    // A native button holds text-like content only; a box is a role=button
    // element instead. (`role` is there when the child is not a control.)
    final native = attributes['role'] == 'button' && _isTextLike(child);
    if (native) {
      attributes
        ..remove('role')
        ..remove('tabindex')
        ..['type'] = 'button';
    }
    if (!canRequestFocus) {
      attributes.remove('tabindex');
      if (native) attributes['tabindex'] = '-1';
    }
    if (autofocus) attributes['autofocus'] = '';

    const text = 'currentColor';
    String mix(int percent) =>
        'color-mix(in srgb, $text $percent%, transparent)';
    String layer(String color) => _isCircle
        ? 'radial-gradient(circle closest-side, $color 99%, transparent 100%)'
        : 'linear-gradient($color, $color)';
    final pressed = highlightColor ?? splashColor;
    final corner = customBorder?.radiusCss ?? borderRadius?.css;
    return WrapData(
      tag: native ? 'button' : null,
      baseCss: native ? buttonResetCss : const {},
      css: {
        ...base.css,
        'cursor': (mouseCursor ?? SystemMouseCursors.click).css,
        'border-radius': ?corner,
      },
      conditions: [
        ...base.conditions,
        ConditionalCss(CssCondition.hover, {
          'background-image': layer(hoverColor?.css ?? mix(8)),
        }),
        ConditionalCss(CssCondition.focused, {
          'background-image': layer(focusColor?.css ?? mix(12)),
          'outline': '2px solid ${ThemeTokens.primary}',
          'outline-offset': '2px',
        }),
        ConditionalCss(CssCondition.pressed, {
          'background-image': layer(pressed?.css ?? mix(12)),
        }),
      ],
      attributes: attributes,
    );
  }
}

/// Whether [child] is only text, an icon or an image: what a `<button>` may
/// hold (through the wrappers and app components around it).
bool _isTextLike(Widget child) {
  final leaf = resolveLeaf(child);
  return leaf is Text || leaf is Icon || leaf is Image;
}

/// Flutter's `InkWell`: [InkResponse] whose feedback fills the element
/// (see [InkResponse] for how the web does it).
///
/// ```dart
/// InkWell(
///   onTap: inbox.open,            // void open()
///   borderRadius: BorderRadius.circular(12),
///   child: MessageTile(m),
/// )
/// ```
class InkWell extends InkResponse {
  /// Creates a tap target whose feedback fills [child].
  const InkWell({
    super.key,
    required super.child,
    super.onTap,
    super.onDoubleTap,
    super.onLongPress,
    super.mouseCursor,
    super.borderRadius,
    super.customBorder,
    super.focusColor,
    super.hoverColor,
    super.highlightColor,
    super.splashColor,
    super.radius,
    super.excludeFromSemantics,
    super.canRequestFocus,
    super.autofocus,
    @Deprecated(
      'Use onTap (it fires on the click): this does not exist on the web',
    )
    super.onTapDown,
    @Deprecated(
      'Use onTap (it fires on the click): this does not exist on the web',
    )
    super.onTapUp,
    @Deprecated('Use onTap: this does not exist on the web') super.onTapCancel,
    @Deprecated(
      'Use onLongPress (a right click and the context-menu key are a long press): this does not exist on the web',
    )
    super.onSecondaryTap,
    @Deprecated(
      'Use onLongPress (a right click is a long press): this does not exist on the web',
    )
    super.onSecondaryTapDown,
    @Deprecated(
      'Use onLongPress (a right click is a long press): this does not exist on the web',
    )
    super.onSecondaryTapUp,
    @Deprecated('Use onLongPress: this does not exist on the web')
    super.onSecondaryTapCancel,
    @Deprecated('Use onLongPress: this does not exist on the web')
    super.onLongPressUp,
    @Deprecated(
      'Use highlightColor (the pressed look is CSS :active): this does not exist on the web',
    )
    super.onHighlightChanged,
    @Deprecated(
      'Use hoverColor (the hover look is CSS :hover): this does not exist on the web',
    )
    super.onHover,
    @Deprecated(
      'Use focusColor (the focus look is CSS :focus-visible): this does not exist on the web',
    )
    super.onFocusChange,
  }) : super(containedInkWell: true, highlightShape: BoxShape.rectangle);
}
