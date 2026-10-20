import 'dart:math' as math;

import 'adaptive.dart';
import 'css.dart';
import 'geometry.dart' show Offset;

/// Flutter's `Curve`: maps animation progress `t` (0..1) to a value.
///
/// Every curve can be evaluated in Dart ([transform], for explicit
/// animations and tests) and compiled to a CSS easing function ([css], for
/// transitions and the Web Animations API). Cubic curves become an exact
/// `cubic-bezier()`; any other curve is sampled into `linear()`.
abstract class Curve {
  /// Const constructor for subclasses.
  const Curve();

  /// The curve's value at [t]. `transform(0) == 0` and `transform(1) == 1`
  /// (overshooting curves may leave 0..1 in between).
  double transform(double t) {
    assert(t >= 0 && t <= 1, 'Curve.transform: t must be in 0..1, got $t');
    if (t == 0 || t == 1) return t;
    return transformInternal(t);
  }

  /// Subclass hook: [transform] delegates here once `t` is confirmed to be
  /// strictly between 0 and 1.
  double transformInternal(double t);

  /// CSS `<easing-function>`.
  String get css => sampledCss(this);

  /// This curve played backwards (Flutter's `Curve.flipped`).
  Curve get flipped => FlippedCurve(this);
}

/// Samples [curve] into CSS `linear()` with [points] evenly spaced stops.
/// 40 points keep elastic/bounce curves visually exact at 60fps durations.
String sampledCss(Curve curve, {int points = 40}) {
  final stops = [
    for (var i = 0; i <= points; i++)
      cssNum(_round(curve.transform(i / points))),
  ];
  return 'linear(${stops.join(', ')})';
}

double _round(double v) => (v * 1000).roundToDouble() / 1000;

/// `linear`.
class _Linear extends Curve {
  const _Linear._();

  @override
  double transformInternal(double t) => t;

  @override
  String get css => 'linear';
}

/// A cubic Bézier curve (`cubic-bezier(a, b, c, d)`), like Flutter's `Cubic`.
class Cubic extends Curve {
  /// Creates a cubic Bézier curve from its four control values.
  const Cubic(this.a, this.b, this.c, this.d);

  /// X coordinate of the first control point.
  final double a;

  /// Y coordinate of the first control point.
  final double b;

  /// X coordinate of the second control point.
  final double c;

  /// Y coordinate of the second control point.
  final double d;

  static const _cubicErrorBound = 0.001;

  double _evaluate(double a, double b, double m) =>
      3 * a * (1 - m) * (1 - m) * m + 3 * b * (1 - m) * m * m + m * m * m;

  // Same bisection as Flutter, so values match the real framework.
  @override
  double transformInternal(double t) {
    var start = 0.0;
    var end = 1.0;
    while (true) {
      final midpoint = (start + end) / 2;
      final estimate = _evaluate(a, c, midpoint);
      if ((t - estimate).abs() < _cubicErrorBound) {
        return _evaluate(b, d, midpoint);
      }
      if (estimate < t) {
        start = midpoint;
      } else {
        end = midpoint;
      }
    }
  }

  @override
  String get css =>
      'cubic-bezier(${cssNum(a)}, ${cssNum(b)}, ${cssNum(c)}, ${cssNum(d)})';

  @override
  bool operator ==(Object other) =>
      other is Cubic &&
      other.a == a &&
      other.b == b &&
      other.c == c &&
      other.d == d;

  @override
  int get hashCode => Object.hash(a, b, c, d);
}

/// Flutter's `ThreePointCubic`: two cubics sharing a [midpoint]. Sampled
/// into `linear()` in CSS (it is not one `cubic-bezier()`).
class ThreePointCubic extends Curve {
  /// Creates two cubic curves that share the control point [midpoint]; the
  /// ends (0, 0) and (1, 1) are implied.
  const ThreePointCubic(this.a1, this.b1, this.midpoint, this.a2, this.b2);

  /// First control point of the first curve.
  final Offset a1;

  /// Second control point of the first curve.
  final Offset b1;

  /// The point both curves share.
  final Offset midpoint;

  /// First control point of the second curve.
  final Offset a2;

  /// Second control point of the second curve.
  final Offset b2;

