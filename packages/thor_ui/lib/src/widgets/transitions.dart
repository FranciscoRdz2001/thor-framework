/// Flutter's explicit transitions, compiled on the server.
///
/// The widget reads its animation once, on the server: the element gets
/// the value it has now (the first frame, painted with no JavaScript) and
/// the keyframes of the whole range of its `AnimationController`:
///
/// - controller in a `ThorState`: the keyframes go in the element's
///   `data-ta` and the engine plays them with the Web Animations API when
///   the state's methods call `forward()`, `reverse()`, `repeat()`…;
/// - controller already playing when the page renders (an entrance, a
///   loop): a CSS animation in the class, which needs no engine at all.
///
/// Several transitions on one element each add their own track (a fade
/// from one controller and a scale from another). Honors
/// `prefers-reduced-motion`: nothing moves, it shows where the playback
/// rests.
///
/// web: a transition of the same property twice on one element keeps the
/// innermost one (Flutter would multiply two opacities).
library;

import 'dart:convert';

import 'package:thor_engine/thor_engine.dart';
import 'package:thor_style/thor_style.dart';

import '../animation/tween.dart';
import '../core/core.dart';
import '../foundation/child_rules.dart';
import '../foundation/element.dart' show thorElement;
import '../foundation/parent_data.dart';
import '../foundation/style_registry.dart';
import 'basic.dart' show DecoratedBox, SizedBox;

/// Returns the element's data and, without a `ThorApp` (no stylesheet),
/// the `@keyframes` rule to ship next to it.
(WrapData, String?) _transitionData<T>(
  BuildContext context,
  Animation<T> animation,
  String property,
  String Function(T value) css, {
  CssDeclarations extra = const {},
}) {
  final now = <String, String>{property: css(animation.value), ...extra};
  final plan = planAnimation(animation);
  if (plan.item case final item?) {
    return (_listItemData(item, plan, property, css, now), null);
  }
  final controller = plan.controller;
  if (controller == null) return (WrapData(css: now), null);
  return _track(
    context,
    controller,
    property,
    now,
    _frames(plan.forward, css),
    plan.reverse == null ? null : _frames(plan.reverse!, css),
    extra,
    // A loop over a stretch of the range plays only that part of the frames.
    window: (min, max, reversing) => _frames(
      windowSegments(
        animation,
        reversing ? plan.reverse ?? plan.forward : plan.forward,
        min,
        max,
        reversing: reversing,
      ),
      css,
    ),
  );
}

/// The row of an `AnimatedList` ([ListItemAnimation]): [property] rests at
/// [now] and moves with a CSS transition from the value it has at the
/// start of the animation (0): when the row enters (`@starting-style`, only
/// the rows the page adds: `data-tli`) and when it leaves (`data-tlo`, which
/// the engine sets and removes the row after the transition).
///
/// web: only the two ends and the easing of a single stretch come across: a
/// `TweenSequence` over the row animation moves between its first and last
/// values along its own curve.
WrapData _listItemData<T>(
  ListItemAnimation item,
  AnimationPlan<T> plan,
  String property,
  String Function(T value) css,
  CssDeclarations now,
) {
  final frames = _frames(plan.forward, css);
  final start = frames.first.$2;
  final from = {property: start};
  return WrapData(
    css: {
      ...now,
      ...cssTransition(
        [property],
        duration: item.duration,
        curve: frames.length == 2 ? frames.first.$3 : Curves.linear,
      ),
    },
    conditions: [
      ConditionalCss(
        const CssCondition.startingStyleWithin('[data-tli]'),
        from,
      ),
      ConditionalCss(
        const CssCondition.selector(':where([data-tlo],[data-tlo] *)'),
        from,
      ),
      const ConditionalCss(CssCondition.reducedMotion, {
        'transition-duration': '1ms',
      }),
    ],
  );
}

