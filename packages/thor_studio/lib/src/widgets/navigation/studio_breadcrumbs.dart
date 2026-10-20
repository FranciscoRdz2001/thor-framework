import 'package:thor_ui/thor_ui.dart';

import '../../attributes.dart';
import '../../icons.dart';
import '../../l10n/studio_localizations.dart';
import '../../theme/component_themes/studio_nav_theme.dart';
import '../../theme/studio_extra_colors.dart';
import '../../tokens/spacing/studio_spacing.dart';
import 'studio_nav_destination.dart';

/// Where the page sits in the site: a trail of links ending in the current
/// page.
///
/// ```dart
/// StudioBreadcrumbs(
///   trail: [
///     StudioNavDestination('Learn', href: '/learn'),
///     StudioNavDestination('Widgets', href: '/learn/widgets'),
///   ],
///   selectedIndex: 1, // the current page: plain text, not a link
/// )
/// ```
///
/// A `<nav>` holding a list: every item but the current one is a link, the
/// current one is plain text with `aria-current="page"`, and the separators
/// are decoration the screen reader skips. The trail wraps on a phone.
///
/// `// web:` Flutter has no breadcrumb; this is a `<nav>` (named by [label],
/// default `StudioLocalizations.breadcrumb`) holding a `<ul>`, and the current
/// crumb carries `aria-current="page"`.
class StudioBreadcrumbs extends StatelessWidget implements ThorElementWidget {
  /// A trail of [trail]; [label] names the landmark.
  const StudioBreadcrumbs({
    super.key,
    required this.trail,
    this.selectedIndex,
    this.label,
  });

  /// The pages from the section down to the current one.
  final List<StudioNavDestination> trail;

  /// The index in [trail] of the current page (usually the last).
  final int? selectedIndex;

  /// The landmark's accessible name (`aria-label`; default:
  /// `StudioLocalizations.breadcrumb`).
  final String? label;

  @override
  Widget build(BuildContext context) {
    final nav = StudioNavThemeData.of(context);
    final text = Theme.of(context).textTheme;
    return Semantics(
      role: SemanticsRole.navigation,
      label: label ?? StudioLocalizations.of(context).breadcrumb,
      // A column between the two roles: a nav and a list on one element would
      // merge into a single `<ul>`.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            role: SemanticsRole.list,
            child: Wrap(
              spacing: StudioSpacing.xxs,
              runSpacing: StudioSpacing.xxs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final (i, crumb) in trail.indexed) ...[
                  if (i > 0)
                    ExcludeSemantics(
                      child: Icon(
                        StudioIcons.chevronRight,
                        size: 14,
                        color: StudioExtraColors.of(context).onSurfaceFaint,
                      ),
                    ),
                  Semantics(
                    role: SemanticsRole.listItem,
                    child: i == selectedIndex
                        ? StudioAttributes(
                            const {'aria-current': 'page'},
                            child: Text(
                              crumb.label,
                              style: text.labelMedium.copyWith(
                                color: nav.selectedItemColor,
                              ),
                            ),
                          )
                        : Link(
                            href: RouteUrl(crumb.href),
                            child: Text(
                              crumb.label,
                              style: text.labelMedium.copyWith(
                                color: nav.itemColor.when(
                                  hover: nav.selectedItemColor,
                                ),
                              ),
                            ),
                          ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
