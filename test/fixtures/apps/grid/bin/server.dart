import 'dart:io';

import 'package:grid/app.dart';
import 'package:thor_ui/router.dart';

/// The app's server: `thor dev` runs it and restarts it on every change;
/// `thor build` compiles it.
Future<void> main() => ThorServer.serve(
  () => ThorServer(
    handler: RouteHandler(
      routes: gridApp.routes,
      renderer: WidgetRenderer.router(gridApp),
    ),
    // build/public after `thor build`; web/ under `thor dev`.
    publicDir: ThorServer.appPublicDir(),
  ),
  port: int.parse(Platform.environment['PORT'] ?? '4300'),
);