/// One track of [controller] on the element: [property] through [forward]
/// (and [reverse], when it differs), from its value [now].
(WrapData, String?) _track(
  BuildContext context,
  AnimationController controller,
  String property,
  CssDeclarations now,
  List<_Frame> forward,
  List<_Frame>? reverse,
  CssDeclarations extra, {
  List<_Frame> Function(double min, double max, bool reversing)? window,
}) {
  final range = controller.viewRange;
  if (range != null) {
    return _viewData(context, property, forward, range, extra);
  }
  final registry = ThorStyleRegistry.of(context);
  final visible = controller.visibleRange;
  // A scroll trigger plays it in CSS: the engine would start it on load.
  final owner = visible == null ? ThorState.controllerId(controller) : null;
  final playback = controller.playback;

  var declarations = now;
  var conditions = const <ConditionalCss>[];
  String? cssName;
  String? inline;
  if (playback != null && playback.sweep > Duration.zero) {
    // web: only the transitions of one property loop over a stretch; the
    // others (a count) play the whole range.
    final stretch = playback.windowed && window != null;
    final whole = playback.reverse && reverse != null ? reverse : forward;
    final frames = stretch
        ? window(
            playback.min,
            playback.max,
            playback.reverse && reverse != null,
          )
        : whole;
    final body = _keyframesCss(
      property,
      stretch ? frames : _eased(frames, playback),
    );
    cssName = 'ta${ThorStyleRegistry.stableHash(body)}';
    final active = ThorStyleRegistry.active(context);
    if (active != null) {
      active.addKeyframes(cssName, body);
    } else {
      // Like `CircularProgressIndicator`'s: next to the element.
      inline = '@keyframes $cssName{$body}';
    }
    declarations = {
      ...now,
      'animation': _cssAnimation(cssName, playback, stretch: stretch),
    };
    if (visible != null) {
      final trigger = '--tv${ThorStyleRegistry.stableHash(_rangeCss(visible))}';
      declarations = {
        ...declarations,
        // Its own value is the end: while it waits the animation holds the
        // start (fill backwards), and wherever the animation is gone
        // (printing, reduced motion) it shows whole.
        property: forward.last.$2,
        'timeline-trigger': '$trigger view() ${_rangeCss(visible)}',
        'animation-trigger': '$trigger play-once',
      };
      conditions = const [
        // web: with reduced motion or on paper there is no animation, so it
        // shows its end. Not `animation-trigger: none`: Chrome keeps an
        // animation that was already waiting paused at its start when the
        // media changes after load (printing).
        ConditionalCss(CssCondition.reducedMotion, {'animation': 'none'}),
        ConditionalCss(CssCondition.media('print'), {'animation': 'none'}),
      ];
    } else {
      conditions = [
        // web: reduced motion shows where the playback rests (the end; for a
        // loop, the upper bound), like the engine does. The -1ms delay starts
        // it already finished: no frame at its start while it's pending. A
        // move that stops short of the bound (`animateTo`) keeps its count:
        // it rests where it stops.
        ConditionalCss(CssCondition.reducedMotion, {
          'animation-duration': '1ms',
          'animation-delay': '-1ms',
          'animation-iteration-count': playback.to == null
              ? '1'
              : cssNum(playback.count),
        }),
      ];
    }
  }

  var attributes = const <String, String>{};
  if (owner != null) {
    registry?.useState(owner.$1);
    final value = controller.value;
    attributes = {
      animationAttr: jsonEncode([
        {
          'c': owner.$2,
          'k': _waapi(property, forward),
          if (reverse != null) 'r': _waapi(property, reverse),
          if (value != controller.lowerBound) 'v': value,
          'a': ?cssName,
          // A loop over a stretch: the page maps the CSS pass to the value.
          if (cssName != null &&
              playback != null &&
              playback.windowed &&
              window != null)
            'w': [_round(playback.min), _round(playback.max)],
          // The move's curve and stretch, so the page reads the value of the
          // pass the CSS animation is at: [css curve, from, where it stops].
          if (cssName != null && playback?.easing != null)
            'x': [
              playback!.easing,
              playback.from,
              playback.to ?? (playback.reverse ? 0 : 1),
            ],
        },
      ]),
    };
  }
  return (
    WrapData(css: declarations, conditions: conditions, attributes: attributes),
    inline,
  );
}

/// [range] as the two edges of a CSS timeline range (`entry 0% exit 100%`).
String _rangeCss(ViewRange range) {
  String edge(ViewPhase phase, double at) =>
      '${phase.name} ${cssNum(_round(at * 100))}%';
  return '${edge(range.startPhase, range.start)} '
      '${edge(range.endPhase, range.end)}';
}

