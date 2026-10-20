import 'package:thor_ui/thor_ui.dart';

import '../../attributes.dart';
import '../../icons.dart';
import '../../l10n/studio_localizations.dart';
import '../../theme/component_themes/studio_nav_theme.dart';
import '../../theme/studio_extra_colors.dart';
import '../../tokens/spacing/studio_spacing.dart';
import '../../tokens/typography/studio_font_weights.dart';
import 'studio_markup.dart';
import 'studio_toc_entry.dart';

/// "On this page": the headings of the current page as a list of anchors,
/// with a rule that marks the section being read.
///
/// ```dart
/// StudioTableOfContents(
///   title: l10n.onThisPage, // 'On this page'
///   entries: [
///     StudioTocEntry('Installing', href: '#installing'),
///     StudioTocEntry('With pub', href: '#pub', depth: 1),
///   ],
///   scrollSpy: true,
/// )
/// ```
///
/// Plain anchors work with no JavaScript. With [scrollSpy] the browser
/// itself follows the reading position (CSS scroll markers, no script);
/// where it can't, the list stays plain anchors, or marks [current] when
/// the page knows the section (a server-rendered one).
///
/// `// web:` Flutter has no table of contents; this is a `<nav>` of anchors
/// whose current entry carries `aria-current="location"`. When the section on
/// screen changes, the rule and the text of the entry that loses it fade out
/// while the next one's fade in (120 ms, no movement to drop under
/// `prefers-reduced-motion`; the color change just becomes instant).
class StudioTableOfContents extends StatelessWidget
    implements ThorElementWidget {
  /// A table of contents titled [title] listing [entries].
  const StudioTableOfContents({
    super.key,
    required this.entries,
    this.title,
    this.current,
    this.scrollSpy = false,
    this.backToTopLabel,
    this.backToTopHref = '#',
  });

  /// The text of the "back to top" link under the list (a hairline, an
  /// arrow and this label); null shows none.
  final String? backToTopLabel;

  /// Where the "back to top" link goes (default `#`, the top of the page).
  final String backToTopHref;

  /// The heading of the list (also the landmark's accessible name);
  /// default: `StudioLocalizations.onThisPage`.
  final String? title;

  /// The headings, in page order.
  final List<StudioTocEntry> entries;

  /// The `href` of the section to mark as current. Ignored with
  /// [scrollSpy], where the reading position decides.
  final String? current;

  /// Marks the section being read as the page scrolls, with CSS scroll
  /// markers (`scroll-target-group` and `:target-current`): no JavaScript,
  /// and a plain list in browsers without them.
  final bool scrollSpy;

  @override
  Widget build(BuildContext context) {
    final nav = StudioNavThemeData.of(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final title = this.title ?? StudioLocalizations.of(context).onThisPage;
    return Semantics(
      role: SemanticsRole.navigation,
      label: title,
      child: Styled(
        // web: the browser's own scroll spy.
        style: StyleProps(
          scrollTargetGroup: scrollSpy ? ScrollTargetGroup.auto : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: StudioSpacing.sm,
          children: [
            Semantics(
              headingLevel: 2,
              child: Text(
                title,
                style: text.titleSmall.copyWith(color: nav.sectionTitleColor),
              ),
            ),
            // The rail: one hairline the entries sit on.
            Container(
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: scheme.outlineVariant)),
              ),
              child: Semantics(
                role: SemanticsRole.list,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final entry in entries)
                      Semantics(
                        role: SemanticsRole.listItem,
                        child: _Entry(
                          entry,
                          current: !scrollSpy && entry.href == current,
                          scrollSpy: scrollSpy,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (backToTopLabel != null)
              _BackToTop(label: backToTopLabel!, href: backToTopHref),
          ],
        ),
      ),
    );
  }
}

/// The hairline and the "back to top" link under the entries.
class _BackToTop extends StatelessWidget implements ThorElementWidget {
  const _BackToTop({required this.label, required this.href});

  final String label;
  final String href;

  @override
  Widget build(BuildContext context) {
    final nav = StudioNavThemeData.of(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final color = nav.itemColor.when(hover: scheme.onSurface);
    return Container(
      padding: const EdgeInsets.only(top: StudioSpacing.sm),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: [
          Link(
            href: RouteUrl(href),
            child: Row(
              spacing: 6,
              children: [
                ExcludeSemantics(
                  child: Icon(StudioIcons.arrowUp, size: 14, color: color),
                ),
                Text(label, style: text.bodySmall.copyWith(color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

const _clear = Colors.transparent;

class _Entry extends StatelessWidget implements ThorElementWidget {
  const _Entry(this.entry, {required this.current, required this.scrollSpy});

  final StudioTocEntry entry;
  final bool current;
  final bool scrollSpy;

  @override
  Widget build(BuildContext context) {
    final nav = StudioNavThemeData.of(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final extra = StudioExtraColors.of(context);
    return StudioAttributes(
      {if (current) 'aria-current': 'location'},
      child: StudioMarkup(
        // web: the scroll spy changes the color by a selector, which no
        // widget transition sees: the entry says so itself.
        css: scrollSpy
            ? cssTransition(
                const ['color', 'border-left-color'],
                duration: nav.duration,
                curve: nav.curve,
              )
            : const {},
        // web: where the browser tracks the reading position (scroll
        // markers), the entry of the section on screen takes the accent.
        conditions: [
          if (scrollSpy)
            ConditionalCss(
              CssCondition.supports(
                'selector(:target-current)',
                const CssCondition.selector(':target-current'),
              ),
              {
                'color': scheme.accent.css,
                'font-weight': '500',
                'border-left-color': scheme.accent.css,
              },
            ),
          if (scrollSpy)
            const ConditionalCss(CssCondition.reducedMotion, {
              'transition-duration': '1ms',
            }),
        ],
        // The 2 px bar lies centred over the list's 1 px rail, so the rail
        // stays one line.
        child: Transform.translate(
          offset: const Offset(-1.5, 0),
          child: Link(
            href: RouteUrl(entry.href),
            child: AnimatedContainer(
              duration: nav.duration,
              curve: nav.curve,
              padding: EdgeInsets.fromLTRB(
                StudioSpacing.sm + entry.depth * StudioSpacing.sm,
                6,
                StudioSpacing.xs,
                6,
              ),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: current
                        ? scheme.accent
                        : _clear.when(hover: extra.lineStrong),
                    width: 2,
                  ),
                ),
              ),
              child: Text(
                entry.label,
                style: text.bodyMedium.copyWith(
                  fontSize: 13,
                  height: 1.4,
                  fontWeight: current ? StudioFontWeights.medium : null,
                  color: current
                      ? scheme.accent
                      : nav.itemColor.when(hover: nav.selectedItemColor),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
