/// What the motion benches share to show a curve: the graph of the curve and
/// a dot that travels it, and the timeline under it.
///
/// The graph is the curve itself, sampled on the server (`Curve.transform`)
/// and drawn as one SVG path; the dot is two elements, one that moves at a
/// constant speed along the time axis and one that moves along the value
/// axis with the curve, so together they trace the path.
library;

import 'package:thor_ui/thor_ui.dart';

import 'motion_curve.dart';

/// The curves of the curve visualizer (the benches' [MotionCurve] plus the
/// ones that show best on a graph).
enum GraphCurve {
  /// `Curves.easeOut`.
  easeOut,

  /// `Curves.easeInOut`.
  easeInOut,

  /// `Curves.easeIn`: what not to use for an interface.
  easeIn,

  /// `Curves.easeOutBack`.
  easeOutBack,

  /// `Curves.elasticOut`.
  elasticOut,

  /// `Curves.bounceOut`.
  bounceOut;

  /// The name the Code view shows.
  String get code => switch (this) {
    GraphCurve.easeOut => 'Curves.easeOut',
    GraphCurve.easeInOut => 'Curves.easeInOut',
    GraphCurve.easeIn => 'Curves.easeIn',
    GraphCurve.elasticOut => 'Curves.elasticOut',
    GraphCurve.easeOutBack => 'Curves.easeOutBack',
    GraphCurve.bounceOut => 'Curves.bounceOut',
  };
}

/// The Flutter curve of [curve].
Curve graphCurveOf(GraphCurve curve) => switch (curve) {
  GraphCurve.easeOut => Curves.easeOut,
  GraphCurve.easeInOut => Curves.easeInOut,
  GraphCurve.easeIn => Curves.easeIn,
  GraphCurve.elasticOut => Curves.elasticOut,
  GraphCurve.easeOutBack => Curves.easeOutBack,
  GraphCurve.bounceOut => Curves.bounceOut,
};

/// Side of the graph, in logical pixels.
const _side = 180.0;

/// The dot's diameter.
const _dot = 12.0;

// The path lives in a 100 × 100 box: time from 10 to 90, value 0 at 80 and
// value 1 at 24, which leaves room for what a back or an elastic curve
// overshoots.
const _x0 = 10.0;
const _x1 = 90.0;
const _y0 = 80.0;
const _y1 = 24.0;

/// How many dots of travel the time axis is (the dot moves in fractions of
/// its own size).
const _travelX = (_x1 - _x0) * _side / 100 / _dot;

/// The same for the value axis, upward.
const _travelY = (_y0 - _y1) * _side / 100 / _dot;

/// The SVG path of [curve] in the graph's box.
String curvePath(Curve curve, {int samples = 56}) {
  final out = StringBuffer();
  for (var i = 0; i <= samples; i++) {
    final t = i / samples;
    final x = _x0 + (_x1 - _x0) * t;
    final y = _y0 - (_y0 - _y1) * curve.transform(t);
    out.write(
      '${i == 0 ? 'M' : 'L'}${x.toStringAsFixed(2)} ${y.toStringAsFixed(2)}',
    );
  }
  return out.toString();
}

/// The graph of a curve with a dot that travels it, and under it a timeline
/// of the duration.
///
/// [CurveGraph.implicit] moves the dot when [atEnd] changes (a transition of
/// the browser); [CurveGraph.explicit] plays it once when the page is drawn
/// (the bench's Replay restarts it) and counts the milliseconds.
class CurveGraph extends StatelessWidget {
  /// A graph whose dot goes to the end when [atEnd] is true and back when it
  /// is false.
  const CurveGraph.implicit({
    super.key,
    required this.name,
    required this.curve,
    required this.duration,
    required bool this.atEnd,
  });

  /// A graph whose dot plays once at render.
  const CurveGraph.explicit({
    super.key,
    required this.name,
    required this.curve,
    required this.duration,
  }) : atEnd = null;

  /// A name for the path's SVG symbol, unique per curve.
  final String name;

  /// The curve drawn.
  final Curve curve;

  /// The time the dot takes.
  final Duration duration;

  /// Where the dot is, or null when it plays at render.
  final bool? atEnd;

