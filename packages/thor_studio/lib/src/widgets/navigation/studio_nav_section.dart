import 'package:thor_ui/thor_ui.dart';

import 'studio_nav_destination.dart';

/// A titled group of [StudioNavDestination]s: a sidebar section or a column
/// of the footer.
///
/// ```dart
/// const StudioNavSection(
///   title: 'Learn',
///   items: [StudioNavDestination('Widgets', href: '/widgets')],
/// )
/// ```
class StudioNavSection {
  /// A section called [title] holding [items], with an optional [icon]
  /// before its heading.
  const StudioNavSection({required this.title, required this.items, this.icon});

  /// The section's title (empty: the items alone, with no heading).
  final String title;

  /// The icon before the heading, in the heading's muted ink, or null.
  final IconData? icon;

  /// Its links.
  final List<StudioNavDestination> items;
}
