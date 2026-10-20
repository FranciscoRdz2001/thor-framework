import 'package:thor_ui/thor_ui.dart';

import '../../attributes.dart';
import '../../icons.dart';
import '../../l10n/studio_localizations.dart';
import '../../theme/component_themes/studio_card_theme.dart';
import '../../theme/component_themes/studio_nav_theme.dart';
import '../../tokens/spacing/studio_spacing.dart';
import 'studio_nav_destination.dart';

/// Previous and next page at the end of an article: two big cards, one at
/// each side.
///
/// ```dart
/// StudioPagerLinks(
///   previousLabel: l10n.previous, // 'Previous'
///   nextLabel: l10n.next,         // 'Next'
///   previous: StudioNavDestination('Layout', href: '/layout'),
///   next: StudioNavDestination('Navigation', href: '/navigation'),
/// )
/// ```
///
/// A `<nav>` of two links (`rel="prev"` and `rel="next"`); a missing side
/// leaves its cell empty so the other card keeps its column. The cards stack
/// on a phone. On hover a card lifts 2 px and its arrow nudges toward where
/// it points; pressed, it squeezes to `scale(.985)` (none of it under
/// `prefers-reduced-motion`).
///
/// `// web:` the links carry `rel="prev"` and `rel="next"` (search engines
/// read the sequence); Flutter has no pager.
class StudioPagerLinks extends StatelessWidget implements ThorElementWidget {
  /// A pager with [previous] and/or [next].
  const StudioPagerLinks({
    super.key,
    this.previous,
    this.next,
    this.previousLabel,
    this.nextLabel,
    this.label,
  });

  /// The page before this one, if any.
  final StudioNavDestination? previous;

  /// The page after this one, if any.
  final StudioNavDestination? next;

  /// The caption over the previous page's title (default:
  /// `StudioLocalizations.previous`).
  final String? previousLabel;

  /// The caption over the next page's title (default:
  /// `StudioLocalizations.next`).
  final String? nextLabel;

  /// The landmark's accessible name (`aria-label`; default:
  /// `StudioLocalizations.pagination`).
  final String? label;

  @override
  Widget build(BuildContext context) {
    final l10n = StudioLocalizations.of(context);
    return Semantics(
      role: SemanticsRole.navigation,
      label: label ?? l10n.pagination,
      child: Grid(
        layout: const GridLayout(
          columns: 1,
          gap: StudioSpacing.md,
        ).when(medium: const GridLayout(columns: 2, gap: StudioSpacing.md)),
        children: [
          if (previous case final page?)
            _PagerCard(
              page,
              caption: previousLabel ?? l10n.previous,
              rel: 'prev',
              forward: false,
            )
          else
            const SizedBox.shrink(),
          if (next case final page?)
            _PagerCard(
              page,
              caption: nextLabel ?? l10n.next,
              rel: 'next',
              forward: true,
            )
          else
            const SizedBox.shrink(),
        ],
      ),
    );
  }
}

class _PagerCard extends StatelessWidget implements ThorElementWidget {
  const _PagerCard(
    this.page, {
    required this.caption,
    required this.rel,
    required this.forward,
  });

  final StudioNavDestination page;
  final String caption;
  final String rel;
  final bool forward;

  @override
  Widget build(BuildContext context) {
    final card = StudioCardThemeData.of(context);
    final nav = StudioNavThemeData.of(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final arrow = ExcludeSemantics(
      child: Styled(
        duration: card.hoverDuration,
        curve: card.curve,
        style: const StyleProps(offset: Offset.zero).when(
          groupHover: StyleProps(
            offset: Offset(forward ? card.arrowNudge : -card.arrowNudge, 0),
          ),
        ),
        child: Icon(
          forward ? StudioIcons.arrowRight : StudioIcons.chevronLeft,
          size: nav.iconSize,
          color: nav.hintColor,
        ),
      ),
    );
    return StudioAttributes(
      {'rel': rel},
      child: HoverGroup(
        child: Styled(
          duration: card.hoverDuration,
          curve: card.curve,
          style: const StyleProps(offset: Offset.zero, scale: 1).when(
            hover: StyleProps(offset: Offset(0, -card.hoverLift)),
            pressed: StyleProps(scale: card.pressScale),
          ),
          child: Link(
            href: RouteUrl(page.href),
            child: AnimatedContainer(
              duration: nav.duration,
              curve: nav.curve,
              padding: card.padding,
              decoration: BoxDecoration(
                color: card.color,
                border: Border.all(
                  color: card.borderColor.when(hover: card.hoverBorderColor),
                ),
                borderRadius: BorderRadius.circular(card.radius),
                boxShadow: card.shadows,
              ),
              child: Row(
                spacing: StudioSpacing.md,
                children: [
                  if (!forward) arrow,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: forward
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      spacing: StudioSpacing.xxs,
                      children: [
                        Text(
                          caption,
                          style: text.labelMedium.copyWith(
                            color: nav.hintColor,
                          ),
                        ),
                        Text(
                          page.label,
                          textAlign: forward ? TextAlign.end : TextAlign.start,
                          style: text.titleLarge.copyWith(
                            color: scheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (forward) arrow,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