  @override
  Widget build(BuildContext context) {
    final explicit = atEnd == null;
    final run = explicit
        ? (AnimationController(duration: duration)..forward())
        : null;
    final curved = run == null
        ? null
        : CurvedAnimation(parent: run, curve: curve);
    final shape = IconData.svg(
      'curve-$name',
      // The value-0 and value-1 lines, and the straight (linear) path.
      '<path d="M10 80H90M10 24H90" stroke-width="1" opacity=".25"/>'
          '<path d="M10 80L90 24" stroke-width="1" opacity=".4" '
          'stroke-dasharray="2 3"/>'
          '<path d="${curvePath(curve)}"/>',
      viewBox: '0 0 100 100',
      strokeWidth: 1.6,
    );
    final dot = Container(
      width: _dot,
      height: _dot,
      decoration: BoxDecoration(
        color: ThemeColor.primary,
        borderRadius: BorderRadius.circular(_dot / 2),
        boxShadow: [
          BoxShadow(
            color: ThemeColor.primary.withValues(alpha: 0.35),
            blurRadius: 8,
          ),
        ],
      ),
    );
    // Time moves at a constant speed, value follows the curve: the two
    // together draw the path.
    final Widget traveller = run == null
        ? AnimatedSlide(
            offset: Offset(atEnd! ? _travelX : 0, 0),
            duration: duration,
            child: SizedBox(
              width: _dot,
              height: _dot,
              child: AnimatedSlide(
                offset: Offset(0, atEnd! ? -_travelY : 0),
                duration: duration,
                curve: curve,
                child: dot,
              ),
            ),
          )
        : SlideTransition(
            position: Tween(
              begin: Offset.zero,
              end: const Offset(_travelX, 0),
            ).animate(run),
            child: SizedBox(
              width: _dot,
              height: _dot,
              child: SlideTransition(
                position: Tween(
                  begin: Offset.zero,
                  end: const Offset(0, -_travelY),
                ).animate(curved!),
                child: dot,
              ),
            ),
          );
    final Widget fill = run == null
        ? AnimatedSlide(
            offset: Offset(atEnd! ? 0 : -1, 0),
            duration: duration,
            child: const _TimelineFill(),
          )
        : SlideTransition(
            position: Tween(
              begin: const Offset(-1, 0),
              end: Offset.zero,
            ).animate(run),
            child: const _TimelineFill(),
          );
    return Container(
      width: _side + 32,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ThemeColor.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          SizedBox(
            width: _side,
            height: _side,
            child: Stack(
              children: [
                Icon(shape, size: _side, color: ThemeColor.onSurfaceVariant),
                Positioned(
                  left: _x0 * _side / 100 - _dot / 2,
                  top: _y0 * _side / 100 - _dot / 2,
                  child: traveller,
                ),
              ],
            ),
          ),
          // The timeline: it fills at a constant speed for as long as the
          // duration, so a longer one is a slower fill.
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: Container(
              width: _side,
              height: 4,
              color: ThemeColor.outlineVariant,
              child: fill,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SizedBox(
                width: _side,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const _Tick('0 ms'),
                    if (run != null)
                      CountTransition(
                        count: IntTween(
                          begin: 0,
                          end: duration.inMilliseconds,
                        ).animate(run),
                        suffix: ' ms',
                        style: _tickStyle,
                      )
                    else
                      _Tick('${duration.inMilliseconds} ms'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

const _tickStyle = TextStyle(
  fontSize: 12,
  color: ThemeColor.onSurfaceVariant,
  fontFeatures: [FontFeature.tabularFigures()],
);

class _Tick extends StatelessWidget {
  const _Tick(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(text, style: _tickStyle);
}

/// A timeline under a state change: its fill goes at a constant speed for as
/// long as [duration] when [atEnd] changes, so a longer duration is a slower
/// fill, and the end label is the duration in milliseconds.
class MotionTimeline extends StatelessWidget {
  /// A timeline [width] logical pixels wide.
  const MotionTimeline({
    super.key,
    required this.atEnd,
    required this.duration,
    this.width = 280,
  });

  /// Whether the fill is full (the state changed to its second value).
  final bool atEnd;

  /// How long the fill takes.
  final Duration duration;

  /// Its width.
  final double width;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    spacing: 6,
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: Container(
          width: width,
          height: 4,
          color: ThemeColor.outlineVariant,
          child: AnimatedSlide(
            offset: Offset(atEnd ? 0 : -1, 0),
            duration: duration,
            child: Container(
              width: width,
              height: 4,
              color: ThemeColor.primary,
            ),
          ),
        ),
      ),
      SizedBox(
        width: width,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const _Tick('0 ms'),
            _Tick('${duration.inMilliseconds} ms'),
          ],
        ),
      ),
    ],
  );
}

/// What a motion bench has chosen, as it sits on the stage once everything
/// has settled: a small sketch of the curve and the duration in
/// milliseconds, so a Switch or a Level that only changes how it moves still
/// changes what the stage shows.
class MotionMeta extends StatelessWidget {
  /// The meta of a bench whose state has [step] (a coarse duration step) and
  /// [curve] fields.
  const MotionMeta({super.key, required this.step, required this.curve});

  /// The state's coarse duration step.
  final StateSignal<int> step;

  /// The state's curve.
  final StateSignal<MotionCurve> curve;

  @override
  Widget build(BuildContext context) => Watch.field(
    step,
    count: coarseSteps,
    builder: (s) => Watch.field(
      curve,
      builder: (c) => Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        children: [
          Icon(
            IconData.svg(
              'curve-mini-${c.name}',
              '<path d="${curvePath(curveOf(c), samples: 24)}"/>',
              viewBox: '0 0 100 100',
              strokeWidth: 7,
            ),
            size: 28,
            color: ThemeColor.onSurfaceVariant,
          ),
          _Tick('${coarseDuration(s).inMilliseconds} ms'),
        ],
      ),
    ),
  );
}

class _TimelineFill extends StatelessWidget {
  const _TimelineFill();

  @override
  Widget build(BuildContext context) =>
      const Container(width: _side, height: 4, color: ThemeColor.primary);
}
