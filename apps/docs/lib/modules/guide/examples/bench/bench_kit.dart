/// Small helpers the catalog benches share, so each example declares its
/// controls in a few lines.
library;

import 'bench_example.dart';

/// A yes / no switch over a `bool` field: [label] names it, [value] is the
/// first paint and [onChanged] a method of the example's state
/// (`void setEnabled(bool value)`).
BenchToggle boolSwitch({
  required MessageOf label,
  required bool value,
  required void Function(bool) onChanged,
}) => BenchToggle(label: label, value: value, onChanged: onChanged);

/// The "Enabled" Switch most widgets have.
BenchToggle enabledSwitch({
  required bool value,
  required void Function(bool) onChanged,
}) => boolSwitch(
  label: (t) => t.exCatEnabled,
  value: value,
  onChanged: onChanged,
);

/// A Level that shows its value in px.
BenchLevel pxLevel({
  required MessageOf label,
  required num value,
  required double min,
  required double max,
  required int divisions,
  required void Function(double) onChanged,
  required String Function() valueText,
}) => BenchLevel(
  label: label,
  value: value,
  min: min,
  max: max,
  divisions: divisions,
  onChanged: onChanged,
  valueText: valueText,
);
