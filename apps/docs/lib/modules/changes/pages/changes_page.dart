import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

import '../../../core/content/changelog.dart';
import '../../../core/content/doc_view.dart';
import '../../../core/content/library.dart';
import '../../../core/content/page_meta.dart';
import '../../../core/i18n/docs_locale.dart';

/// The pages `/cambios` and `/cambios/:package`.
class ChangesPage extends ThorPage<DocPage> {
  /// Rendered once per process; the site is static.
  const ChangesPage() : super(cache: const Duration(hours: 1));

  /// The index (the migration notes and the packages), or a package's
  /// changelog.
  @override
  DocPage load(PageRequest request) {
    final package = request.pathParameters['package'];
    final t = messagesOf(request);
    final markdown = package == null
        ? changesIndexMarkdown(t)
        : changelogMarkdown(package, t);
    if (markdown == null) throw NotFound(t.notFoundChanges);
    return renderMarkdown(
      markdown,
      // The index is generated from every package: no file of its own.
      source: package == null ? null : 'packages/$package/CHANGELOG.md',
      locale: localeTagOf(request),
    );
  }

  /// Title and description.
  @override
  PageMeta meta(PageState<DocPage> state) {
    final t = messagesOf(state.request);
    return docsMeta(
      state.request,
      title: state.request.pathParameters['package'] == null
          ? t.changesTitle
          : t.changesPackageTitle(state.data.title),
      path: state.uri.path,
      description: state.data.description,
    );
  }

  /// The page.
  @override
  Widget build(BuildContext context, PageState<DocPage> state) => DocView(
    page: state.data,
    path: state.request.routePath,
    eyebrow: context.l10n.changesEyebrow,
    subsections: false,
    // Generated pages (the index, and each package's CHANGELOG.md): no page
    // actions.
    editable: false,
  );
}
