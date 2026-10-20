/// Flutter's animation values: [Tween], [ColorTween], [CurveTween],
/// [TweenSequence], [CurvedAnimation], [ReverseAnimation] and
/// [AlwaysStoppedAnimation], on top of the engine's `AnimationController`.
///
/// They evaluate in Dart like in Flutter (`tween.transform(t)`,
/// `animation.value`), and the server compiles a chain of them into
/// keyframes of the controller's range ([planAnimation]): the page never
/// evaluates a curve per frame.
library;

import 'package:thor_engine/thor_engine.dart';
import 'package:thor_style/thor_style.dart';

/// Flutter's `Animatable<T>`: maps a `double` (usually 0 to 1) to a `T`.
abstract class Animatable<T> {
  /// Const constructor for subclasses.
  const Animatable();

  /// The value at [t].
  T transform(double t);

  /// The value at [animation]'s current value.
  T evaluate(Animation<double> animation) => transform(animation.value);

  /// An animation of this, driven by [parent].
  Animation<T> animate(Animation<double> parent) =>
      _AnimatedEvaluation<T>(parent, this);

  /// This, applied after [parent] (`tween.chain(CurveTween(curve: …))`).
  Animatable<T> chain(Animatable<double> parent) =>
      _ChainedEvaluation<T>(parent, this);
}

/// Flutter's `Animation.drive`: `controller.drive(Tween(begin: 0.8, end: 1.0))`.
extension AnimationDrive on Animation<double> {
  /// An animation of [child], driven by this one.
  Animation<U> drive<U>(Animatable<U> child) => child.animate(this);
}

/// Flutter's `Tween`: a linear interpolation from [begin] to [end].
///
/// `lerp` knows `double`, `Offset`, `Color` and `Alignment`; for any other
/// type, subclass and override [lerp] (the server then samples it).
class Tween<T extends Object?> extends Animatable<T> {
  /// A tween from [begin] to [end].
  Tween({this.begin, this.end});

  /// The value at 0.
  T? begin;

  /// The value at 1.
  T? end;

  /// The value at [t] between [begin] and [end].
  ///
  /// Throws an [UnsupportedError] for a type it doesn't know.
  T lerp(double t) {
    final a = begin, b = end;
    final Object? v = switch ((a, b)) {
      (final num a, final num b) => a + (b - a) * t,
      (final Offset a, final Offset b) => Offset(
        a.dx + (b.dx - a.dx) * t,
        a.dy + (b.dy - a.dy) * t,
      ),
      (final Alignment a, final Alignment b) => Alignment(
        a.x + (b.x - a.x) * t,
        a.y + (b.y - a.y) * t,
      ),
      (final Color? a, final Color? b) when a != null || b != null => lerpColor(
        a,
        b,
        t,
      ),
      _ => throw UnsupportedError(
        'Tween<$T>.lerp: thor interpolates double, Offset, Color and '
        'Alignment; override lerp for $T.',
      ),
    };
    return v as T;
  }

  @override
  T transform(double t) => t == 0.0
      ? begin as T
      : t == 1.0
      ? end as T
      : lerp(t);

  @override
  String toString() => 'Tween($begin → $end)';
}

/// Flutter's `ColorTween`. Between theme colors (variables), the value in
/// Dart is a `color-mix()`; the page interpolates them itself.
class ColorTween extends Tween<Color?> {
  /// A tween from [begin] to [end].
  ColorTween({super.begin, super.end});

  @override
  Color? lerp(double t) => lerpColor(begin, end, t);
}

/// Flutter's `DecorationTween`: a [BoxDecoration] from [begin] to [end].
///
/// Color, corner radii, border sides (width and color) and shadows
/// interpolate; the browser does the same in CSS for a
/// `DecoratedBoxTransition`. A gradient, an image and the shape cannot: they
/// switch at the half way (the browser does the same).
class DecorationTween extends Tween<BoxDecoration> {
  /// A tween from [begin] to [end].
  DecorationTween({super.begin, super.end});

