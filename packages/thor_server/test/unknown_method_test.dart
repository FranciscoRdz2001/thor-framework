// An HTTP method the server doesn't know gets a completed 501.
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:thor_server/thor_server.dart';

class _Renderer implements PageRenderer<String> {
  @override
  List<int> render(String page, RenderContext context) => utf8.encode(page);

  @override
  String errorPage(ErrorState state) => 'error ${state.status}';
}

void main() {
  test('an unknown method answers 501 and closes the response', () async {
    final server = ThorServer(
      handler: RouteHandler<String>(
        renderer: _Renderer(),
        onError: (request, error, stack) {},
        routes: [PageRoute<String, void>(path: '', build: (s) => 'home')],
      ),
    );
    final http = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    http.listen(server.handleHttp);
    final client = HttpClient();
    try {
      final req = await client.open('PROPFIND', 'localhost', http.port, '/');
      final res = await req.close().timeout(const Duration(seconds: 5));
      expect(res.statusCode, 501);
      await res.drain<void>();
    } finally {
      client.close(force: true);
      await http.close(force: true);
    }
  });
}
