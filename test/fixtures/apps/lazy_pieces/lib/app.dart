/// The app around every page, for the server and the tests.
library;

import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

import 'router.dart';

/// The app.
final app = ThorApp.router(routerConfig: router, styles: thorResetStyles);

/// The handler: [app] in English.
RouteHandler<Widget> appHandler() => RouteHandler(
  routes: app.routes,
  renderer: WidgetRenderer.router(app, locale: const Locale('en')),
);
