/// `:::bench bench-switcher`: changing what is shown. `AnimatedSwitcher`
/// animates the change of a `Watch` and moves each `Hero` that is in both
/// states.
library;

import 'package:thor_ui/thor_ui.dart';

import 'bench_example.dart';
import 'motion_curve.dart';
import 'motion_graph.dart';

/// How the cards of the switcherState bench are laid out.
enum SwitchLayout {
  /// Three squares in a row.
  row,

  /// Three bars in a column.
  column,
}

/// What the switcherState bench controls and the stage reads.
class SwitcherViewModel extends ThorState {
  /// The layout.
  final layout = state(SwitchLayout.row);

  /// The curve of the move.
  final curve = state(MotionCurve.easeInOut);

  /// The duration, as a step of 100 ms.
  final step = state(1);

  /// The number next to the duration Level's bar.
  String durationText() => '${coarseDuration(step.value).inMilliseconds} ms';

  /// The `duration` line of the Code view.
  String durationCode() =>
      'duration: Duration(milliseconds: ${coarseDuration(step.value).inMilliseconds}),';

  /// The `switchInCurve` line of the Code view.
  String curveCode() => 'switchInCurve: ${curve.value.code},';

  /// The `direction` line of the Code view.
  String directionCode() =>
      'direction: ${layout.value == SwitchLayout.row ? 'Axis.horizontal' : 'Axis.vertical'},';

  /// What the layout Switch and the stage's button call.
  void setLayout(Set<SwitchLayout> value) => layout.value = value.first;

  /// What the curve Switch calls.
  void setCurve(MotionCurve? value) =>
      curve.value = value ?? MotionCurve.easeOut;

  /// What the duration Level calls.
  void setDuration(double ms) => step.value = coarseStepOf(ms);

  /// Swaps the layout (the stage's button).
  void swap() => layout.value = layout.value == SwitchLayout.row
      ? SwitchLayout.column
      : SwitchLayout.row;
}

/// One instance, at the top level: the browser boots with it.
final switcherState = SwitcherViewModel();

/// The switcherState example.
final switcherBench = BenchExample(
  title: (t) => t.exMotion2SwitcherTitle,
  description: (t) => t.exMotion2SwitcherDescription,
  stage: const SwitcherStage(),
  code: BenchCode([
    const BenchCodeLine('AnimatedSwitcher('),
    BenchCodeLine.live(switcherState.durationCode, indent: 1),
    BenchCodeLine.live(switcherState.curveCode, indent: 1),
    const BenchCodeLine('child: Watch(', indent: 1),
    const BenchCodeLine('layout.isRow,', indent: 2),
    const BenchCodeLine('builder: (row) => Flex(', indent: 2),
    BenchCodeLine.live(switcherState.directionCode, indent: 3),
    const BenchCodeLine('children: [', indent: 3),
    const BenchCodeLine(
      "for (final i in [0, 1, 2]) Hero(tag: 'card-\$i', child: card(i)),",
      indent: 4,
    ),
    const BenchCodeLine('],', indent: 3),
    const BenchCodeLine('),', indent: 2),
    const BenchCodeLine('),', indent: 1),
    const BenchCodeLine(')'),
  ], appCode: true),
  controls: [
    BenchSwitch<SwitchLayout>(
      label: (t) => t.exMotion2Layout,
      value: switcherState.layout.value,
      onChanged: switcherState.setLayout,
      segments: [
        BenchSegment(SwitchLayout.row, label: (t) => t.exMotion2LayoutRow),
        BenchSegment(
          SwitchLayout.column,
          label: (t) => t.exMotion2LayoutColumn,
        ),
      ],
    ),
    BenchDropdown<MotionCurve>(
      label: (t) => t.exMotionCurve,
      value: switcherState.curve.value,
      onChanged: switcherState.setCurve,
      code: true,
      items: motionCurveSegments(),
    ),
    BenchLevel(
      label: (t) => t.exMotionDuration,
      value: coarseMs(switcherState.step.value),
      min: coarseMinMs.toDouble(),
      max: coarseMaxMs.toDouble(),
      divisions: coarseSteps - 1,
      onChanged: switcherState.setDuration,
      valueText: switcherState.durationText,
    ),
  ],
);

/// The switcherState stage: three cards that change layout, each a `Hero`.
class SwitcherStage extends StatelessWidget {
  /// The stage of the example.
  const SwitcherStage({super.key});

  @override
  Widget build(BuildContext context) => Watch.field(
    switcherState.step,
    count: coarseSteps,
    builder: (step) => Watch.field(
      switcherState.curve,
      builder: (curve) => Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 16,
        children: [
          SizedBox(
            width: 280,
            height: 188,
            child: AnimatedSwitcher(
              duration: coarseDuration(step),
              switchInCurve: curveOf(curve),
              child: Watch.field(
                switcherState.layout,
                builder: (layout) => _Cards(row: layout == SwitchLayout.row),
              ),
            ),
          ),
          MotionMeta(step: switcherState.step, curve: switcherState.curve),
          OutlinedButton(
            onPressed: switcherState.swap,
            child: const Text('Swap layout'),
          ),
        ],
      ),
    ),
  );
}

class _Cards extends StatelessWidget {
  const _Cards({required this.row});

  final bool row;

  @override
  Widget build(BuildContext context) {
    const colors = [
      ThemeColor.primary,
      ThemeColor.onSurfaceVariant,
      ThemeColor.outline,
    ];
    return Flex(
      direction: row ? Axis.horizontal : Axis.vertical,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < 3; i++)
          Hero(
            tag: 'card-$i',
            child: Container(
              width: row ? 80 : 280,
              height: row ? 120 : 48,
              decoration: BoxDecoration(
                color: colors[i],
                borderRadius: BorderRadius.circular(row ? 16 : 12),
              ),
            ),
          ),
      ],
    );
  }
}