  @override
  double transformInternal(double t) {
    final firstCurve = t < midpoint.dx;
    final scaleX = firstCurve ? midpoint.dx : 1.0 - midpoint.dx;
    final scaleY = firstCurve ? midpoint.dy : 1.0 - midpoint.dy;
    final scaledT = (t - (firstCurve ? 0.0 : midpoint.dx)) / scaleX;
    if (firstCurve) {
      return Cubic(
            a1.dx / scaleX,
            a1.dy / scaleY,
            b1.dx / scaleX,
            b1.dy / scaleY,
          ).transform(scaledT) *
          scaleY;
    }
    return Cubic(
              (a2.dx - midpoint.dx) / scaleX,
              (a2.dy - midpoint.dy) / scaleY,
              (b2.dx - midpoint.dx) / scaleX,
              (b2.dy - midpoint.dy) / scaleY,
            ).transform(scaledT) *
            scaleY +
        midpoint.dy;
  }
}

/// Flutter's `Interval`: [curve] runs between [begin] and [end] of the
/// parent animation (staggered animations).
class Interval extends Curve {
  /// Creates an interval curve running from [begin] to [end], easing with
  /// [curve] in between.
  const Interval(this.begin, this.end, {this.curve = Curves.linear})
    : assert(begin >= 0 && begin <= 1 && end >= 0 && end <= 1 && end >= begin);

  /// Fraction of the parent animation at which this interval starts (0..1).
  final double begin;

  /// Fraction of the parent animation at which this interval ends (0..1).
  final double end;

  /// Curve applied between [begin] and [end].
  final Curve curve;

  @override
  double transformInternal(double t) {
    // web: Flutter divides by zero here (`NaN`); an empty interval is a step
    // at [begin], like a `Threshold`.
    if (begin == end) return t < begin ? 0 : 1;
    final v = ((t - begin) / (end - begin)).clamp(0.0, 1.0);
    if (v == 0 || v == 1) return v;
    return curve.transform(v);
  }
}

/// Flutter's `Threshold`: jumps from 0 to 1 at [threshold].
class Threshold extends Curve {
  /// Creates a threshold curve that jumps from 0 to 1 at [threshold].
  const Threshold(this.threshold);

  /// Progress value (0..1) at which the curve jumps from 0 to 1.
  final double threshold;

  @override
  double transformInternal(double t) => t < threshold ? 0 : 1;

  @override
  String get css => threshold == 0
      ? 'step-start'
      : threshold == 1
      ? 'step-end'
      : 'linear(0, 0 ${cssNum(threshold * 100)}%, 1 ${cssNum(threshold * 100)}%, 1)';
}

/// Flutter's `FlippedCurve`.
class FlippedCurve extends Curve {
  /// Creates a curve that plays [curve] backwards.
  const FlippedCurve(this.curve);

  /// The curve being flipped.
  final Curve curve;

  @override
  double transformInternal(double t) => 1 - curve.transform(1 - t);

  @override
  String get css {
    final c = curve;
    if (c is Cubic) return Cubic(1 - c.c, 1 - c.d, 1 - c.a, 1 - c.b).css;
    return sampledCss(this);
  }
}

/// Flutter's `ElasticOutCurve` (and In/InOut).
class ElasticOutCurve extends Curve {
  /// Creates an elastic-out curve with the given oscillation [period].
  const ElasticOutCurve([this.period = 0.4]);

  /// Duration of the oscillation, as a fraction of the overall curve.
  final double period;

  @override
  double transformInternal(double t) {
    final s = period / 4;
    return math.pow(2, -10 * t) * math.sin((t - s) * (math.pi * 2) / period) +
        1;
  }
}

/// Flutter's `ElasticInCurve`.
class ElasticInCurve extends Curve {
  /// Creates an elastic-in curve with the given oscillation [period].
  const ElasticInCurve([this.period = 0.4]);

  /// Duration of the oscillation, as a fraction of the overall curve.
  final double period;

  @override
  double transformInternal(double t) {
    final s = period / 4;
    t = t - 1;
    return -math.pow(2, 10 * t) * math.sin((t - s) * (math.pi * 2) / period);
  }
}

/// Flutter's `ElasticInOutCurve`.
class ElasticInOutCurve extends Curve {
  /// Creates an elastic-in-out curve with the given oscillation [period].
  const ElasticInOutCurve([this.period = 0.4]);

  /// Duration of the oscillation, as a fraction of the overall curve.
  final double period;

  @override
  double transformInternal(double t) {
    final s = period / 4;
    t = 2 * t - 1;
    if (t < 0) {
      return -0.5 *
          math.pow(2, 10 * t) *
          math.sin((t - s) * (math.pi * 2) / period);
    }
    return math.pow(2, -10 * t) *
            math.sin((t - s) * (math.pi * 2) / period) *
            0.5 +
        1;
  }
}

