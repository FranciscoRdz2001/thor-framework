/// `:::bench bench-wrap`: a `Wrap` of tags. A Level narrows its box (the
/// children go to the next line when they do not fit), two more set the
/// space between children and between lines.
///
/// The box's width is continuous, so it reaches the stage as a CSS variable;
/// the two spacings take a few steps the server compiles ahead.
library;

import 'package:thor_ui/thor_ui.dart';

import '../bench/bench_example.dart';
import 'learn_parts.dart';

const _stepPx = 4;
const _steps = 5;
const _tags = ['Flutter', 'Dart', 'HTML', 'CSS', 'Signals', 'Routes', 'Forms'];

/// What the panel controls and the stage reads.
class WrapViewModel extends ThorState {
  /// The box's width, in px.
  final width = state(300.0);

  /// The space between children on a line, in steps of 4 px.
  final spacing = state(2);

  /// The space between lines, in steps of 4 px.
  final runSpacing = state(2);

  /// The `width` line of the Code view.
  String widthCode() => 'width: ${width.value.round()},';

  /// The `spacing` line of the Code view.
  String spacingCode() => 'spacing: ${spacing.value * _stepPx},';

  /// The `runSpacing` line of the Code view.
  String runSpacingCode() => 'runSpacing: ${runSpacing.value * _stepPx},';

  /// The number next to the width Level.
  String widthText() => '${width.value.round()} px';

  /// The number next to the spacing Level.
  String spacingText() => '${spacing.value * _stepPx} px';

  /// The number next to the runSpacing Level.
  String runSpacingText() => '${runSpacing.value * _stepPx} px';

  /// What the width Level calls.
  void setWidth(double value) => width.value = value;

  /// What the spacing Level calls.
  void setSpacing(double value) => spacing.value = (value / _stepPx).round();

  /// What the runSpacing Level calls.
  void setRunSpacing(double value) =>
      runSpacing.value = (value / _stepPx).round();
}

/// One instance, at the top level: the browser boots with it.
final wrapDemo = WrapViewModel();

/// The example.
final wrapBench = BenchExample(
  title: (t) => t.exLayoutWrapTitle,
  description: (t) => t.exLayoutWrapDescription,
  stage: const WrapStage(),
  code: BenchCode([
    const BenchCodeLine('SizedBox('),
    BenchCodeLine.live(wrapDemo.widthCode, indent: 1),
    const BenchCodeLine('child: Wrap(', indent: 1),
    BenchCodeLine.live(wrapDemo.spacingCode, indent: 2),
    BenchCodeLine.live(wrapDemo.runSpacingCode, indent: 2),
    const BenchCodeLine('children: [for (final t in tags) Tag(t)],', indent: 2),
    const BenchCodeLine('),', indent: 1),
    const BenchCodeLine(')'),
  ], appCode: true),
  controls: [
    BenchLevel(
      label: (t) => t.exLayoutWrapWidth,
      value: wrapDemo.width.value,
      min: 140,
      max: 340,
      divisions: 20,
      onChanged: wrapDemo.setWidth,
      valueText: wrapDemo.widthText,
    ),
    BenchLevel(
      label: (t) => t.exLayoutWrapSpacing,
      value: wrapDemo.spacing.value * _stepPx,
      max: (_steps - 1) * _stepPx.toDouble(),
      divisions: _steps - 1,
      onChanged: wrapDemo.setSpacing,
      valueText: wrapDemo.spacingText,
    ),
    BenchLevel(
      label: (t) => t.exLayoutWrapRunSpacing,
      value: wrapDemo.runSpacing.value * _stepPx,
      max: (_steps - 1) * _stepPx.toDouble(),
      divisions: _steps - 1,
      onChanged: wrapDemo.setRunSpacing,
      valueText: wrapDemo.runSpacingText,
    ),
  ],
);

/// The stage: tags in a box whose width the first Level sets.
class WrapStage extends StatelessWidget {
  /// The stage of the example.
  const WrapStage({super.key});

  @override
  Widget build(BuildContext context) => Watch.field(
    wrapDemo.spacing,
    count: _steps,
    builder: (spacing) => Watch.field(
      wrapDemo.runSpacing,
      count: _steps,
      builder: (run) => Styled(
        // web: the box's width follows the Level in the browser
        // (`BoundLength`).
        style: StyleProps(maxWidth: wrapDemo.width.px),
        child: LearnFrame(
          width: double.infinity,
          child: Wrap(
            spacing: spacing * _stepPx.toDouble(),
            runSpacing: run * _stepPx.toDouble(),
            children: [
              for (final tag in _tags) LearnTile(label: tag, filled: false),
            ],
          ),
        ),
      ),
    ),
  );
}
