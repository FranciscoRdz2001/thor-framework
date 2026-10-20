/// The benches of choreography: `bench-stagger` (rows that enter one after
/// another) and `bench-repeat` (a loop between a minimum and a maximum).
///
/// Both play when the stage is drawn (an `AnimationController` that
/// already runs), so the browser plays them as CSS animations and the
/// bench's Replay button restarts them. Every control has a finite set of
/// values, so each is a `Watch.field` whose variants the server compiled.
library;

import 'package:thor_ui/thor_ui.dart';

import 'bench_example.dart';
import 'motion_curve.dart';

// ---------------------------------------------------------------------------
// Stagger
// ---------------------------------------------------------------------------

/// The delays between rows the Level offers, in ms.
const staggerDelays = [0, 30, 60, 90];

/// How many rows enter.
const _rows = 5;

/// What the stagger bench controls and the stage reads.
class StaggerViewModel extends ThorState {
  /// The delay between rows, as an index of [staggerDelays].
  final delayStep = state(2);

  /// The duration of each row, as a step of 100 ms.
  final step = state(2);

  /// The number next to the delay Level's bar.
  String delayText() => '${staggerDelays[delayStep.value.clamp(0, 3)]} ms';

  /// The number next to the duration Level's bar.
  String durationText() => '${coarseDuration(step.value).inMilliseconds} ms';

  /// The line of the Code view that sets the delay.
  String delayCode() =>
      'const delay = ${staggerDelays[delayStep.value.clamp(0, 3)]}; // ms between rows';

  /// The line of the Code view that sets the duration.
  String durationCode() =>
      'const duration = ${coarseDuration(step.value).inMilliseconds}; // ms of each row';

  /// What the delay Level calls.
  void setDelay(double ms) => delayStep.value = (ms / 30).round().clamp(0, 3);

  /// What the duration Level calls.
  void setDuration(double ms) => step.value = coarseStepOf(ms);
}

/// One instance, at the top level: the browser boots with it.
final staggerState = StaggerViewModel();

/// The stagger example.
final staggerBench = BenchExample(
  title: (t) => t.exMotion2StaggerTitle,
  description: (t) => t.exMotion2StaggerDescription,
  replay: true,
  stage: const StaggerStage(),
  code: BenchCode([
    BenchCodeLine.live(staggerState.delayCode),
    BenchCodeLine.live(staggerState.durationCode),
    const BenchCodeLine('const rows = 5;'),
    const BenchCodeLine('const total = duration + (rows - 1) * delay;'),
    const BenchCodeLine(' '),
    const BenchCodeLine('final controller = AnimationController('),
    const BenchCodeLine('duration: Duration(milliseconds: total),', indent: 1),
    const BenchCodeLine(')..forward();'),
    const BenchCodeLine(' '),
    const BenchCodeLine('for (var i = 0; i < rows; i++)'),
    const BenchCodeLine('FadeTransition(', indent: 1),
    const BenchCodeLine('opacity: CurvedAnimation(', indent: 2),
    const BenchCodeLine('parent: controller,', indent: 3),
    const BenchCodeLine('curve: Interval(', indent: 3),
    const BenchCodeLine('i * delay / total,', indent: 4),
    const BenchCodeLine('(i * delay + duration) / total,', indent: 4),
    const BenchCodeLine('curve: Curves.easeOutQuart,', indent: 4),
    const BenchCodeLine('),', indent: 3),
    const BenchCodeLine('),', indent: 2),
    const BenchCodeLine('child: row(i),', indent: 2),
    const BenchCodeLine('),', indent: 1),
  ], appCode: true),
  controls: [
    BenchLevel(
      label: (t) => t.exMotion2Delay,
      value: staggerDelays[staggerState.delayStep.value].toDouble(),
      min: 0,
      max: 90,
      divisions: 3,
      onChanged: staggerState.setDelay,
      valueText: staggerState.delayText,
    ),
    BenchLevel(
      label: (t) => t.exMotionDuration,
      value: coarseMs(staggerState.step.value),
      min: coarseMinMs.toDouble(),
      max: coarseMaxMs.toDouble(),
      divisions: coarseSteps - 1,
      onChanged: staggerState.setDuration,
      valueText: staggerState.durationText,
    ),
  ],
);

/// The stage: five rows that enter one after another, and the timeline of
/// the whole entrance with its total in milliseconds.
class StaggerStage extends StatelessWidget {
  /// The stage of the example.
  const StaggerStage({super.key});

