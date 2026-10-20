/// `:::bench bench-flex`: a Switch picks `Expanded` or `Flexible` for the two
/// children that share a `Row`'s free space, a Level the first one's `flex`.
/// `Expanded` fills its share; `Flexible` may stay as small as its content.
library;

import 'package:thor_ui/thor_ui.dart';

import '../bench/bench_example.dart';
import 'learn_parts.dart';

const _maxFlex = 4;

/// The two widgets the Switch offers.
enum FlexKind {
  /// `Expanded`: fills its share.
  expanded,

  /// `Flexible`: at most its share.
  flexible,
}

/// What the panel controls and the stage reads.
class FlexViewModel extends ThorState {
  /// `Expanded` or `Flexible`.
  final kind = state(FlexKind.expanded);

  /// The first child's `flex`, minus one (so it counts from 0).
  final step = state(1);

  /// The widget's name, for the Code view.
  String kindName() =>
      kind.value == FlexKind.expanded ? 'Expanded' : 'Flexible';

  /// The first child's line of the Code view.
  String firstCode() => '${kindName()}(flex: ${step.value + 1}, child: B()),';

  /// The second child's line of the Code view.
  String secondCode() => '${kindName()}(child: C()),';

  /// The number next to the Level.
  String flexText() => '${step.value + 1}';

  /// What the Switch calls.
  void setKind(Set<FlexKind> value) => kind.value = value.first;

  /// What the Level calls.
  void setFlex(double value) => step.value = value.round() - 1;
}

/// One instance, at the top level: the browser boots with it.
final flexDemo = FlexViewModel();

/// The example.
final flexBench = BenchExample(
  title: (t) => t.exLayoutFlexTitle,
  description: (t) => t.exLayoutFlexDescription,
  stage: const FlexStage(),
  code: BenchCode([
    const BenchCodeLine('Row('),
    const BenchCodeLine('spacing: 8,', indent: 1),
    const BenchCodeLine('children: [', indent: 1),
    const BenchCodeLine('A(), // 48 px', indent: 2),
    BenchCodeLine.live(flexDemo.firstCode, indent: 2),
    BenchCodeLine.live(flexDemo.secondCode, indent: 2),
    const BenchCodeLine('],', indent: 1),
    const BenchCodeLine(')'),
  ], appCode: true),
  controls: [
    BenchSwitch<FlexKind>(
      label: (t) => t.exLayoutFlexKind,
      value: flexDemo.kind.value,
      onChanged: flexDemo.setKind,
      segments: [
        BenchSegment(FlexKind.expanded, label: (t) => t.exLayoutFlexExpanded),
        BenchSegment(FlexKind.flexible, label: (t) => t.exLayoutFlexFlexible),
      ],
    ),
    BenchLevel(
      label: (t) => t.exLayoutFlexFactor,
      value: flexDemo.step.value + 1,
      min: 1,
      max: _maxFlex.toDouble(),
      divisions: _maxFlex - 1,
      onChanged: flexDemo.setFlex,
      valueText: flexDemo.flexText,
    ),
  ],
);

/// The stage: a fixed tile and two that share what is left.
class FlexStage extends StatelessWidget {
  /// The stage of the example.
  const FlexStage({super.key});

  @override
  Widget build(BuildContext context) => Watch.field(
    flexDemo.kind,
    builder: (kind) => Watch.field(
      flexDemo.step,
      count: _maxFlex,
      builder: (step) {
        const a = LearnTile(label: 'A', width: 56, height: 72);
        const b = LearnTile(label: 'B', filled: false, height: 72);
        const c = LearnTile(label: 'C', height: 72);
        return LearnFrame(
          width: 480,
          child: Row(
            spacing: 8,
            children: [
              a,
              if (kind == FlexKind.expanded) ...[
                Expanded(flex: step + 1, child: b),
                const Expanded(child: c),
              ] else ...[
                Flexible(flex: step + 1, child: b),
                const Flexible(child: c),
              ],
            ],
          ),
        );
      },
    ),
  );
}
