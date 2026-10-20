import 'package:thor_ui/thor_ui.dart';

import '../../icons.dart';
import '../../l10n/studio_localizations.dart';
import '../../theme/component_themes/studio_nav_theme.dart';
import '../../theme/studio_extra_text_styles.dart';
import '../../tokens/shape/studio_radii.dart';
import '../../tokens/spacing/studio_spacing.dart';

/// The search entry of the top bar: a pill with a magnifier, a placeholder
/// and an optional keyboard hint. It is a plain link to the search page, so
/// it works with no JavaScript; a site that has a command palette can open
/// it from the same pill. On a phone it shrinks to the magnifier.
///
/// ```dart
/// StudioSearchPill(
///   href: '/search',
///   placeholder: l10n.searchPlaceholder, // 'Search the docs'
///   shortcut: '⌘K',
/// )
/// ```
///
/// `// web:` Flutter's `SearchAnchor` opens a view over the page; here the
/// pill navigates to [href] (a results page the server renders).
class StudioSearchPill extends StatelessWidget
    implements ThorElementWidget, MultipleRoots {
  /// A pill that leads to [href], showing [placeholder].
  const StudioSearchPill({
    super.key,
    required this.href,
    this.placeholder,
    this.shortcut,
  });

  /// The search page.
  final String href;

  /// What the pill says (also its accessible name on a phone); default:
  /// `StudioLocalizations.search`.
  final String? placeholder;

  /// The keyboard hint at the end of the pill (`⌘K`); null shows none.
  /// Wiring the keys is the site's job.
  final String? shortcut;

  @override
  Widget build(BuildContext context) {
    final nav = StudioNavThemeData.of(context);
    final text = Theme.of(context).textTheme;
    final placeholder =
        this.placeholder ?? StudioLocalizations.of(context).search;
    return Widget.fragment([
      // From `md` the whole pill (it takes the room the bar leaves, up to the
      // theme's width); below it only the magnifier: a phone has no room for
      // a placeholder.
      Expanded(
        child: ResponsiveVisibility(
          visibleFrom: WindowSizeClass.medium,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Expanded(
                child: Styled(
                  duration: nav.duration,
                  curve: nav.curve,
                  style: const StyleProps(
                    scale: 1,
                  ).when(pressed: StyleProps(scale: nav.pressScale)),
                  child: Link(
                    href: RouteUrl(href),
                    label: placeholder,
                    child: AnimatedContainer(
                      duration: nav.duration,
                      curve: nav.curve,
                      height: nav.searchHeight,
                      constraints: BoxConstraints(maxWidth: nav.searchMaxWidth),
                      padding: const EdgeInsets.only(
                        left: StudioSpacing.sm,
                        right: 6,
                      ),
                      decoration: BoxDecoration(
                        color: nav.searchColor.when(
                          hover: nav.searchHoverColor,
                        ),
                        border: Border.all(color: nav.barBorderColor),
                        borderRadius: BorderRadius.circular(
                          StudioRadii.control,
                        ),
                      ),
                      child: Row(
                        spacing: StudioSpacing.xs,
                        children: [
                          ExcludeSemantics(
                            child: Icon(
                              StudioIcons.search,
                              size: 16,
                              color: nav.hintColor,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              placeholder,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.bodyMedium.copyWith(
                                color: nav.hintColor,
                              ),
                            ),
                          ),
                          if (shortcut != null) _KeyHint(shortcut!),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      // On a phone the magnifier goes to the end of the bar.
      const ResponsiveVisibility(
        hiddenFrom: WindowSizeClass.medium,
        child: Spacer(),
      ),
      ResponsiveVisibility(
        hiddenFrom: WindowSizeClass.medium,
        child: Link(
          href: RouteUrl(href),
          label: placeholder,
          child: AnimatedContainer(
            duration: nav.duration,
            curve: nav.curve,
            width: nav.searchHeight,
            height: nav.searchHeight,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: nav.barColor.when(hover: nav.itemHoverColor),
              borderRadius: BorderRadius.circular(StudioRadii.control),
            ),
            child: Icon(StudioIcons.search, size: 18, color: nav.hintColor),
          ),
        ),
      ),
    ]);
  }
}

/// The keyboard hint inside the pill.
class _KeyHint extends StatelessWidget implements ThorElementWidget {
  const _KeyHint(this.keys);

  final String keys;

  @override
  Widget build(BuildContext context) {
    final nav = StudioNavThemeData.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: StudioSpacing.xs,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: nav.hintBackground,
        borderRadius: BorderRadius.circular(StudioRadii.small),
      ),
      child: Semantics(
        role: SemanticsRole.keyboardKey,
        child: Text(
          keys,
          style: StudioExtraTextStyles.of(
            context,
          ).codeSmall.copyWith(color: nav.hintColor),
        ),
      ),
    );
  }
}
