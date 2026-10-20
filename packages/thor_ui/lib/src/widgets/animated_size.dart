import 'package:thor_engine/thor_engine.dart' show sizeAnimationAttr;
import 'package:thor_style/thor_style.dart';

import '../core/core.dart';
import '../engine/watch.dart' show engineAttributes;
import '../foundation/child_rules.dart' show ThorBuiltIn, ThorElementWidget;
import '../foundation/element.dart';
import '../foundation/layout_hint.dart';
import '../foundation/style_registry.dart';
import 'stack.dart' show Stack;

/// The shell of [AnimatedSize] and [AnimatedCrossFade]: a clipping element
/// that the engine sizes with the Web Animations API when its content's
/// height changes, around one element that measures that content.
///
/// CSS cannot animate `auto` → `auto`, so the browser is told after the
/// fact: a `ResizeObserver` on the measured element (Flutter's own
/// `RenderAnimatedSize` does the same in layout) animates the shell's
/// `height` from where it is to the new one, from any cause, and starts
/// over from the current height if the content changes again mid-way.
/// Without JS, or with `prefers-reduced-motion`, the size just follows the
/// content (the first state is always right).
Widget _sizeShell({
  required Duration duration,
  Duration? reverseDuration,
  required Curve curve,
  required Alignment alignment,
  required Clip clip,
  required String debugName,
  required List<Widget> children,
  VoidCallback? onEnd,
  bool animateWidth = false,
}) {
  final reverse = reverseDuration ?? duration;
  return thorElement(
    'div',
    debugName: debugName,
    fillsWidth: !animateWidth,
    css: {
      'display': 'flex',
      'flex-direction': 'column',
      'justify-content': alignment.flexJustify,
      if (clip != Clip.none) 'overflow': clip.css,
      // web: the width follows the content only when it is animated: the
      // shell shrink-wraps (Flutter's AnimatedSize always does).
      if (animateWidth) ...{'width': 'fit-content', 'max-width': '100%'},
    },
    attributes: {
      sizeAnimationAttr:
          '${duration.inMilliseconds}|${curve.css}|${reverse.inMilliseconds}'
          '${animateWidth ? '|w' : ''}',
      // The engine fires a `transitionend` on the shell when the size
      // animation finishes: `onEnd` of a ThorState method is wired to it.
      ...engineAttributes({'transitionend': onEnd}),
    },
    children: [
      thorElement(
        'div',
        css: {
          // Contains the children's margins, so the height is the content's.
          'display': 'flow-root',
          'position': 'relative',
          'flex': 'none',
          // The content's own width, so the shell's animated width does not
          // feed back into what is measured (text does not wrap here).
          if (animateWidth) 'width': 'max-content',
        },
        children: children,
      ),
    ],
  );
}

