/// `:::bench bench-explicit`: explicit animations. A card enters with an
/// `AnimationController` that already runs when the page is drawn, so the
/// browser plays it as a CSS animation and the Replay button restarts it.
///
/// A Switch picks the curve and a Level the duration; each is a variant the
/// server compiled with its own controller.
library;

import 'package:thor_ui/thor_ui.dart';

import 'bench_example.dart';
import 'motion_curve.dart';
import 'motion_graph.dart';

/// What the panel controls and the stage reads.
class ExplicitViewModel extends ThorState {
  /// The curve of the entrance.
  final curve = state(MotionCurve.easeOut);

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
  void setCurve(MotionCurve? value) =>
      curve.value = value ?? MotionCurve.easeOut;

  /// What the duration Level calls.
  void setDuration(double ms) => step.value = coarseStepOf(ms);
}

/// One instance, at the top level: the browser boots with it.
final explicit = ExplicitViewModel();

/// The example: a Switch, a Level, the stage and its code.
final explicitBench = BenchExample(
  title: (t) => t.exMotionExplicitTitle,
  description: (t) => t.exMotionExplicitDescription,
  replay: true,
  stage: const ExplicitStage(),
  code: BenchCode([
    const BenchCodeLine('final controller = AnimationController('),
    BenchCodeLine.live(explicit.durationCode, indent: 1),
    const BenchCodeLine(')..forward();'),
    const BenchCodeLine(' '),
    const BenchCodeLine('final entrance = CurvedAnimation('),
    const BenchCodeLine('parent: controller,', indent: 1),
    BenchCodeLine.live(explicit.curveCode, indent: 1),
    const BenchCodeLine(');'),
    const BenchCodeLine(' '),
    const BenchCodeLine('FadeTransition('),
    const BenchCodeLine('opacity: entrance,', indent: 1),
    const BenchCodeLine('child: SlideTransition(', indent: 1),
    const BenchCodeLine(
      'position: Tween(begin: Offset(0, .3), end: Offset.zero)',
      indent: 2,
    ),
    const BenchCodeLine('.animate(entrance),', indent: 4),
    const BenchCodeLine('child: card,', indent: 2),
    const BenchCodeLine('),', indent: 1),
    const BenchCodeLine(')'),
  ], appCode: true),
  controls: [
    BenchDropdown<MotionCurve>(
      label: (t) => t.exMotionCurve,
      value: explicit.curve.value,
      onChanged: explicit.setCurve,
      code: true,
      items: motionCurveSegments(),
    ),
    BenchLevel(
      label: (t) => t.exMotionDuration,
      value: coarseMs(explicit.step.value),
      min: coarseMinMs.toDouble(),
      max: coarseMaxMs.toDouble(),
      divisions: coarseSteps - 1,
      onChanged: explicit.setDuration,
      valueText: explicit.durationText,
    ),
  ],
);

/// The stage: the card, one copy per curve and duration.
class ExplicitStage extends StatelessWidget {
  /// The stage of the example.
  const ExplicitStage({super.key});

  @override
  Widget build(BuildContext context) => Watch.field(
    explicit.step,
    count: coarseSteps,
    builder: (step) => Watch.field(
      explicit.curve,
      builder: (curve) {
        final entrance = CurvedAnimation(
          parent: AnimationController(duration: coarseDuration(step))
            ..forward(),
          curve: curveOf(curve),
        );
        return Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 16,
          children: [
            FadeTransition(
              opacity: entrance,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0, 0.3),
                  end: Offset.zero,
                ).animate(entrance),
                child: const _Card(),
              ),
            ),
            // The curve the card follows, with a dot that travels it.
            CurveGraph.explicit(
              name: curve.name,
              curve: curveOf(curve),
              duration: coarseDuration(step),
            ),
          ],
        );
      },
    ),
  );
}

class _Card extends StatelessWidget {
  const _Card();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ThemeColor.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 6,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: ThemeColor.primary,
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          const Text(
            'Order #1042',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const Text(
            'Ready for pickup',
            style: TextStyle(color: ThemeColor.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
