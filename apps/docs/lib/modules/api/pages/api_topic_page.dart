import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

import '../../../core/content/doc_view.dart';
import '../../../core/content/library.dart';
import '../../../core/i18n/docs_locale.dart';

/// The page `/api/:package/:folder`.
class ApiTopicPage extends ThorPage<GuideContent> {
  /// Rendered once per process; the site is static.
  const ApiTopicPage() : super(cache: const Duration(hours: 1));

  /// `/api/<package>/<folder>`: one folder of a package's reference.
  @override
  GuideContent load(PageRequest request) {
    final page = loadApiContent(
      request.pathParameters['package']!,
      localeTagOf(request),
      folder: request.pathParameters['folder'],
    );
    if (page == null) throw NotFound(messagesOf(request).notFoundFolder);
    return page;
  }

  /// Title and description.
  @override
  PageMeta meta(PageState<GuideContent> state) =>
      apiMeta(state.request, state.data.page, state.uri.path);

  /// The reference.
  @override
  Widget build(BuildContext context, PageState<GuideContent> state) {
    final t = context.l10n;
    final content = state.data;
    return DocView(
      page: content.page,
      path: state.request.routePath,
      eyebrow: t.apiEyebrow,
      subsections: false,
      // Generated from the package's dartdoc: there is no page to edit.
      editable: false,
      notice: content.fallback
          ? t.docFallbackNotice(endonymOf(content.locale))
          : null,
    );
  }
}