/// Flutter's `AnimatedSize`: animates its own size when [child]'s changes.
///
/// ```dart
/// AnimatedSize(
///   duration: const Duration(milliseconds: 200),
///   curve: Curves.easeOut,
///   child: Watch(faq.open, builder: (open) => Text(open ? longAnswer : shortAnswer)),
/// )
/// ```
///
/// The content must change *inside* the widget (a `Watch` below it, a list
/// that grows): a `Watch` around the whole `AnimatedSize` swaps the element
/// itself, and there is nothing left to animate. The size follows growing
/// and shrinking, from zero and back to zero, and a change in the middle of
/// an animation starts from the height it has then.
///
/// `// web:` only the height animates by default (the width is the parent's,
/// as a block); `animateWidth: true` shrink-wraps the content and animates
/// both. [alignment] positions the content vertically while it grows or
/// shrinks (the horizontal part does nothing). [onEnd] runs when the size
/// animation finishes (not when it is cut short by a newer change; with
/// `prefers-reduced-motion` it runs right after the instant change). The
/// measuring and the animation run in the browser: before the page
/// is interactive the size changes at once.
class AnimatedSize extends StatelessWidget
    implements LayoutHint, ThorElementWidget, ThorBuiltIn {
  /// Animates the height of [child].
  const AnimatedSize({
    super.key,
    this.child,
    this.alignment = Alignment.topCenter,
    this.curve = Curves.linear,
    required this.duration,
    this.reverseDuration,
    this.clipBehavior = Clip.hardEdge,
    this.onEnd,
    this.animateWidth = false,
  });

  /// The widget whose size is followed.
  final Widget? child;

  /// Where the content sits while the size catches up (vertical only).
  final Alignment alignment;

  /// The easing of the size.
  final Curve curve;

  /// How long growing takes.
  final Duration duration;

  /// How long shrinking takes (default: [duration]).
  final Duration? reverseDuration;

  /// [Clip.none] lets the content spill out while it animates.
  final Clip clipBehavior;

  /// Called when a size animation finishes (a `ThorState` method runs in
  /// the browser).
  final VoidCallback? onEnd;

  // web: not in Flutter.
  /// Also animate the width. The shell then takes the content's
  /// width (up to its parent's) instead of filling it.
  final bool animateWidth;

  @override
  bool get fillsWidth => !animateWidth;

  @override
  Widget build(BuildContext context) => _sizeShell(
    onEnd: onEnd,
    animateWidth: animateWidth,
    duration: duration,
    reverseDuration: reverseDuration,
    curve: curve,
    alignment: alignment,
    clip: clipBehavior,
    debugName: 'AnimatedSize',
    children: [?child],
  );
}

/// Which child [AnimatedCrossFade] shows.
enum CrossFadeState {
  /// The first child.
  showFirst,

  /// The second child.
  showSecond,
}

/// Lays out the children of an [AnimatedCrossFade] (Flutter's
/// `AnimatedCrossFadeBuilder`).
typedef AnimatedCrossFadeBuilder =
    Widget Function(
      Widget topChild,
      Key topChildKey,
      Widget bottomChild,
      Key bottomChildKey,
    );

