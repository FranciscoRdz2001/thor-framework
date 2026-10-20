/// The view of a markdown page (a guide, an API reference, an error
/// code): the doc layout around its title and body.
library;

import 'package:thor_studio/thor_studio.dart'
    show StudioCallout, StudioTone, StudioSpacing, StudioTocEntry;
import 'package:thor_ui/html.dart' as html;
import 'package:thor_ui/router.dart' show PageMeta, PageRequest;
import 'package:thor_ui/thor_ui.dart';

import '../i18n/docs_locale.dart';
import '../layouts/doc_layout.dart';
import 'blocks.dart';
import 'blocks_view.dart';
import 'library.dart';
import 'page_meta.dart';

/// A markdown page in the frame: trail, title, body, the pages before and
/// after, and its headings in the table of contents.
class DocView extends StatelessWidget {
  /// The view of [page] at [path].
  const DocView({
    super.key,
    required this.page,
    required this.path,
    this.eyebrow,
    this.subsections = true,
    this.embed,
    this.layersEmbed,
    this.markdownHref,
    this.notice,
    this.searchWeight,
    this.editable = true,
  });

  /// An API reference page (only files in the table of contents: members
  /// are many), under [eyebrow].
  const DocView.api({
    super.key,
    required this.page,
    required this.path,
    required this.eyebrow,
  }) : subsections = false,
       embed = null,
       layersEmbed = null,
       markdownHref = null,
       notice = null,
       searchWeight = null,
       editable = false;

  /// A line above the body (the page is in another language than the
  /// reader's), or null.
  final String? notice;

  /// Whether the page has a source file to edit: a generated page (the API
  /// reference) has none, so its "edit this page" link is left out.
  final bool editable;

  /// How much the search favors the page's words (see
  /// `DocLayout.searchWeight`), or null.
  final double? searchWeight;

  /// Where the page's Markdown is (`/es/datos-y-estado/estado.md`), for its "copy as
  /// Markdown" link; null: no such file.
  final String? markdownHref;

  /// The page.
  final DocPage page;

  /// The current route path (without the language).
  final String path;

  /// Its group.
  final String? eyebrow;

  /// Whether `###` headings go in the table of contents.
  final bool subsections;

  /// The widget a `:::example id` / `:::bench id` shows (`open`: its code
  /// view starts shown); `null`, or a `null` result, drops the block.
  final Widget? Function(String id, {required bool open})? embed;

  /// The widget a `:::layers id` shows; `null`, or a `null` result, drops
  /// the block.
  final Widget? Function(String id)? layersEmbed;

  @override
  Widget build(BuildContext context) {
    // The heading over a folder page's entries: the table of contents leaves
    // it out.
    final symbolsHeading = context.l10n.apiSymbolsHeading;
    final headings = [
      for (final e in page.toc)
        if (e.label != symbolsHeading) e,
    ];
    // The `###` headings too, unless the list would grow past 12 entries.
    final deep = subsections && headings.length <= 12;
    final toc = [
      for (final e in headings)
        if (deep || e.depth == 0)
          StudioTocEntry(e.label, href: e.href, depth: e.depth),
    ];
    // The first paragraph, before any heading, is the lead under the title,
    // with its links and inline code.
    final (lead, _) = splitLead(page.blocks);
    return DocLayout(
      path: path,
      title: page.title.replaceAll('`', ''),
      leadMarkup: lead == null ? null : localizeLinks(context.docsLocale, lead),
      eyebrow: eyebrow,
      toc: toc,
      editHref: editable && page.source != null
          ? repoFile(page.source!, view: RepoView.edit)
          : null,
      markdownHref: markdownHref,
      searchWeight: searchWeight,
      // A page shown from the default language says so to assistive
      // technology and to search engines.
      lang: notice != null ? defaultLocale : null,
      content: DocEmbeds(
        example: embed,
        layers: layersEmbed,
        child: DocBody(page: page, notice: notice, skipLead: lead != null),
      ),
    );
  }
}

/// What a page says, without the frame around it (the layout puts the
/// trail, the title and the pager): the notice, if any, and the body made of
/// its blocks. Put it under a [DocEmbeds] to show the page's examples and
/// layer diagrams.
class DocBody extends StatelessWidget {
  /// The body of [page].
  const DocBody({
    super.key,
    required this.page,
    this.notice,
    this.skipLead = false,
  });

  /// Whether the first paragraph is left out (the layout shows it as the
  /// lead).
  final bool skipLead;

  /// The page.
  final DocPage page;

  /// A line above the body (the page is in another language than the
  /// reader's), or null.
  final String? notice;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: StudioSpacing.lg,
    children: [
      // The copy button of every code block is the studio's one script.
      const html.script(src: '/scripts/studio-code.js', defer: true),
      if (notice != null)
        StudioCallout(
          tone: StudioTone.note,
          title: context.l10n.calloutNote,
          body: notice,
        ),
      DocBlocks(skipLead ? splitLead(page.blocks).$2 : page.blocks),
    ],
  );
}

/// The first `<p>` of a block that opens with one.
final _firstParagraph = RegExp(r'^\s*(<p>(?:(?!</p>)[\s\S])*</p>)\s*');

/// The page's lead (the first paragraph, when the page opens with one, as
/// HTML) and the blocks after it: the rest of the first block stays in the
/// body.
(String?, List<DocBlock>) splitLead(List<DocBlock> blocks) {
  final first = blocks.firstOrNull;
  if (first is! ProseBlock) return (null, blocks);
  final match = _firstParagraph.firstMatch(first.html);
  if (match == null) return (null, blocks);
  final rest = first.html.substring(match.end);
  return (
    match[1],
    [if (rest.trim().isNotEmpty) ProseBlock(rest), ...blocks.skip(1)],
  );
}

/// An API reference page's title and description.
PageMeta apiMeta(PageRequest request, DocPage page, String path) {
  final name = page.title.replaceAll('`', '');
  final t = messagesOf(request);
  return docsMeta(
    request,
    title: t.apiPageTitle(name),
    path: path,
    description: t.apiPageDescription(name),
  );
}
