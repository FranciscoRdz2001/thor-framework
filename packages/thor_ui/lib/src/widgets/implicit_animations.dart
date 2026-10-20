import 'package:thor_style/thor_style.dart';

import '../animation/tween.dart' show Tween;
import '../core/core.dart';
import '../engine/watch.dart' show engineAttributes;
import '../foundation/child_rules.dart';
import '../foundation/element.dart';
import '../foundation/layout_hint.dart';
import '../foundation/parent_data.dart';
import '../foundation/style_registry.dart';
import 'basic.dart';
import 'stack.dart' show Positioned;
import 'text.dart' show DefaultTextStyle;

/// Flutter's implicit animations, compiled to CSS transitions.
///
/// The widget only describes the *target* values; each value is a state of
/// a `Watch` rendered by the server, so switching states changes the
/// element's class and the browser interpolates on its own (on the
/// compositor for `opacity`, `scale`, `rotate` and `translate`). No ticker,
/// no rebuild per frame. Interrupting mid-way starts from the current value,
/// like Flutter.
///
/// Honors `prefers-reduced-motion` (the change is applied instantly, like
/// Flutter's `MediaQuery.disableAnimations`).
WrapData implicitAnimation(
  List<String> properties, {
  required Duration duration,
  required Curve curve,
  VoidCallback? onEnd,
  CssDeclarations css = const {},
}) => WrapData(
  css: {
    ...css,
    ...cssTransition(properties, duration: duration, curve: curve),
  },
  // web: 1ms instead of 0s, so the change is still instant but the browser
  // runs (and ends) the transition: `onEnd` fires like in Flutter with
  // disabled animations.
  conditions: const [
    ConditionalCss(CssCondition.reducedMotion, {'transition-duration': '1ms'}),
  ],
  // A ThorState method as `onEnd` runs in the browser on `transitionend`
  // (the engine only counts the element's own transitions).
  attributes: engineAttributes({'transitionend': onEnd}),
);

/// Common API of the `Animated*` widgets.
abstract class ImplicitlyAnimatedWidget extends StatelessWidget
    implements ThorElementWidget, ThorBuiltIn {
  /// Creates a base for widgets that implicitly animate their properties.
  const ImplicitlyAnimatedWidget({
    super.key,
    required this.duration,
    this.curve = Curves.linear,
    this.onEnd,
  });

  /// How long the transition takes.
  final Duration duration;

  /// The easing curve for the transition. Flutter default: linear.
  final Curve curve;

  /// Called once when the change has finished transitioning (not once per
  /// property: it waits for the last one, as Flutter's does).
  final VoidCallback? onEnd;
}

/// Flutter's `AnimatedOpacity` (compositor-only).
class AnimatedOpacity extends ImplicitlyAnimatedWidget {
  /// Creates a widget that animates the opacity of [child].
  const AnimatedOpacity({
    super.key,
    required this.opacity,
    required super.duration,
    super.curve,
    super.onEnd,
    required this.child,
  }) : assert(opacity >= 0 && opacity <= 1);

  /// Target opacity, between 0 (invisible) and 1 (fully opaque).
  final double opacity;

  /// The widget below this one in the tree.
  final Widget child;

  @override
  Widget build(BuildContext context) => WrapWith(
    implicitAnimation(
      const ['opacity'],
      duration: duration,
      curve: curve,
      onEnd: onEnd,
      css: {'opacity': cssNum(opacity)},
    ),
    child: child,
  );
}

/// Flutter's `AnimatedScale` (CSS `scale`: composes with other transforms).
class AnimatedScale extends ImplicitlyAnimatedWidget {
  /// Creates a widget that animates the scale of [child].
  const AnimatedScale({
    super.key,
    required this.scale,
    this.alignment = Alignment.center,
    required super.duration,
    super.curve,
    super.onEnd,
    required this.child,
  });

  /// Target scale factor.
  final double scale;

  /// Origin of the scale transform. Defaults to `Alignment.center`.
  final Alignment alignment;

  /// The widget below this one in the tree.
  final Widget child;

