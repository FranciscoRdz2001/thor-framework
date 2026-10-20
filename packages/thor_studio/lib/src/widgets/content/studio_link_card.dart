import 'package:thor_ui/thor_ui.dart';

import '../../theme/component_themes/studio_card_theme.dart';
import '../../theme/studio_extra_colors.dart';
import '../../tokens/color/studio_surface_colors.dart';
import 'studio_content_icons.dart';

/// A card that is one link: an optional icon (in the accent, on a square of
/// its tint), a title and a description.
///
/// ```dart
/// StudioLinkCard(
///   title: 'Architecture',
///   description: 'View, ViewModel, Repository and Service, the Flutter way.',
///   href: '/architecture',
/// )
/// ```
///
/// The whole card is the `<a>`: one tab stop, one accessible name (the title
/// then the description). Hover darkens the border and turns the card to
/// the canvas; pressing squeezes it to `scale(.985)`; with [external] a
/// small arrow after the title points out and the link opens in a new tab.
/// The look is `StudioCardThemeData` (28 px corners, a hairline, no shadow).
///
/// `// web:` the hover only applies where there is a pointer that hovers
/// (never on touch). The color change is not movement, so it stays under
/// `prefers-reduced-motion`; the squeeze goes.
class StudioLinkCard extends StatelessWidget implements ThorElementWidget {
  /// A card titled [title] that goes to [href].
  const StudioLinkCard({
    super.key,
    required this.title,
    required this.href,
    this.description,
    this.icon,
    this.external = false,
  });

  /// The card's title.
  final String title;

  /// Where it goes.
  final String href;

  /// A sentence under the title.
  final String? description;

  /// A small icon above the title.
  final IconData? icon;

  /// A link to another site: opens in a new tab and shows an out arrow.
  final bool external;

  @override
  Widget build(BuildContext context) {
    final card = StudioCardThemeData.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final extra = StudioExtraColors.of(context);
    final titleText = Text(
      title,
      style: text.titleMedium.copyWith(fontSize: 15, color: scheme.onSurface),
    );
    return HoverGroup(
      child: Styled(
        duration: card.duration,
        curve: card.curve,
        style: const StyleProps(
          scale: 1,
        ).when(pressed: StyleProps(scale: card.pressScale)),
        child: Link(
          href: RouteUrl(href),
          newTab: external,
          child: AnimatedContainer(
            duration: card.hoverDuration,
            curve: card.curve,
            padding: card.padding,
            decoration: BoxDecoration(
              color: card.color.when(groupHover: StudioSurfaceColors.canvas),
              border: Border.all(
                color: card.borderColor.when(groupHover: extra.lineStrong),
              ),
              borderRadius: BorderRadius.circular(card.radius),
              boxShadow: card.shadows,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 6,
              children: [
                if (icon case final icon?)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Semantics(
                          hidden: true,
                          // The icon in the accent on a square of its tint.
                          child: Container(
                            width: 36,
                            height: 36,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: scheme.accentContainer,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(icon, size: 18, color: scheme.accent),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (external)
                  Row(
                    spacing: 6,
                    children: [
                      Flexible(child: titleText),
                      Semantics(
                        hidden: true,
                        child: Icon(
                          StudioContentIcons.arrowUpRight,
                          size: 14,
                          color: scheme.onSurfaceVariant!,
                        ),
                      ),
                    ],
                  )
                else
                  titleText,
                if (description != null)
                  Text(
                    description!,
                    style: text.bodyMedium.copyWith(
                      color: scheme.onSurfaceVariant!,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
