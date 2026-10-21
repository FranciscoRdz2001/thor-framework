// PageRoute.cacheControl: what a public page tells browsers and CDNs
// (`public, max-age=60, stale-while-revalidate=600`); anything personal,
// failing or setting a cookie keeps `private, no-cache`.
import 'dart:convert';

import 'package:test/test.dart';
import 'package:thor_server/thor_server.dart';

class _Renderer implements PageRenderer<String> {
  @override
  List<int> render(String page, RenderContext context) => utf8.encode(page);

  @override
  String errorPage(ErrorState state) => 'error ${state.status}';
}

PageRequest _get(String path, [String? cookie]) => PageRequest(
  method: HttpMethod.get,
  uri: Uri.parse('http://site.test$path'),
  headers: {HttpHeader.host: 'site.test', HttpHeader.cookie: ?cookie},
);

const _swr = CacheControl(
  maxAge: Duration(seconds: 60),
  staleWhileRevalidate: Duration(seconds: 600),
);

void main() {
  final handler = RouteHandler<String>(
    renderer: _Renderer(),
    onError: (request, error, stack) {},
    routes: [
      PageRoute<String, void>(
        path: 'open',
        cacheControl: _swr,
        build: (s) => 'open',
      ),
      PageRoute<String, void>(
        path: 'mine',
        cacheControl: _swr,
        personalized: true,
        build: (s) => 'mine',
      ),
      PageRoute<String, void>(
        path: 'cookie',
        cacheControl: _swr,
        load: (r) => r.response.setCookie('seen', '1'),
        build: (s) => 'cookie',
      ),
      PageRoute<String, String>(
        path: 'reads',
        cacheControl: _swr,
        load: (r) => r.cookies['store'] ?? 'none',
        build: (s) => 'reads ${s.data}',
      ),
      PageRoute<String, void>(
        path: 'own',
        cacheControl: _swr,
        load: (r) =>
            r.response.headers[HttpHeader.cacheControl] = 'public, max-age=5',
        build: (s) => 'own',
      ),
      PageRoute<String, void>(
        path: 'missing',
        cacheControl: _swr,
        load: (r) => throw const NotFound(),
        build: (s) => 'missing',
      ),
      PageRoute<String, void>(path: 'plain', build: (s) => 'plain'),
      PageRoute<String, void>(
        path: 'cached',
        cache: const Duration(minutes: 5),
        cacheControl: _swr,
        build: (s) => 'cached',
      ),
      LayoutRoute<String, void>(
        path: 'docs',
        cacheControl: const CacheControl(maxAge: Duration(hours: 1)),
        build: (s, child) => child,
        children: [
          PageRoute<String, void>(path: 'a', build: (s) => 'a'),
          PageRoute<String, void>(
            path: 'b',
            cacheControl: _swr,
            build: (s) => 'b',
          ),
        ],
      ),
    ],
  );

  Future<String?> header(String path, [String? cookie]) async =>
      (await handler.handle(_get(path, cookie))).headers['cache-control'];

  test('the header spells every option', () {
    expect(_swr.header, 'public, max-age=60, stale-while-revalidate=600');
    expect(
      const CacheControl(
        maxAge: Duration(minutes: 1),
        sharedMaxAge: Duration(hours: 1),
        staleIfError: Duration(days: 1),
      ).header,
      'public, max-age=60, s-maxage=3600, stale-if-error=86400',
    );
  });

  test('a public page offers it to browsers and CDNs', () async {
    expect(
      await header('/open'),
      'public, max-age=60, stale-while-revalidate=600',
    );
    expect(await header('/plain'), 'no-cache');
  });

  test('a conditional request still gets it on the 304', () async {
    final first = await handler.handle(_get('/open'));
    final etag = first.headers['etag']!;
    final again = await handler.handle(
      PageRequest(
        method: HttpMethod.get,
        uri: Uri.parse('http://site.test/open'),
        headers: {HttpHeader.host: 'site.test', HttpHeader.ifNoneMatch: etag},
      ),
    );
    expect(again.status, 304);
    expect(
      again.headers['cache-control'],
      contains('stale-while-revalidate=600'),
    );
  });

  test('a personal page, a cookie and a failure keep it private', () async {
    expect(await header('/mine'), 'private, no-cache');
    expect(await header('/cookie'), 'no-cache');
    expect(await header('/reads', 'store=madrid'), 'private, no-cache');
    expect(await header('/missing'), isNot(contains('stale-while-revalidate')));
  });

  test('a page with a CSP nonce is never offered to a shared cache', () async {
    final secured = RouteHandler<String>(
      renderer: _Renderer(),
      routes: [
        LayoutRoute<String, void>(
          build: (s, child) => child,
          error: (e) => 'error',
          middleware: contentSecurityPolicy(),
          children: [
            PageRoute<String, void>(
              path: 'csp',
              cacheControl: _swr,
              build: (s) => 'csp',
            ),
          ],
        ),
      ],
    );
    final r = await secured.handle(_get('/csp'));
    expect(r.headers['cache-control'], isNot(contains('public')));
  });

  test('what the load wrote wins', () async {
    expect(await header('/own'), 'public, max-age=5');
  });

  test('a layout gives its pages a default; their own wins', () async {
    expect(await header('/docs/a'), 'public, max-age=3600');
    expect(
      await header('/docs/b'),
      'public, max-age=60, stale-while-revalidate=600',
    );
  });

  test('with the server cache the stored page carries it too', () async {
    expect(
      await header('/cached'),
      'public, max-age=60, stale-while-revalidate=600',
    );
    expect(
      await header('/cached'),
      'public, max-age=60, stale-while-revalidate=600',
    );
  });
}
