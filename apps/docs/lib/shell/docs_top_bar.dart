import 'package:thor_studio/thor_studio.dart';
import 'package:thor_ui/thor_ui.dart';

import '../core/content/library.dart';
import '../core/i18n/docs_locale.dart';
import '../core/layouts/docs_place.dart';
import '../modules/search/search_routes.dart';
import 'docs_areas.dart';
import 'docs_locale_switcher.dart';

/// The site's version, shown next to the brand.
const docsVersion = '0.1';

/// The top bar of every page: the brand and its version, the four areas
/// (Guide, Components, Examples, API; the one the page is in marked), the
/// search field with its key hint, the repository and the theme toggle. On
/// a phone: the menu, the brand, the search and the theme (the areas and the
/// repository are in the drawer).
class DocsTopBar extends StatelessWidget {
  /// The bar of the page at [path] (the route's own: without the language).
  const DocsTopBar({super.key, required this.path});

  /// The current route path.
  final String path;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final area = DocsPlace.of(path).area;
    return StudioTopBar(
      brand: StudioBrand(
        name: 'Thor',
        href: context.localized('/'),
        version: docsVersion,
      ),
      selectedIndex: docsAreaIndex(area),
      links: docsAreaTabs(context),
      // Below 1024 px the drawer holds the areas.
      linksVisibleFrom: WindowSizeClass.expanded,
      linksLabel: t.navAreas,
      // A link to the search page (what it is without JavaScript); the site
      // script opens the search dialog instead. The Mac key: the script
      // swaps it for `Ctrl K` elsewhere (the server cannot know the
      // reader's keyboard).
      search: StudioSearchPill(
        href: context.localized(searchRoute.link()),
        placeholder: t.searchTitle,
        shortcut: '⌘K',
      ),
      actions: [
        ResponsiveVisibility(
          visibleFrom: WindowSizeClass.expanded,
          child: StudioIconButton(
            icon: const Icon(StudioIcons.github),
            href: repositoryUrl,
            tooltip: t.navGithub,
            newTab: true,
          ),
        ),
        if (docsLocales.length > 1) const DocsLocaleSwitcher(),
        const StudioThemeToggle(),
      ],
    );
  }
}
