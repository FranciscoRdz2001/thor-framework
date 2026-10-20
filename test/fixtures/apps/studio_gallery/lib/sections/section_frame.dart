import 'package:thor_studio/thor_studio.dart';
import 'package:thor_ui/thor_ui.dart';

/// One section of the gallery: a mono caption (what it shows, a detail) over
/// a card, in the v2 theme.
class SectionFrame extends StatelessWidget implements ThorElementWidget {
  /// A [child] under [label] and [meta].
  const SectionFrame({
    super.key,
    required this.label,
    required this.meta,
    required this.child,
    this.maxWidth = 820,
  });

  /// What the section shows.
  final String label;

  /// A detail on the right.
  final String meta;

  /// The content.
  final Widget child;

  /// Its widest.
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final caption = StudioExtraTextStyles.of(
      context,
    ).codeSmall.copyWith(color: scheme.onSurfaceVariant!);
    final card = StudioCardThemeData.of(context);
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: StudioSpacing.xs,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: StudioSpacing.xxs,
              ),
              // On a phone the detail goes under the caption: the two never
              // fit in one line there.
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: StudioSpacing.sm,
                children: [
                  Text(label, style: caption),
                  Text(meta, style: caption),
                ],
              ),
            ),
            Semantics(
              role: SemanticsRole.article,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(
                      horizontal: StudioSpacing.lg,
                      vertical: StudioSpacing.lg,
                    ).when(
                      medium: const EdgeInsets.symmetric(
                        horizontal: StudioSpacing.xxl,
                        vertical: StudioSpacing.xl,
                      ),
                    ),
                decoration: BoxDecoration(
                  color: card.color,
                  border: Border.all(color: card.borderColor),
                  borderRadius: BorderRadius.circular(card.radius),
                ),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
