// `X-Forwarded-Host` is a header any client can send: without a host list
// or a public origin it still never names the site (a sitemap built from
// it is publicly cacheable).
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
  late HttpServer http;

  setUp(() async {
    final server = ThorServer(
      handler: RouteHandler<String>(
        renderer: _Renderer(),
        onError: (request, error, stack) {},
        routes: [
          ResourceRoute.sitemap((r) => const Sitemap([SitemapUrl('/')])),
          ResourceRoute.robots((r) => const Robots([])),
        ],
      ),
    );
    http = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    http.listen(server.handleHttp);
  });
  tearDown(() => http.close(force: true));

  Future<String> body(String path) async {
    final client = HttpClient();
    try {
      final req = await client.get(http.address.host, http.port, path);
      req.headers
        ..host = 'site.test'
        ..set('x-forwarded-host', 'evil.example');
      final res = await req.close();
      return await utf8.decodeStream(res);
    } finally {
      client.close(force: true);
    }
  }

  test('the sitemap ignores X-Forwarded-Host', () async {
    final xml = await body('/sitemap.xml');
    expect(xml, contains('<loc>http://site.test:${http.port}/</loc>'));
    expect(xml, isNot(contains('evil.example')));
  });

  test('robots.txt ignores X-Forwarded-Host', () async {
    expect(await body('/robots.txt'), isNot(contains('evil.example')));
  });
}
