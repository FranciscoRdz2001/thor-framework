import 'package:thor_studio/thor_studio.dart';
import 'package:thor_ui/thor_ui.dart';

import '../../modules/errors/errors_routes.dart';
import '../../shell/docs_areas.dart';
import '../content/library.dart';
import '../i18n/docs_locale.dart';
import '../layouts/docs_place.dart';

/// The icon of each guide section in the sidebar (and on the home page).
const docsSectionIcons = <String, IconData>{
  'empezar': StudioIcons.rocket,
  'fundamentos': StudioIcons.bookOpen,
  'arquitectura': StudioIcons.layers,
  'interfaz': StudioIcons.palette,
  'datos-y-estado': StudioIcons.database,
  'publicar': StudioIcons.send,
};

/// The icon of each page of the catalog.
const _componentIcons = <String, IconData>{
  'componentes': StudioIcons.layoutGrid,
  'componentes-botones': StudioIcons.mousePointerClick,
  'componentes-entradas': StudioIcons.textCursorInput,
  'componentes-seleccion': StudioIcons.squareCheck,
  'componentes-contenido': StudioIcons.fileText,
  'componentes-navegacion': StudioIcons.compass,
  'componentes-avisos': StudioIcons.bell,
};

/// How many examples are whole apps (the index, the 7GUIs and the content
/// page); the rest are interaction patterns.
const _exampleApps = 9;

/// The sidebar of the page's area: the guide's six sections, the catalog,
/// the examples, or the API reference with the error codes. Every page is in
/// sight, under its section's heading.
/// Below 1024 px it is the drawer, and then it starts with a switcher of the
/// four areas and ends with the repository.
class DocsSideNav extends StatelessWidget {
  /// The sidebar at [path] (the route's own: without the language).
  const DocsSideNav({super.key, required this.path});

  /// The current route path.
  final String path;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final place = DocsPlace.of(path);
    String href(String route) => context.localized(route);
    StudioNavDestination page(Guide guide, {IconData? icon}) =>
        StudioNavDestination(
          guide.title(t),
          href: href(guide.path),
          icon: icon,
        );
    GuideSection section(String slug) =>
        guideSections.firstWhere((s) => s.slug == slug);

    final sections = switch (place.area) {
      DocsArea.components => [
        StudioNavSection(
          title: '',
          items: [
            for (final guide in section(componentsSection).guides)
              page(guide, icon: _componentIcons[guide.slug]),
          ],
        ),
      ],
      DocsArea.examples => [
        StudioNavSection(
          title: t.navExamplesApps,
          icon: StudioIcons.appWindow,
          items: [
            for (final guide in section(
              examplesSection,
            ).guides.take(_exampleApps))
              page(guide),
          ],
        ),
        StudioNavSection(
          title: t.navExamplesPatterns,
          icon: StudioIcons.pointer,
          items: [
            for (final guide in section(
              examplesSection,
            ).guides.skip(_exampleApps))
              page(guide),
          ],
        ),
      ],
      DocsArea.api || DocsArea.errors || DocsArea.changes => [
        StudioNavSection(
          title: apiPackages.first,
          icon: StudioIcons.code,
          items: [
            for (final api in apiPages())
              StudioNavDestination(
                _apiLabel(t, api) ?? api.labelIn(context.docsLocale),
                href: href(api.path),
              ),
          ],
        ),
        StudioNavSection(
          title: t.footerReference,
          icon: StudioIcons.bookOpen,
          items: [
            StudioNavDestination(
              t.navErrors,
              href: href(errorsRoute.link()),
              icon: StudioIcons.triangleAlert,
            ),
          ],
        ),
      ],
      _ => [
        for (final s in guideSections)
          if (s.slug != componentsSection && s.slug != examplesSection)
            StudioNavSection(
              title: s.title(t),
              icon: docsSectionIcons[s.slug],
              items: [for (final guide in s.guides) page(guide)],
            ),
      ],
    };
    // `selectedIndex` counts the items of every section, top to bottom (like
    // `NavigationDrawer`); -1 marks none.
    final hrefs = [
      for (final s in sections)
        for (final item in s.items) item.href,
    ];
    final current = href(
      place.area == DocsArea.errors ? errorsRoute.link() : path,
    );
    // The page itself, else the item it is under (a widget's page under its
    // API topic): the longest href the path starts with.
    var selectedIndex = hrefs.indexOf(current);
    if (selectedIndex < 0) {
      var longest = 0;
      for (final (i, h) in hrefs.indexed) {
        if (current.startsWith('$h/') && h.length > longest) {
          longest = h.length;
          selectedIndex = i;
        }
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ResponsiveVisibility(
          hiddenFrom: WindowSizeClass.expanded,
          child: Padding(
            padding: const EdgeInsets.only(bottom: StudioSpacing.lg),
            child: _AreaSwitcher(selected: docsAreaIndex(place.area)),
          ),
        ),
        StudioSideNav(sections: sections, selectedIndex: selectedIndex),
        ResponsiveVisibility(
          hiddenFrom: WindowSizeClass.expanded,
          child: Padding(
            // The space above a section of the sidebar.
            padding: const EdgeInsets.only(
              top: StudioSpacing.lg + StudioSpacing.xxs,
            ),
            child: StudioSideNav(
              label: t.navGithub,
              sections: [
                StudioNavSection(
                  title: '',
                  items: [
                    StudioNavDestination(
                      t.footerGithub,
                      href: repositoryUrl,
                      icon: StudioIcons.github,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// The human name of a facade's page (`package:thor_ui/server.dart` →
  /// Servidor), or null for a topic (its own title).
  static String? _apiLabel(AppLocalizations t, ApiPage page) =>
      switch (page.folder) {
        'server' => t.apiLabelServer,
        'router' => t.apiLabelRouter,
        'html' => t.apiLabelHtml,
        'testing' => t.apiLabelTesting,
        'intl' => t.apiLabelIntl,
        'thor_test' => t.apiLabelThorTest,
        'thor_studio' => t.apiLabelStudio,
        _ => null,
      };
}

/// The four areas as a segmented switch at the top of the drawer: links in
/// a raised track, the current one in the accent on its tint (as in the top
/// bar). Two rows of two when the
/// drawer is too narrow for one.
class _AreaSwitcher extends StatelessWidget {
  const _AreaSwitcher({required this.selected});

  final int selected;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final tabs = docsAreaTabs(context);
    return Semantics(
      role: SemanticsRole.navigation,
      label: t.navAreas,
      child: Container(
        padding: const EdgeInsets.all(StudioSpacing.xxs),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(StudioRadii.inner + 4),
        ),
        child: Grid(
          layout: const GridLayout(columns: 2, gap: StudioSpacing.xxs),
          children: [
            for (final (i, tab) in tabs.indexed)
              Link(
                href: RouteUrl(tab.href),
                current: i == selected,
                child: Container(
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == selected
                        ? scheme.accentContainer
                        : Colors.transparent.when(
                            hover: StudioExtraColors.of(context).hover,
                          ),
                    borderRadius: BorderRadius.circular(StudioRadii.inner),
                  ),
                  child: Text(
                    tab.label,
                    style: text.labelLarge.copyWith(
                      color: i == selected
                          ? scheme.accent
                          : scheme.onSurfaceVariant!,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
