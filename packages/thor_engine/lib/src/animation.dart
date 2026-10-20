/// Flutter's explicit animations: [AnimationController] and the
/// [Animation] contract.
///
/// The controller is pure Dart: it lives in a `ThorState` (so it runs on
/// the server and in the browser) and decides *what* plays. *How* it plays
/// is the browser's job: in the page the engine attaches an
/// [AnimationDriver] that runs the Web Animations API with keyframes the
/// server precompiled, so no Dart runs per frame. On the server (no
/// driver) a playing controller is written as a CSS animation.
library;

import 'dart:async' show Completer;
import 'dart:math' as math;

import 'controllers.dart' show ThorController;
import 'easing.dart';

import 'reactive.dart';

/// Flutter's `AnimationStatus`.
enum AnimationStatus {
  /// Stopped at the beginning (the lower bound).
  dismissed,

  /// Running from the beginning towards the end.
  forward,

  /// Running from the end towards the beginning.
  reverse,

  /// Stopped at the end (the upper bound).
  completed;

  /// Whether the animation is moving ([forward] or [reverse]).
  bool get isAnimating => this == forward || this == reverse;

  /// Whether the animation stopped at the end.
  bool get isCompleted => this == completed;

  /// Whether the animation stopped at the beginning.
  bool get isDismissed => this == dismissed;

  /// Whether the animation runs forward or already reached the end.
  bool get isForwardOrCompleted => this == forward || this == completed;
}

/// Flutter's `AnimationStatusListener`.
typedef AnimationStatusListener = void Function(AnimationStatus status);

/// Flutter's `Animation<T>`: a value that changes over time, and a status.
///
/// web: there is no `addListener` (a callback per frame): frames run in the
/// browser's compositor, not in Dart. Status listeners work (they fire at
/// the start and the end), and a `Watch` of a method that reads [status]
/// updates the page.
abstract class Animation<T> {
  /// Const constructor for subclasses.
  const Animation();

  /// The current value.
  T get value;

  /// The current status.
  AnimationStatus get status;

  /// Calls [listener] every time [status] changes.
  void addStatusListener(AnimationStatusListener listener);

  /// Stops calling [listener].
  void removeStatusListener(AnimationStatusListener listener);

  /// Whether the animation is moving.
  bool get isAnimating => status.isAnimating;

  /// Whether the animation stopped at the end.
  bool get isCompleted => status.isCompleted;

  /// Whether the animation stopped at the beginning.
  bool get isDismissed => status.isDismissed;

  /// Whether the animation runs forward or already reached the end.
  bool get isForwardOrCompleted => status.isForwardOrCompleted;
}

/// How an [AnimationController] is playing: what the page runs (the
/// engine) or what the server writes as a CSS animation. Positions are
/// fractions of the controller's range (0 = lower bound, 1 = upper bound).
final class AnimationPlayback {
  /// A playback starting at [from] whose full pass takes [sweep].
  const AnimationPlayback({
    required this.from,
    required this.sweep,
    this.reverse = false,
    this.iterations = 1,
    this.alternate = false,
    this.to,
    this.easing,
    this.curve,
    this.min = 0.0,
    this.max = 1.0,
    double? at,
  }) : _at = at;

  /// The stretch of the range a pass covers, 0 to 1 of it: a pass goes from
  /// [min] to [max] (`repeat(min:, max:)`); the whole range by default.
  /// [sweep] is then how long that stretch takes.
  final double min, max;

  /// Whether a pass covers less than the whole range.
  bool get windowed => min > 0 || max < 1;

  /// The easing that maps a pass to the stretch (a `linear()` from [min] to
  /// [max]), or null when a pass covers the whole range.
  String? get windowEasing => windowed ? 'linear($min, $max)' : null;

  /// Where in its pass the playback starts, 0 to 1: [at] itself, or, in a
  /// window, [at] clamped into it and measured from [min].
  double get passAt {
    final a = at < min ? min : (at > max ? max : at);
    return windowed ? (max > min ? (a - min) / (max - min) : 0) : at;
  }