/// An [AnimationController.inView] track: a CSS animation on the element's
/// view timeline. The element's own value is where the animation ends, so
/// it shows whole wherever the animation doesn't run: a browser with no
/// view timelines drops `animation-timeline` (and one with no `auto`
/// duration, the whole shorthand) and plays it in 0s to its end; reduced
/// motion does the same.
(WrapData, String?) _viewData(
  BuildContext context,
  String property,
  List<_Frame> frames,
  ViewRange range,
  CssDeclarations extra,
) {
  final body = _keyframesCss(property, frames);
  final cssName = 'ta${ThorStyleRegistry.stableHash(body)}';
  final active = ThorStyleRegistry.active(context);
  String? inline;
  if (active != null) {
    active.addKeyframes(cssName, body);
  } else {
    inline = '@keyframes $cssName{$body}';
  }
  return (
    WrapData(
      css: {
        property: frames.last.$2,
        ...extra,
        // The shorthand first: it resets the timeline and the range.
        'animation': '$cssName auto linear both',
        'animation-timeline': 'view()',
        'animation-range': _rangeCss(range),
      },
      conditions: const [
        ConditionalCss(CssCondition.reducedMotion, {
          'animation-timeline': 'auto',
        }),
      ],
    ),
    inline,
  );
}

/// One keyframe: its offset (0 to 1), its CSS value and the easing of the
/// stretch that starts at it.
typedef _Frame = (double offset, String value, Curve easing);

List<_Frame> _frames<T>(
  List<AnimationSegment<T>> segments,
  String Function(T) css,
) {
  final out = <_Frame>[];
  for (final s in segments) {
    final v0 = css(s.v0);
    if (out.isNotEmpty && out.last.$1 == s.t0 && out.last.$2 == v0) {
      out.last = (s.t0, v0, s.curve);
    } else {
      out.add((s.t0, v0, s.curve));
    }
    out.add((s.t1, css(s.v1), Curves.linear));
  }
  return out;
}

double _round(double v) => double.parse(v.toStringAsFixed(4));

/// Keyframes for `element.animate()`: property names in camelCase.
List<Map<String, Object>> _waapi(String property, List<_Frame> frames) {
  final name = property.replaceAllMapped(
    RegExp('-([a-z])'),
    (m) => m[1]!.toUpperCase(),
  );
  return [
    for (final (offset, value, easing) in frames)
      {
        'offset': _round(offset),
        name: value,
        if (!identical(easing, Curves.linear)) 'easing': easing.css,
      },
  ];
}

/// A curve that is a function (the easing of a stretch of keyframes, as
/// sampled).
class _Sampled extends Curve {
  const _Sampled(this._f);
  final double Function(double) _f;

  @override
  double transformInternal(double t) => _f(t);
}

/// [frames] for a move with a curve (`animateTo(curve:)`, `fling`) that CSS
/// can run: a CSS animation has one easing per stretch of keyframes, not one
/// for the whole pass, so the pass is warped instead. The value at the pass
/// progress `q` is the one the page gives (`playback.valueAt(q)`: the curve
/// inside the move's stretch, the identity outside), which puts each keyframe
/// at the `q` where the value reaches its offset and gives each stretch the
/// easing of the curve composed with the original one. The page continues
/// the same move from the same point. Where the value is not monotonic
/// (an elastic curve) CSS cannot show it and the frames stay as they were.
List<_Frame> _eased(List<_Frame> frames, AnimationPlayback p) {
  if (p.curve == null || frames.length < 2) return frames;
  const n = 512;
  final e = [for (var i = 0; i <= n; i++) p.valueAt(i / n)];
  for (var i = 1; i <= n; i++) {
    if (e[i] < e[i - 1] - 1e-9) return frames;
  }
  // The first pass progress whose value reaches [o].
  double at(double o) {
    if (o <= e.first) return 0;
    for (var i = 1; i <= n; i++) {
      if (e[i] >= o - 1e-9) {
        final a = e[i - 1], b = e[i];
        return b == a ? i / n : ((i - 1) + (o - a) / (b - a)) / n;
      }
    }
    return 1;
  }

  final out = <_Frame>[];
  for (var k = 0; k < frames.length; k++) {
    final (o0, value, curve) = frames[k];
    final q0 = at(o0);
    var easing = curve;
    if (k + 1 < frames.length && frames[k + 1].$1 > o0) {
      final o1 = frames[k + 1].$1;
      final q1 = at(o1);
      double g(double u) {
        final q = q0 + u * (q1 - q0);
        final s = ((p.valueAt(q) - o0) / (o1 - o0)).clamp(0.0, 1.0);
        return curve.transform(s);
      }

      // Only where the composition is not the stretch's own easing.
      var same = true;
      for (final u in const [0.1, 0.25, 0.5, 0.75, 0.9]) {
        if ((g(u) - curve.transform(u)).abs() > 1e-3) same = false;
      }
      if (!same && q1 > q0) easing = _Sampled(g);
    }
    out.add((q0, value, easing));
  }
  // The value holds its last keyframe once the move has arrived.
  if (out.last.$1 < 1 - 1e-6) out.add((1, out.last.$2, Curves.linear));
  return out;
}