/// Flutter's `AnimatedCrossFade`: fades between two children while its size
/// goes from the one's to the other's.
///
/// ```dart
/// Watch(panel.open, builder: (open) => AnimatedCrossFade(
///   firstChild: const Text('Show more'),
///   secondChild: Details(item),
///   crossFadeState: open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
///   duration: const Duration(milliseconds: 250),
/// ))
/// ```
///
/// Both children are always in the page, and switching [crossFadeState]
/// only changes their classes (that is what a `Watch` swaps in the
/// browser): the shown one is in the flow and sets the size, the other
/// fades out over it, then leaves the accessibility tree and the tab order
/// (`visibility`), so `excludeBottomFocus` is always true. Switching fast
/// back and forth (A → B → A) reverses from the opacity and the height it
/// has at that moment.
///
/// `// web:` [alignment] is vertical only; the size animates like
/// [AnimatedSize] (otherwise it changes at once while the fade still runs in
/// CSS); [onEnd] (not in Flutter) and `animateWidth` are those of
/// [AnimatedSize]. With a [layoutBuilder] the hidden child stays where the
/// builder puts it (Flutter's default puts it over the shown one): it fades
/// and leaves the accessibility tree and the tab order all the same.
class AnimatedCrossFade extends StatelessWidget
    implements LayoutHint, ThorElementWidget, ThorBuiltIn {
  /// Fades between [firstChild] and [secondChild].
  const AnimatedCrossFade({
    super.key,
    required this.firstChild,
    required this.secondChild,
    this.firstCurve = Curves.linear,
    this.secondCurve = Curves.linear,
    this.sizeCurve = Curves.linear,
    this.alignment = Alignment.topCenter,
    required this.crossFadeState,
    required this.duration,
    this.reverseDuration,
    this.excludeBottomFocus = true,
    this.layoutBuilder = defaultLayoutBuilder,
    this.onEnd,
    this.animateWidth = false,
  });

  /// Flutter's default layout: the hidden child over the shown one, which
  /// sets the size.
  static Widget defaultLayoutBuilder(
    Widget topChild,
    Key topChildKey,
    Widget bottomChild,
    Key bottomChildKey,
  ) => Stack(children: [bottomChild, topChild]);

  /// The child shown with [CrossFadeState.showFirst].
  final Widget firstChild;

  /// The child shown with [CrossFadeState.showSecond].
  final Widget secondChild;

  /// The easing of the first child's fade.
  final Curve firstCurve;

  /// The easing of the second child's fade.
  final Curve secondCurve;

  /// The easing of the size.
  final Curve sizeCurve;

  /// Where the content sits while the size catches up (vertical only).
  final Alignment alignment;

  /// Which child shows.
  final CrossFadeState crossFadeState;

  /// How long the fade and the size take.
  final Duration duration;

  /// How long the way back takes (default: [duration]).
  final Duration? reverseDuration;

  /// web: always true (`visibility: hidden` on the hidden child).
  final bool excludeBottomFocus;

  /// Lays out the two children: the one that is shown ([CrossFadeState]'s)
  /// as `topChild`, the other as `bottomChild`, with Flutter's keys
  /// (`ValueKey(CrossFadeState.showFirst/showSecond)`). Default: the hidden
  /// one over the shown one, out of the flow.
  final AnimatedCrossFadeBuilder layoutBuilder;

  // web: not in Flutter.
  /// Called when a size animation finishes (a `ThorState` method
  /// runs in the browser).
  final VoidCallback? onEnd;

  // web: not in Flutter.
  /// Also animate the width (see [AnimatedSize.animateWidth]).
  final bool animateWidth;

  @override
  bool get fillsWidth => !animateWidth;

  bool get _customLayout => !identical(layoutBuilder, defaultLayoutBuilder);

  Widget _side(
    Widget child,
    Curve curve, {
    required bool shown,
    required Key key,
    required Duration time,
  }) {
    final fade = '${cssDuration(time)} ${curve.css}';
    return thorElement(
      'div',
      key: key,
      css: shown
          ? {
              'opacity': '1',
              // Visible at once, the fade-in runs.
              'transition': 'opacity $fade, visibility 0s linear 0s',
            }
          : {
              // Out of the flow at once: the shown child sets the size
              // (with a custom layout the builder decides).
              if (!_customLayout) ...{
                'position': 'absolute',
                'top': '0',
                'left': '0',
                'right': '0',
              },
              'opacity': '0',
              'visibility': 'hidden',
              'pointer-events': 'none',
              // Hidden for good only after the fade.
              'transition':
                  'opacity $fade, visibility 0s linear ${cssDuration(time)}',
            },
      conditions: const [
        ConditionalCss(CssCondition.reducedMotion, {'transition': 'none'}),
      ],
      children: [child],
    );
  }

  @override
  Widget build(BuildContext context) {
    final first = crossFadeState == CrossFadeState.showFirst;
    const firstKey = ValueKey<CrossFadeState>(CrossFadeState.showFirst);
    const secondKey = ValueKey<CrossFadeState>(CrossFadeState.showSecond);
    // Flutter: showing the first child is the controller's way back, so it
    // fades with [reverseDuration], like the size does.
    final time = first ? (reverseDuration ?? duration) : duration;
    final one = _side(
      firstChild,
      firstCurve,
      shown: first,
      key: firstKey,
      time: time,
    );
    final two = _side(
      secondChild,
      secondCurve,
      shown: !first,
      key: secondKey,
      time: time,
    );
    return _sizeShell(
      onEnd: onEnd,
      animateWidth: animateWidth,
      duration: duration,
      reverseDuration: reverseDuration,
      curve: sizeCurve,
      alignment: alignment,
      clip: Clip.hardEdge,
      debugName: 'AnimatedCrossFade',
      children: _customLayout
          ? [
              first
                  ? layoutBuilder(one, firstKey, two, secondKey)
                  : layoutBuilder(two, secondKey, one, firstKey),
            ]
          : [one, two],
    );
  }
}
