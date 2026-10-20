import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

import '../../../core/content/doc_view.dart';
import '../../../core/content/library.dart';
import '../../../core/i18n/docs_locale.dart';

/// The page `/api/:package`.
class ApiPackagePage extends ThorPage<GuideContent> {
  /// Rendered once per process; the site is static.
  const ApiPackagePage() : super(cache: const Duration(hours: 1));

  /// `/api/<package>`: the API reference, in the reader's language or the
  /// default one with a notice.
  @override
  GuideContent load(PageRequest request) {
    final package = request.pathParameters['package']!;
    final page = loadApiContent(package, localeTagOf(request));
    if (page == null) throw NotFound(messagesOf(request).notFoundPackage);
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