  @override
  BoxDecoration lerp(double t) => _lerpDecoration(begin!, end!, t);
}

double _lerpNum(double a, double b, double t) => a + (b - a) * t;

BorderSide _lerpSide(BorderSide a, BorderSide b, double t) {
  if (a.style == BorderStyle.none && b.style == BorderStyle.none) return b;
  // A side that is not drawn yet grows from nothing, in the other's color.
  final from = a.style == BorderStyle.none
      ? BorderSide(color: b.color.withOpacity(0), width: 0, style: b.style)
      : a;
  final to = b.style == BorderStyle.none
      ? BorderSide(color: a.color.withOpacity(0), width: 0, style: a.style)
      : b;
  return BorderSide(
    color: lerpColor(from.color, to.color, t) ?? to.color,
    width: _lerpNum(from.width, to.width, t),
    style: to.style,
  );
}

Radius _lerpRadius(Radius a, Radius b, double t) =>
    Radius.elliptical(_lerpNum(a.x, b.x, t), _lerpNum(a.y, b.y, t));

BoxShadow _lerpShadow(BoxShadow a, BoxShadow b, double t) => BoxShadow(
  color: lerpColor(a.color, b.color, t) ?? b.color,
  offset: Offset(
    _lerpNum(a.offset.dx, b.offset.dx, t),
    _lerpNum(a.offset.dy, b.offset.dy, t),
  ),
  blurRadius: _lerpNum(a.blurRadius, b.blurRadius, t),
  spreadRadius: _lerpNum(a.spreadRadius, b.spreadRadius, t),
  inset: b.inset,
);

// Corners interpolate within one kind (physical or directional); a pair
// of different kinds (their corners are not the same ones until the browser
// knows the direction) switches halfway.
BorderRadiusGeometry? _lerpBorderRadius(
  BorderRadiusGeometry? a,
  BorderRadiusGeometry? b,
  BorderRadiusGeometry? later,
  double t,
) {
  if (a == null && b == null) return null;
  final x = a ?? BorderRadius.zero, y = b ?? BorderRadius.zero;
  if (x is BorderRadius && y is BorderRadius) {
    return BorderRadius.only(
      topLeft: _lerpRadius(x.topLeft, y.topLeft, t),
      topRight: _lerpRadius(x.topRight, y.topRight, t),
      bottomRight: _lerpRadius(x.bottomRight, y.bottomRight, t),
      bottomLeft: _lerpRadius(x.bottomLeft, y.bottomLeft, t),
    );
  }
  if (x is BorderRadiusDirectional && y is BorderRadiusDirectional) {
    return BorderRadiusDirectional.only(
      topStart: _lerpRadius(x.topStart, y.topStart, t),
      topEnd: _lerpRadius(x.topEnd, y.topEnd, t),
      bottomStart: _lerpRadius(x.bottomStart, y.bottomStart, t),
      bottomEnd: _lerpRadius(x.bottomEnd, y.bottomEnd, t),
    );
  }
  return later;
}

BoxDecoration _lerpDecoration(BoxDecoration a, BoxDecoration b, double t) {
  if (t == 0) return a;
  if (t == 1) return b;
  final ra = a.borderRadius, rb = b.borderRadius;
  final ba = a.border, bb = b.border;
  final sa = a.boxShadow ?? const <BoxShadow>[];
  final sb = b.boxShadow ?? const <BoxShadow>[];
  final shadows = <BoxShadow>[
    for (var i = 0; i < (sa.length > sb.length ? sa.length : sb.length); i++)
      _lerpShadow(
        i < sa.length ? sa[i] : BoxShadow(color: sb[i].color.withOpacity(0)),
        i < sb.length ? sb[i] : BoxShadow(color: sa[i].color.withOpacity(0)),
        t,
      ),
  ];
  final later = t < 0.5 ? a : b;
  return BoxDecoration(
    color: lerpColor(a.color, b.color, t),
    image: later.image,
    gradient: later.gradient,
    shape: later.shape,
    border: ba == null && bb == null
        ? null
        : Border(
            top: _lerpSide(
              ba?.top ?? BorderSide.none,
              bb?.top ?? BorderSide.none,
              t,
            ),
            right: _lerpSide(
              ba?.right ?? BorderSide.none,
              bb?.right ?? BorderSide.none,
              t,
            ),
            bottom: _lerpSide(
              ba?.bottom ?? BorderSide.none,
              bb?.bottom ?? BorderSide.none,
              t,
            ),
            left: _lerpSide(
              ba?.left ?? BorderSide.none,
              bb?.left ?? BorderSide.none,
              t,
            ),
          ),
    borderRadius: _lerpBorderRadius(ra, rb, later.borderRadius, t),
    boxShadow: shadows.isEmpty ? null : shadows,
  );
}

