/// `:::bench bench-curves`: what a curve is. The curve is drawn as a path and a
/// dot travels it when the bench replays; the timeline and the millisecond
/// readout under it follow the duration.
///
/// A Switch picks the curve and a Level the duration; each is a variant the
/// server compiled with its own controller that runs when the page is drawn.
library;

import 'package:thor_ui/thor_ui.dart';

import 'bench_example.dart';
import 'motion_curve.dart';
import 'motion_graph.dart';

/// What the panel controls and the stage reads.
class CurvesViewModel extends ThorState {
  /// The curve.
  final curve = state(GraphCurve.easeOut);

  /// The duration, as a step of 100 ms.
  final step = state(2);

  /// The number next to the duration Level's bar.
  String durationText() => '${coarseDuration(step.value).inMilliseconds} ms';

  /// The `duration` line of the Code view.
  String durationCode() =>
      'duration: Duration(milliseconds: ${coarseDuration(step.value).inMilliseconds}),';

  /// The `curve` line of the Code view.
  String curveCode() => 'curve: ${curve.value.code},';

  /// What the curve Switch calls.
  void setCurve(GraphCurve? value) => curve.value = value ?? GraphCurve.easeOut;

  /// What the duration Level calls.
  void setDuration(double ms) => step.value = coarseStepOf(ms);
}

/// One instance, at the top level: the browser boots with it.
final curvesState = CurvesViewModel();

/// The example: a Switch, a Level, the stage and its code.
final curvesBench = BenchExample(
  title: (t) => t.exMotion2CurvesTitle,
  description: (t) => t.exMotion2CurvesDescription,
  replay: true,
  stage: const CurvesStage(),
  code: BenchCode([
    const BenchCodeLine('final controller = AnimationController('),
    BenchCodeLine.live(curvesState.durationCode, indent: 1),
    const BenchCodeLine(')..forward();'),
    const BenchCodeLine(' '),
    const BenchCodeLine('final progress = CurvedAnimation('),
    const BenchCodeLine('parent: controller,', indent: 1),
    BenchCodeLine.live(curvesState.curveCode, indent: 1),
    const BenchCodeLine(');'),
    const BenchCodeLine(' '),
    const BenchCodeLine('SlideTransition('),
    const BenchCodeLine(
      'position: Tween(begin: Offset.zero, end: Offset(0, -8)).animate(progress),',
      indent: 1,
    ),
    const BenchCodeLine('child: dot,', indent: 1),
    const BenchCodeLine(')'),
  ], appCode: true),
  controls: [
    BenchDropdown<GraphCurve>(
      label: (t) => t.exMotion2Curve,
      value: curvesState.curve.value,
      onChanged: curvesState.setCurve,
      code: true,
      items: [
        for (final c in GraphCurve.values)
          BenchSegment(c, label: (_) => c.name),
      ],
    ),
    BenchLevel(
      label: (t) => t.exMotionDuration,
      value: coarseMs(curvesState.step.value),
      min: coarseMinMs.toDouble(),
      max: coarseMaxMs.toDouble(),
      divisions: coarseSteps - 1,
      onChanged: curvesState.setDuration,
      valueText: curvesState.durationText,
    ),
  ],
);

/// The stage: the graph, one copy per curve and duration.
class CurvesStage extends StatelessWidget {
  /// The stage of the example.
  const CurvesStage({super.key});

  @override
  Widget build(BuildContext context) => Watch.field(
    curvesState.step,
    count: coarseSteps,
    builder: (step) => Watch.field(
      curvesState.curve,
      builder: (curve) => CurveGraph.explicit(
        name: curve.name,
        curve: graphCurveOf(curve),
        duration: coarseDuration(step),
      ),
    ),
  );
}
