/// The changes module: what changed, from the packages' changelogs.
library;

import 'package:thor_ui/router.dart';

import 'pages/changes_page.dart';

/// The index, `/cambios`.
final changesRoute = ThorRoute('/cambios', const ChangesPage());

/// One package's changes, `/cambios/:package`.
final changesPackageRoute = ThorRoute('/cambios/:package', const ChangesPage());

/// Every route of the changes.
final changesModule = Group(children: [changesRoute, changesPackageRoute]);
