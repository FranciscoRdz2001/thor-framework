import 'package:thor_ui/thor_ui.dart';

import '../inputs/studio_segmented_control.dart';

/// One line of a bench panel's Switches: the name on the left, the control
/// on the right.
///
/// ```dart
/// StudioBenchRow(
///   label: 'Fill',
///   child: StudioSegmentedControl<Fill>(semanticLabel: 'Fill', …),
/// )
/// ```
///
/// When the control is too wide to share the line (long segments in a narrow
/// panel) it drops under the name instead of being squeezed or clipped. A
/// `StudioSegmentedControl` of more than two segments always takes its own
/// full-width line under the name, so three to five options sit in one row
/// of equal cells instead of wrapping next to the label.
///
/// A Level (`StudioLevelSlider`) draws its own name, so it needs no row.
class StudioBenchRow extends StatelessWidget implements ThorElementWidget {
  /// A row naming [child] as [label].
  const StudioBenchRow({super.key, required this.label, required this.child});

  /// The visible name (a parameter, so the site translates it).
  final String label;

  /// The control.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant!;
    final name = Text(
      label,
      style: Theme.of(context).textTheme.bodyMedium.copyWith(color: muted),
    );
    final c = child;
    if (c is StudioSegmentedControl && c.segments.length > 2) {
      // web: the name above, the control as wide as the row.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [name, c.withExpandedInsets(EdgeInsets.zero)],
      );
    }
    // web: a wrapping row: the control sits right of its name while both fit
    // and drops under it (left aligned) when they do not.
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: [name, child],
    );
  }
}
