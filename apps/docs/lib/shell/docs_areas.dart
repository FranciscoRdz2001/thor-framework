/// The four areas of the site, as the top bar's tabs and the drawer's
/// switcher show them: Guide, Components, Examples and API.
library;

import 'package:thor_studio/thor_studio.dart';
import 'package:thor_ui/thor_ui.dart';

import '../core/content/library.dart';
import '../core/i18n/docs_locale.dart';
import '../core/layouts/docs_place.dart';
import '../modules/api/api_routes.dart';

/// The tabs, each leading to its area's first page.
List<StudioNavDestination> docsAreaTabs(BuildContext context) {
  final t = context.l10n;
  String href(String route) => context.localized(route);
  return [
    StudioNavDestination(t.navGuide, href: href(allGuides.first.path)),
    StudioNavDestination(
      t.navComponents,
      href: href(guideBySlug(componentsSection)!.path),
    ),
    StudioNavDestination(
      t.navExamples,
      href: href(guideBySlug(examplesSection)!.path),
    ),
    StudioNavDestination(t.navApi, href: href(apiHomePath)),
  ];
}

/// The tab of [area] in [docsAreaTabs], or -1 (the home, the search, the
/// changes: no tab is theirs). The error codes are reached from the API's
/// sidebar, so they are the API's tab.
int docsAreaIndex(DocsArea area) => switch (area) {
  DocsArea.guide => 0,
  DocsArea.components => 1,
  DocsArea.examples => 2,
  DocsArea.api || DocsArea.errors => 3,
  _ => -1,
};