  /// Where it starts, 0 to 1.
  final double from;

  /// Where it stops, 0 to 1, when that is not the bound it runs towards
  /// (`animateTo`, `animateBack`); null runs to the end of the range.
  final double? to;

  /// How long one full pass (lower bound to upper bound) takes.
  final Duration sweep;

  /// The CSS easing (`curve.css`) of an `animateTo` / `animateBack` / `fling`
  /// move, over the stretch from [from] to where it stops; null is linear.
  /// The driver composes it with the stretch (an easing of the whole range
  /// that is the identity outside it) so the controller's value follows the
  /// curve, clamped to the bounds like Flutter's.
  final String? easing;

  /// The curve as a function (0..1 to 0..1) where it has one: what the
  /// server samples to write the move as keyframes, and the page to know the
  /// value at a point of the move.
  final double Function(double)? curve;

  final double? _at;

  /// Where the move is now, in the progress of its pass (0 to 1, directed):
  /// [from] unless it is resumed half way (a server animation that was
  /// already running when the page woke up).
  double get at => _at ?? from;

  /// The easing of the whole range this move plays: the identity outside
  /// the stretch from [from] to where it stops, and along [curve] inside it,
  /// clamped to the bounds. [q] is the progress of the pass (directed).
  double valueAt(double q) {
    final c = curve;
    if (c == null) return q;
    final end = to ?? (reverse ? 0.0 : 1.0);
    if (q < (from < end ? from : end) || q > (from < end ? end : from)) {
      return q;
    }
    final s = end == from ? 1.0 : (q - from) / (end - from);
    return (from + (end - from) * c(s.clamp(0.0, 1.0))).clamp(0.0, 1.0);
  }

  /// Whether it runs towards the lower bound.
  final bool reverse;

  /// How many passes (`double.infinity` for `repeat()` without a count).
  final double iterations;

  /// Whether every other pass runs backwards (`repeat(reverse: true)`).
  final bool alternate;

  /// Whether it runs forever.
  bool get repeats => iterations.isInfinite;

  /// How many passes the animation runs for: [iterations], or the part of
  /// one it covers when it stops at [to]. Playing forwards from [from], a
  /// pass that ends at `to` is `to` long; backwards (`direction: reverse`
  /// starts at `1 - from`) it is `1 - to` long.
  double get count => to == null ? iterations : (reverse ? 1 - to! : to!);
}

/// A stage of an element's pass through the viewport, as it scrolls: the
/// named ranges of a CSS view timeline.
enum ViewPhase {
  /// From the moment its first edge enters until its last edge leaves.
  cover,

  /// While it is fully inside the viewport (or, taller than it, while it
  /// fills it).
  contain,

  /// While it is entering: from its first edge in to fully in.
  entry,

  /// While it is leaving: from its first edge out to fully out.
  exit,
}

/// The stretch of scrolling over which an [AnimationController.inView]
/// runs from its lower bound to its upper bound: from [start] of
/// [startPhase] to [end] of [endPhase], each a fraction of its phase (0 to
/// 1).
///
/// ```dart
/// ViewRange.entry                                  // while it enters
/// ViewRange(phase: ViewPhase.entry, end: 0.5)      // the first half of that
/// ViewRange.span(ViewPhase.entry, 0, ViewPhase.cover, 0.3)
/// ```
final class ViewRange {
  /// From [start] to [end] of one [phase].
  const ViewRange({
    ViewPhase phase = ViewPhase.entry,
    this.start = 0,
    this.end = 1,
  }) : startPhase = phase,
       endPhase = phase;

  /// From [start] of [startPhase] to [end] of [endPhase].
  const ViewRange.span(this.startPhase, this.start, this.endPhase, this.end);

  /// While the element enters the viewport: done once it is fully in.
  static const entry = ViewRange();

  /// The phase where it starts.
  final ViewPhase startPhase;

  /// Where in [startPhase] it starts, 0 to 1.
  final double start;

  /// The phase where it ends.
  final ViewPhase endPhase;

  /// Where in [endPhase] it ends, 0 to 1.
  final double end;

