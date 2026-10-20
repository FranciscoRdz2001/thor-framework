import 'package:thor_ui/thor_ui.dart';

import '../../theme/component_themes/studio_bench_theme.dart';
import 'bench_scope.dart';

/// The side panel of a `StudioBench`: the example's name and description,
/// its controls in labelled groups, and the actions at the bottom.
///
/// ```dart
/// StudioBenchPanel(
///   groups: [
///     StudioBenchGroup(label: 'Switches', children: [
///       StudioBenchRow(label: 'Theme', child: StudioSegmentedControl<Fill>(…)),
///     ]),
///     StudioBenchGroup(label: 'Levels', children: [
///       StudioLevelSlider(title: 'Radius', …),
///     ]),
///   ],
///   footer: [
///     OutlinedButton(href: url, child: Text('Share')),
///     FilledButton(onPressed: demo.copy, child: Text('Copy code')),
///   ],
/// )
/// ```
///
/// Inside a `StudioBench` the [title] and [description] default to the
/// bench's own, so an example names itself once. The footer sticks to the
/// panel's bottom when the stage is taller than the controls.
///
/// Colors, radius and padding come from the nearest [StudioBenchThemeData];
/// [theme] overrides it.
class StudioBenchPanel extends StatelessWidget implements ThorElementWidget {
  /// A panel with [groups] and a [footer] of actions.
  const StudioBenchPanel({
    super.key,
    this.title,
    this.description,
    this.groups = const [],
    this.footer = const [],
    this.headingLevel = 3,
    this.theme,
  });

  /// The example's name (defaults to the bench's).
  final String? title;

  /// A sentence about the example (defaults to the bench's).
  final String? description;

  /// The controls, usually `StudioBenchGroup`s.
  final List<Widget> groups;

  /// The actions at the bottom, top to bottom (usually pill buttons).
  final List<Widget> footer;

  /// The title's heading level (3: an example under a section's `h2`).
  final int headingLevel;

  /// Overrides the bench theme.
  final StudioBenchThemeData? theme;

  @override
  Widget build(BuildContext context) {
    final t = StudioBenchThemeData.of(context, theme);
    final scope = BenchScope.maybeOf(context);
    final name = title ?? scope?.title;
    final about = description ?? scope?.description;
    final text = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant!;
    return Container(
      padding: t.panelPadding,
      decoration: BoxDecoration(
        color: t.panelColor,
        border: Border.all(color: t.borderColor),
        borderRadius: BorderRadius.circular(t.panelRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: t.panelGap,
        children: [
          if (name != null)
            Semantics(
              headingLevel: headingLevel,
              child: Text(name, style: text.titleLarge),
            ),
          if (about != null)
            Text(about, style: text.bodyMedium.copyWith(color: muted)),
          // web: the controls' scope: a segmented control asks how wide this
          // panel is (a container query), so it stacks its cells when the
          // labels would not fit one row in it.
          if (groups.isNotEmpty)
            LayoutScope(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: t.panelGap,
                children: groups,
              ),
            ),
          if (footer.isNotEmpty) ...[
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 8,
              children: footer,
            ),
          ],
        ],
      ),
    );
  }
}
