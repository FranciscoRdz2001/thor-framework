import 'package:thor_studio/thor_studio.dart';
import 'package:thor_ui/html.dart' as html;
import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

import '../../../core/content/page_meta.dart';
import '../../../core/i18n/docs_locale.dart';
import '../../../core/layouts/doc_layout.dart';
import '../widgets/search_box.dart';
import '../widgets/search_results.dart';

export '../widgets/search_results.dart' show searchResultsId;

/// The page `/buscar`.
class SearchPage extends ThorPage<void> {
  /// Rendered once per process; the site is static.
  const SearchPage() : super(cache: const Duration(hours: 1));

  /// Title and description.
  @override
  PageMeta meta(PageState<void> state) {
    final t = messagesOf(state.request);
    return docsMeta(
      state.request,
      title: t.searchTitle,
      path: state.uri.path,
      description: t.searchDescription,
    );
  }

  /// The search box and its results, and the script that fills them
  /// (Pagefind, fetched when there is something to look for).
  @override
  Widget build(BuildContext context, PageState<void> state) {
    final prefix = RequestScope.of(context).publicPathPrefix;
    return DocLayout(
      path: state.request.routePath,
      title: context.l10n.searchTitle,
      indexed: false,
      pager: false,
      sidebar: false,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: StudioSpacing.lg,
        children: [
          const SearchBox(),
          const SearchResults(),
          html.script(src: '$prefix/search.js', defer: true),
        ],
      ),
    );
  }
}
