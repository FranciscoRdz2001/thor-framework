import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

import '../../../core/content/doc_view.dart';
import '../../../core/content/library.dart';
import '../../../core/content/page_meta.dart';
import '../../../core/content/redirects.dart';
import '../../../core/i18n/docs_locale.dart';
import '../examples/examples.dart';
import '../examples/layers/layer_sets.dart';

/// A guide page: the page `/<section>/:slug` of [section].
class GuidePage extends ThorPage<(Guide, GuideContent)> {
  /// The pages of [section]. Rendered once per process; the site is static.
  const GuidePage(this.section) : super(cache: const Duration(hours: 1));

  /// The section's URL segment (`empezar`).
  final String section;

  /// `/<section>/<slug>`: a page of the guide, in the reader's language
  /// (`docs/guia/<locale>/`), or in the default one when it is not
  /// translated yet. A page that moved to another section redirects
  /// (permanently) to where it is now.
  @override
  Future<(Guide, GuideContent)> load(PageRequest request) async {
    final slug = request.pathParameters['slug']!;
    final guide = guideAt(section, slug);
    final moved = guide == null ? legacySectionPath('/$section/$slug') : null;
    if (moved != null) {
      throw Redirect.permanent(request.localizedPath(moved));
    }
    final content = guide == null
        ? null
        : loadGuide(guide, localeTagOf(request));
    if (guide == null || content == null) {
      throw NotFound(messagesOf(request).notFoundGuide);
    }
    // Its live examples, rendered once (their HTML and CSS for "View code").
    await prepareExamples(content.page.examples);
    return (guide, content);
  }

  /// Title and description from the markdown.
  @override
  PageMeta meta(PageState<(Guide, GuideContent)> state) => docsMeta(
    state.request,
    title: state.data.$2.page.title,
    path: state.uri.path,
    description: state.data.$2.page.description,
  );

  /// The guide.
  @override
  Widget build(BuildContext context, PageState<(Guide, GuideContent)> state) {
    final t = context.l10n;
    final (guide, content) = state.data;
    return DocView(
      page: content.page,
      path: guide.path,
      eyebrow: sectionOfGuide(guide).title(t),
      embed: ExampleEmbed.new,
      layersEmbed: LayersEmbed.new,
      // The guide outranks the generated reference in the search.
      searchWeight: 5,
      markdownHref: '${state.uri.path}.md',
      notice: content.fallback
          ? t.docFallbackNotice(endonymOf(content.locale))
          : null,
    );
  }
}
