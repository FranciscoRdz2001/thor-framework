// A server for server_shutdown_test: `/slow` takes a while to load, so a
// signal can arrive while it is in flight.
import 'dart:convert';
import 'dart:io';

import 'package:thor_server/thor_server.dart';

class _Renderer implements PageRenderer<String> {
  @override
  List<int> render(String page, RenderContext context) => utf8.encode(page);

  @override
  String errorPage(ErrorState state) => 'error ${state.status}';
}

Future<void> main(List<String> args) => ThorServer.serve(
  () => ThorServer(
    handler: RouteHandler<String>(
      renderer: _Renderer(),
      routes: [
        PageRoute<String, String>(
          path: 'slow',
          load: (_) async {
            await Future<void>.delayed(const Duration(milliseconds: 1500));
            return 'slow done';
          },
          build: (s) => s.data,
        ),
        PageRoute<String, void>(build: (_) => 'home'),
      ],
    ),
  ),
  address: InternetAddress.loopbackIPv4,
  port: int.parse(args.first),
  isolates: int.parse(args[1]),
  shutdownTimeout: const Duration(seconds: 5),
);
