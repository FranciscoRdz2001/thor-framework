/// The guide module: a page of the guide, `/<section>/<slug>` (the language
/// goes in front of it: `/es/empezar/instalacion`), and the addresses the
/// guide had before: `/guia/<slug>` and the sections it no longer has.
library;

import 'package:thor_ui/router.dart';

import '../../core/content/library.dart';
import '../../core/content/redirects.dart';
import 'pages/guide_page.dart';
import 'pages/legacy_guide_page.dart';

/// A page of the guide, one route per section: `/empezar/:slug`.
final guideRoutes = [
  for (final section in guideSections)
    ThorRoute('/${section.slug}/:slug', GuidePage(section.slug)),
];

/// What `/guia/:slug` was: it redirects to where the page is now.
final legacyGuideRoute = ThorRoute('/guia/:slug', const LegacyGuidePage());

/// The sections the guide no longer has (`/aprender/:slug`): every page of
/// theirs redirects to where it is now (`legacySectionTargets`).
final legacySectionRoutes = [
  for (final section in legacySections)
    if (!guideSections.any((s) => s.slug == section))
      ThorRoute('/$section/:slug', GuidePage(section)),
];

/// A route of the guide, as the examples of the guide show them (`link`).
final guideRoute = guideRoutes.first;

/// Every route of the guide.
final guideModule = Group(
  children: [...guideRoutes, ...legacySectionRoutes, legacyGuideRoute],
);
