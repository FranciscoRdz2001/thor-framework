/// Helpers of the content catalog's benches.
library;

import 'bench_example.dart';

/// A Level over a few equal steps (`min`, `min + step`, …): the state keeps
/// the step's index (an `int`), so the stage can swap precompiled variants.
///
/// [unit] follows the number (`' px'`); [onChanged] and [valueText] are
/// methods of the example's state.
BenchLevel stepLevel({
  required MessageOf label,
  required double min,
  required double step,
  required int steps,
  required int initial,
  required void Function(double) onChanged,
  required String Function() valueText,
  String unit = ' px',
}) => BenchLevel(
  label: label,
  value: min + step * initial,
  min: min,
  max: min + step * (steps - 1),
  divisions: steps - 1,
  onChanged: onChanged,
  valueText: valueText,
);
