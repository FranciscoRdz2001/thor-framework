import 'dart:io';

import 'package:recipes/app.dart';
import 'package:thor_ui/router.dart';

/// The app's server: `thor dev` runs it and restarts it on every change;
/// `thor build` compiles it.
Future<void> main() => ThorServer.serve(
  () => ThorServer(
    // Routes from lib/router.dart, languages from pubspec.yaml.
    handler: recipesHandler(),
    // build/public after `thor build`; web/ under `thor dev`.
    publicDir: ThorServer.appPublicDir(),
  ),
  port: int.parse(Platform.environment['PORT'] ?? '4300'),
);
