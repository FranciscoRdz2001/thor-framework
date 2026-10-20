import 'package:thor_studio/thor_studio.dart';
import 'package:thor_ui/router.dart' show RequestScope;
import 'package:thor_ui/thor_ui.dart';

import '../core/i18n/docs_locale.dart';
import '../modules/search/search_routes.dart';

/// The search dialog's DOM id (the site script opens it).
const docsSearchDialogId = 'docs-search';

/// The search dialog of every page: the top bar's search field and ⌘K open
/// it (the site script, `search-shortcut.js`), Pagefind answers as you
/// type. Without the script the field is a link to the search page and this
/// dialog stays closed.
class DocsSearchDialog extends StatelessWidget {
  /// The dialog.
  const DocsSearchDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final prefix = RequestScope.maybeOf(context)?.publicPathPrefix ?? '';
    return StudioAttributes(
      const {'data-pagefind-ignore': 'all'},
      child: StudioSearchDialog(
        id: docsSearchDialogId,
        action: '$prefix${context.localized(searchRoute.link())}',
        label: t.searchDialogLabel,
        placeholder: t.searchHint,
        hints: [
          ('↑↓', t.searchDialogHintMove),
          ('↵', t.searchDialogHintOpen),
          ('Esc', t.searchDialogHintClose),
        ],
        results: _Results(base: '$prefix/'),
      ),
    );
  }
}

/// Where the script draws the hits: groups by section (`.dsr-group` with a
/// `.dsr-label`), rows of a title and an excerpt (`.dsr-row`), the current
/// row marked `data-current`. The messages travel in the page.
class _Results extends StatelessWidget {
  const _Results({required this.base});

  final String base;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return StudioAttributes(
      {
        'id': 'docs-search-results',
        'aria-live': 'polite',
        'data-base': base,
        'data-msg-prompt': t.searchPrompt,
        'data-msg-none': t.searchNone('{query}'),
        'data-msg-best': t.searchBestMatch,
        'data-msg-error': t.searchNoIndex,
      },
      child: Styled(
        descendants: {
          '.dsr-note': StyleProps(
            padding: const EdgeInsets.symmetric(
              horizontal: StudioSpacing.sm,
              vertical: StudioSpacing.md,
            ),
            textStyle: text.bodyMedium.copyWith(
              color: scheme.onSurfaceVariant!,
            ),
          ),
          '.dsr-group + .dsr-group': const StyleProps(
            margin: EdgeInsets.only(top: StudioSpacing.xs),
          ),
          '.dsr-label': StyleProps(
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.fromLTRB(
              StudioSpacing.sm,
              StudioSpacing.xs,
              StudioSpacing.sm,
              StudioSpacing.xxs,
            ),
            textStyle: text.titleSmall.copyWith(
              color: scheme.onSurfaceVariant!,
            ),
          ),
          '.dsr-row': StyleProps(
            cursor: SystemMouseCursors.click,
            padding: const EdgeInsets.symmetric(
              horizontal: StudioSpacing.sm,
              vertical: 6,
            ),
            constraints: const BoxConstraints(minHeight: 44),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(StudioRadii.inner),
            ),
            textStyle: const TextStyle(decoration: TextDecoration.none),
          ),
          '.dsr-row[data-current]': StyleProps(
            decoration: BoxDecoration(
              color: StudioExtraColors.of(context).accentWash,
              borderRadius: BorderRadius.circular(StudioRadii.inner),
            ),
          ),
          '.dsr-title': StyleProps(
            textStyle: text.bodyMedium.copyWith(
              fontWeight: FontWeight.w500,
              color: scheme.onSurface,
              decoration: TextDecoration.none,
            ),
          ),
          '.dsr-row[data-current] .dsr-title': StyleProps(
            textStyle: TextStyle(color: scheme.accent),
          ),
          '.dsr-excerpt': StyleProps(
            margin: const EdgeInsets.only(top: 2),
            textStyle: text.bodySmall.copyWith(
              fontSize: 13,
              color: scheme.onSurfaceVariant!,
            ),
          ),
          '.dsr-excerpt mark': StyleProps(
            decoration: const BoxDecoration(color: Colors.transparent),
            textStyle: TextStyle(
              color: scheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              t.searchPrompt,
              style: text.bodyMedium.copyWith(color: scheme.onSurfaceVariant!),
            ),
          ],
        ),
      ),
    );
  }
}