  @override
  Widget build(BuildContext context) => WrapWith(
    implicitAnimation(
      const ['scale'],
      duration: duration,
      curve: curve,
      onEnd: onEnd,
      css: {
        'scale': cssNum(scale),
        if (alignment != Alignment.center)
          'transform-origin': alignment.cssPosition,
      },
    ),
    child: child,
  );
}

/// Flutter's `AnimatedRotation` ([turns] = full rotations, like Flutter).
class AnimatedRotation extends ImplicitlyAnimatedWidget {
  /// Creates a widget that animates the rotation of [child].
  const AnimatedRotation({
    super.key,
    required this.turns,
    this.alignment = Alignment.center,
    required super.duration,
    super.curve,
    super.onEnd,
    required this.child,
  });

  /// Target rotation, in full turns (1.0 = 360°).
  final double turns;

  /// Origin of the rotation. Defaults to `Alignment.center`.
  final Alignment alignment;

  /// The widget below this one in the tree.
  final Widget child;

  @override
  Widget build(BuildContext context) => WrapWith(
    implicitAnimation(
      const ['rotate'],
      duration: duration,
      curve: curve,
      onEnd: onEnd,
      css: {
        'rotate': '${cssNum(turns)}turn',
        if (alignment != Alignment.center)
          'transform-origin': alignment.cssPosition,
      },
    ),
    child: child,
  );
}

/// Flutter's `AnimatedSlide`: [offset] is a fraction of the child's size.
class AnimatedSlide extends ImplicitlyAnimatedWidget {
  /// Creates a widget that animates the position of [child].
  const AnimatedSlide({
    super.key,
    required this.offset,
    required super.duration,
    super.curve,
    super.onEnd,
    required this.child,
  });

  /// Target offset, as a fraction of `child`'s size.
  final Offset offset;

  /// The widget below this one in the tree.
  final Widget child;

  @override
  Widget build(BuildContext context) => WrapWith(
    implicitAnimation(
      const ['translate'],
      duration: duration,
      curve: curve,
      onEnd: onEnd,
      css: {
        'translate': '${cssNum(offset.dx * 100)}% ${cssNum(offset.dy * 100)}%',
      },
    ),
    child: child,
  );
}

/// Flutter's `AnimatedAlign`.
///
/// web: the child is placed with the fractional form (`left`/`top` % plus
/// `translate`) for every alignment, because those interpolate in CSS while
/// flex alignment and auto margins don't. Needs a bounded height to align
/// vertically, like Flutter's Align inside a sized parent.
class AnimatedAlign extends ImplicitlyAnimatedWidget
    implements LayoutHint, HeightHint {
  /// Creates a widget that animates the alignment of [child].
  const AnimatedAlign({
    super.key,
    required this.alignment,
    required super.duration,
    super.curve,
    super.onEnd,
    this.child,
  });

  /// Target alignment of `child` within this widget.
  final Alignment alignment;

  /// The widget below this one in the tree.
  final Widget? child;

  @override
  bool get fillsWidth => true;

  @override
  bool get fillsHeight => true;

  @override
  Widget build(BuildContext context) => thorElement(
    'div',
    debugName: 'AnimatedAlign',
    fillsWidth: true,
    fillsHeight: true,
    css: const {...boxCss, 'justify-content': 'flex-start'},
    childRules: ChildRules.aligned(Alignment.topLeft),
    children: [
      if (child != null)
        WrapWith(
          implicitAnimation(
            const ['left', 'top', 'translate'],
            duration: duration,
            curve: curve,
            onEnd: onEnd,
            css: alignment.fractionalChildCss(),
          ),
          child: child!,
        ),
    ],
  );
}

/// Flutter's `AnimatedPositioned` (inside a `Stack`). Offsets and size
/// interpolate in CSS; switching a side between set and unset jumps, as it
/// does in Flutter.
class AnimatedPositioned extends ImplicitlyAnimatedWidget {
  /// Creates a widget that animates the position of [child] inside a `Stack`.
  const AnimatedPositioned({
    super.key,
    this.left,
    this.top,
    this.right,
    this.bottom,
    this.width,
    this.height,
    required super.duration,
    super.curve,
    super.onEnd,
    required this.child,
  });

  /// Target distance from the left edge of the `Stack`.
  final double? left;

