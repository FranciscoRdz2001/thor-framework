/// `:::bench bench-implicit`: an implicit animation. A Switch moves the box
/// between two places, a second one picks the curve and a Level the duration.
///
/// The three values are finite, so each is a `Watch.field` whose variants the
/// server compiled; the one that flips the position is the innermost, so the
/// browser swaps a class on the same element and the CSS transition runs.
library;

import 'package:thor_ui/thor_ui.dart';

import 'bench_example.dart';
import 'motion_curve.dart';
import 'motion_graph.dart';

/// Where the box is.
enum BoxPlace {
  /// At the start of the track.
  start,

  /// At the end of the track.
  end,
}

/// What the panel controls and the stage reads.
class ImplicitViewModel extends ThorState {
  /// Where the box is.
  final place = state(BoxPlace.start);

  /// The curve of the transition.
  final curve = state(MotionCurve.easeOut);

  /// The duration, as a step of 100 ms.
  final step = state(1);

  /// The number next to the duration Level's bar.
  String durationText() => '${coarseDuration(step.value).inMilliseconds} ms';

  /// The `duration` line of the Code view.
  String durationCode() =>
      'duration: Duration(milliseconds: ${coarseDuration(step.value).inMilliseconds}),';

  /// The `curve` line of the Code view.
  String curveCode() => 'curve: ${curve.value.code},';

  /// The `transform` line of the Code view.
  String placeCode() => place.value == BoxPlace.end
      ? 'transform: Matrix4.translationValues(184, 0, 0),'
      : 'transform: Matrix4.identity(),';

  /// What the place Switch calls.
  void setPlace(Set<BoxPlace> value) => place.value = value.first;

  /// What the curve Switch calls.
  void setCurve(MotionCurve? value) =>
      curve.value = value ?? MotionCurve.easeOut;

  /// What the duration Level calls.
  void setDuration(double ms) => step.value = coarseStepOf(ms);
}

/// One instance, at the top level: the browser boots with it.
final implicit = ImplicitViewModel();

/// The example: two Switches, a Level, the stage and its code.
final implicitBench = BenchExample(
  title: (t) => t.exMotionImplicitTitle,
  description: (t) => t.exMotionImplicitDescription,
  stage: const ImplicitStage(),
  code: BenchCode([
    const BenchCodeLine('AnimatedContainer('),
    BenchCodeLine.live(implicit.durationCode, indent: 1),
    BenchCodeLine.live(implicit.curveCode, indent: 1),
    BenchCodeLine.live(implicit.placeCode, indent: 1),
    const BenchCodeLine('width: 48,', indent: 1),
    const BenchCodeLine('height: 48,', indent: 1),
    const BenchCodeLine(')'),
  ]),
  controls: [
    BenchSwitch<BoxPlace>(
      label: (t) => t.exMotionPlace,
      value: implicit.place.value,
      onChanged: implicit.setPlace,
      segments: [
        BenchSegment(BoxPlace.start, label: (t) => t.exMotionPlaceStart),
        BenchSegment(BoxPlace.end, label: (t) => t.exMotionPlaceEnd),
      ],
    ),
    BenchDropdown<MotionCurve>(
      label: (t) => t.exMotionCurve,
      value: implicit.curve.value,
      onChanged: implicit.setCurve,
      code: true,
      items: motionCurveSegments(),
    ),
    BenchLevel(
      label: (t) => t.exMotionDuration,
      value: coarseMs(implicit.step.value),
      min: coarseMinMs.toDouble(),
      max: coarseMaxMs.toDouble(),
      divisions: coarseSteps - 1,
      onChanged: implicit.setDuration,
      valueText: implicit.durationText,
    ),
  ],
);

/// The stage: a track and the box that crosses it.
class ImplicitStage extends StatelessWidget {
  /// The stage of the example.
  const ImplicitStage({super.key});

  @override
  Widget build(BuildContext context) => Watch.field(
    implicit.step,
    count: coarseSteps,
    builder: (step) => Watch.field(
      implicit.curve,
      builder: (curve) => Watch.field(
        implicit.place,
        builder: (place) => Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 16,
          children: [
            _Track(
              duration: coarseDuration(step),
              curve: curveOf(curve),
              atEnd: place == BoxPlace.end,
            ),
            // The curve the box follows, with a dot that travels it.
            CurveGraph.implicit(
              name: curve.name,
              curve: curveOf(curve),
              duration: coarseDuration(step),
              atEnd: place == BoxPlace.end,
            ),
          ],
        ),
      ),
    ),
  );
}

class _Track extends StatelessWidget {
  const _Track({
    required this.duration,
    required this.curve,
    required this.atEnd,
  });

  final Duration duration;
  final Curve curve;
  final bool atEnd;

  @override
  Widget build(BuildContext context) => Container(
    width: 280,
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: ThemeColor.surfaceContainer,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        AnimatedContainer(
          width: 48,
          height: 48,
          duration: duration,
          curve: curve,
          // web: the box moves with `transform`, which the GPU paints
          // without a layout per frame.
          transform: atEnd
              ? Matrix4.translationValues(184, 0, 0)
              : Matrix4.identity(),
          decoration: BoxDecoration(
            color: atEnd ? ThemeColor.primary : ThemeColor.onSurfaceVariant,
            borderRadius: BorderRadius.circular(atEnd ? 24 : 12),
          ),
        ),
      ],
    ),
  );
}
