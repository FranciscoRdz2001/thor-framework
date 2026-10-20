import 'package:thor_studio/thor_studio.dart';
import 'package:thor_ui/router.dart' show RequestScope;
import 'package:thor_ui/thor_ui.dart';

import '../../../core/i18n/docs_locale.dart';

/// Where the results are drawn (`search.js` fills it).
const searchResultsId = 'docs-results';

/// The results: Pagefind's hits written by `search.js` (a list of
/// `.docs-hit`, which no widget builds), styled by the theme's roles.
class SearchResults extends StatelessWidget {
  /// The results.
  const SearchResults({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final extra = StudioExtraColors.of(context);
    // A site published under a path (`/thor`): the script and the index are
    // under it too.
    final base = '${RequestScope.of(context).publicPathPrefix}/';
    return StudioAttributes(
      {
        'id': searchResultsId,
        'aria-live': 'polite',
        'data-base': base,
        // The messages travel in the page, in the reader's language.
        'data-msg-prompt': t.searchPrompt,
        'data-msg-one': t.searchResultOne('{query}'),
        // One message per plural category the language uses (`search.js`
        // picks with `Intl.PluralRules`); `other` always.
        'data-msg-other': t.searchResultMany('{count}', '{query}'),
        'data-msg-none': t.searchNone('{query}'),
        'data-msg-more': t.searchShowMore('{count}'),
        'data-msg-less': t.searchShowLess,
        'data-msg-best': t.searchBestMatch,
        'data-msg-error': t.searchNoIndex,
      },
      // Without JavaScript the text stays: a static site has no server to
      // answer a query.
      child: Styled(
        descendants: {
          '.docs-hit-note': StyleProps(
            margin: const EdgeInsets.only(bottom: StudioSpacing.lg),
            textStyle: text.bodyLarge.copyWith(color: scheme.onSurfaceVariant!),
          ),
          '.docs-hit': const StyleProps(
            margin: EdgeInsets.only(bottom: StudioSpacing.lg),
          ),
          '.docs-hit-group': const StyleProps(
            margin: EdgeInsets.only(bottom: StudioSpacing.xl),
          ),
          '.docs-hit-section': StyleProps(
            margin: const EdgeInsets.only(bottom: StudioSpacing.sm),
            padding: const EdgeInsets.only(bottom: StudioSpacing.xs),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
            ),
            textStyle: text.labelLarge.copyWith(
              color: scheme.onSurfaceVariant!,
            ),
          ),
          '.docs-hit-more': StyleProps(
            padding: const EdgeInsets.symmetric(
              horizontal: StudioSpacing.sm,
              vertical: StudioSpacing.xxs,
            ),
            // A stylesheet rule has no `MouseRegion`.
            cursor: SystemMouseCursors.click,
            decoration: BoxDecoration(
              color: scheme.surfaceContainer,
              border: Border.all(color: scheme.outlineVariant),
              borderRadius: BorderRadius.circular(StudioRadii.control),
            ),
            textStyle: text.labelMedium.copyWith(color: scheme.onSurface),
          ),
          '.docs-hit-title': StyleProps(
            textStyle: text.titleLarge.copyWith(
              color: scheme.onSurface,
              decoration: TextDecoration.none,
            ),
          ),
          '.docs-hit-title:hover': const StyleProps(
            textStyle: TextStyle(decoration: TextDecoration.underline),
          ),
          '.docs-hit-excerpt': StyleProps(
            margin: const EdgeInsets.only(top: StudioSpacing.xxs),
            textStyle: text.bodyMedium.copyWith(color: extra.onSurfaceSoft),
          ),
          '.docs-hit-excerpt mark': StyleProps(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: extra.accentWash,
              borderRadius: BorderRadius.circular(StudioRadii.small),
            ),
            textStyle: TextStyle(color: scheme.onSurface),
          ),
        },
        child: Text(
          t.searchNeedsJs,
          style: text.bodyLarge.copyWith(color: scheme.onSurfaceVariant!),
        ),
      ),
    );
  }
}