String _keyframesCss(String property, List<_Frame> frames) {
  final out = StringBuffer();
  for (final (offset, value, easing) in frames) {
    // Like every class rule: the value cannot end the rule or the <style>.
    out.write(
      '${cssNum(_round(offset * 100))}%{'
      '${isCssPropertyName(property) ? '$property:${cssSafeValue(value)}' : ''}',
    );
    if (!identical(easing, Curves.linear)) {
      out.write(';animation-timing-function:${easing.css}');
    }
    out.write('}');
  }
  return '$out';
}

/// The `animation` shorthand that runs [p] from where it starts: a
/// negative delay puts the animation at that point from the first frame.
String _cssAnimation(String name, AnimationPlayback p, {bool stretch = false}) {
  final sweep = p.sweep.inMicroseconds / 1000;
  final from = stretch ? p.passAt : p.from;
  final elapsed = (p.reverse ? 1 - from : from) * sweep;
  final delay = elapsed == 0 ? '0s' : '${cssNum(_round(-elapsed))}ms';
  final count = p.repeats ? 'infinite' : cssNum(p.count);
  final direction = p.reverse
      ? 'reverse'
      : p.alternate
      ? 'alternate'
      : 'normal';
  return '$name ${cssDuration(p.sweep)} linear $delay $count $direction both';
}

/// Base of the `*Transition` widgets: they decorate their child's element
/// (no node of their own).
abstract class _Transition extends StatelessWidget
    implements ThorElementWidget, ThorBuiltIn {
  const _Transition({super.key, this.child});

  /// The widget below this one in the tree.
  final Widget? child;

  (WrapData, String?) _data(BuildContext context);

  @override
  Widget build(BuildContext context) {
    final (wrap, keyframes) = _data(context);
    final built = WrapWith(wrap, child: child ?? const SizedBox.shrink());
    if (keyframes == null) return built;
    return Widget.fragment([
      Widget.element(tag: 'style', children: [RawText(keyframes)]),
      built,
    ]);
  }
}

String _origin(Alignment alignment) => alignment.cssPosition;

/// Flutter's `FadeTransition`: [opacity] of the child (compositor-only).
class FadeTransition extends _Transition {
  /// Fades [child] by [opacity].
  const FadeTransition({
    super.key,
    required this.opacity,
    this.alwaysIncludeSemantics = false,
    super.child,
  });

  /// The opacity, 0 (invisible) to 1.
  final Animation<double> opacity;

  /// web: ignored; a transparent element stays in the accessibility tree,
  /// as with `alwaysIncludeSemantics: true`.
  final bool alwaysIncludeSemantics;

  @override
  (WrapData, String?) _data(BuildContext context) => _transitionData(
    context,
    opacity,
    'opacity',
    (v) => cssNum(_round(v.clamp(0.0, 1.0))),
  );
}

/// Flutter's `ScaleTransition` (CSS `scale`: composes with the other
/// transforms of the element).
class ScaleTransition extends _Transition {
  /// Scales [child] by [scale] around [alignment].
  const ScaleTransition({
    super.key,
    required this.scale,
    this.alignment = Alignment.center,
    super.child,
  });

  /// The scale factor.
  final Animation<double> scale;

  /// The origin of the scale.
  final Alignment alignment;

