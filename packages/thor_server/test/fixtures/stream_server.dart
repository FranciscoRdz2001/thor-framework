// A server for the adversarial tests that need a real process: header
// trickle (`idleTimeout`) and a graceful shutdown with event streams open.
// Args: port, isolates, idleTimeout in ms.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:thor_server/thor_server.dart';

class _Renderer implements PageRenderer<String> {
  @override
  List<int> render(String page, RenderContext context) => utf8.encode(page);

  @override
  String errorPage(ErrorState state) => 'error ${state.status}';
}

var _open = 0;

Future<void> main(List<String> args) => ThorServer.serve(
  () => ThorServer(
    idleTimeout: Duration(milliseconds: int.parse(args[2])),
    handler: RouteHandler<String>(
      renderer: _Renderer(),
      routes: [
        ResourceRoute<String>(
          path: 'events',
          respond: (r) {
            // ignore: close_sinks
            final c = StreamController<ServerEvent>(
              onListen: () => _open++,
              onCancel: () => _open--,
            );
            return ThorResponse.events(
              c.stream,
              heartbeat: const Duration(seconds: 30),
            );
          },
        ),
        ResourceRoute<String>(
          path: 'open',
          respond: (r) => ThorResponse.json({'open': _open}),
        ),
        PageRoute<String, void>(build: (_) => 'home'),
      ],
    ),
  ),
  address: InternetAddress.loopbackIPv4,
  port: int.parse(args.first),
  isolates: int.parse(args[1]),
  shutdownTimeout: const Duration(seconds: 6),
);