double _bounce(double t) {
  if (t < 1 / 2.75) return 7.5625 * t * t;
  if (t < 2 / 2.75) {
    t -= 1.5 / 2.75;
    return 7.5625 * t * t + 0.75;
  }
  if (t < 2.5 / 2.75) {
    t -= 2.25 / 2.75;
    return 7.5625 * t * t + 0.9375;
  }
  t -= 2.625 / 2.75;
  return 7.5625 * t * t + 0.984375;
}

class _BounceOut extends Curve {
  const _BounceOut._();

  @override
  double transformInternal(double t) => _bounce(t);
}

class _BounceIn extends Curve {
  const _BounceIn._();

  @override
  double transformInternal(double t) => 1 - _bounce(1 - t);
}

class _BounceInOut extends Curve {
  const _BounceInOut._();

  @override
  double transformInternal(double t) =>
      t < 0.5 ? (1 - _bounce(1 - t * 2)) * 0.5 : _bounce(t * 2 - 1) * 0.5 + 0.5;
}

/// Flutter's `Curves`, with the same constants.
abstract final class Curves {
  /// A curve where the rate of change starts out quickly and then decreases
  /// steadily. Straight `linear` in CSS terms.
  static const Curve linear = _Linear._();

  /// A curve that starts quickly and eases into its final position.
  static const Cubic decelerate = Cubic(1 / 3, 2 / 3, 2 / 3, 1);

  /// A curve that starts linearly and eases into its final position.
  static const Cubic fastLinearToSlowEaseIn = Cubic(0.18, 1, 0.04, 1);

  /// A cubic curve that starts slow, speeds up, then slows down again.
  static const Cubic ease = Cubic(0.25, 0.1, 0.25, 1);

  /// A cubic curve that starts slow and ends fast.
  static const Cubic easeIn = Cubic(0.42, 0, 1, 1);

  /// A curve that starts slow and eases into a linear rate.
  static const Cubic easeInToLinear = Cubic(0.67, 0.03, 0.65, 0.09);

  /// A cubic curve that starts slow and ends fast, using a sine easing
  /// function.
  static const Cubic easeInSine = Cubic(0.47, 0, 0.745, 0.715);

  /// A cubic curve that starts slow and ends fast, using a quadratic easing
  /// function.
  static const Cubic easeInQuad = Cubic(0.55, 0.085, 0.68, 0.53);

  /// A cubic curve that starts slow and ends fast, using a cubic easing
  /// function.
  static const Cubic easeInCubic = Cubic(0.55, 0.055, 0.675, 0.19);

  /// A cubic curve that starts slow and ends fast, using a quartic easing
  /// function.
  static const Cubic easeInQuart = Cubic(0.895, 0.03, 0.685, 0.22);

  /// A cubic curve that starts slow and ends fast, using a quintic easing
  /// function.
  static const Cubic easeInQuint = Cubic(0.755, 0.05, 0.855, 0.06);

  /// A cubic curve that starts slow and ends fast, using an exponential
  /// easing function.
  static const Cubic easeInExpo = Cubic(0.95, 0.05, 0.795, 0.035);

  /// A cubic curve that starts slow and ends fast, using a circular easing
  /// function.
  static const Cubic easeInCirc = Cubic(0.6, 0.04, 0.98, 0.335);

  /// A cubic curve that starts slow, overshoots backwards, then ends fast.
  static const Cubic easeInBack = Cubic(0.6, -0.28, 0.735, 0.045);

  /// A cubic curve that starts fast and ends slow.
  static const Cubic easeOut = Cubic(0, 0, 0.58, 1);

  /// A curve that starts at a linear rate and eases into its final
  /// position.
  static const Cubic linearToEaseOut = Cubic(0.35, 0.91, 0.33, 0.97);

  /// A cubic curve that starts fast and ends slow, using a sine easing
  /// function.
  static const Cubic easeOutSine = Cubic(0.39, 0.575, 0.565, 1);

  /// A cubic curve that starts fast and ends slow, using a quadratic
  /// easing function.
  static const Cubic easeOutQuad = Cubic(0.25, 0.46, 0.45, 0.94);

  /// A cubic curve that starts fast and ends slow, using a cubic easing
  /// function.
  static const Cubic easeOutCubic = Cubic(0.215, 0.61, 0.355, 1);

  /// A cubic curve that starts fast and ends slow, using a quartic easing
  /// function.
  static const Cubic easeOutQuart = Cubic(0.165, 0.84, 0.44, 1);