  @override
  Widget build(BuildContext context) => Watch.field(
    staggerState.step,
    count: coarseSteps,
    builder: (step) => Watch.field(
      staggerState.delayStep,
      count: staggerDelays.length,
      builder: (delayStep) {
        final delay = staggerDelays[delayStep];
        final duration = coarseDuration(step).inMilliseconds;
        final total = duration + (_rows - 1) * delay;
        final run = AnimationController(duration: Duration(milliseconds: total))
          ..forward();
        const titles = [
          'Order received',
          'Payment confirmed',
          'Preparing',
          'On the way',
          'Delivered',
        ];
        return SizedBox(
          width: 280,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 14,
            children: [
              Column(
                spacing: 8,
                children: [
                  for (var i = 0; i < _rows; i++)
                    _Entering(
                      animation: CurvedAnimation(
                        parent: run,
                        curve: Interval(
                          i * delay / total,
                          (i * delay + duration) / total,
                          curve: Curves.easeOutQuart,
                        ),
                      ),
                      child: _Row(title: titles[i], tint: i),
                    ),
                ],
              ),
              _Elapsed(run: run, total: total),
            ],
          ),
        );
      },
    ),
  );
}

/// A row that fades in while it slides up, following [animation].
class _Entering extends StatelessWidget {
  const _Entering({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: animation,
    child: SlideTransition(
      position: Tween(
        begin: const Offset(0, 0.5),
        end: Offset.zero,
      ).animate(animation),
      child: child,
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row({required this.title, required this.tint});

  final String title;
  final int tint;

  @override
  Widget build(BuildContext context) => Container(
    height: 44,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: ThemeColor.surfaceContainer,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      spacing: 12,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: tint.isEven
                ? ThemeColor.primary
                : ThemeColor.onSurfaceVariant,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      ],
    ),
  );
}

/// A fill that goes at a constant speed over [total] ms and the milliseconds
/// elapsed.
class _Elapsed extends StatelessWidget {
  const _Elapsed({required this.run, required this.total});

