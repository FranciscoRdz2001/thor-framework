/// `:::bench bench-grid`: a `Grid` of six cards. Levels set the columns and
/// the gap, a Switch makes the first card span two columns.
library;

import 'package:thor_ui/thor_ui.dart';

import '../bench/bench_example.dart';
import 'learn_parts.dart';

const _maxColumns = 4;
const _gapSteps = 4;
const _gapPx = 8;

/// How wide the first card is.
enum GridFirst {
  /// One column, like the others.
  single,

  /// `GridPlacement.fullWidth`.
  wide,
}

/// What the panel controls and the stage reads.
class GridViewModel extends ThorState {
  /// The columns, minus one.
  final columns = state(1);

  /// The gap, in steps of 8 px.
  final gap = state(1);

  /// The first card's width.
  final first = state(GridFirst.single);

  /// The `GridLayout` line of the Code view.
  String layoutCode() =>
      'layout: GridLayout(columns: ${columns.value + 1}, gap: ${gap.value * _gapPx}),';

  /// The first card's line of the Code view.
  String firstCode() => first.value == GridFirst.wide
      ? 'GridItem(placement: GridPlacement.fullWidth, child: Card()),'
      : 'Card(),';

  /// The number next to the columns Level.
  String columnsText() => '${columns.value + 1}';

  /// The number next to the gap Level.
  String gapText() => '${gap.value * _gapPx} px';

  /// What the columns Level calls.
  void setColumns(double value) => columns.value = value.round() - 1;

  /// What the gap Level calls.
  void setGap(double value) => gap.value = (value / _gapPx).round();

  /// What the Switch calls.
  void setFirst(Set<GridFirst> value) => first.value = value.first;
}

/// One instance, at the top level: the browser boots with it.
final gridDemo = GridViewModel();

/// The example.
final gridBench = BenchExample(
  title: (t) => t.exLayoutGridTitle,
  description: (t) => t.exLayoutGridDescription,
  stage: const GridStage(),
  code: BenchCode([
    const BenchCodeLine('Grid('),
    BenchCodeLine.live(gridDemo.layoutCode, indent: 1),
    const BenchCodeLine('children: [', indent: 1),
    BenchCodeLine.live(gridDemo.firstCode, indent: 2),
    const BenchCodeLine('Card(), Card(), Card(), Card(), Card(),', indent: 2),
    const BenchCodeLine('],', indent: 1),
    const BenchCodeLine(')'),
  ], appCode: true),
  controls: [
    BenchSwitch<GridFirst>(
      label: (t) => t.exLayoutGridFirst,
      value: gridDemo.first.value,
      onChanged: gridDemo.setFirst,
      segments: [
        BenchSegment(GridFirst.single, label: (t) => t.exLayoutGridSingle),
        BenchSegment(GridFirst.wide, label: (t) => t.exLayoutGridWide),
      ],
    ),
    BenchLevel(
      label: (t) => t.exLayoutGridColumns,
      value: gridDemo.columns.value + 1,
      min: 1,
      max: _maxColumns.toDouble(),
      divisions: _maxColumns - 1,
      onChanged: gridDemo.setColumns,
      valueText: gridDemo.columnsText,
    ),
    BenchLevel(
      label: (t) => t.exLayoutGridGap,
      value: gridDemo.gap.value * _gapPx,
      max: (_gapSteps * _gapPx).toDouble(),
      divisions: _gapSteps,
      onChanged: gridDemo.setGap,
      valueText: gridDemo.gapText,
    ),
  ],
);

/// The stage: six cards in a `Grid`.
class GridStage extends StatelessWidget {
  /// The stage of the example.
  const GridStage({super.key});

  @override
  Widget build(BuildContext context) => Watch.field(
    gridDemo.columns,
    count: _maxColumns,
    builder: (columns) => Watch.field(
      gridDemo.gap,
      count: _gapSteps + 1,
      builder: (gap) => Watch.field(
        gridDemo.first,
        builder: (first) => LearnFrame(
          child: Grid(
            layout: GridLayout(
              columns: columns + 1,
              gap: gap * _gapPx.toDouble(),
            ),
            children: [
              if (first == GridFirst.wide)
                const GridItem(
                  placement: GridPlacement.fullWidth,
                  child: LearnTile(label: '1', height: 44, filled: true),
                )
              else
                const LearnTile(label: '1', height: 44, filled: true),
              for (var n = 2; n <= 6; n++) LearnTile(label: '$n', height: 44),
            ],
          ),
        ),
      ),
    ),
  );
}
