import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

import '../../../core/content/doc_view.dart';
import '../../../core/content/library.dart';
import '../../../core/content/page_meta.dart';
import '../../../core/i18n/docs_locale.dart';

/// The page `/errores`.
class ErrorsPage extends ThorPage<GuideContent> {
  /// Rendered once per process; the site is static.
  const ErrorsPage() : super(cache: const Duration(hours: 1));

  /// `/errores`: every error code, in the reader's language or the default one with a
  /// notice.
  @override
  Future<GuideContent> load(PageRequest request) async {
    final content = loadErrorContent('README', localeTagOf(request));
    if (content == null) throw NotFound(messagesOf(request).notFoundCodes);
    return content;
  }

  /// Title and description from the markdown.
  @override
  PageMeta meta(PageState<GuideContent> state) => docsMeta(
    state.request,
    title: state.data.page.title,
    path: state.uri.path,
    description: state.data.page.description,
  );

  /// The page.
  @override
  Widget build(BuildContext context, PageState<GuideContent> state) {
    final t = context.l10n;
    final content = state.data;
    return DocView(
      page: content.page,
      path: state.request.routePath,
      eyebrow: t.errorsEyebrow,
      // The index is a reference page: no page actions.
      editable: false,
      notice: content.fallback
          ? t.docFallbackNotice(endonymOf(content.locale))
          : null,
    );
  }
}
