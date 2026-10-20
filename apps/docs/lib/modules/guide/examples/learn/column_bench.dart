/// `:::bench bench-column-align`: a Switch picks the `crossAxisAlignment` of
/// a `Column`, a Level its `spacing`. With `stretch` every child fills the
/// width; with the others each one is as wide as its content.
library;

import 'package:thor_ui/thor_ui.dart';

import '../bench/bench_example.dart';
import 'learn_parts.dart';

const _stepPx = 4;
const _steps = 5;

/// The values of the Switch (the state keeps its own enum).
enum ColumnAlignment {
  /// `CrossAxisAlignment.start`.
  start,

  /// `CrossAxisAlignment.center`.
  center,

  /// `CrossAxisAlignment.stretch`.
  stretch,
}

/// What the panel controls and the stage reads.
class ColumnAlignViewModel extends ThorState {
  /// The Column's `crossAxisAlignment`.
  final alignment = state(ColumnAlignment.center);

  /// The Column's `spacing`, in steps of 4 px.
  final spacing = state(4);

  /// The `crossAxisAlignment` line of the Code view.
  String alignmentCode() =>
      'crossAxisAlignment: CrossAxisAlignment.${alignment.value.name},';

  /// The `spacing` line of the Code view.
  String spacingCode() => 'spacing: ${spacing.value * _stepPx},';

  /// The number next to the spacing Level.
  String spacingText() => '${spacing.value * _stepPx} px';

  /// What the Switch calls.
  void setAlignment(Set<ColumnAlignment> value) =>
      alignment.value = value.first;

  /// What the Level calls.
  void setSpacing(double value) => spacing.value = (value / _stepPx).round();
}

/// One instance, at the top level: the browser boots with it.
final columnAlign = ColumnAlignViewModel();

/// The example.
final columnAlignBench = BenchExample(
  title: (t) => t.exLayoutColumnTitle,
  description: (t) => t.exLayoutColumnDescription,
  stage: const ColumnAlignStage(),
  code: BenchCode([
    const BenchCodeLine('Column('),
    BenchCodeLine.live(columnAlign.alignmentCode, indent: 1),
    BenchCodeLine.live(columnAlign.spacingCode, indent: 1),
    const BenchCodeLine('children: [', indent: 1),
    const BenchCodeLine("Text('Coffee'),", indent: 2),
    const BenchCodeLine("Text('Chai tea'),", indent: 2),
    const BenchCodeLine("Text('Mate'),", indent: 2),
    const BenchCodeLine('],', indent: 1),
    const BenchCodeLine(')'),
  ]),
  controls: [
    BenchSwitch<ColumnAlignment>(
      label: (t) => t.exLayoutColumnAlignment,
      value: columnAlign.alignment.value,
      onChanged: columnAlign.setAlignment,
      segments: [
        BenchSegment(ColumnAlignment.start, label: (t) => t.benchSegmentStart),
        BenchSegment(
          ColumnAlignment.center,
          label: (t) => t.benchSegmentCenter,
        ),
        BenchSegment(
          ColumnAlignment.stretch,
          label: (t) => t.exLayoutColumnStretch,
        ),
      ],
    ),
    BenchLevel(
      label: (t) => t.benchRowSpacing,
      value: columnAlign.spacing.value * _stepPx,
      max: (_steps - 1) * _stepPx.toDouble(),
      divisions: _steps - 1,
      onChanged: columnAlign.setSpacing,
      valueText: columnAlign.spacingText,
    ),
  ],
);

/// The stage: three items in a `Column`.
class ColumnAlignStage extends StatelessWidget {
  /// The stage of the example.
  const ColumnAlignStage({super.key});

  @override
  Widget build(BuildContext context) {
    return Watch.field(
      columnAlign.alignment,
      builder: (alignment) => Watch.field(
        columnAlign.spacing,
        count: _steps,
        builder: (step) => LearnFrame(
          width: 260,
          child: Column(
            crossAxisAlignment: switch (alignment) {
              ColumnAlignment.start => CrossAxisAlignment.start,
              ColumnAlignment.center => CrossAxisAlignment.center,
              ColumnAlignment.stretch => CrossAxisAlignment.stretch,
            },
            spacing: step * _stepPx.toDouble(),
            children: [
              const LearnTile(label: 'Coffee', hugs: true),
              const LearnTile(label: 'Chai tea', filled: false, hugs: true),
              const LearnTile(label: 'Mate', hugs: true),
            ],
          ),
        ),
      ),
    );
  }
}