  @override
  (WrapData, String?) _data(BuildContext context) => _transitionData(
    context,
    scale,
    'scale',
    (v) => cssNum(_round(v)),
    extra: {
      if (alignment != Alignment.center) 'transform-origin': _origin(alignment),
    },
  );
}

/// Flutter's `RotationTransition`: [turns] full rotations (1.0 = 360°).
class RotationTransition extends _Transition {
  /// Rotates [child] by [turns] around [alignment].
  const RotationTransition({
    super.key,
    required this.turns,
    this.alignment = Alignment.center,
    super.child,
  });

  /// The rotation, in full turns.
  final Animation<double> turns;

  /// The origin of the rotation.
  final Alignment alignment;

  @override
  (WrapData, String?) _data(BuildContext context) => _transitionData(
    context,
    turns,
    'rotate',
    (v) => '${cssNum(_round(v))}turn',
    extra: {
      if (alignment != Alignment.center) 'transform-origin': _origin(alignment),
    },
  );
}

/// Flutter's `SlideTransition`: [position] is a fraction of the child's
/// size (CSS `translate` in %).
class SlideTransition extends _Transition {
  /// Moves [child] by [position].
  const SlideTransition({
    super.key,
    required this.position,
    this.transformHitTests = true,
    this.textDirection,
    super.child,
  });

  /// The offset, as a fraction of the child's size.
  final Animation<Offset> position;

  /// web: always true (the browser hit-tests the moved element).
  final bool transformHitTests;

  /// With [TextDirection.rtl], the horizontal offset is flipped.
  final TextDirection? textDirection;

  @override
  (WrapData, String?) _data(BuildContext context) {
    final flip = textDirection == TextDirection.rtl ? -1 : 1;
    return _transitionData(
      context,
      position,
      'translate',
      (o) =>
          '${cssNum(_round(o.dx * 100 * flip))}% '
          '${cssNum(_round(o.dy * 100))}%',
    );
  }
}

/// Where Flutter's `DecoratedBoxTransition` paints its decoration.
enum DecorationPosition {
  /// Behind the child.
  background,

  /// In front of the child.
  foreground,
}

/// Flutter's `DecoratedBoxTransition`: a [DecoratedBox] whose [decoration]
/// animates.
///
/// ```dart
/// DecoratedBoxTransition(
///   decoration: DecorationTween(
///     begin: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
///     end: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(20)),
///   ).animate(CurvedAnimation(parent: card.pulse, curve: Curves.easeOut)),
///   child: content,
/// )
/// ```
///
/// Each property of the decoration that changes (background color, corner
/// radius, border, shadows) is a track of keyframes between its two values,
/// and the browser interpolates it; what stays the same isn't animated. It
/// plays like the other transitions (a controller of a `ThorState`, at
/// render, `AnimationController.onVisible`, and as the row animation of an
/// `AnimatedList`).
///
/// `// web:` [position] is ignored: the decoration is always behind the
/// child (CSS has no foreground box); a gradient or an image can't
/// interpolate and flips at the half way.
class DecoratedBoxTransition extends StatelessWidget
    implements ThorElementWidget, ThorBuiltIn {
  /// Animates [decoration] behind [child].
  const DecoratedBoxTransition({
    super.key,
    required this.decoration,
    this.position = DecorationPosition.background,
    this.child,
  });

  /// The decoration, as it animates (`DecorationTween(…).animate(controller)`).
  final Animation<Decoration> decoration;

  /// web: ignored; it is always [DecorationPosition.background].
  final DecorationPosition position;

  /// The widget below this one in the tree.
  final Widget? child;

  /// What a property is when a decoration doesn't say (CSS interpolates
  /// from the initial value).
  static const _initial = {
    'background-color': 'transparent',
    'border-radius': '0',
    'box-shadow': 'none',
  };

  @override
  Widget build(BuildContext context) {
    final plan = planAnimation(decoration);
    final ends = [
      decoration.value,
      for (final s in plan.forward) ...[s.v0, s.v1],
      for (final s
          in plan.reverse ?? const <AnimationSegment<Decoration>>[]) ...[
        s.v0,
        s.v1,
      ],
    ];
    // The properties whose value is not the same in every stretch.
    final changing = <String>[
      for (final key in {for (final d in ends) ...d.toCss().keys})
        if ({for (final d in ends) d.toCss()[key] ?? _initial[key]}.length > 1)
          key,
    ];
    var wrap = const WrapData();
    final keyframes = <String>[];
    for (final key in changing) {
      final (data, frames) = _transitionData<Decoration>(
        context,
        decoration,
        key,
        (d) => d.toCss()[key] ?? _initial[key] ?? 'initial',
      );
      wrap = wrap.merge(data);
      if (frames != null) keyframes.add(frames);
    }
    final built = WrapWith(
      wrap,
      child: DecoratedBox(decoration: decoration.value, child: child),
    );
    if (keyframes.isEmpty) return built;
    return Widget.fragment([
      Widget.element(tag: 'style', children: [RawText(keyframes.join())]),
      built,
    ]);
  }
}