  @override
  bool operator ==(Object other) =>
      other is ViewRange &&
      other.startPhase == startPhase &&
      other.start == start &&
      other.endPhase == endPhase &&
      other.end == end;

  @override
  int get hashCode => Object.hash(startPhase, start, endPhase, end);

  @override
  String toString() =>
      'ViewRange(${startPhase.name} $start, ${endPhase.name} $end)';
}

/// What plays an [AnimationController] in the page: the engine's Web
/// Animations driver. Positions are fractions of the controller's range.
abstract interface class AnimationDriver {
  /// Where the animation is now, 0 to 1.
  double get progress;

  /// Whether the user asked for reduced motion (then nothing moves: a
  /// playback jumps to its end; a `repeat`, to the upper bound).
  bool get reducedMotion;

  /// Starts [playback].
  void play(AnimationPlayback playback);

  /// Stops at [t] (0 to 1).
  void seek(double t);
}

/// Flutter's `AnimationController`: a value from [lowerBound] to
/// [upperBound] that plays over [duration].
///
/// Declare it as a field of a `ThorState` and control it from the state's
/// methods; the `*Transition` widgets it drives compile to keyframes on the
/// server and the engine plays them:
///
/// ```dart
/// class CardState extends ThorState {
///   final reveal = AnimationController(duration: const Duration(milliseconds: 300));
///
///   void show() => reveal.forward();
///   void hide() => reveal.reverse();
/// }
/// ```
///
/// A controller that is not in a `ThorState` and is already playing when
/// the page renders (`AnimationController(duration: …)..forward()`) becomes
/// a CSS animation: an entrance or a loop with no JavaScript.
///
/// web: there is no `vsync` (the browser owns the frame clock), and the
/// methods return nothing instead of a `TickerFuture`: use
/// [addStatusListener] to act when it ends.
class AnimationController extends Animation<double> implements ThorController {
  /// Creates a controller at [value] (default [lowerBound]).
  ///
  /// Throws an [ArgumentError] for a negative [duration] or
  /// [reverseDuration], bounds that are not finite or not increasing, or a
  /// [value] that is not a finite number.
  AnimationController({
    double? value,
    Duration? duration,
    Duration? reverseDuration,
    this.debugLabel,
    this.lowerBound = 0.0,
    this.upperBound = 1.0,
  }) : _duration = _checkDuration(duration, 'duration'),
       _reverseDuration = _checkDuration(reverseDuration, 'reverseDuration'),
       _value = Signal(lowerBound),
       _status = Signal(AnimationStatus.dismissed),
       viewRange = null,
       visibleRange = null {
    if (!lowerBound.isFinite ||
        !upperBound.isFinite ||
        !(lowerBound < upperBound)) {
      throw ArgumentError(
        'AnimationController: lowerBound ($lowerBound) must be less than '
        'upperBound ($upperBound), and both finite.',
      );
    }
    if (value != null) {
      if (!value.isFinite) {
        throw ArgumentError.value(value, 'value', 'must be a finite number');
      }
      _value.value = _clamp(value);
      _status.value = _statusAt(_value.peek());
    }
  }

  /// A controller that runs as its element scrolls through [range] of
  /// the viewport instead of over time: an element that appears as it
  /// comes into view, with no JavaScript (a CSS view timeline).
  ///
  /// Each element it animates follows its own position. Where the browser
  /// has no view timelines, with reduced motion, and on the server's first
  /// paint, the element shows at the upper bound: it never stays hidden.
  ///
  /// ```dart
  /// FadeTransition(opacity: AnimationController.inView(), child: card)
  /// ```
  ///
  /// It has no duration: [forward], [reverse], [repeat] and [toggle] throw
  /// a [StateError]. It can't be a field of a `ThorState` (the scroll, not
  /// the state, moves it).
  AnimationController.inView({
    ViewRange range = ViewRange.entry,
    this.debugLabel,
  }) : viewRange = range,
       lowerBound = 0.0,
       upperBound = 1.0,
       _duration = null,
       _reverseDuration = null,
       _value = Signal(0.0),
       _status = Signal(AnimationStatus.dismissed),
       visibleRange = null;

