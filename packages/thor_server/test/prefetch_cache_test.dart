// A page fetched ahead of the visit (`Sec-Purpose: prefetch`, `Purpose`,
// Firefox's `<link rel=prefetch>`) may be used by the click without asking
// again: a short private `max-age` instead of `no-cache`. Only a public GET
// page that sets nothing for the visitor.
import 'dart:convert';

import 'package:test/test.dart';
import 'package:thor_server/thor_server.dart';

class _Renderer implements PageRenderer<String> {
  @override
  List<int> render(String page, RenderContext context) => utf8.encode(page);

  @override
  String errorPage(ErrorState state) => 'error ${state.status}';
}

PageRequest _get(String path, [Map<HttpHeader, String> headers = const {}]) =>
    PageRequest(
      method: HttpMethod.get,
      uri: Uri.parse('http://site.test$path'),
      headers: {HttpHeader.host: 'site.test', ...headers},
    );

void main() {
  final handler = RouteHandler<String>(
    renderer: _Renderer(),
    onError: (request, error, stack) {},
    routes: [
      PageRoute<String, void>(path: '/open', build: (s) => 'open'),
      PageRoute<String, void>(
        path: '/mine',
        personalized: true,
        build: (s) => 'mine',
      ),
      PageRoute<String, void>(
        path: '/cookie',
        build: (s) => 'cookie',
        load: (r) => r.response.setCookie('seen', '1'),
      ),
      PageRoute<String, void>(
        path: '/own',
        build: (s) => 'own',
        load: (r) =>
            r.response.headers[HttpHeader.cacheControl] = 'public, max-age=60',
      ),
      PageRoute<String, void>(
        path: '/act',
        build: (s) => 'act',
        actions: {'x': (r) => null},
      ),
    ],
  );

  Future<String?> cacheControl(
    String path, [
    Map<HttpHeader, String> headers = const {},
  ]) async =>
      (await handler.handle(_get(path, headers))).headers['cache-control'];

  for (final purpose in <Map<HttpHeader, String>>[
    {const HttpHeader('sec-purpose'): 'prefetch'},
    {const HttpHeader('purpose'): 'prefetch'},
    {const HttpHeader('sec-purpose'): 'prefetch;anonymous-client-ip'},
    {const HttpHeader('x-moz'): 'prefetch'},
  ]) {
    test(
      'a public page fetched ahead ($purpose) is kept a few seconds',
      () async {
        expect(await cacheControl('/open', purpose), 'private, max-age=5');
        final r = await handler.handle(_get('/open', purpose));
        expect(r.headers['etag'], isNotNull);
      },
    );
  }

  test('a visit is asked again every time, as before', () async {
    expect(await cacheControl('/open'), 'no-cache');
  });

  test(
    'never a page of the visitor, with a cookie or with its own cache',
    () async {
      const ahead = <HttpHeader, String>{HttpHeader('sec-purpose'): 'prefetch'};
      expect(await cacheControl('/mine', ahead), contains('no-cache'));
      expect(await cacheControl('/mine', ahead), contains('private'));
      expect(await cacheControl('/cookie', ahead), 'no-cache');
      expect(await cacheControl('/own', ahead), 'public, max-age=60');
      // A visitor with a session cookie that the route reads is still safe:
      // only the answer decides.
      expect(await cacheControl('/missing', ahead), isNot(contains('max-age')));
    },
  );

  test('an answer that is not a plain 200 page is untouched', () async {
    const ahead = <HttpHeader, String>{HttpHeader('sec-purpose'): 'prefetch'};
    final r = await handler.handle(
      PageRequest(
        method: HttpMethod.post,
        uri: Uri.parse('http://site.test/act?/x'),
        headers: {
          HttpHeader.host: 'site.test',
          HttpHeader.origin: 'http://site.test',
          HttpHeader.contentType: 'application/x-www-form-urlencoded',
          ...ahead,
        },
        body: Stream.value(const []),
      ),
    );
    expect(r.headers['cache-control'], isNot(contains('max-age')));
  });

  test('the ETag still answers a revalidation with a 304', () async {
    final first = await handler.handle(
      _get('/open', {const HttpHeader('sec-purpose'): 'prefetch'}),
    );
    final again = await handler.handle(
      _get('/open', {HttpHeader.ifNoneMatch: first.headers['etag']!}),
    );
    expect(again.status, 304);
  });
}