/// Flutter's `IntTween`: whole numbers from [begin] to [end], rounded (a
/// count).
class IntTween extends Tween<int> {
  /// A tween from [begin] to [end].
  IntTween({super.begin, super.end});

  @override
  int lerp(double t) => (begin! + (end! - begin!) * t).round();
}

/// Flutter's `ConstantTween`: always the same value.
class ConstantTween<T> extends Tween<T> {
  /// A tween that is always `value`.
  ConstantTween(T value) : super(begin: value, end: value);

  @override
  T lerp(double t) => begin as T;
}

/// Flutter's `CurveTween`: [curve] as an animatable.
class CurveTween extends Animatable<double> {
  /// Applies [curve].
  CurveTween({required this.curve});

  /// The curve.
  Curve curve;

  @override
  double transform(double t) => t == 0.0 || t == 1.0 ? t : curve.transform(t);
}

/// Flutter's `TweenSequenceItem`: a [tween] over a share ([weight]) of the
/// sequence.
class TweenSequenceItem<T> {
  /// An item of a [TweenSequence].
  const TweenSequenceItem({required this.tween, required this.weight})
    : assert(weight > 0);

  /// What plays over this item's share.
  final Animatable<T> tween;

  /// Its share, relative to the other items' weights.
  final double weight;
}

/// Flutter's `TweenSequence`: several tweens one after another.
class TweenSequence<T> extends Animatable<T> {
  /// Plays [items] in order, each over its share of 0 to 1.
  ///
  /// Throws an [ArgumentError] when [items] is empty or a weight is not
  /// positive.
  TweenSequence(List<TweenSequenceItem<T>> items)
    : items = List.unmodifiable(items) {
    if (items.isEmpty) {
      throw ArgumentError.value(items, 'items', 'must not be empty');
    }
    var total = 0.0;
    for (final i in items) {
      if (!(i.weight > 0) || !i.weight.isFinite) {
        throw ArgumentError.value(i.weight, 'weight', 'must be positive');
      }
      total += i.weight;
    }
    var start = 0.0;
    for (final i in items) {
      final end = start + i.weight / total;
      _intervals.add((start, end));
      start = end;
    }
  }

  /// The items, in order.
  final List<TweenSequenceItem<T>> items;
  final List<(double, double)> _intervals = [];

  @override
  T transform(double t) {
    if (t == 1.0) return items.last.tween.transform(1);
    for (var i = 0; i < items.length; i++) {
      final (a, b) = _intervals[i];
      if (t < b || i == items.length - 1) {
        return items[i].tween.transform(((t - a) / (b - a)).clamp(0.0, 1.0));
      }
    }
    return items.last.tween.transform(1);
  }
}

/// Flutter's `AlwaysStoppedAnimation`: [value], forever. A transition with
/// one is a static style.
class AlwaysStoppedAnimation<T> extends Animation<T> {
  /// Always [value].
  const AlwaysStoppedAnimation(this.value);

  @override
  final T value;

  @override
  AnimationStatus get status => AnimationStatus.forward;

