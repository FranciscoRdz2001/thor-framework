/// The layout of a guide, API, error or search page: the frame around a
/// trail, the page's title, its content and the pages before and after.
library;

import 'package:thor_studio/thor_studio.dart';
import 'package:thor_ui/html.dart' as html;
import 'package:thor_ui/thor_ui.dart';

import '../../shell/docs_scaffold.dart';
import '../content/library.dart';
import '../i18n/docs_locale.dart';
import '../widgets/docs_breadcrumbs.dart';
import '../widgets/docs_toc_disclosure.dart';
import 'docs_place.dart';

/// Frame, trail, title, [content] and pager.
class DocLayout extends StatelessWidget {
  /// The layout at [path] around [content], titled [title], with [toc] on
  /// the right.
  const DocLayout({
    super.key,
    required this.path,
    required this.content,
    required this.title,
    this.lead,
    this.leadMarkup,
    this.eyebrow,
    this.toc = const [],
    this.editHref,
    this.markdownHref,
    this.lang,
    this.indexed = true,
    this.pager = true,
    this.searchWeight,
    this.sidebar = true,
  });

  /// The current route path (without the language).
  final String path;

  /// The page's body.
  final Widget content;

  /// The page's title (its `h1`, and the last crumb).
  final String title;

  /// The sentence or two under the title (the page's first paragraph), or
  /// null.
  final String? lead;

  /// The lead as HTML (the page's rendered first paragraph, links already
  /// localized), in place of [lead].
  final String? leadMarkup;

  /// The group the page belongs to, named in search results.
  final String? eyebrow;

  /// Its headings.
  final List<StudioTocEntry> toc;

  /// Where to edit the page, if it has a source.
  final String? editHref;

  /// Where the page's Markdown is, for its "copy as Markdown" link; null: no
  /// such file.
  final String? markdownHref;

  /// The language of the content when it is not the reader's (a fallback
  /// page), or null.
  final String? lang;

  /// Whether the search index takes the page.
  final bool indexed;

  /// Whether the previous and next guides close the page.
  final bool pager;

  /// Whether the page has the sidebar (the search page does not).
  final bool sidebar;

  /// How much more the search counts the words of this page's content than
  /// the default 1 (Pagefind's `data-pagefind-weight`): a guide page outranks
  /// a generated reference page that repeats its words. Null: the default.
  final double? searchWeight;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final place = DocsPlace.of(path);
    final previous = place.previous;
    final next = place.next;
    StudioNavDestination link(Guide guide) => StudioNavDestination(
      guide.title(t),
      href: context.localized(guide.path),
    );
    return DocsScaffold(
      path: path,
      toc: toc,
      contentLang: lang,
      indexed: indexed,
      sidebar: sidebar,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // One line: where the page is, and what can be done with it.
          SizedBox(
            height: 28,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              spacing: StudioSpacing.sm,
              children: [
                Expanded(
                  child: DocsBreadcrumbs(path: path, title: title),
                ),
                if (markdownHref != null || editHref != null)
                  _PageActions(markdownHref: markdownHref, editHref: editHref),
              ],
            ),
          ),
          if (markdownHref != null)
            const html.script(src: '/copy-md.js', defer: true),
          const SizedBox(height: StudioSpacing.md),
          // Search results name the section, not read it as text; the title
          // counts more than the body (an exact title is the best match).
          StudioAttributes(
            {
              if (eyebrow != null) 'data-pagefind-meta': 'section:$eyebrow',
              'data-pagefind-weight': '10',
            },
            child: StudioPageHeader(
              title: title,
              lead: lead,
              leadMarkup: leadMarkup,
            ),
          ),
          // Below 1280 px the contents' column is a disclosure here.
          if (toc.isNotEmpty)
            ResponsiveVisibility(
              hiddenFrom: WindowSizeClass.large,
              child: Padding(
                padding: const EdgeInsets.only(top: StudioSpacing.lg),
                // The contents are not the page's words: search skips them.
                child: StudioAttributes(const {
                  'data-pagefind-ignore': 'all',
                }, child: DocsTocDisclosure(entries: toc)),
              ),
            ),
          const SizedBox(height: StudioSpacing.lg),
          searchWeight == null
              ? content
              : StudioAttributes({
                  'data-pagefind-weight': '$searchWeight',
                }, child: content),
          if (pager && (previous != null || next != null))
            Padding(
              padding: const EdgeInsets.only(top: StudioSpacing.xxl),
              child: StudioPagerLinks(
                previous: previous == null ? null : link(previous),
                next: next == null ? null : link(next),
              ),
            ),
        ],
      ),
    );
  }
}

/// "Copy as Markdown" and "Edit on GitHub": two small icon buttons with
/// tooltips at the end of the breadcrumb's line, or, below 840 px, one "⋯"
/// menu with both.
class _PageActions extends StatelessWidget {
  const _PageActions({this.markdownHref, this.editHref});

  final String? markdownHref;
  final String? editHref;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    // `copy-md.js` makes a click on the link copy the Markdown instead of
    // opening it.
    Widget copies(Widget child) => StudioAttributes({
      'data-copy-md': '',
      'data-copied': StudioLocalizations.of(context).copied,
    }, child: child);
    return StudioAttributes(
      const {'data-pagefind-ignore': ''},
      child: Row(
        children: [
          ResponsiveVisibility(
            visibleFrom: WindowSizeClass.expanded,
            child: Row(
              spacing: StudioSpacing.xxs,
              children: [
                if (markdownHref case final href?)
                  copies(
                    StudioIconButton(
                      icon: const Icon(StudioIcons.copy, size: 16),
                      tooltip: t.docCopyMarkdown,
                      href: href,
                      size: 28,
                    ),
                  ),
                if (editHref case final href?)
                  StudioIconButton(
                    icon: const Icon(StudioIcons.github, size: 16),
                    tooltip: t.docEditPage,
                    href: href,
                    newTab: true,
                    size: 28,
                  ),
              ],
            ),
          ),
          ResponsiveVisibility(
            hiddenFrom: WindowSizeClass.expanded,
            child: MenuAnchor(
              builder: (context, controller, child) => StudioIconButton(
                icon: const Icon(StudioIcons.ellipsis, size: 16),
                tooltip: t.docPageActions,
                onPressed: () =>
                    controller.isOpen ? controller.close() : controller.open(),
                size: 28,
              ),
              menuChildren: [
                if (markdownHref case final href?)
                  copies(
                    MenuItemButton(
                      leadingIcon: const Icon(StudioIcons.copy, size: 16),
                      href: href,
                      child: Text(t.docCopyMarkdown),
                    ),
                  ),
                if (editHref case final href?)
                  MenuItemButton(
                    leadingIcon: const Icon(StudioIcons.github, size: 16),
                    href: href,
                    child: Text(t.docEditPage),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
