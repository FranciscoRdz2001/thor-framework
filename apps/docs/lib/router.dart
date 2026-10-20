/// The app's routes: the table the server serves, composed of the
/// modules' route groups under the shell's layout and error page.
library;

import 'package:thor_ui/router.dart';

import 'modules/api/api_routes.dart';
import 'modules/changes/changes_routes.dart';
import 'modules/errors/errors_routes.dart';
import 'modules/guide/guide_routes.dart';
import 'modules/home/home_routes.dart';
import 'modules/search/search_routes.dart';
import 'shell/app_error_page.dart';
import 'shell/root_layout.dart';

/// Every route of the app.
final ThorRouter router = ThorRouter([
  Group(
    layout: const RootLayout(),
    error: const AppErrorPage(),
    children: [
      homeRoute,
      guideModule,
      apiModule,
      changesModule,
      errorsModule,
      searchModule,
    ],
  ),
]);
