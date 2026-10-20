import 'package:thor_ui/thor_ui.dart';

import '../../icons.dart';
import '../../l10n/studio_localizations.dart';
import '../../theme/component_themes/studio_nav_theme.dart';
import '../../tokens/spacing/studio_spacing.dart';
import '../navigation/nav_item.dart';
import '../navigation/studio_nav_destination.dart';
import 'studio_scaffold_scope.dart';

/// The bar at the top of every page: [brand] and the primary [links] on the
/// left, the [search] pill in the middle and the [actions] on the right. It
/// sticks to the top while the page scrolls.
///
/// ```dart
/// StudioTopBar(
///   brand: StudioBrand(name: 'thor'),
///   links: [
///     StudioNavDestination('Guide', href: '/guide'),
///     StudioNavDestination('API', href: '/api'),
///   ],
///   selectedIndex: 0, // the Guide link is the current one
///   search: StudioSearchPill(href: '/search'),
///   actions: [StudioThemeToggle()],
/// )
/// ```
///
/// Inside a `StudioScaffold` with a sidebar it also shows the menu button
/// that opens the drawer (below `lg`), so a phone reaches the navigation.
/// The links show from `md`; put them in the sidebar as well for a phone.
///
/// `// web:` Flutter's `AppBar` is not sticky and has no landmark; this is a
/// `<header>` that stays under the notch: its top padding is the device's
/// safe-area inset (`SafeArea`), so a standalone web app on a phone does not
/// slide under the status bar.
class StudioTopBar extends StatelessWidget implements ThorElementWidget {
  /// A bar with [brand] and the optional [links], [search] and [actions].
  const StudioTopBar({
    super.key,
    required this.brand,
    this.links = const [],
    this.selectedIndex,
    this.linksLabel,
    this.search,
    this.actions = const [],
    this.linksVisibleFrom = WindowSizeClass.medium,
  });

  /// From which window size the [links] show (below it they are left to the
  /// drawer).
  final WindowSizeClass linksVisibleFrom;

  /// The product mark and name (a `StudioBrand`, or any widget).
  final Widget brand;

  /// The primary sections of the site.
  final List<StudioNavDestination> links;

  /// The index in [links] of the current one, which is marked (like
  /// `NavigationBar.selectedIndex`).
  final int? selectedIndex;

  /// The accessible name of the links' `<nav>` (default:
  /// `StudioLocalizations.sections`).
  final String? linksLabel;

  /// A `StudioSearchPill`.
  final Widget? search;

  /// What sits at the end: the theme toggle, the locale switcher, links.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final nav = StudioNavThemeData.of(context);
    final scope = StudioScaffoldScope.maybeOf(context);
    return Styled(
      style: const StyleProps(
        position: BoxPosition.sticky(top: Length.zero),
        zIndex: 20,
      ),
      child: Semantics(
        role: SemanticsRole.header,
        child: Container(
          decoration: BoxDecoration(
            color: nav.barColor,
            border: Border(bottom: BorderSide(color: nav.barBorderColor)),
          ),
          // The inset above the bar (a notch, the status bar of an installed
          // web app); the bar keeps its own height under it.
          child: SafeArea(
            bottom: false,
            child: Container(
              height: nav.barHeight,
              padding: const EdgeInsets.symmetric(horizontal: StudioSpacing.md)
                  .when(
                    medium: const EdgeInsets.symmetric(
                      horizontal: StudioSpacing.lg,
                    ),
                  ),
              child: Row(
                spacing: StudioSpacing.xs,
                children: [
                  if (scope != null)
                    ResponsiveVisibility(
                      hiddenFrom: WindowSizeClass.expanded,
                      child: DialogTrigger(
                        id: scope.sidebarId,
                        child: IconButton(
                          onPressed: () {},
                          tooltip: scope.menuLabel,
                          icon: const Icon(StudioIcons.menu, size: 20),
                        ),
                      ),
                    ),
                  brand,
                  if (links.isNotEmpty) const SizedBox(width: StudioSpacing.xs),
                  if (links.isNotEmpty)
                    ResponsiveVisibility(
                      visibleFrom: linksVisibleFrom,
                      child: Semantics(
                        role: SemanticsRole.navigation,
                        label:
                            linksLabel ??
                            StudioLocalizations.of(context).sections,
                        child: Row(
                          spacing: StudioSpacing.xxs,
                          children: [
                            for (final (i, link) in links.indexed)
                              NavItemLink(link, current: i == selectedIndex),
                          ],
                        ),
                      ),
                    ),
                  if (search != null) search! else const Spacer(),
                  ...actions,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