/// Flutter's `SizeTransition`: [sizeFactor] (0 to 1) is the fraction of the
/// child's size that shows along [axis], clipped, with the child aligned by
/// [axisAlignment] (-1 start, 0 center, 1 end).
///
/// ```dart
/// SizeTransition(
///   sizeFactor: CurvedAnimation(parent: panel.open, curve: Curves.easeOut),
///   axisAlignment: -1,
///   child: Details(item),
/// )
/// ```
///
/// Plays like the other transitions (the controller of a `ThorState`, at
/// render, `onVisible`). The size is a grid track of `<n>fr` (Radix's
/// collapsible measures the height in JS; `interpolate-size: allow-keywords`
/// only works in Chromium; a fraction of a track works everywhere and
/// needs no measuring): the element's own class holds the first frame.
///
/// `// web:` unlike the other transitions it has elements of its own (a
/// grid that clips, and a flex box that aligns the child); no
/// `fixedCrossAxisSizeFactor`. Fully collapsed (factor 0) the child gets
/// `visibility: hidden`, so it is out of the tab order and the
/// accessibility tree (Flutter's would still be focusable).
class SizeTransition extends StatelessWidget
    implements ThorElementWidget, ThorBuiltIn {
  /// Shows [sizeFactor] of [child] along [axis].
  const SizeTransition({
    super.key,
    this.axis = Axis.vertical,
    required this.sizeFactor,
    this.axisAlignment = 0.0,
    this.child,
  });

  /// The direction that grows and shrinks.
  final Axis axis;

  /// The fraction of the child's size shown, 0 to 1.
  final Animation<double> sizeFactor;

  /// Where the child sits while it is cut: -1 start, 0 center, 1 end.
  final double axisAlignment;

  /// The widget below this one in the tree.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final vertical = axis == Axis.vertical;
    final (size, sizeKeyframes) = _transitionData<double>(
      context,
      sizeFactor,
      vertical ? 'grid-template-rows' : 'grid-template-columns',
      (v) => '${cssNum(_round(v.clamp(0.0, 1.0)))}fr',
    );
    final (shown, shownKeyframes) = _transitionData<double>(
      context,
      sizeFactor,
      'visibility',
      // Interpolated between hidden and visible it is visible all the way.
      (v) => v <= 0 ? 'hidden' : 'visible',
    );
    final justify = switch (axisAlignment) {
      <= -1 => 'flex-start',
      >= 1 => 'flex-end',
      _ => 'center',
    };
    final grid = thorElement(
      'div',
      debugName: 'SizeTransition',
      css: {'display': 'grid', 'overflow': 'hidden'},
      children: [
        thorElement(
          'div',
          css: {
            // The track squeezes it below its content.
            if (vertical) 'min-height': '0' else 'min-width': '0',
            'overflow': 'hidden',
            'display': 'flex',
            'flex-direction': vertical ? 'column' : 'row',
            'justify-content': justify,
          },
          childRules: vertical ? ChildRules.column : ChildRules.row,
          children: [child ?? const SizedBox.shrink()],
        ),
      ],
    );
    final built = WrapWith(size, child: WrapWith(shown, child: grid));
    final frames = [?sizeKeyframes, ?shownKeyframes];
    if (frames.isEmpty) return built;
    return Widget.fragment([
      Widget.element(tag: 'style', children: [RawText(frames.join())]),
      built,
    ]);
  }
}