  /// A controller that plays forward over [duration], once, when its
  /// element becomes visible: an entrance for what is below the first
  /// screen, with no JavaScript (a CSS scroll trigger). [range] is the
  /// stretch of the element's pass through the viewport where it counts as
  /// visible (by default, from 30% into its entry until it has left).
  ///
  /// Like `AnimationController(duration: …)..forward()`, but it waits to be
  /// seen: it plays at its own pace, not the scroll's, and does not reverse.
  /// Each element it animates waits for itself. Where the browser has no
  /// scroll triggers it plays when the page loads, like `..forward()`; with
  /// reduced motion or when printing it shows the end.
  ///
  /// ```dart
  /// final visible = AnimationController.onVisible(
  ///   duration: const Duration(milliseconds: 700),
  /// );
  /// FadeTransition(opacity: visible, child: card)
  /// ```
  factory AnimationController.onVisible({
    required Duration duration,
    ViewRange range = const ViewRange.span(
      ViewPhase.entry,
      0.3,
      ViewPhase.exit,
      1,
    ),
    String? debugLabel,
  }) => AnimationController._visible(duration, range, debugLabel)..forward();

  AnimationController._visible(
    Duration duration,
    ViewRange this.visibleRange,
    this.debugLabel,
  ) : viewRange = null,
      lowerBound = 0.0,
      upperBound = 1.0,
      _duration = _checkDuration(duration, 'duration'),
      _reverseDuration = null,
      _value = Signal(0.0),
      _status = Signal(AnimationStatus.dismissed);

  /// A label for debugging (`toString`).
  final String? debugLabel;

  /// With [AnimationController.inView], the stretch of scrolling it runs
  /// over; null for a controller that runs over time.
  final ViewRange? viewRange;

  /// With [AnimationController.onVisible], where its element counts as
  /// visible (it plays when it gets there); null otherwise.
  final ViewRange? visibleRange;

  /// The smallest [value] (dismissed).
  final double lowerBound;

  /// The largest [value] (completed).
  final double upperBound;

  Duration? _duration;
  Duration? _reverseDuration;

  /// How long a full pass forward takes. Required before [forward],
  /// [repeat] or [toggle].
  Duration? get duration => _duration;
  set duration(Duration? value) =>
      _duration = _checkDuration(value, 'duration');

  /// How long a full pass backward takes (default [duration]).
  Duration? get reverseDuration => _reverseDuration;
  set reverseDuration(Duration? value) =>
      _reverseDuration = _checkDuration(value, 'reverseDuration');

  // Signals: per request on the server (`SignalScope`), reactive in the
  // page (a `Watch` of a method that reads the status updates).
  final Signal<double> _value;
  final Signal<AnimationStatus> _status;
  final Signal<AnimationPlayback?> _playback = Signal(null);
  bool _forward = true;
  bool _disposed = false;
  AnimationDriver? _driver;
  final List<AnimationStatusListener> _listeners = [];
  // The futures of animateTo / animateBack / fling still playing.
  final List<Completer<void>> _pending = [];

  /// The current value: from the page's animation while one is attached,
  /// else the last value set.
  @override
  double get value {
    final driver = _driver;
    return driver == null ? _value.value : _fromT(driver.progress);
  }

  /// Stops the animation and jumps to [newValue] (clamped to the bounds).
  set value(double newValue) {
    _alive('value=');
    if (!newValue.isFinite) {
      throw ArgumentError.value(newValue, 'value', 'must be a finite number');
    }
    final v = _clamp(newValue);
    batch(() {
      _halt();
      _value.value = v;
      _driver?.seek(_toT(v));
      _setStatus(_statusAt(v));
    });
  }

  @override
  AnimationStatus get status => _status.value;

  /// How it is playing now, or null when it is stopped. The server writes
  /// it as a CSS animation; the page's engine runs it.
  AnimationPlayback? get playback => _playback.value;

  @override
  bool get isAnimating => _playback.value != null;

  @override
  void addStatusListener(AnimationStatusListener listener) =>
      _listeners.add(listener);

