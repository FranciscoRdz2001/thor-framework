// A server for server_shutdown_hook_test: `onShutdown` appends to a log file
// so the test sees when it ran, and what it did to the server meanwhile.
//
// args: port, log file, mode (`ok`, `throws`, `hangs`).
import 'dart:convert';
import 'dart:io';

import 'package:thor_server/thor_server.dart';

class _Renderer implements PageRenderer<String> {
  @override
  List<int> render(String page, RenderContext context) => utf8.encode(page);

  @override
  String errorPage(ErrorState state) => 'error ${state.status}';
}

Future<void> main(List<String> args) {
  final log = File(args[1]);
  final mode = args[2];
  return ThorServer.serve(
    () => ThorServer(
      handler: RouteHandler<String>(
        renderer: _Renderer(),
        routes: [PageRoute<String, void>(build: (_) => 'home')],
      ),
    ),
    address: InternetAddress.loopbackIPv4,
    port: int.parse(args.first),
    isolates: 1,
    shutdownTimeout: const Duration(seconds: 2),
    onShutdown: () async {
      log.writeAsStringSync('start\n', mode: FileMode.append);
      switch (mode) {
        case 'throws':
          throw StateError('boom');
        case 'hangs':
          await Future<void>.delayed(const Duration(minutes: 5));
        default:
          await Future<void>.delayed(const Duration(milliseconds: 400));
      }
      log.writeAsStringSync('end\n', mode: FileMode.append);
    },
  );
}
