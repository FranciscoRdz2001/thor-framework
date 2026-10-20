/// `:::bench bench-row-align`: the layout reference example. A Switch picks
/// the `mainAxisAlignment` of a `Row`, a Level its `spacing`; the stage and
/// the Code view follow.
///
/// A finite choice (the alignment, the spacing in steps of 4 px) reaches the
/// stage as `Watch.field` variants the server compiles ahead: the browser
/// only swaps one for another and never builds a style.
library;

import 'package:thor_ui/thor_ui.dart';

import 'bench_example.dart';

/// The pixels of one step of the spacing Level.
const _stepPx = 4;

/// How many values the spacing takes (0 to 24 px).
const _steps = 7;

/// The values of the alignment Switch: the ones of `MainAxisAlignment` it
/// offers (the state keeps its own enum: the browser cannot use Flutter's).
enum RowAlignment {
  /// `MainAxisAlignment.start`.
  start,

  /// `MainAxisAlignment.center`.
  center,

  /// `MainAxisAlignment.end`.
  end,

  /// `MainAxisAlignment.spaceBetween`.
  spaceBetween,
}

/// What the panel controls and the stage reads.
class RowAlignmentViewModel extends ThorState {
  /// The Row's `mainAxisAlignment`.
  final alignment = state(RowAlignment.start);

  /// The Row's `spacing`, in steps of 4 px.
  final spacing = state(2);

  /// The `mainAxisAlignment` line of the Code view.
  String alignmentCode() =>
      'mainAxisAlignment: MainAxisAlignment.${alignment.value.name},';

  /// The `spacing` line of the Code view.
  String spacingCode() => 'spacing: ${spacing.value * _stepPx},';

  /// The number next to the spacing Level's bar.
  String spacingText() => '${spacing.value * _stepPx} px';

  /// What the alignment Switch calls.
  void setAlignment(Set<RowAlignment> value) => alignment.value = value.first;

  /// What the spacing Level calls.
  void setSpacing(double value) => spacing.value = (value / _stepPx).round();
}

/// One instance, at the top level: the browser boots with it.
final rowAlignment = RowAlignmentViewModel();

/// The example: a Switch, a Level, the stage and its code.
final rowAlignmentBench = BenchExample(
  title: (t) => t.benchRowTitle,
  description: (t) => t.benchRowDescription,
  stage: const RowAlignmentStage(),
  code: BenchCode([
    const BenchCodeLine('Row('),
    BenchCodeLine.live(rowAlignment.alignmentCode, indent: 1),
    BenchCodeLine.live(rowAlignment.spacingCode, indent: 1),
    const BenchCodeLine('children: [', indent: 1),
    const BenchCodeLine('Box(),', indent: 2),
    const BenchCodeLine('Box(),', indent: 2),
    const BenchCodeLine('Box(),', indent: 2),
    const BenchCodeLine('],', indent: 1),
    const BenchCodeLine(')'),
  ], appCode: true),
  controls: [
    BenchSwitch<RowAlignment>(
      label: (t) => t.benchRowAlignment,
      value: rowAlignment.alignment.value,
      onChanged: rowAlignment.setAlignment,
      segments: [
        BenchSegment(RowAlignment.start, label: (t) => t.benchSegmentStart),
        BenchSegment(RowAlignment.center, label: (t) => t.benchSegmentCenter),
        BenchSegment(RowAlignment.end, label: (t) => t.benchSegmentEnd),
        BenchSegment(
          RowAlignment.spaceBetween,
          label: (t) => t.benchSegmentBetween,
        ),
      ],
    ),
    BenchLevel(
      label: (t) => t.benchRowSpacing,
      value: rowAlignment.spacing.value * _stepPx,
      max: (_steps - 1) * _stepPx.toDouble(),
      divisions: _steps - 1,
      onChanged: rowAlignment.setSpacing,
      valueText: rowAlignment.spacingText,
    ),
  ],
);

/// The stage: the `Row` the controls change, inside a frame that shows the
/// free space.
class RowAlignmentStage extends StatelessWidget {
  /// The stage of the example.
  const RowAlignmentStage({super.key});

  @override
  Widget build(BuildContext context) => Watch.field(
    rowAlignment.alignment,
    builder: (alignment) => Watch.field(
      rowAlignment.spacing,
      count: _steps,
      builder: (step) => _Frame(
        alignment: switch (alignment) {
          RowAlignment.start => MainAxisAlignment.start,
          RowAlignment.center => MainAxisAlignment.center,
          RowAlignment.end => MainAxisAlignment.end,
          RowAlignment.spaceBetween => MainAxisAlignment.spaceBetween,
        },
        spacing: step * _stepPx.toDouble(),
      ),
    ),
  );
}

class _Frame extends StatelessWidget {
  const _Frame({required this.alignment, required this.spacing});

  final MainAxisAlignment alignment;
  final double spacing;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 480),
    child: Container(
      width: double.infinity,
      height: 144,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(
          color: ThemeColor.outline,
          style: BorderStyle.dashed,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: alignment,
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: spacing,
        children: const [
          _Box(label: 'A', size: 72, color: ThemeColor.primary),
          _Box(
            label: 'B',
            size: 96,
            color: ThemeColor.surfaceContainerHigh,
            ink: ThemeColor.onSurface,
            outlined: true,
          ),
          _Box(label: 'C', size: 72, color: ThemeColor.primary),
        ],
      ),
    ),
  );
}

class _Box extends StatelessWidget {
  const _Box({
    required this.label,
    required this.size,
    required this.color,
    this.ink = ThemeColor.onPrimary,
    this.outlined = false,
  });

  final String label;
  final double size;
  final Color color;
  final Color ink;

  /// A hairline around it: a quiet fill alone vanishes on a dark stage.
  final bool outlined;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: color,
      border: outlined
          ? Border.all(color: ThemeColor.onSurfaceVariant, width: 2)
          : null,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: ink),
    ),
  );
}
