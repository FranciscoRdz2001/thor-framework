import 'dart:io';

import 'package:lazy_pieces/app.dart';
import 'package:thor_ui/router.dart';

/// The app's server: `thor dev` runs it; `thor build` compiles it. One
/// isolate: the demo's database lives in memory, per isolate.
Future<void> main() => ThorServer.serve(
  () => ThorServer(
    handler: appHandler(),
    publicDir: Directory('build/public').existsSync() ? 'build/public' : 'web',
  ),
  port: int.parse(Platform.environment['PORT'] ?? '6231'),
  isolates: 1,
);
