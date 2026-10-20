import 'package:thor_ui/thor_ui.dart' show IconData, Widget;

import '../../tokens/color/studio_tone.dart';

/// A place in the site: a label and where it goes. The data every
/// navigation widget of the studio takes (top bar links, sidebar items,
/// breadcrumbs, the footer, the pager).
///
/// ```dart
/// const StudioNavDestination('Widgets', href: '/widgets')
/// // A sidebar item with a count at its end (an app's open issues):
/// const StudioNavDestination(
///   'Issues',
///   href: '/issues',
///   count: 31,
///   countTone: StudioTone.danger,
///   countLabel: '31 open',
/// )
/// ```
///
/// The page being shown is marked by the container, like Flutter's
/// `NavigationDrawer(selectedIndex:)`: `StudioSideNav(selectedIndex:)`,
/// `StudioTopBar(selectedIndex:)`, `StudioBreadcrumbs(selectedIndex:)`.
///
/// [count], [countTone], [countLabel] and [trailing] are for the sidebar
/// (`StudioSideNav`); the other navigations ignore them.
class StudioNavDestination {
  /// A destination called [label] at [href].
  const StudioNavDestination(
    this.label, {
    required this.href,
    this.icon,
    this.count,
    this.countTone = StudioTone.neutral,
    this.countLabel,
    this.trailing,
  });

  /// The text of the link.
  final String label;

  /// Where it goes (a path, a URL or `#section`).
  final String href;

  /// An icon before the label (the sidebar shows it; null: none).
  final IconData? icon;

  /// A number at the end of the sidebar item, in a pill (`StudioStatusLabel`)
  /// that shows `99+` from a hundred. Null or zero: no pill (zero is "nothing
  /// to look at", so it stays out of the way).
  final int? count;

  /// The tone of the [count] pill (`danger` for issues, `warn` for alerts).
  final StudioTone countTone;

  /// What a screen reader says for the [count] instead of the bare number
  /// (`'31 open issues'`; default: the number).
  final String? countLabel;

  /// Anything else at the end of the sidebar item (after the [count], if
  /// there is one): a dot, a small icon, a "new" label.
  final Widget? trailing;
}