  @override
  void addStatusListener(AnimationStatusListener listener) {}

  @override
  void removeStatusListener(AnimationStatusListener listener) {}
}

/// An animation that follows [parent]'s status and listeners.
abstract class _Derived<T> extends Animation<T> {
  const _Derived(this.parent);

  final Animation<Object?> parent;

  @override
  AnimationStatus get status => parent.status;

  @override
  void addStatusListener(AnimationStatusListener listener) =>
      parent.addStatusListener(listener);

  @override
  void removeStatusListener(AnimationStatusListener listener) =>
      parent.removeStatusListener(listener);
}

/// Flutter's `CurvedAnimation`: [parent] (0 to 1) through [curve], and
/// through [reverseCurve] while it runs in reverse.
class CurvedAnimation extends _Derived<double> {
  /// [parent] through [curve].
  CurvedAnimation({
    required Animation<double> parent,
    required this.curve,
    this.reverseCurve,
  }) : super(parent);

  /// The curve forward.
  Curve curve;

  /// The curve in reverse (default [curve]).
  Curve? reverseCurve;

  @override
  Animation<double> get parent => super.parent as Animation<double>;

  @override
  double get value {
    final t = parent.value;
    if (t == 0.0 || t == 1.0) return t;
    return _curveFor(parent.status == AnimationStatus.reverse).transform(t);
  }

  Curve _curveFor(bool reversing) => reversing ? reverseCurve ?? curve : curve;
}

/// Flutter's `ReverseAnimation`: 1 minus [parent]'s value, status flipped.
class ReverseAnimation extends _Derived<double> {
  /// The reverse of [parent].
  const ReverseAnimation(Animation<double> super.parent);

  @override
  Animation<double> get parent => super.parent as Animation<double>;

  @override
  double get value => 1.0 - parent.value;

  @override
  AnimationStatus get status => switch (parent.status) {
    AnimationStatus.forward => AnimationStatus.reverse,
    AnimationStatus.reverse => AnimationStatus.forward,
    AnimationStatus.completed => AnimationStatus.dismissed,
    AnimationStatus.dismissed => AnimationStatus.completed,
  };
}

class _AnimatedEvaluation<T> extends _Derived<T> {
  _AnimatedEvaluation(Animation<double> super.parent, this.animatable);

  final Animatable<T> animatable;

  Animation<double> get _parent => parent as Animation<double>;

  @override
  T get value => animatable.evaluate(_parent);
}

class _ChainedEvaluation<T> extends Animatable<T> {
  _ChainedEvaluation(this.parent, this.child);

  final Animatable<double> parent;
  final Animatable<T> child;

  @override
  T transform(double t) => child.transform(parent.transform(t));
}

/// [a] to [b] at [t], like Flutter's `Color.lerp` (null = transparent
/// version of the other). Colors from the theme (variables, CSS) become a
/// `color-mix()`.
Color? lerpColor(Color? a, Color? b, double t) {
  if (a == null && b == null) return null;
  a ??= _transparent(b!);
  b ??= _transparent(a);
  if (t == 0) return a;
  if (t == 1) return b;
  if (!a.hasChannels || !b.hasChannels) {
    final p = ((1 - t) * 100).clamp(0, 100);
    return Color.css('color-mix(in srgb, ${a.css} ${cssNum(p)}%, ${b.css})');
  }
  int ch(int x, int y) => (x + (y - x) * t).round().clamp(0, 255);
  return Color.fromARGB(
    ch(a.alpha, b.alpha),
    ch(a.red, b.red),
    ch(a.green, b.green),
    ch(a.blue, b.blue),
  );
}

Color _transparent(Color c) =>
    c.hasChannels && c.value != 0 ? c.withAlpha(0) : c.withOpacity(0);

// ---------------------------------------------------------------------------
// Server-side planning: a chain of animations → keyframes of the controller.

