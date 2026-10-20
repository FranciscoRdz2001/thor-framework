// A server with one page. A page is any type `P` (here a String) drawn by a
// `PageRenderer`; `package:thor_ui/router.dart` provides the widget one.
import 'dart:convert';

import 'package:thor_server/thor_server.dart';

class TextRenderer implements PageRenderer<String> {
  @override
  List<int> render(String page, RenderContext context) =>
      utf8.encode('<!doctype html><title>thor</title><h1>$page</h1>');

  @override
  String errorPage(ErrorState state) => 'Error ${state.status}';
}

Future<void> main() => ThorServer.serve(
  () => ThorServer(
    handler: RouteHandler<String>(
      routes: [PageRoute<String, void>(build: (_) => 'Hello from thor')],
      renderer: TextRenderer(),
    ),
  ),
  port: 8080,
);
