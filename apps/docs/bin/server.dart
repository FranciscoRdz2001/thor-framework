import 'dart:io';

import 'package:docs/app.dart';
import 'package:thor_ui/router.dart';

/// Serves the docs while writing them: `PORT=4600 dart run bin/server.dart`
/// (edits to `docs/*.md` show after a restart).
Future<void> main() => ThorServer.serve(
  () => ThorServer(handler: docsHandler(), publicDir: 'web'),
  port: int.parse(Platform.environment['PORT'] ?? '4600'),
  isolates: 1,
);
