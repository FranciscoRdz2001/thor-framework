/// The app around every page, for the export and the tests.
library;

import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

import 'router.dart';

/// The app: the page reset is the edge cases' (the other pages are
/// insensitive to it).
final app = ThorApp.router(routerConfig: router, styles: thorResetStyles);

/// The handler: [app] in Spanish, like the pages it replaces.
RouteHandler<Widget> appHandler() => RouteHandler(
  routes: app.routes,
  renderer: WidgetRenderer.router(app, locale: const Locale('es')),
);
