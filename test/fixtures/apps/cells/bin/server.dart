import 'dart:io';

import 'package:cells/app.dart';
import 'package:thor_ui/router.dart';

/// The app's server: `thor dev` runs it; `thor build` compiles it.
Future<void> main() => ThorServer.serve(
  () => ThorServer(handler: appHandler(), publicDir: ThorServer.appPublicDir()),
  port: int.parse(Platform.environment['PORT'] ?? '6291'),
);
