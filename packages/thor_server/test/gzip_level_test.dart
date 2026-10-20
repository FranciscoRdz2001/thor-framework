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

/// A page the size of a real one, varied enough that the two levels
/// compress it differently.
String _body(String who) => [
  for (var i = 0; i < 400; i++)
    '<li class="c${i % 7}">$who item $i · ${i * i % 97}</li>',
].join();

void main() {
  late RouteHandler<String> handler;

  setUp(() {
    handler = RouteHandler<String>(
      renderer: _Renderer(),
      onError: (request, error, stack) {},
      personalized: (r) => r.cookies.containsKey('user'),
      routes: [
        LayoutRoute<String, void>(
          build: (s, child) => child,
          children: [
            PageRoute<String, void>(
              path: 'shared',
              cache: const Duration(minutes: 1),
              build: (s) => _body('everyone'),
            ),
            LayoutRoute<String, void>(
              middleware: securityHeaders(),
              build: (s, child) => child,
              children: [
                PageRoute<String, void>(
                  path: 'secured',
                  cache: const Duration(minutes: 1),
                  build: (s) => _body('everyone'),
                ),
              ],
            ),
            PageRoute<String, void>(
              path: 'mine',
              cache: const Duration(minutes: 1),
              build: (s) => _body(s.request.cookies['user'] ?? 'guest'),
            ),
          ],
        ),
      ],
    );
  });

  Future<ThorResponse> get(String path, {String? cookie}) => handler.handle(
    PageRequest(
      method: HttpMethod.get,
      uri: Uri.parse('http://site.test$path'),
      headers: {HttpHeader.host: 'site.test', HttpHeader.cookie: ?cookie},
    ),
  );

  test('a page kept in the cache is compressed small, once', () async {
    final first = await get('/shared');
    final again = await get('/shared');
    expect(identical(first, again), isTrue, reason: 'served from the cache');
    expect(first.gzipped, GZipCodec(level: 6).encode(first.body));
    expect(identical(first.gzipped, again.gzipped), isTrue);
    expect(gzip.decode(first.gzipped), first.body);
  });

  test('a page rendered for one visitor is compressed fast', () async {
    final r = await get('/mine', cookie: 'user=ana');
    final again = await get('/mine', cookie: 'user=ana');
    expect(identical(r, again), isFalse, reason: 'rendered each time');
    expect(r.gzipped, GZipCodec(level: 1).encode(r.body));
    expect(gzip.decode(r.gzipped), r.body);
    // The fast level is a trade: a bigger body, never a wrong one.
    expect(
      r.gzipped.length,
      greaterThanOrEqualTo(GZipCodec(level: 6).encode(r.body).length),
    );
  });

  test('a response built by hand is compressed fast', () {
    final r = ThorResponse(200, body: utf8.encode(_body('x')));
    expect(r.gzipped, GZipCodec(level: 1).encode(r.body));
  });

  test(
    'a small response is compressed small even when built for one visitor',
    () {
      // Under 8 KB level 6 costs some 20 µs more for 10-18 % fewer bytes.
      final small = ThorResponse(
        200,
        body: utf8.encode(_body('x').substring(0, 6000)),
      );
      expect(small.gzipped, GZipCodec(level: 6).encode(small.body));
      final big = ThorResponse(200, body: utf8.encode(_body('x')));
      expect(big.body.length, greaterThan(8192));
      expect(big.gzipped, GZipCodec(level: 1).encode(big.body));
    },
  );

  test('a cached page behind securityHeaders() is compressed once', () async {
    final first = await get('/secured');
    final again = await get('/secured');
    expect(
      first.headers.keys.map((k) => k.toLowerCase()),
      contains('x-frame-options'),
    );
    expect(first.gzipped, GZipCodec(level: 6).encode(first.body));
    expect(identical(first.gzipped, again.gzipped), isTrue);
  });

  test('ThorServer(securityHeaders:) keeps the compressed bytes', () async {
    final first = await get('/shared');
    final secured = const SecurityHeaders().apply(first);
    expect(identical(secured, first), isFalse);
    expect(identical(secured.gzipped, first.gzipped), isTrue);
    expect(secured.gzipped, GZipCodec(level: 6).encode(first.body));
  });
}
