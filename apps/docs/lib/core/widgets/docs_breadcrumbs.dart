import 'package:thor_studio/thor_studio.dart';
import 'package:thor_ui/thor_ui.dart';

import '../../modules/api/api_routes.dart';
import '../../modules/changes/changes_routes.dart';
import '../../modules/errors/errors_routes.dart';
import '../i18n/docs_locale.dart';
import '../layouts/docs_place.dart';

/// The trail above a page's title: its section (or the reference it is in)
/// and the page. Nothing for the home, the search and a missing page.
class DocsBreadcrumbs extends StatelessWidget {
  /// The trail of the page at [path] titled [title].
  const DocsBreadcrumbs({super.key, required this.path, required this.title});

  /// The current route path.
  final String path;

  /// The page's own title: the last crumb.
  final String title;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final place = DocsPlace.of(path);
    // The reference areas: their root page, then the page itself.
    StudioNavDestination root(String label, String route) =>
        StudioNavDestination(label, href: context.localized(route));
    final trail = switch (place.area) {
      DocsArea.guide || DocsArea.components || DocsArea.examples => [
        StudioNavDestination(
          place.section!.title(t),
          href: context.localized(place.section!.guides.first.path),
        ),
        StudioNavDestination(title, href: context.localized(path)),
      ],
      DocsArea.api => [
        root(t.navApi, apiHomePath),
        if (path != apiHomePath)
          StudioNavDestination(title, href: context.localized(path)),
      ],
      DocsArea.errors => [
        root(t.navErrors, errorsRoute.link()),
        if (path != errorsRoute.link())
          StudioNavDestination(title, href: context.localized(path)),
      ],
      DocsArea.changes => [
        root(t.navChanges, changesRoute.link()),
        if (path != changesRoute.link())
          StudioNavDestination(title, href: context.localized(path)),
      ],
      _ => const <StudioNavDestination>[],
    };
    if (trail.isEmpty) return const SizedBox.shrink();
    return StudioBreadcrumbs(
      trail: trail,
      // The last crumb is the page: plain text, not a link.
      selectedIndex: trail.length - 1,
    );
  }
}
