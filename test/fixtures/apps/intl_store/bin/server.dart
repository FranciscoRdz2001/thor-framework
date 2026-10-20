import 'dart:io';

import 'package:intl_store/handler.dart';
import 'package:thor_ui/router.dart';

/// Serves the shop: `PORT=4400 dart run bin/server.dart`. A release build
/// (`thor build`) serves its compiled engine from build/public.
Future<void> main() => ThorServer.serve(
  () => ThorServer(
    handler: storeHandler(baseUrl: Platform.environment['BASE_URL']),
    publicDir: ThorServer.appPublicDir(),
  ),
  port: int.parse(Platform.environment['PORT'] ?? '4400'),
);