  /// A cubic curve that starts fast and ends slow, using a quintic easing
  /// function.
  static const Cubic easeOutQuint = Cubic(0.23, 1, 0.32, 1);

  /// A cubic curve that starts fast and ends slow, using an exponential
  /// easing function.
  static const Cubic easeOutExpo = Cubic(0.19, 1, 0.22, 1);

  /// A cubic curve that starts fast and ends slow, using a circular easing
  /// function.
  static const Cubic easeOutCirc = Cubic(0.075, 0.82, 0.165, 1);

  /// A cubic curve that starts fast, overshoots past its end, then settles.
  static const Cubic easeOutBack = Cubic(0.175, 0.885, 0.32, 1.275);

  /// A cubic curve that starts slow, speeds up, then ends slow.
  static const Cubic easeInOut = Cubic(0.42, 0, 0.58, 1);

  /// An ease-in-out curve using a sine easing function.
  static const Cubic easeInOutSine = Cubic(0.445, 0.05, 0.55, 0.95);

  /// An ease-in-out curve using a quadratic easing function.
  static const Cubic easeInOutQuad = Cubic(0.455, 0.03, 0.515, 0.955);

  /// An ease-in-out curve using a cubic easing function.
  static const Cubic easeInOutCubic = Cubic(0.645, 0.045, 0.355, 1);

  /// A cubic curve that speeds up quickly and ends slowly (steeper than
  /// [easeInOutCubic]).
  static const Curve easeInOutCubicEmphasized = ThreePointCubic(
    Offset(0.05, 0),
    Offset(0.133333, 0.06),
    Offset(0.166666, 0.4),
    Offset(0.208333, 0.82),
    Offset(0.25, 1),
  );

  /// An ease-in-out curve using a quartic easing function.
  static const Cubic easeInOutQuart = Cubic(0.77, 0, 0.175, 1);

  /// An ease-in-out curve using a quintic easing function.
  static const Cubic easeInOutQuint = Cubic(0.86, 0, 0.07, 1);

  /// An ease-in-out curve using an exponential easing function.
  static const Cubic easeInOutExpo = Cubic(1, 0, 0, 1);

  /// An ease-in-out curve using a circular easing function.
  static const Cubic easeInOutCirc = Cubic(0.785, 0.135, 0.15, 0.86);

  /// An ease-in-out curve that overshoots backwards, then forwards.
  static const Cubic easeInOutBack = Cubic(0.68, -0.55, 0.265, 1.55);

  /// The standard Material easing curve.
  static const Cubic fastOutSlowIn = Cubic(0.4, 0, 0.2, 1);

  /// A curve that is fast at the start and eases out slowly (derived from
  /// native iOS 16.3 transitions).
  static const Curve fastEaseInToSlowEaseOut = ThreePointCubic(
    Offset(0.056, 0.024),
    Offset(0.108, 0.3085),
    Offset(0.198, 0.541),
    Offset(0.3655, 1),
    Offset(0.5465, 0.989),
  );

  /// A curve that is fast at the beginning and end, slow in the middle.
  static const Cubic slowMiddle = Cubic(0.15, 0.85, 0.85, 0.15);

  /// An oscillating curve that grows in magnitude, starting from zero.
  static const Curve bounceIn = _BounceIn._();

  /// An oscillating curve that shrinks in magnitude, ending at 1.
  static const Curve bounceOut = _BounceOut._();

  /// An oscillating curve that grows and then shrinks in magnitude.
  static const Curve bounceInOut = _BounceInOut._();

  /// An oscillating curve that grows in magnitude while overshooting its
  /// bounds, ending at 1.
  static const Curve elasticIn = ElasticInCurve();

  /// An oscillating curve that shrinks in magnitude while overshooting its
  /// bounds, starting from 1.
  static const Curve elasticOut = ElasticOutCurve();

  /// An oscillating curve that grows and then shrinks in magnitude while
  /// overshooting its bounds.
  static const Curve elasticInOut = ElasticInOutCurve();
}

/// A CSS `<time>` for [duration] (`200ms`, `1.5s` is written `1500ms`).
String cssDuration(Duration duration) {
  final us = duration.inMicroseconds;
  return us % 1000 == 0 ? '${us ~/ 1000}ms' : '${cssNum(us / 1000)}ms';
}

