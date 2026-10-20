import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

import '../../../core/content/doc_view.dart';
import '../../../core/content/library.dart';
import '../../../core/content/page_meta.dart';
import '../../../core/i18n/docs_locale.dart';

/// The page `/errores/:code`.
class ErrorCodePage extends ThorPage<GuideContent> {
  /// Rendered once per process; the site is static.
  const ErrorCodePage() : super(cache: const Duration(hours: 1));

  /// `/errores/:code`: what an error code means and how to fix it, in the reader's language or the default one with a
  /// notice.
  @override
  Future<GuideContent> load(PageRequest request) async {
    final code = request.pathParameters['code']!;
    final content = RegExp(r'^THOR-[A-Z]\d{3}$').hasMatch(code)
        ? loadErrorContent(code, localeTagOf(request))
        : null;
    if (content == null) throw NotFound(messagesOf(request).notFoundCode);
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
      notice: content.fallback
          ? t.docFallbackNotice(endonymOf(content.locale))
          : null,
    );
  }
}