/// A whole number that counts as [count] animates, from where it starts to
/// where it ends: a figure of a dashboard that fills up. [prefix] and
/// [suffix] go around it (`' %'`), in [style].
///
/// ```dart
/// CountTransition(
///   count: IntTween(begin: 0, end: 96).animate(
///     CurvedAnimation(parent: controller, curve: Curves.easeOutCubic),
///   ),
///   suffix: ' %',
/// )
/// ```
///
/// The page holds the final figure as text (it copies, searches and reads
/// as `96 %`, and it sets the width, so nothing moves); while it counts a
/// copy on top shows the steps. It plays like the other transitions: at
/// render, [AnimationController.onVisible] or [AnimationController.inView].
///
/// web: the steps are CSS counters, so they are plain digits (no thousands
/// separator); the final text is [format]ted. A controller of a `ThorState`
/// shows the figure where it rests, with no count yet.
class CountTransition extends StatelessWidget
    implements ThorElementWidget, ThorBuiltIn {
  /// Counts along [count].
  const CountTransition({
    super.key,
    required this.count,
    this.prefix = '',
    this.suffix = '',
    this.style,
    this.format,
  });

  /// The number, as it animates.
  final Animation<int> count;

  /// Text before the number.
  final String prefix;

  /// Text after the number (`' %'`).
  final String suffix;

  /// The text's style (default: the surrounding one).
  final TextStyle? style;

  /// How the final figure is written (default: `'$n'`).
  final String Function(int value)? format;

  /// At most this many steps: a count of thousands jumps instead of
  /// writing every number.
  static const maxSteps = 60;

  @override
  Widget build(BuildContext context) {
    final plan = planAnimation(count);
    final controller = plan.controller;
    final end = controller == null ? count.value : animationValueAt(count, 1);
    final text = '$prefix${format?.call(end) ?? '$end'}$suffix';
    final shown = WrapData(
      css: {
        'position': 'relative',
        'display': 'inline-block',
        ...?style?.toCss(),
      },
    );
    if (controller == null ||
        controller.visibleRange == null &&
            controller.viewRange == null &&
            controller.playback == null) {
      return WrapWith(
        shown,
        child: Widget.element(tag: 'span', children: [Widget.text(text)]),
      );
    }

    // The final text hides while it counts; the steps show on top of it.
    List<_Frame> swap(String during, String after) => [
      (0, during, const Threshold(1)),
      (1, after, Curves.linear),
    ];
    final steps = <_Frame>[];
    for (var i = 0; i <= maxSteps; i++) {
      final t = i / maxSteps;
      final value = 'tc ${animationValueAt(count, t)}';
      if (steps.isEmpty || steps.last.$2 != value || i == maxSteps) {
        steps.add((
          t,
          value,
          i == maxSteps ? Curves.linear : const Threshold(1),
        ));
      }
    }
    final (finalText, finalCss) = _track(
      context,
      controller,
      'visibility',
      const {'visibility': 'visible'},
      swap('hidden', 'visible'),
      null,
      const {},
    );
    final (digits, digitsCss) = _track(
      context,
      controller,
      'visibility',
      const {'visibility': 'hidden'},
      swap('visible', 'hidden'),
      null,
      const {},
    );
    final (counter, counterCss) = _track(
      context,
      controller,
      'counter-reset',
      {'counter-reset': 'tc $end'},
      steps,
      null,
      const {},
    );
    String quoted(String s) =>
        '"${s.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';
    final overlay = digits
        .merge(counter)
        .merge(
          WrapData(
            css: const {'position': 'absolute', 'inset': '0'},
            conditions: [
              ConditionalCss(const CssCondition.selector('::after'), {
                'content': '${quoted(prefix)} counter(tc) ${quoted(suffix)}',
              }),
            ],
            attributes: const {'aria-hidden': 'true'},
          ),
        );
    final keyframes = [?finalCss, ?digitsCss, ?counterCss];
    return Widget.fragment([
      if (keyframes.isNotEmpty)
        Widget.element(tag: 'style', children: [RawText(keyframes.join())]),
      WrapWith(
        shown,
        child: Widget.element(
          tag: 'span',
          children: [
            WrapWith(
              finalText,
              child: Widget.element(tag: 'span', children: [Widget.text(text)]),
            ),
            WrapWith(overlay, child: const Widget.element(tag: 'span')),
          ],
        ),
      ),
    ]);
  }
}