  /// Target distance from the top edge of the `Stack`.
  final double? top;

  /// Target distance from the right edge of the `Stack`.
  final double? right;

  /// Target distance from the bottom edge of the `Stack`.
  final double? bottom;

  /// Target width.
  final double? width;

  /// Target height.
  final double? height;

  /// The widget below this one in the tree.
  final Widget child;

  @override
  Widget build(BuildContext context) => WrapWith(
    implicitAnimation(
      const ['left', 'top', 'right', 'bottom', 'width', 'height'],
      duration: duration,
      curve: curve,
      onEnd: onEnd,
    ),
    child: Positioned(
      left: left,
      top: top,
      right: right,
      bottom: bottom,
      width: width,
      height: height,
      child: child,
    ),
  );
}

/// Flutter's `AnimatedPadding`.
class AnimatedPadding extends ImplicitlyAnimatedWidget implements LayoutHint {
  /// Creates a widget that animates the padding around [child].
  const AnimatedPadding({
    super.key,
    required this.padding,
    required super.duration,
    super.curve,
    super.onEnd,
    this.child,
  });

  /// Target amount of space to inset `child` by.
  final EdgeInsetsGeometry padding;

  /// The widget below this one in the tree.
  final Widget? child;

  @override
  bool get fillsWidth => layoutFillsWidth(child);

  @override
  Widget build(BuildContext context) => WrapWith(
    // Padding may land as the child's padding or margin (node merging).
    implicitAnimation(
      const ['padding', 'margin'],
      duration: duration,
      curve: curve,
      onEnd: onEnd,
    ),
    child: Padding(padding: padding, child: child),
  );
}

/// Flutter's `AnimatedContainer`: every box property transitions (size,
/// padding, margin, colors, radius, border, shadow). Alignment changes are
/// applied instantly: auto margins can't be interpolated by CSS.
class AnimatedContainer extends ImplicitlyAnimatedWidget implements LayoutHint {
  /// Creates a Container that animates changes to its box properties.
  const AnimatedContainer({
    super.key,
    this.alignment,
    this.padding,
    this.color,
    this.decoration,
    this.width,
    this.height,
    this.constraints,
    this.margin,
    this.transform,
    this.transformAlignment,
    this.clipBehavior = Clip.none,
    required super.duration,
    super.curve,
    super.onEnd,
    this.child,
  });

  /// How to align `child`. Alignment changes apply instantly (auto margins
  /// don't interpolate).
  final Alignment? alignment;

  /// Target inset space around `child`.
  final EdgeInsetsGeometry? padding;

  /// Target background color. Mutually exclusive with `decoration`.
  final Color? color;

  /// Target background decoration. Mutually exclusive with `color`.
  final BoxDecoration? decoration;

  /// Target width, in logical pixels.
  final double? width;

  /// Target height, in logical pixels.
  final double? height;

  /// Target min/max size constraints.
  final BoxConstraints? constraints;

  /// Target space surrounding the decoration/color and `child`.
  final EdgeInsetsGeometry? margin;

  /// Target transform. It interpolates in CSS (translation, rotation, scale
  /// and skew between two matrices, on the compositor); a transform going
  /// from none to one interpolates from the identity.
  final Matrix4? transform;

  /// Where [transform] is anchored (default: the top-left corner, like
  /// Flutter).
  final Alignment? transformAlignment;

  /// Whether and how to clip content that overflows the container.
  final Clip clipBehavior;

  /// The widget below this one in the tree.
  final Widget? child;

  static const _properties = [
    'width',
    'height',
    'min-width',
    'min-height',
    'max-width',
    'max-height',
    'padding',
    'margin',
    'background-color',
    'border-radius',
    'border-color',
    'border-width',
    'box-shadow',
    'transform',
  ];

  Container get _container => Container(
    alignment: alignment,
    padding: padding,
    color: color,
    decoration: decoration,
    width: width,
    height: height,
    constraints: constraints,
    margin: margin,
    transform: transform,
    transformAlignment: transformAlignment,
    clipBehavior: clipBehavior,
    child: child,
  );

  @override
  bool get fillsWidth => _container.fillsWidth;

