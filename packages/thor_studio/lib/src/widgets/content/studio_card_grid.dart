import 'package:thor_ui/thor_ui.dart';

import '../../theme/component_themes/studio_card_theme.dart';

/// A responsive grid of cards: one column on a phone, [columns] from the
/// `md` breakpoint up (three or more: two at `md`, [columns] from
/// `expanded`).
///
/// ```dart
/// StudioCardGrid(children: [
///   StudioLinkCard(title: 'Widgets', href: '/widgets', description: 'Build the view.'),
///   StudioLinkCard(title: 'State', href: '/state', description: 'Make it react.'),
/// ])
/// ```
///
/// The gap is `StudioCardThemeData.gridGap`. It is a CSS grid with a media
/// query (no JavaScript), so it is right on the first paint.
class StudioCardGrid extends StatelessWidget implements ThorElementWidget {
  /// A grid of [children].
  const StudioCardGrid({super.key, required this.children, this.columns = 2});

  /// The cards (usually `StudioLinkCard`s).
  final List<Widget> children;

  /// How many columns from the `md` breakpoint up.
  final int columns;

  @override
  Widget build(BuildContext context) {
    final card = StudioCardThemeData.of(context);
    return Grid(
      layout: GridLayout(columns: 1, gap: card.gridGap).when(
        medium: GridLayout(
          columns: columns > 2 ? 2 : columns,
          gap: card.gridGap,
        ),
        expanded: GridLayout(columns: columns, gap: card.gridGap),
      ),
      children: children,
    );
  }
}
