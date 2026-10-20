/// What the motion benches share: the curves their Switch offers and the
/// steps of their duration Level.
library;

import 'package:thor_ui/thor_ui.dart';

import 'bench_example.dart';

/// The curves of the motion benches' Switch (the state keeps its own enum:
/// the browser cannot use Flutter's `Curve`).
enum MotionCurve {
  /// `Curves.easeOut`: the default for entrances.
  easeOut,

  /// `Curves.easeInOut`: for what moves across the screen.
  easeInOut,

  /// `Curves.linear`: constant motion.
  linear,

  /// `Curves.easeOutBack`: a small overshoot.
  back;

  /// The `Curves` constant's name, the segment's label.
  String get label => switch (this) {
    MotionCurve.easeOut => 'easeOut',
    MotionCurve.easeInOut => 'easeInOut',
    MotionCurve.linear => 'linear',
    MotionCurve.back => 'easeOutBack',
  };

  /// The name the Code view shows.
  String get code => switch (this) {
    MotionCurve.easeOut => 'Curves.easeOut',
    MotionCurve.easeInOut => 'Curves.easeInOut',
    MotionCurve.linear => 'Curves.linear',
    MotionCurve.back => 'Curves.easeOutBack',
  };
}

/// The Flutter curve of [curve]. A function of its own: the enum is read by
/// the states, which run in the browser, where a `Curve` cannot go.
Curve curveOf(MotionCurve curve) => switch (curve) {
  MotionCurve.easeOut => Curves.easeOut,
  MotionCurve.easeInOut => Curves.easeInOut,
  MotionCurve.linear => Curves.linear,
  MotionCurve.back => Curves.easeOutBack,
};

/// The curves of a motion bench's dropdown, named by their `Curves`
/// constants.
List<BenchSegment<MotionCurve>> motionCurveSegments() => [
  for (final c in MotionCurve.values) BenchSegment(c, label: (_) => c.label),
];

/// The duration Level's first value, in ms.
const motionMinMs = 100;

/// The ms between two steps of the duration Level.
const motionStepMs = 100;

/// How many values the duration takes (100 to 800 ms).
const motionSteps = 8;

/// The duration of step [step].
Duration motionDuration(int step) =>
    Duration(milliseconds: motionMinMs + step * motionStepMs);

/// The value, in ms, of a duration Level at step [step].
double motionMs(int step) => (motionMinMs + step * motionStepMs).toDouble();

/// The step of a duration Level at [ms].
int motionStepOf(double ms) =>
    ((ms - motionMinMs) / motionStepMs).round().clamp(0, motionSteps - 1);

// A coarser duration Level (150 to 600 ms in four steps) for the benches whose
// stage multiplies by several controls: every step is a variant the server
// writes into the page, so fewer steps keep the page light.

/// The coarse duration Level's first value, in ms.
const coarseMinMs = 150;

/// The ms between two steps of the coarse duration Level.
const coarseStepMs = 150;

/// How many values the coarse duration takes (150 to 600 ms).
const coarseSteps = 4;

/// The greatest value of the coarse duration Level.
const coarseMaxMs = coarseMinMs + (coarseSteps - 1) * coarseStepMs;

/// The duration of coarse step [step].
Duration coarseDuration(int step) =>
    Duration(milliseconds: coarseMinMs + step * coarseStepMs);

/// The value, in ms, of a coarse duration Level at step [step].
double coarseMs(int step) => (coarseMinMs + step * coarseStepMs).toDouble();

/// The coarse step of a duration Level at [ms].
int coarseStepOf(double ms) =>
    ((ms - coarseMinMs) / coarseStepMs).round().clamp(0, coarseSteps - 1);