/// A stretch of an animation between two positions of its controller
/// ([t0] to [t1], fractions of its range): the value goes from [v0] to
/// [v1] along [curve]. It becomes two keyframes (the first with [curve]
/// as its easing).
class AnimationSegment<T> {
  /// A stretch from ([t0], [v0]) to ([t1], [v1]).
  const AnimationSegment(this.t0, this.t1, this.v0, this.v1, this.curve);

  /// Where it starts and ends, 0 to 1 of the controller's range.
  final double t0, t1;

  /// The values at [t0] and [t1].
  final T v0, v1;

  /// How it goes from [v0] to [v1].
  final Curve curve;
}

/// The animation an `AnimatedList` gives the builder of each row: 1 for a row
/// at rest, 0 where the row starts (before it enters, once it has left).
///
/// There is no time in it: the browser runs the move as a CSS transition
/// between the two (`@starting-style` when the row is inserted, a marker
/// when it leaves), so a transition widget fed with it (or a tween or curve
/// of it) writes its two ends and its easing, and [duration] is the length
/// of the transition.
///
/// `// web:` Flutter's is driven by the list state's `insertItem` and
/// `removeItem`, per row, with a controller each; here the page's list does
/// the same by changing the list in its state.
class ListItemAnimation extends Animation<double> {
  /// A row's animation that takes [duration] to enter or leave.
  const ListItemAnimation(this.duration);

  /// How long entering or leaving takes.
  final Duration duration;

  @override
  double get value => 1.0;

  @override
  AnimationStatus get status => AnimationStatus.completed;

  @override
  void addStatusListener(AnimationStatusListener listener) {}

  @override
  void removeStatusListener(AnimationStatusListener listener) {}
}

/// The [ListItemAnimation] at the root of [animation]'s chain, or null.
ListItemAnimation? listItemOf(Animation<Object?> animation) =>
    switch (animation) {
      ListItemAnimation() => animation,
      _Derived() => listItemOf(animation.parent),
      _ => null,
    };

/// What the server compiles an animation into ([planAnimation]).
class AnimationPlan<T> {
  /// A plan.
  const AnimationPlan(this.controller, this.forward, this.reverse, [this.item]);

  /// The controller at the root of the chain, or null (a static value).
  final AnimationController? controller;

  /// The list row animation at the root of the chain, or null: then
  /// [forward] has the stretches from the row's start (0) to its rest (1).
  final ListItemAnimation? item;

  /// The stretches while the controller runs forward, in order.
  final List<AnimationSegment<T>> forward;

  /// The stretches while it runs in reverse, when they differ (a
  /// `reverseCurve`); else null.
  final List<AnimationSegment<T>>? reverse;
}

/// Samples per chain the server can't compile exactly (a nested curve, a
/// custom tween): like `Curve.css` does for `linear()`.
const _samples = 40;

/// Compiles [animation] into stretches of its controller: exact for a
/// controller through a curve, a tween, a `CurveTween` chain or a
/// `TweenSequence` of those; sampled for anything else. An animation with
/// no controller (`AlwaysStoppedAnimation`, a custom one) is static.
AnimationPlan<T> planAnimation<T>(Animation<T> animation) {
  final item = listItemOf(animation);
  if (item != null) {
    return AnimationPlan<T>(
      null,
      _exact<T>(animation, false) ?? _sampledItem<T>(animation),
      null,
      item,
    );
  }
  final root = _rootOf(animation);
  if (root == null) return AnimationPlan<T>(null, const [], null);
  final forward =
      _exact<T>(animation, false) ?? _sampled<T>(animation, root, false);
  final reverse = _hasReverseCurve(animation)
      ? _exact<T>(animation, true) ?? _sampled<T>(animation, root, true)
      : null;
  return AnimationPlan<T>(root, forward, reverse);
}

/// [animation]'s value at [t] (0 to 1) of its controller's range while
/// it runs forward: what a widget samples when the value has no CSS
/// interpolation (a count).
T animationValueAt<T>(Animation<T> animation, double t) =>
    _valueAt(animation, t, false);

