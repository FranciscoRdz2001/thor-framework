/// `:::bench bench-tween`: a `TweenAnimationBuilder`. A Level sets where the
/// tween ends and another how long it takes; the dot lifts and fades toward
/// the new end.
///
/// The builder runs on the server once per state, with the tween's final
/// value; the element it returns transitions from the previous state.
library;

import 'package:thor_ui/thor_ui.dart';

import 'bench_example.dart';
import 'motion_curve.dart';

/// How many values the tween's end takes (0, .25, .5, .75 and 1).
const _ends = 5;

/// What the panel controls and the stage reads.
class TweenViewModel extends ThorState {
  /// Where the tween ends, in quarters.
  final end = state(0);

  /// The duration, as a step of 100 ms.
  final step = state(2);

  /// The `end` of the tween, as text.
  String endText() => (end.value / (_ends - 1)).toStringAsFixed(2);

  /// The number next to the duration Level's bar.
  String durationText() => '${motionDuration(step.value).inMilliseconds} ms';

  /// The `tween` line of the Code view.
  String endCode() => 'tween: Tween(end: ${endText()}),';

  /// The `duration` line of the Code view.
  String durationCode() =>
      'duration: Duration(milliseconds: ${motionDuration(step.value).inMilliseconds}),';

  /// What the end Level calls.
  void setEnd(double value) => end.value = value.round();

  /// What the duration Level calls.
  void setDuration(double ms) => step.value = motionStepOf(ms);
}

/// One instance, at the top level: the browser boots with it.
final tween = TweenViewModel();

/// The example: two Levels, the stage and its code.
final tweenBench = BenchExample(
  title: (t) => t.exMotionTweenTitle,
  description: (t) => t.exMotionTweenDescription,
  stage: const TweenStage(),
  code: BenchCode([
    const BenchCodeLine('TweenAnimationBuilder<double>('),
    BenchCodeLine.live(tween.endCode, indent: 1),
    BenchCodeLine.live(tween.durationCode, indent: 1),
    const BenchCodeLine('curve: Curves.easeOutQuart,', indent: 1),
    const BenchCodeLine('builder: (context, v, child) => Opacity(', indent: 1),
    const BenchCodeLine('opacity: 1 - 0.6 * v,', indent: 2),
    const BenchCodeLine('child: Transform.translate(', indent: 2),
    const BenchCodeLine('offset: Offset(260 * v, 0),', indent: 3),
    const BenchCodeLine('child: child!,', indent: 3),
    const BenchCodeLine('),', indent: 2),
    const BenchCodeLine('),', indent: 1),
    const BenchCodeLine('child: dot,', indent: 1),
    const BenchCodeLine(')'),
  ], appCode: true),
  controls: [
    BenchLevel(
      label: (t) => t.exMotionTweenEnd,
      value: tween.end.value,
      max: (_ends - 1).toDouble(),
      divisions: _ends - 1,
      onChanged: tween.setEnd,
      valueText: tween.endText,
    ),
    BenchLevel(
      label: (t) => t.exMotionDuration,
      value: motionMs(tween.step.value),
      min: motionMinMs.toDouble(),
      max: (motionMinMs + (motionSteps - 1) * motionStepMs).toDouble(),
      divisions: motionSteps - 1,
      onChanged: tween.setDuration,
      valueText: tween.durationText,
    ),
  ],
);

/// The stage: a track and the dot the tween moves.
class TweenStage extends StatelessWidget {
  /// The stage of the example.
  const TweenStage({super.key});

  @override
  Widget build(BuildContext context) => Watch.field(
    tween.step,
    count: motionSteps,
    builder: (step) => Watch.field(
      tween.end,
      count: _ends,
      builder: (end) => Container(
        width: 340,
        height: 96,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: ThemeColor.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            // A mark for each value the Level offers: where the dot can end.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var i = 0; i < _ends; i++)
                  const Container(
                    width: 2,
                    height: 80,
                    color: ThemeColor.outlineVariant,
                  ),
              ],
            ),
            TweenAnimationBuilder<double>(
              tween: Tween(end: end / (_ends - 1)),
              duration: motionDuration(step),
              curve: Curves.easeOutQuart,
              builder: (context, v, child) => Opacity(
                opacity: 1 - 0.6 * v,
                child: Transform.translate(
                  offset: Offset(260 * v, 0),
                  child: child!,
                ),
              ),
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: ThemeColor.primary,
                  borderRadius: BorderRadius.circular(32),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
