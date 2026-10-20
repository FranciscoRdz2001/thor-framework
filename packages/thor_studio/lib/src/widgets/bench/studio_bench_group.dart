import 'package:thor_ui/thor_ui.dart';

import '../inputs/state_styles.dart';

/// A labelled set of controls in a bench panel: "Switches" holds the
/// segmented controls, "Levels" the bars.
///
/// ```dart
/// StudioBenchGroup(
///   label: 'Levels', // a parameter: the site passes its translation
///   children: [StudioLevelSlider(…), StudioLevelSlider(…)],
/// )
/// ```
///
/// The group is a `role=group` named by its [label], so a screen reader
/// announces "Levels, group" when focus enters it; the label is not drawn
/// (each control carries its own name).
class StudioBenchGroup extends StatelessWidget implements ThorElementWidget {
  /// A group named [label] around [children].
  const StudioBenchGroup({
    super.key,
    required this.label,
    required this.children,
    this.spacing = 16,
  });

  /// The group's accessible name.
  final String label;

  /// The controls, top to bottom.
  final List<Widget> children;

  /// The space between controls.
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return StateStyles(
      attributes: {'role': 'group', 'aria-label': label},
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: spacing,
        children: children,
      ),
    );
  }
}
