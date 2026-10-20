/// The site's frame, made of thor_studio: top bar, sidebar (a drawer on a
/// phone), table of contents and footer around a page.
library;

import 'package:thor_studio/thor_studio.dart';
import 'package:thor_ui/thor_ui.dart';

import '../core/i18n/docs_locale.dart';
import '../core/widgets/docs_side_nav.dart';
import 'docs_footer.dart';
import 'docs_top_bar.dart';

/// The widest the page grows to (sidebar, text and contents), centred.
const docsPageWidth = 1440.0;

/// Every page's frame. The page is [body]; its headings go to the table of
/// contents on the right.
class DocsScaffold extends StatelessWidget {
  /// The frame around [body] at [path] (the route's own: without the
  /// language).
  const DocsScaffold({
    super.key,
    required this.path,
    required this.body,
    this.toc = const [],
    this.contentLang,
    this.indexed = true,
    this.sidebar = true,
    this.maxContentWidth = StudioLayout.readingWidth,
  });

  /// The current route path.
  final String path;

  /// The page.
  final Widget body;

  /// Its headings.
  final List<StudioTocEntry> toc;

  /// The language of the page's text when it is not the reader's (a page
  /// shown from the default language): the `lang` of its content.
  final String? contentLang;

  /// Whether the search index takes the page (the search page itself does
  /// not: its text is the form).
  final bool indexed;

  /// Whether the page has the sidebar (the home does not).
  final bool sidebar;

  /// The widest the page grows to (the home is wider than a text).
  final double maxContentWidth;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    return StudioScaffold(
      maxContentWidth: maxContentWidth,
      maxPageWidth: docsPageWidth,
      // The view transition in core/theme/motion.dart points at this id.
      sidebarId: 'studio-sidebar',
      // The list stays where the reader left it from page to page.
      sidebarRestorationId: 'docs-sidebar',
      appBar: DocsTopBar(path: path),
      drawer: sidebar ? DocsSideNav(path: path) : null,
      drawerHeader: StudioBrand(
        name: 'Thor',
        href: context.localized('/'),
        version: docsVersion,
      ),
      // With a sidebar the contents' column is always there (empty on a
      // page with no headings), so the text starts at the same x on every
      // page.
      tableOfContents: !sidebar
          ? null
          : toc.isEmpty
          ? const SizedBox.shrink()
          : StudioTableOfContents(
              entries: toc,
              title: t.tocOnThisPage,
              scrollSpy: true,
              backToTopLabel: t.tocBackToTop,
            ),
      body: StudioAttributes({
        // The only part of a page Pagefind indexes (not the navigation).
        if (indexed) 'data-pagefind-body': '',
        'lang': ?contentLang,
      }, child: body),
      // Lined up with the page: the columns' row, or the home's width.
      footer: DocsFooter(
        maxWidth: sidebar
            ? docsPageWidth - 2 * StudioSpacing.lg
            : maxContentWidth,
      ),
    );
  }
}
