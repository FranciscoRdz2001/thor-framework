import 'package:thor_ui/thor_ui.dart';

import '../../theme/component_themes/studio_nav_theme.dart';
import '../../tokens/spacing/studio_spacing.dart';
import '../navigation/nav_item.dart';
import '../navigation/studio_nav_section.dart';

/// The end of the page: columns of links, the [brand] and a line of [legal]
/// text with the site's [actions] (theme toggle, locale switcher).
///
/// ```dart
/// StudioFooter(
///   brand: StudioBrand(name: 'thor'),
///   sections: [
///     StudioNavSection(
///       title: l10n.footerCommunity,
///       items: [StudioNavDestination('GitHub', href: 'https://github.com')],
///     ),
///   ],
///   legal: l10n.license, // 'MIT licensed'
///   actions: [StudioLocaleSwitcher(…), StudioThemeToggle()],
/// )
/// ```
///
/// A `<footer>` landmark; the columns are `<nav>`s named by their titles and
/// stack on a phone.
///
/// `// web:` Flutter has no footer; the `<footer>` is the page's
/// `contentinfo` landmark, and each column of links is a `<nav>` so a screen
/// reader lists them.
class StudioFooter extends StatelessWidget implements ThorElementWidget {
  /// A footer of [sections].
  const StudioFooter({
    super.key,
    this.brand,
    this.sections = const [],
    this.legal,
    this.actions = const [],
    this.maxWidth,
  });

  /// The widest the footer's content grows to, centred (line it up with
  /// the page: `StudioScaffold.maxPageWidth`); null fills the width.
  final double? maxWidth;

  /// The product mark and name, over the first column.
  final Widget? brand;

  /// The columns of links.
  final List<StudioNavSection> sections;

  /// The small print (license, copyright).
  final String? legal;

  /// Controls at the end of the bottom line.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final nav = StudioNavThemeData.of(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      role: SemanticsRole.contentInfo,
      child: Container(
        padding:
            const EdgeInsets.symmetric(
              horizontal: StudioSpacing.md,
              vertical: StudioSpacing.xl,
            ).when(
              medium: const EdgeInsets.symmetric(
                horizontal: StudioSpacing.lg,
                vertical: StudioSpacing.xxl,
              ),
            ),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: nav.barBorderColor)),
        ),
        child: Align(
          alignment: Alignment.topCenter,
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(maxWidth: maxWidth ?? double.infinity),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: StudioSpacing.xl,
              children: [
                Grid(
                  layout: const GridLayout(columns: 1, gap: StudioSpacing.lg)
                      .when(
                        medium: const GridLayout(
                          columns: 4,
                          gap: StudioSpacing.lg,
                        ),
                      ),
                  children: [
                    ?brand,
                    for (final section in sections)
                      Semantics(
                        role: SemanticsRole.navigation,
                        label: section.title,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: StudioSpacing.xxs,
                          children: [
                            Padding(
                              padding: EdgeInsets.fromLTRB(
                                nav.itemPadding.left,
                                nav.itemPadding.top,
                                nav.itemPadding.right,
                                StudioSpacing.xxs,
                              ),
                              child: Text(
                                section.title,
                                style: text.titleSmall.copyWith(
                                  color: nav.sectionTitleColor,
                                ),
                              ),
                            ),
                            for (final item in section.items) NavItemLink(item),
                          ],
                        ),
                      ),
                  ],
                ),
                Row(
                  spacing: StudioSpacing.xs,
                  children: [
                    if (legal != null)
                      Expanded(
                        child: Text(
                          legal!,
                          style: text.bodySmall.copyWith(
                            color: scheme.onSurfaceVariant!,
                          ),
                        ),
                      )
                    else
                      const Spacer(),
                    ...actions,
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