  @override
  void removeStatusListener(AnimationStatusListener listener) =>
      _listeners.remove(listener);

  /// Plays towards [upperBound] (from [from], if given) over the rest of
  /// [duration]. At the end the status is `completed`.
  ///
  /// Throws a [StateError] if [duration] is null.
  void forward({double? from}) {
    _alive('forward');
    _needTime('forward');
    final d = _need(_duration, 'forward');
    _forward = true;
    batch(() {
      if (from != null) value = from;
      _animateTo(upperBound, d);
    });
  }

  /// Plays towards [lowerBound] (from [from], if given) over the rest of
  /// [reverseDuration] (or [duration]). At the end the status is
  /// `dismissed`; at the lower bound already, nothing plays.
  ///
  /// Throws a [StateError] if neither duration is set.
  void reverse({double? from}) {
    _alive('reverse');
    _needTime('reverse');
    final d = _need(_reverseDuration ?? _duration, 'reverse');
    _forward = false;
    batch(() {
      if (from != null) value = from;
      _animateTo(lowerBound, d);
    });
  }

  /// Plays to [target] (clamped to the bounds) over [duration] (this move's
  /// time; by default the rest of the range at [duration]'s pace) and
  /// completes when it gets there, or when something else moves the
  /// controller (another call, a value, [stop], [dispose]).
  ///
  /// Like Flutter's, the status runs `forward` and ends `completed`, even
  /// when [target] is below the value.
  ///
  /// [curve] (any `Curve`; the engine doesn't depend on `thor_style`, it
  /// uses the curve's `css`) shapes the value between where it is and
  /// [target], clamped to the bounds (an overshooting curve stops at them),
  /// as in Flutter; the `*Transition` widgets add their own curves on top.
  /// The browser evaluates it (a CSS `cubic-bezier()` or `linear()` easing).
  ///
  /// `// web:` a Flutter future that is cancelled never completes; this one
  /// does (when something else moves the controller).
  ///
  /// Throws a [StateError] without a [duration] (here or in the
  /// constructor), on a disposed controller or on
  /// `AnimationController.inView`.
  Future<void> animateTo(double target, {Duration? duration, Object? curve}) =>
      _animateToward(
        'animateTo',
        target,
        duration,
        _duration,
        true,
        easing: cssEasingOf(curve),
        curveFn: transformOf(curve),
      );

  /// Plays to [target] (clamped to the bounds) backwards over [duration]
  /// (by default [reverseDuration] or [duration]); like [animateTo] but the
  /// status runs `reverse` and ends `dismissed` (Flutter's).
  Future<void> animateBack(
    double target, {
    Duration? duration,
    Object? curve,
  }) => _animateToward(
    'animateBack',
    target,
    duration,
    _reverseDuration ?? _duration,
    false,
    easing: cssEasingOf(curve),
    curveFn: transformOf(curve),
  );

  /// Runs to the upper bound, or to the lower one with a negative
  /// [velocity] (Flutter's `fling`).
  ///
  /// [velocity] is in value units per second towards the bound it runs to
  /// (its sign picks the bound). It needs no [duration].
  ///
  /// `// web:` Flutter drives it with a spring simulation (critically
  /// damped, stiffness 500, like Flutter's); the browser has no springs, so
  /// the same spring is sampled once into a CSS `linear()` easing and the
  /// browser plays that, over the time the spring takes to arrive.
  Future<void> fling({double velocity = 1.0}) {
    if (!velocity.isFinite) {
      throw ArgumentError.value(velocity, 'velocity', 'must be finite');
    }
    return _animateToward(
      'fling',
      velocity < 0 ? lowerBound : upperBound,
      null,
      null,
      velocity >= 0,
      velocity: velocity.abs(),
    );
  }