/// The part [min] to [max] (fractions of the controller's range) of
/// [animation], as stretches over 0 to 1: what a loop over a stretch of the
/// range plays (`repeat(min:, max:)`). The values at its ends and where a
/// stretch of [segments] begins or ends come from the animation itself; a
/// stretch of a curve that the window cuts is sampled, because the part of
/// a curve is no longer that curve.
///
/// [reversing] picks the `reverseCurve` side.
List<AnimationSegment<T>> windowSegments<T>(
  Animation<T> animation,
  List<AnimationSegment<T>> segments,
  double min,
  double max, {
  bool reversing = false,
}) {
  T at(double t) => _valueAt<T>(animation, t, reversing);
  if (!(max > min)) {
    final v = at(min);
    return [AnimationSegment<T>(0, 1, v, v, Curves.linear)];
  }
  double scale(double t) => (t - min) / (max - min);
  final out = <AnimationSegment<T>>[];
  for (final s in segments) {
    final a = s.t0 < min ? min : s.t0, b = s.t1 > max ? max : s.t1;
    if (!(b > a)) continue;
    final cut = a > s.t0 || b < s.t1;
    if (!cut || identical(s.curve, Curves.linear)) {
      out.add(
        AnimationSegment<T>(
          scale(a),
          scale(b),
          cut ? at(a) : s.v0,
          cut ? at(b) : s.v1,
          s.curve,
        ),
      );
      continue;
    }
    const pieces = 16;
    for (var i = 0; i < pieces; i++) {
      final p = a + (b - a) * i / pieces, q = a + (b - a) * (i + 1) / pieces;
      out.add(
        AnimationSegment<T>(scale(p), scale(q), at(p), at(q), Curves.linear),
      );
    }
  }
  if (out.isEmpty) {
    final v = at(min);
    return [AnimationSegment<T>(0, 1, v, at(max), Curves.linear)];
  }
  return out;
}

AnimationController? _rootOf(Animation<Object?> a) => switch (a) {
  AnimationController() => a,
  _Derived() => _rootOf(a.parent),
  _ => null,
};

bool _hasReverseCurve(Animation<Object?> a) => switch (a) {
  CurvedAnimation(:final reverseCurve) when reverseCurve != null => true,
  _Derived() => _hasReverseCurve(a.parent),
  _ => false,
};

/// Whether [a]'s own status is `reverse` while its controller reverses
/// ([reversing]).
bool _reversingAt(Animation<Object?> a, bool reversing) => switch (a) {
  ReverseAnimation() => !_reversingAt(a.parent, reversing),
  _Derived() => _reversingAt(a.parent, reversing),
  _ => reversing,
};

/// [a]'s value at [t] of its controller's range.
T _valueAt<T>(Animation<T> a, double t, bool reversing) {
  final Object? v = switch (a) {
    final AnimationController c =>
      c.lowerBound + (c.upperBound - c.lowerBound) * t,
    ListItemAnimation() => t,
    final CurvedAnimation c => () {
      final p = _valueAt<double>(c.parent, t, reversing);
      return p == 0.0 || p == 1.0
          ? p
          : c._curveFor(_reversingAt(c.parent, reversing)).transform(p);
    }(),
    final ReverseAnimation r => 1.0 - _valueAt<double>(r.parent, t, reversing),
    final _AnimatedEvaluation<T> e => e.animatable.transform(
      _valueAt<double>(e._parent, t, reversing),
    ),
    _ => a.value,
  };
  return v as T;
}

List<AnimationSegment<T>> _sampledItem<T>(Animation<T> a) {
  final values = [
    for (var i = 0; i <= _samples; i++) _valueAt(a, i / _samples, false),
  ];
  return [
    for (var i = 0; i < _samples; i++)
      AnimationSegment<T>(
        i / _samples,
        (i + 1) / _samples,
        values[i],
        values[i + 1],
        Curves.linear,
      ),
  ];
}

