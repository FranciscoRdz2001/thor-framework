// A server for isolate_setup_test: every page says whether its isolate ran
// the set-up (a static, like the states' registry thor installs).
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:thor_server/thor_server.dart';

String _ready = 'not set up';

void _setUp() => _ready = 'set up in ${Isolate.current.debugName}';

class _Renderer implements PageRenderer<String> {
  @override
  List<int> render(String page, RenderContext context) => utf8.encode(page);

  @override
  String errorPage(ErrorState state) => 'error ${state.status}';
}

Future<void> main(List<String> args) async {
  ThorServer.setUpIsolates(_setUp);
  await ThorServer.serve(
    () => ThorServer(
      handler: RouteHandler<String>(
        renderer: _Renderer(),
        routes: [PageRoute<String, void>(build: (_) => _ready)],
      ),
    ),
    address: InternetAddress.loopbackIPv4,
    port: int.parse(args.first),
    isolates: 3,
  );
}