  @override
  Widget build(BuildContext context) => WrapWith(
    implicitAnimation(
      _properties,
      duration: duration,
      curve: curve,
      onEnd: onEnd,
    ),
    child: _container,
  );
}

/// Flutter's `AnimatedDefaultTextStyle`.
class AnimatedDefaultTextStyle extends ImplicitlyAnimatedWidget {
  /// Creates a widget that animates changes to the default text style of
  /// [child].
  const AnimatedDefaultTextStyle({
    super.key,
    required this.style,
    this.textAlign,
    required super.duration,
    super.curve,
    super.onEnd,
    required this.child,
  });

  /// Target text style, inherited by `child` and its descendants.
  final TextStyle style;

  /// Target text alignment.
  final TextAlign? textAlign;

  /// The widget below this one in the tree.
  final Widget child;

  @override
  Widget build(BuildContext context) => WrapWith(
    implicitAnimation(
      // web: `font-weight` only interpolates with a variable font (a static
      // family snaps to the nearest weight, as in Flutter's lerp of weights).
      const [
        'color',
        'font-size',
        'font-weight',
        'line-height',
        'letter-spacing',
        'word-spacing',
      ],
      duration: duration,
      curve: curve,
      onEnd: onEnd,
    ),
    child: DefaultTextStyle(style: style, textAlign: textAlign, child: child),
  );
}

/// Flutter's `TweenAnimationBuilder`: builds [builder] with the tween's
/// target and animates the change when the target changes.
///
/// ```dart
/// Watch(card.hovered, builder: (hovered) => TweenAnimationBuilder<double>(
///   tween: Tween(end: hovered ? 1.0 : 0.0),
///   duration: const Duration(milliseconds: 200),
///   builder: (context, lift, child) => Transform.translate(
///     offset: Offset(0, -8 * lift),
///     child: child,
///   ),
///   child: const Text('Card'),
/// ))
/// ```
///
/// `// web:` Flutter calls [builder] on every frame with the interpolated
/// value; here no Dart runs per frame. [builder] runs once per state with
/// `tween.end`, and the element it returns **transitions** (`transition:
/// all`) from the previous state's values to the new ones in CSS: opacity,
/// transform, colors, size, spacing, radius, shadows and any other
/// property CSS can interpolate. So:
///
/// - What animates is the root element of what [builder] returns (and the
///   wrappers fused into it, like `Opacity` or `Transform`); changes to
///   descendants don't animate unless they are `Animated*` widgets
///   themselves.
/// - The value the builder receives is the target, never an intermediate
///   one: don't use it to branch (`value > 0.5 ? a : b`) or to build
///   different structures; that is a switch, not an animation
///   (`AnimatedSwitcher`, `AnimatedCrossFade`).
/// - `tween.begin` is ignored: the first render shows the target (there is
///   no entrance animation); the animation runs when a `Watch` swaps the
///   state, from where the element is, like Flutter's retargeting.
/// - [onEnd] runs once per change in the browser when it is a `ThorState`
///   method; honors `prefers-reduced-motion` (the change is instant).
///
/// For one value across many elements, put it in a CSS variable with an
/// `@property` and let the descendants read it; for the properties of one
/// element prefer the specific `Animated*` widget.
class TweenAnimationBuilder<T extends Object?>
    extends ImplicitlyAnimatedWidget {
  /// Builds [builder] with the target of [tween] and transitions what it
  /// returns when the target changes.
  const TweenAnimationBuilder({
    super.key,
    required this.tween,
    required super.duration,
    super.curve,
    required this.builder,
    super.onEnd,
    this.child,
  });

  /// The values: only [Tween.end] is used (see the class docs).
  final Tween<T> tween;

  /// Builds the widget for the target value; [child] is passed through.
  final Widget Function(BuildContext context, T value, Widget? child) builder;

  /// A widget that doesn't depend on the value, built once.
  final Widget? child;

  @override
  Widget build(BuildContext context) => WrapWith(
    implicitAnimation(
      const ['all'],
      duration: duration,
      curve: curve,
      onEnd: onEnd,
    ),
    child: builder(context, tween.end as T, child),
  );
}