/// Longhand `transition-*` declarations for [properties] sharing one timing.
/// Longhands are shorter than repeating the shorthand per property and let
/// several transitions merge into one class.
CssDeclarations cssTransition(
  List<String> properties, {
  required Duration duration,
  Curve curve = Curves.linear,
  Duration delay = Duration.zero,
}) => properties.isEmpty
    ? const {}
    : {
        'transition-property': properties.join(', '),
        'transition-duration': cssDuration(duration),
        if (curve != Curves.ease) 'transition-timing-function': curve.css,
        if (delay != Duration.zero) 'transition-delay': cssDuration(delay),
      };

const _transitionKeys = [
  'transition-property',
  'transition-duration',
  'transition-timing-function',
  'transition-delay',
];
const _transitionDefaults = ['all', '0s', 'ease', '0s'];

/// Splits a CSS list on top-level commas (`cubic-bezier(0, 0, 1, 1), ease`).
List<String> _splitList(String value) {
  final out = <String>[];
  var depth = 0;
  var start = 0;
  for (var i = 0; i < value.length; i++) {
    final c = value[i];
    if (c == '(') depth++;
    if (c == ')') depth--;
    if (c == ',' && depth == 0) {
      out.add(value.substring(start, i).trim());
      start = i + 1;
    }
  }
  out.add(value.substring(start).trim());
  return out;
}

/// `{...base, ...over}`, except that transitions **combine**: an
/// `AnimatedOpacity` around an `AnimatedContainer` animates both sets of
/// properties (for a property in both, the timing in [over] wins). Two
/// `animation` shorthands run both.
CssDeclarations mergeCss(CssDeclarations base, CssDeclarations over) {
  if (over.isEmpty) return base;
  if (base.isEmpty) return over;
  final a = base['animation'], b = over['animation'];
  if (a != null && b != null && a != b) {
    // Animations combine too: a fade and a scale from two controllers. The
    // per-animation lists (timeline, range, trigger) go after the shorthand
    // (it resets them), one entry per animation of each side; the scroll
    // triggers they name are declared once.
    String list(CssDeclarations css, String key, String initial) {
      final own = css[key];
      if (own != null) return own;
      final n = _splitList(css['animation']!).length;
      return List.filled(n, initial).join(', ');
    }

    const perAnimation = {
      'animation-timeline': 'auto',
      'animation-range': 'normal',
      'animation-trigger': 'none',
    };
    const triggers = 'timeline-trigger';
    bool has(String key) => base.containsKey(key) || over.containsKey(key);
    return {
      ...mergeCss(
        {...base}..removeWhere(
          (k, _) =>
              k == 'animation' || k == triggers || perAnimation.containsKey(k),
        ),
        {...over}..removeWhere(
          (k, _) =>
              k == 'animation' || k == triggers || perAnimation.containsKey(k),
        ),
      ),
      'animation': '$a, $b',
      for (final MapEntry(:key, :value) in perAnimation.entries)
        if (has(key))
          key: '${list(base, key, value)}, ${list(over, key, value)}',
      if (has(triggers))
        triggers: {
          for (final side in [base, over])
            ..._splitList(side[triggers] ?? '').where((t) => t.isNotEmpty),
        }.join(', '),
    };
  }
  if (!over.containsKey('transition-property') ||
      !base.containsKey('transition-property')) {
    return mergeAdaptive(base, over);
  }
  List<List<String>> rows(CssDeclarations css) {
    final props = _splitList(css['transition-property']!);
    final cols = [
      for (var k = 0; k < 4; k++)
        _splitList(css[_transitionKeys[k]] ?? _transitionDefaults[k]),
    ];
    // CSS repeats shorter lists cyclically.
    return [
      for (var i = 0; i < props.length; i++)
        [for (final col in cols) col[i % col.length]],
    ];
  }

  final byProperty = <String, List<String>>{
    for (final r in rows(base)) r[0]: r,
    for (final r in rows(over)) r[0]: r,
  }.values;
  // CSS: when a property is listed twice the last entry wins, so `all` (the
  // default for everything) must come first or it would override the
  // timing of the properties named next to it.
  final merged = [
    ...byProperty.where((r) => r[0] == 'all'),
    ...byProperty.where((r) => r[0] != 'all'),
  ];
  return {...base, ...over}
    ..removeWhere((k, _) => _transitionKeys.contains(k))
    ..addAll({
      for (var k = 0; k < 4; k++)
        if (k == 0 || merged.any((r) => r[k] != _transitionDefaults[k]))
          _transitionKeys[k]: _joinCompact([for (final r in merged) r[k]]),
    });
}

// `200ms, 200ms` → `200ms` (a single value repeats for every property).
String _joinCompact(List<String> values) =>
    values.every((v) => v == values.first) && values.length > 1
    ? values.first
    : values.join(', ');
