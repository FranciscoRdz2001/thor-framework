import 'package:thor_studio/thor_studio.dart';
import 'package:thor_ui/thor_ui.dart';

import '../i18n/docs_locale.dart';

/// "On this page" under the lead, for a window too narrow for the
/// contents' column (below 1280 px): a native disclosure, closed at first,
/// with the page's headings as links.
class DocsTocDisclosure extends StatelessWidget {
  /// The headings [entries].
  const DocsTocDisclosure({super.key, required this.entries});

  /// The page's headings.
  final List<StudioTocEntry> entries;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(StudioRadii.inner),
      side: BorderSide(color: scheme.outlineVariant),
    );
    final linkColor = scheme.onSurfaceVariant!.when(hover: scheme.onSurface);
    return ExpansionTile(
      shape: shape,
      collapsedShape: shape,
      backgroundColor: StudioSurfaceColors.canvas,
      collapsedBackgroundColor: StudioSurfaceColors.canvas,
      iconColor: scheme.onSurfaceVariant!,
      collapsedIconColor: scheme.onSurfaceVariant!,
      tilePadding: const EdgeInsets.symmetric(horizontal: StudioSpacing.md),
      title: Text(
        t.tocOnThisPage,
        style: text.titleSmall.copyWith(color: scheme.onSurfaceVariant!),
      ),
      childrenPadding: const EdgeInsets.fromLTRB(
        StudioSpacing.md,
        0,
        StudioSpacing.md,
        StudioSpacing.sm,
      ),
      children: [
        Semantics(
          role: SemanticsRole.navigation,
          label: t.tocOnThisPage,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final entry in entries)
                Link(
                  href: RouteUrl(entry.href),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      entry.depth * StudioSpacing.sm,
                      6,
                      0,
                      6,
                    ),
                    child: Text(
                      entry.label,
                      style: text.bodyMedium.copyWith(
                        fontSize: 13,
                        color: linkColor,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