  Future<void> _animateToward(
    String method,
    double target,
    Duration? explicit,
    Duration? fallback,
    bool forward, {
    String? easing,
    double Function(double)? curveFn,
    double? velocity,
  }) {
    _alive(method);
    _needTime(method);
    if (!target.isFinite) {
      throw ArgumentError.value(target, 'target', 'must be a finite number');
    }
    // A fling takes the time its spring takes (below); the others a duration.
    final base = velocity != null
        ? Duration.zero
        : explicit ?? _need(fallback, method);
    final t = _clamp(target);
    _forward = forward;
    final completer = Completer<void>();
    batch(() {
      final v = value;
      _halt();
      final fraction = (t - v).abs() / (upperBound - lowerBound);
      var curve = easing;
      var curveFunction = curveFn;
      var move = explicit == null ? base * fraction : base;
      if (velocity != null && fraction != 0) {
        // The spring of Flutter's fling, as the browser can play it.
        (move, curve, curveFunction) = _flingSpring((t - v).abs(), velocity);
      }
      // An explicit duration is this move's; a default one is a full pass's.
      if (fraction == 0 || move == Duration.zero) {
        _jump(t, finished: true);
        return;
      }
      final sweep = explicit == null && velocity == null
          ? base
          : Duration(microseconds: (move.inMicroseconds / fraction).round());
      final atBound = t == lowerBound || t == upperBound;
      _start(
        AnimationPlayback(
          from: _toT(v),
          sweep: sweep,
          reverse: t < v,
          to: atBound ? null : _toT(t),
          easing: curve,
          curve: curve == null ? null : curveFunction,
        ),
        forward ? AnimationStatus.forward : AnimationStatus.reverse,
      );
      // Reduced motion jumps inside `_start`, and with no page nothing
      // tells when it ends.
      if (_playback.peek() != null && _driver != null) {
        _pending.add(completer);
      }
    });
    if (!_pending.contains(completer)) completer.complete();
    return completer.future;
  }

  /// [reverse] when running forward or completed, else [forward].
  void toggle({double? from}) =>
      status.isForwardOrCompleted ? reverse(from: from) : forward(from: from);

  /// Plays from the current value to [upperBound] and starts over, forever
  /// or [count] passes; with [reverse], every other pass runs backwards.
  /// [period] is one pass (default [duration]).
  ///
  /// [min] and [max] (default the bounds) make it loop over that stretch
  /// only, [period] being one pass of it; it starts from the current value
  /// clamped into the stretch, like Flutter's.
  ///
  /// web: the status stays `forward` while it repeats (the browser reports
  /// no pass boundaries).
  ///
  /// Throws a [StateError] without a period, an [ArgumentError] for a
  /// [count] below 1 or a negative [period]. A [min] and [max] that are not
  /// within the bounds in that order fail an assert (Flutter's too), and
  /// are clamped in a release build.
  void repeat({
    double? min,
    double? max,
    bool reverse = false,
    Duration? period,
    int? count,
  }) {
    _alive('repeat');
    _needTime('repeat');
    final p = _need(_checkDuration(period, 'period') ?? _duration, 'repeat');
    if (count != null && count < 1) {
      throw ArgumentError.value(count, 'count', 'must be at least 1');
    }
    final lo = min ?? lowerBound, hi = max ?? upperBound;
    assert(
      lo >= lowerBound && hi <= upperBound && lo <= hi,
      'repeat: lowerBound <= min <= max <= upperBound',
    );
    batch(() {
      _halt();
      if (p == Duration.zero) return;
      _forward = true;
      _start(
        AnimationPlayback(
          from: _toT(value),
          sweep: p,
          iterations: count?.toDouble() ?? double.infinity,
          alternate: reverse,
          min: _toT(lo),
          max: _toT(hi),
        ),
        AnimationStatus.forward,
      );
    });
  }

  /// Stops where it is. The status doesn't change (like Flutter).
  void stop({bool canceled = true}) {
    if (_playback.peek() == null) return;
    final v = value;
    batch(() {
      _halt();
      _value.value = v;
    });
    _driver?.seek(_toT(v));
  }

  /// Stops and jumps to [lowerBound].
  void reset() => value = lowerBound;