  final AnimationController run;
  final int total;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: 6,
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: Container(
          height: 4,
          color: ThemeColor.outlineVariant,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(-1, 0),
              end: Offset.zero,
            ).animate(run),
            child: const Container(height: 4, color: ThemeColor.primary),
          ),
        ),
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Total',
            style: TextStyle(fontSize: 12, color: ThemeColor.onSurfaceVariant),
          ),
          CountTransition(
            count: IntTween(begin: 0, end: total).animate(run),
            suffix: ' ms',
            style: const TextStyle(
              fontSize: 12,
              color: ThemeColor.onSurfaceVariant,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// Repeat between a minimum and a maximum
// ---------------------------------------------------------------------------

/// The minimums and maximums of the loop's window, in percent.
const repeatMins = [0, 25, 50];

/// See [repeatMins].
const repeatMaxes = [75, 100];

/// The periods of the loop the Level offers, in ms.
const repeatPeriods = [600, 1000, 1400];

/// What the repeat bench controls and the stage reads.
class RepeatViewModel extends ThorState {
  /// The minimum, as an index of [repeatMins].
  final minStep = state(1);

  /// The maximum, as an index of [repeatMaxes].
  final maxStep = state(1);

  /// Whether the loop goes back (`reverse: true`).
  final reverse = state(true);

  /// The period, as an index of [repeatPeriods].
  final periodStep = state(1);

  /// The number next to the minimum Level's bar.
  String minText() => '${repeatMins[minStep.value.clamp(0, 2)]} %';

  /// The number next to the maximum Level's bar.
  String maxText() => '${repeatMaxes[maxStep.value.clamp(0, 1)]} %';

  /// The number next to the period Level's bar.
  String periodText() => '${repeatPeriods[periodStep.value.clamp(0, 2)]} ms';

  /// The `repeat` line of the Code view.
  String repeatCode() =>
      'controller.repeat(min: ${repeatMins[minStep.value.clamp(0, 2)] / 100}, '
      'max: ${repeatMaxes[maxStep.value.clamp(0, 1)] / 100}, '
      'reverse: ${reverse.value});';

  /// The `period` line of the Code view.
  String periodCode() =>
      'duration: Duration(milliseconds: ${repeatPeriods[periodStep.value.clamp(0, 2)]}),';

  /// What the minimum Level calls.
  void setMin(double percent) {
    minStep.value = (percent / 25).round().clamp(0, 2);
  }

  /// What the maximum Level calls.
  void setMax(double percent) {
    maxStep.value = ((percent - 75) / 25).round().clamp(0, 1);
  }

  /// What the period Level calls.
  void setPeriod(double ms) =>
      periodStep.value = ms <= 800 ? 0 : (ms <= 1200 ? 1 : 2);

  /// What the reverse Switch calls.
  void setReverse(Set<bool> value) => reverse.value = value.first;
}

/// One instance, at the top level: the browser boots with it.
final repeatState = RepeatViewModel();

/// The repeat example.
final repeatBench = BenchExample(
  title: (t) => t.exMotion2RepeatTitle,
  description: (t) => t.exMotion2RepeatDescription,
  replay: true,
  stage: const RepeatStage(),
  code: BenchCode([
    const BenchCodeLine('final controller = AnimationController('),
    BenchCodeLine.live(repeatState.periodCode, indent: 1),
    BenchCodeLine.live(repeatState.repeatCode),
    const BenchCodeLine(' '),
    const BenchCodeLine('FadeTransition('),
    const BenchCodeLine('opacity: controller,', indent: 1),
    const BenchCodeLine('child: dot,', indent: 1),
    const BenchCodeLine(')'),
  ], appCode: true),
  controls: [
    BenchSwitch<bool>(
      label: (t) => t.exMotion2Reverse,
      value: repeatState.reverse.value,
      onChanged: repeatState.setReverse,
      segments: [
        BenchSegment(true, label: (t) => t.exMotion2ReverseBack),
        BenchSegment(false, label: (t) => t.exMotion2ReverseJump),
      ],
    ),
    BenchLevel(
      label: (t) => t.exMotion2Min,
      value: repeatMins[repeatState.minStep.value].toDouble(),
      min: 0,
      max: 50,
      divisions: 2,
      onChanged: repeatState.setMin,
      valueText: repeatState.minText,
    ),
    BenchLevel(
      label: (t) => t.exMotion2Max,
      value: repeatMaxes[repeatState.maxStep.value].toDouble(),
      min: 75,
      max: 100,
      divisions: 1,
      onChanged: repeatState.setMax,
      valueText: repeatState.maxText,
    ),
    BenchLevel(
      label: (t) => t.exMotion2Period,
      value: repeatPeriods[repeatState.periodStep.value].toDouble(),
      min: 600,
      max: 1400,
      divisions: 2,
      onChanged: repeatState.setPeriod,
      valueText: repeatState.periodText,
    ),
  ],
);

/// The stage: a gauge with the loop's window marked and a dot that travels it,
/// and the pulse the same controller draws.
class RepeatStage extends StatelessWidget {
  /// The stage of the example.
  const RepeatStage({super.key});

  @override
  Widget build(BuildContext context) => Watch.field(
    repeatState.minStep,
    count: 3,
    builder: (minStep) => Watch.field(
      repeatState.maxStep,
      count: 2,
      builder: (maxStep) => Watch.field(
        repeatState.reverse,
        builder: (reverse) => Watch.field(
          repeatState.periodStep,
          count: 3,
          builder: (periodStep) {
            final min = repeatMins[minStep] / 100;
            final max = repeatMaxes[maxStep] / 100;
            final run = AnimationController(
              duration: Duration(milliseconds: repeatPeriods[periodStep]),
            )..repeat(min: min, max: max, reverse: reverse);
            return _Gauge(run: run, min: min, max: max);
          },
        ),
      ),
    ),
  );
}

class _Gauge extends StatelessWidget {
  const _Gauge({required this.run, required this.min, required this.max});

  final AnimationController run;
  final double min;
  final double max;

  // The gauge is 240 wide and its dot 16: 224 px of travel are 14 dots.
  static const _width = 240.0;
  static const _dot = 16.0;
  static const _travel = (_width - _dot) / _dot;

  @override
  Widget build(BuildContext context) => Container(
    width: 280,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: ThemeColor.surfaceContainer,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 20,
      children: [
        FadeTransition(
          opacity: run,
          child: ScaleTransition(
            scale: Tween(begin: 0.6, end: 1.0).animate(run),
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: ThemeColor.primary,
                borderRadius: BorderRadius.circular(32),
              ),
            ),
          ),
        ),
        SizedBox(
          width: _width,
          height: _dot,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              const Container(height: 2, color: ThemeColor.outlineVariant),
              // The window the loop stays in.
              Positioned(
                left: min * (_width - _dot) + _dot / 2,
                width: (max - min) * (_width - _dot),
                top: 5,
                height: 6,
                child: Container(
                  decoration: BoxDecoration(
                    color: ThemeColor.primary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              SlideTransition(
                position: Tween(
                  begin: Offset.zero,
                  end: const Offset(_travel, 0),
                ).animate(run),
                child: Container(
                  width: _dot,
                  height: _dot,
                  decoration: BoxDecoration(
                    color: ThemeColor.primary,
                    borderRadius: BorderRadius.circular(_dot / 2),
                    border: Border.all(
                      color: ThemeColor.surfaceContainer,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