List<AnimationSegment<T>> _sampled<T>(
  Animation<T> a,
  AnimationController root,
  bool reversing,
) {
  final values = [
    for (var i = 0; i <= _samples; i++) _valueAt(a, i / _samples, reversing),
  ];
  return [
    for (var i = 0; i < _samples; i++)
      AnimationSegment<T>(
        i / _samples,
        (i + 1) / _samples,
        values[i],
        values[i + 1],
        Curves.linear,
      ),
  ];
}

bool _isUnit(List<AnimationSegment<double>> s) =>
    s.length == 1 &&
    s.single.t0 == 0 &&
    s.single.t1 == 1 &&
    s.single.v0 == 0 &&
    s.single.v1 == 1 &&
    identical(s.single.curve, Curves.linear);

/// The exact stretches of [a], or null when it needs sampling.
List<AnimationSegment<T>>? _exact<T>(Animation<T> a, bool reversing) {
  final Object? out = switch (a) {
    final AnimationController c => [
      AnimationSegment<double>(0, 1, c.lowerBound, c.upperBound, Curves.linear),
    ],
    ListItemAnimation() => const [
      AnimationSegment<double>(0, 1, 0.0, 1.0, Curves.linear),
    ],
    final CurvedAnimation c => () {
      final p = _exact<double>(c.parent, reversing);
      if (p == null || !_isUnit(p)) return null;
      final curve = c._curveFor(_reversingAt(c.parent, reversing));
      return [AnimationSegment<double>(0, 1, 0.0, 1.0, curve)];
    }(),
    final ReverseAnimation r => switch (_exact<double>(r.parent, reversing)) {
      null => null,
      final p => [
        for (final s in p)
          AnimationSegment<double>(s.t0, s.t1, 1 - s.v0, 1 - s.v1, s.curve),
      ],
    },
    final _AnimatedEvaluation<T> e => () {
      final p = _exact<double>(e._parent, reversing);
      return p == null ? null : _exactAnimatable<T>(e.animatable, p);
    }(),
    _ => null,
  };
  return out as List<AnimationSegment<T>>?;
}

/// Whether [a] interpolates linearly (a plain tween the page interpolates
/// the same way).
bool _isLinear<T>(Animatable<T> a) =>
    a is ColorTween ||
    a is DecorationTween ||
    a is ConstantTween ||
    (a is Tween && a.runtimeType == Tween<T>);

/// [a] applied over the stretches [p] of its parent, or null.
List<AnimationSegment<T>>? _exactAnimatable<T>(
  Animatable<T> a,
  List<AnimationSegment<double>> p,
) {
  if (_isLinear(a)) {
    return [
      for (final s in p)
        AnimationSegment<T>(
          s.t0,
          s.t1,
          a.transform(s.v0),
          a.transform(s.v1),
          s.curve,
        ),
    ];
  }
  if (!_isUnit(p)) return null;
  switch (a) {
    case CurveTween(:final curve):
      return [AnimationSegment<T>(0, 1, 0.0 as T, 1.0 as T, curve)];
    case _ChainedEvaluation(:final parent, :final child)
        when parent is CurveTween && _isLinear(child):
      return [
        AnimationSegment<T>(
          0,
          1,
          child.transform(0),
          child.transform(1),
          parent.curve,
        ),
      ];
    case TweenSequence():
      final out = <AnimationSegment<T>>[];
      for (var i = 0; i < a.items.length; i++) {
        final (start, end) = a._intervals[i];
        final inner = _exactAnimatable<T>(a.items[i].tween, const [
          AnimationSegment<double>(0, 1, 0.0, 1.0, Curves.linear),
        ]);
        if (inner == null) return null;
        for (final s in inner) {
          out.add(
            AnimationSegment<T>(
              start + s.t0 * (end - start),
              start + s.t1 * (end - start),
              s.v0,
              s.v1,
              s.curve,
            ),
          );
        }
      }
      return out;
  }
  return null;
}
