import 'package:thor_ui/thor_ui.dart';

import '../../icons.dart';
import '../../l10n/studio_localizations.dart';
import '../../theme/component_themes/studio_card_theme.dart';
import '../../theme/component_themes/studio_nav_theme.dart';
import '../../tokens/shape/studio_radii.dart';
import '../../tokens/spacing/studio_spacing.dart';
import 'nav_item.dart';
import 'studio_locale_option.dart';
import 'studio_nav_destination.dart';

/// The language menu: a pill showing the current language that opens a list
/// of links, one per language, each to the same page translated.
///
/// ```dart
/// StudioLocaleSwitcher(
///   locales: [
///     StudioLocaleOption(
///       locale: Locale('es'), label: 'Español', href: '/es/widgets'),
///     StudioLocaleOption(
///       locale: Locale('en'), label: 'English', href: '/en/widgets'),
///   ],
///   selectedIndex: 0, // Spanish is the language of this page
/// )
/// ```
///
/// It takes the list and the hrefs, so it knows nothing about how the site
/// routes. The menu is a native popover (open, Esc and click-outside are the
/// browser's, no JavaScript) and every option is a real link carrying
/// `hreflang` and `lang`.
///
/// `// web:` Flutter picks a language with a `Locale` and a delegate, not a
/// menu of links; the menu is a native popover, so the id (one per page) is the
/// popover's DOM id, and the options are links because each language is its
/// own address.
class StudioLocaleSwitcher extends StatelessWidget
    implements ThorElementWidget, MultipleRoots {
  /// A menu of [locales]; [label] names the button.
  const StudioLocaleSwitcher({
    super.key,
    this.id,
    required this.locales,
    this.selectedIndex,
    this.label,
  });

  /// The menu's DOM id (one per page). Optional: the page names it.
  final String? id;

  /// The languages on offer.
  final List<StudioLocaleOption> locales;

  /// The index in [locales] of the language of this page.
  final int? selectedIndex;

  /// The button's accessible name (default: `StudioLocalizations.language`).
  final String? label;

  @override
  Widget build(BuildContext context) {
    final nav = StudioNavThemeData.of(context);
    final card = StudioCardThemeData.of(context);
    final text = Theme.of(context).textTheme;
    final current = selectedIndex == null ? null : locales[selectedIndex!];
    return Popover(
      id: id,
      label: label ?? StudioLocalizations.of(context).language,
      style: ButtonStyle(
        backgroundColor: WidgetStatePropertyAll(nav.searchColor),
        foregroundColor: WidgetStatePropertyAll(nav.selectedItemColor),
        overlayColor: WidgetStatePropertyAll(nav.searchHoverColor),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.only(left: StudioSpacing.md, right: StudioSpacing.sm),
        ),
        minimumSize: WidgetStatePropertyAll(Size(0, nav.searchHeight)),
        shape: const WidgetStatePropertyAll(StadiumBorder()),
        textStyle: WidgetStatePropertyAll(text.labelLarge),
      ),
      decoration: BoxDecoration(
        color: card.color,
        border: Border.all(color: card.borderColor),
        borderRadius: BorderRadius.circular(StudioRadii.inner * 2),
      ),
      menuPadding: const EdgeInsets.all(StudioSpacing.xs),
      constraints: const BoxConstraints(minWidth: 176),
      trigger: Row(
        spacing: StudioSpacing.xxs,
        children: [
          Text((current ?? locales.first).label),
          ExcludeSemantics(
            child: Icon(
              StudioIcons.chevronDown,
              size: 14,
              color: nav.hintColor,
            ),
          ),
        ],
      ),
      child: Semantics(
        role: SemanticsRole.list,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 2,
          children: [
            for (final (i, locale) in locales.indexed)
              Semantics(
                role: SemanticsRole.listItem,
                child: NavItemLink(
                  StudioNavDestination(locale.label, href: locale.href),
                  current: i == selectedIndex,
                  attributes: {
                    'hreflang': locale.locale.toLanguageTag(),
                    'lang': locale.locale.toLanguageTag(),
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
