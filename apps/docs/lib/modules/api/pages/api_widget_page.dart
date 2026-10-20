import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

import '../../../core/content/doc_view.dart';
import '../../../core/content/library.dart';
import '../../../core/content/page_meta.dart';
import '../../../core/content/widget_docs.dart';
import '../../../core/i18n/docs_locale.dart';
import '../../guide/examples/examples.dart';

/// The page `/api/:package/:folder/:name`: one widget.
class ApiWidgetPage extends ThorPage<(WidgetDoc, DocPage)> {
  /// Rendered once per process; the site is static.
  const ApiWidgetPage() : super(cache: const Duration(hours: 1));

  /// `/api/thor_ui/<folder>/<Widget>`: its signature, parameters, a live
  /// example when the guide has one, and Flutter's documentation of it.
  @override
  Future<(WidgetDoc, DocPage)> load(PageRequest request) async {
    final package = request.pathParameters['package']!;
    final folder = request.pathParameters['folder']!;
    // The folder's title (the eyebrow) is known once its page was read.
    if (loadApiContent(package, localeTagOf(request), folder: folder) == null) {
      throw NotFound(messagesOf(request).notFoundFolder);
    }
    final widget = widgetDoc(folder, request.pathParameters['name']!);
    if (widget == null) throw NotFound(messagesOf(request).notFoundWidget);
    final page = widgetPage(
      widget,
      messagesOf(request),
      examples: exampleIdsFor(widget.name, examples.keys),
    );
    await prepareExamples(page.examples);
    return (widget, page);
  }

  /// Title and description.
  @override
  PageMeta meta(PageState<(WidgetDoc, DocPage)> state) {
    final (widget, _) = state.data;
    final summary = widget.constructors.firstOrNull?.summary;
    final t = messagesOf(state.request);
    return docsMeta(
      state.request,
      title: t.widgetPageTitle(widget.name),
      path: state.uri.path,
      description: summary == null
          ? t.widgetPageDescription(widget.name)
          : t.widgetPageDescriptionWithSummary(widget.name, summary),
    );
  }

  /// The page.
  @override
  Widget build(BuildContext context, PageState<(WidgetDoc, DocPage)> state) {
    final (widget, page) = state.data;
    return DocView(
      page: page,
      path: state.request.routePath,
      eyebrow: context.l10n.widgetEyebrow(
        ApiPage('thor_ui', widget.topic).labelIn(context.docsLocale),
      ),
      subsections: false,
      // Generated from `docs/api/widgets.json`: there is no page to edit.
      editable: false,
      embed: ExampleEmbed.new,
    );
  }
}