  /// Stops and forgets the status listeners.
  ///
  /// Like Flutter's, using it afterwards (`forward`, `reverse`, `repeat`, a
  /// `value` write) throws a [StateError]: there is no driver to play it.
  void dispose() {
    stop();
    _disposed = true;
    _listeners.clear();
    _driver = null;
  }

  /// Engine only: attaches the page's [driver]. With [from] (the value the
  /// server rendered, or the progress of its CSS animation) the controller
  /// takes it first: the page wins over the code's initial value.
  void attachDriver(AnimationDriver driver, {double? from}) => batch(() {
    _driver = driver;
    if (from != null && from.isFinite) _value.value = _clamp(from);
    final v = _value.peek();
    final playing = _playback.peek();
    if (playing == null) {
      driver.seek(_toT(v));
      if (from != null) _setStatus(_statusAt(v));
      return;
    }
    // An eased move that was running in the server's CSS: `from` is where
    // its pass is (not the value), the same move goes on from there.
    final resumed = playing.easing != null && from != null;
    if (resumed) {
      final q = _toT(from);
      _value.value = _fromT(playing.valueAt(q));
    }
    // A loop over a stretch the server ran: `from` is where its pass is.
    if (!resumed && playing.windowed && from != null) {
      _value.value = _fromT(
        playing.min + _toT(from) * (playing.max - playing.min),
      );
    }
    final next = resumed
        ? AnimationPlayback(
            from: playing.from,
            sweep: playing.sweep,
            reverse: playing.reverse,
            iterations: playing.iterations,
            alternate: playing.alternate,
            to: playing.to,
            easing: playing.easing,
            curve: playing.curve,
            min: playing.min,
            max: playing.max,
            at: _toT(from),
          )
        : AnimationPlayback(
            from: _toT(_value.peek()),
            sweep: playing.sweep,
            reverse: playing.reverse,
            iterations: playing.iterations,
            alternate: playing.alternate,
            to: playing.to,
            easing: playing.easing,
            curve: playing.curve,
            min: playing.min,
            max: playing.max,
          );
    _playback.value = null;
    _start(next, _status.peek());
  });

  /// Engine only: the page's animation reached its end.
  void driverFinished() {
    final driver = _driver;
    if (driver == null || _playback.peek() == null) return;
    final partial = _playback.peek()!.to != null;
    final v = _fromT(driver.progress);
    batch(() {
      _playback.value = null;
      _value.value = v;
      _setStatus(
        partial
            ? _finalStatus
            : v >= upperBound
            ? AnimationStatus.completed
            : _statusAt(v),
      );
    });
    _finishFutures();
  }

  void _animateTo(double target, Duration sweep) {
    final v = value;
    _halt();
    if (sweep == Duration.zero || v == target) {
      _jump(target);
      return;
    }
    _start(
      AnimationPlayback(
        from: _toT(v),
        sweep: sweep,
        reverse: target == lowerBound,
      ),
      target == upperBound ? AnimationStatus.forward : AnimationStatus.reverse,
    );
  }

  void _start(AnimationPlayback p, AnimationStatus status) {
    final driver = _driver;
    if (driver != null && driver.reducedMotion) {
      // Reduced motion: nothing moves; it jumps to where the playback
      // rests (a loop, to the upper bound), like the CSS animation does.
      if (p.to != null) {
        _jump(_lowerPlus(p.to!), finished: true);
      } else {
        _jump(
          p.reverse
              ? lowerBound
              : (p.windowed ? _lowerPlus(p.max) : upperBound),
        );
      }
      return;
    }
    _playback.value = p;
    // The driver starts before any listener hears of it (Flutter notifies
    // after the ticker starts): a listener that stops, reverses or throws
    // finds controller and driver together.
    final changed = _setStatusQuiet(status);
    driver?.play(p);
    if (changed) _notify(status);
  }

  /// Stops and jumps to [target]; with [finished] the status is the one a
  /// finished `animateTo`/`animateBack` has (completed when the call ran
  /// forwards, dismissed backwards), wherever it landed.
  void _jump(double target, {bool finished = false}) {
    _halt();
    _value.value = target;
    _driver?.seek(_toT(target));
    _setStatus(finished ? _finalStatus : _statusAt(target));
  }

  AnimationStatus get _finalStatus =>
      _forward ? AnimationStatus.completed : AnimationStatus.dismissed;

  void _halt() {
    _playback.value = null;
    _finishFutures();
  }

  void _finishFutures() {
    if (_pending.isEmpty) return;
    final done = List.of(_pending);
    _pending.clear();
    for (final c in done) {
      c.complete();
    }
  }

  AnimationStatus _statusAt(double v) => v == lowerBound
      ? AnimationStatus.dismissed
      : v == upperBound
      ? AnimationStatus.completed
      : _forward
      ? AnimationStatus.forward
      : AnimationStatus.reverse;

  void _setStatus(AnimationStatus next) {
    if (_setStatusQuiet(next)) _notify(next);
  }

  bool _setStatusQuiet(AnimationStatus next) {
    if (_status.peek() == next) return false;
    _status.value = next;
    return true;
  }

  /// Every listener hears it: one that throws is reported (like Flutter's
  /// `notifyStatusListeners`, which uses `FlutterError.reportError`) and
  /// does not cut the others short nor the call that changed the status.
  void _notify(AnimationStatus next) {
    for (final l in List.of(_listeners)) {
      try {
        l(next);
      } catch (e, st) {
        print('AnimationController: a status listener threw: $e\n$st');
      }
    }
  }

  void _alive(String method) {
    if (_disposed) {
      throw StateError('AnimationController.$method() called after dispose()');
    }
  }

  double _lowerPlus(double t) => lowerBound + t * (upperBound - lowerBound);
  double _clamp(double v) => v.clamp(lowerBound, upperBound).toDouble();
  double _toT(double v) => (v - lowerBound) / (upperBound - lowerBound);
  double _fromT(double t) => _clamp(lowerBound + t * (upperBound - lowerBound));

  static Duration? _checkDuration(Duration? d, String name) {
    if (d != null && d.isNegative) {
      throw ArgumentError.value(d, name, 'must not be negative');
    }
    return d;
  }

  void _needTime(String method) {
    if (viewRange == null) return;
    throw StateError(
      'AnimationController.$method() on AnimationController.inView(): the '
      'scroll moves it, not time.',
    );
  }

  static Duration _need(Duration? d, String method) =>
      d ??
      (throw StateError(
        'AnimationController.$method() called with no default duration: '
        'set `duration` in the constructor or before calling it.',
      ));

  @override
  String toString() =>
      'AnimationController#${debugLabel ?? ''}'
      '(${value.toStringAsFixed(3)}; ${status.name})';
}

/// Flutter's fling spring (mass 1, stiffness 500, critically damped) for a
/// move of [distance] value units at [velocity] units/s towards its target,
/// which Flutter puts 0.01 past the bound so the controller reaches it: the
/// time it takes until it gets there, and its progress sampled into a CSS
/// `linear()` easing over that time (0 to 1).
(Duration, String, double Function(double)) _flingSpring(
  double distance,
  double velocity,
) {
  const omega = 22.360679774997898; // sqrt(stiffness / mass)
  const tolerance = 0.01;
  final start = distance + tolerance; // what is left to the shifted target
  final b = omega * start - velocity;
  double left(double t) => (start + b * t) * math.exp(-omega * t);
  var ms = 1;
  while (ms < 10000 && left(ms / 1000) > tolerance) {
    ms++;
  }
  final stops = <String>[];
  const points = 32;
  for (var i = 0; i <= points; i++) {
    final p = i == points
        ? 1.0
        : ((start - left(ms / 1000 * i / points)) / distance).clamp(0.0, 1.0);
    stops.add(_n(p));
  }
  double along(double s) =>
      s >= 1 ? 1.0 : ((start - left(ms / 1000 * s)) / distance).clamp(0.0, 1.0);
  return (Duration(milliseconds: ms), 'linear(${stops.join(', ')})', along);
}

String _n(double v) {
  final s = v.toStringAsFixed(4);
  return s.contains('.') ? s.replaceFirst(RegExp(r'\.?0+$'), '') : s;
}
