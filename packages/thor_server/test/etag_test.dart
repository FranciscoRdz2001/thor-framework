@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:thor_server/src/handler.dart' show etagOf;
import 'package:thor_server/thor_server.dart';

class _Renderer implements PageRenderer<String> {
  var renders = 0;

  @override
  List<int> render(String page, RenderContext context) {
    renders++;
    return utf8.encode(page);
  }

  @override
  String errorPage(ErrorState state) => 'plain error ${state.status}';
}

PageRequest _request(
  String path, {
  HttpMethod method = HttpMethod.get,
  Map<HttpHeader, String> headers = const {},
}) => PageRequest(
  method: method,
  uri: Uri.parse('http://site.test$path'),
  headers: {
    HttpHeader.host: 'site.test',
    HttpHeader.origin: 'http://site.test',
    HttpHeader.contentType: 'application/x-www-form-urlencoded',
    ...headers,
  },
  body: method == HttpMethod.post ? Stream.value(utf8.encode('a=1')) : null,
);

void main() {
  late _Renderer renderer;
  late RouteHandler<String> handler;
  var version = 1;

  setUp(() {
    version = 1;
    renderer = _Renderer();
    handler = RouteHandler<String>(
      renderer: renderer,
      onError: (request, error, stack) {},
      personalized: (r) => r.cookies.containsKey('user'),
      routes: [
        LayoutRoute<String, void>(
          build: (s, child) => child,
          error: (e) => 'error ${e.status}',
          children: [
            PageRoute<String, void>(
              path: 'page',
              build: (s) => 'page v$version',
              actions: {'default': (r) async => const ActionResult.success()},
            ),
            PageRoute<String, void>(
              path: 'cached',
              cache: const Duration(minutes: 1),
              build: (s) => 'cached v$version',
            ),
            PageRoute<String, void>(
              path: 'me',
              cache: const Duration(minutes: 1),
              build: (s) => 'hello ${s.request.cookies['user'] ?? 'guest'}',
            ),
            PageRoute<String, void>(
              path: 'flash',
              load: (r) => r.response.setCookie('flash', ''),
              build: (s) => 'flash',
            ),
            PageRoute<String, void>(
              path: 'own-tag',
              load: (r) =>
                  r.response.headers[const HttpHeader('ETag')] = '"v7"',
              build: (s) => 'own',
            ),
            PageRoute<String, void>(
              path: 'secret',
              load: (r) =>
                  r.response.headers[HttpHeader.cacheControl] = 'no-store',
              build: (s) => 'secret',
            ),
            PageRoute<String, void>(
              path: 'accepted',
              load: (r) => r.response.status = 202,
              build: (s) => 'accepted',
            ),
          ],
        ),
      ],
    );
  });

  Future<ThorResponse> get(
    String path, {
    String? ifNoneMatch,
    HttpMethod method = HttpMethod.get,
    String? cookie,
  }) => handler.handle(
    _request(
      path,
      method: method,
      headers: {
        HttpHeader.ifNoneMatch: ?ifNoneMatch,
        HttpHeader.cookie: ?cookie,
      },
    ),
  );

  group('ETag', () {
    test('a page gets a strong tag that follows its body', () async {
      final a = (await get('/page')).headers['etag']!;
      expect(a, matches(RegExp(r'^"[0-9a-f]+-[0-9a-f]{16}"$')));
      expect((await get('/page')).headers['etag'], a);
      version = 2;
      expect((await get('/page')).headers['etag'], isNot(a));
    });

    test('one byte apart anywhere, in either lane or the tail: different '
        'tags', () {
      final random = Random(9);
      for (final length in [0, 1, 7, 8, 15, 16, 17, 31, 33, 100, 4099]) {
        final body = Uint8List.fromList([
          for (var i = 0; i < length; i++) random.nextInt(256),
        ]);
        final tag = etagOf(body);
        expect(etagOf(Uint8List.fromList(body)), tag);
        expect(etagOf(body.toList()), tag);
        for (var at = 0; at < length; at++) {
          final changed = Uint8List.fromList(body);
          changed[at] ^= 1 + random.nextInt(255);
          expect(etagOf(changed), isNot(tag), reason: 'length $length at $at');
        }
      }
    });

    test('same length, one byte apart: different tags', () async {
      final a = (await get('/page')).headers['etag'];
      version = 3;
      expect((await get('/page')).headers['etag'], isNot(a));
    });

    test('HEAD gets the same tag as GET', () async {
      expect(
        (await get('/page', method: HttpMethod.head)).headers['etag'],
        (await get('/page')).headers['etag'],
      );
    });

    test('not on pages that set cookies, not even with *', () async {
      final r = await get('/flash', ifNoneMatch: '*');
      expect(r.status, 200);
      expect(r.headers, isNot(contains('etag')));
      expect(r.cookies, isNotEmpty);
    });

    test('not on error pages; * does not turn a 404 into a 304', () async {
      final r = await get('/nowhere', ifNoneMatch: '*');
      expect(r.status, 404);
      expect(r.headers, isNot(contains('etag')));
    });

    test('not on a status other than 200', () async {
      final r = await get('/accepted', ifNoneMatch: '*');
      expect(r.status, 202);
      expect(r.headers, isNot(contains('etag')));
    });

    test('not on no-store pages (nothing is kept to revalidate)', () async {
      final r = await get('/secret', ifNoneMatch: '*');
      expect(r.status, 200);
      expect(r.headers, isNot(contains('etag')));
    });

    test("the app's own ETag is kept and validated", () async {
      final r = await get('/own-tag');
      expect(r.headers['ETag'], '"v7"');
      expect(r.headers, isNot(contains('etag')));
      expect((await get('/own-tag', ifNoneMatch: '"v7"')).status, 304);
    });

    test('a cached page is hashed once and keeps its tag', () async {
      final a = await get('/cached');
      final b = await get('/cached');
      expect(renderer.renders, 1);
      expect(identical(a, b), isTrue); // the stored response, tag included
      expect(
        (await get('/cached', ifNoneMatch: a.headers['etag'])).status,
        304,
      );
      expect(renderer.renders, 1);
    });
  });

  group('If-None-Match', () {
    late String tag;

    setUp(() async => tag = (await get('/page')).headers['etag']!);

    test(
      'a match is a 304 without body that keeps the cache headers',
      () async {
        final r = await get('/page', ifNoneMatch: tag);
        expect(r.status, 304);
        expect(r.body, isEmpty);
        expect(r.headers['etag'], tag);
        expect(r.headers['cache-control'], 'no-cache');
        expect(r.headers, isNot(contains('content-type')));
      },
    );

    test('another tag is a full 200', () async {
      final r = await get('/page', ifNoneMatch: '"0-0000000000000000"');
      expect(r.status, 200);
      expect(r.text, 'page v1');
    });

    test('a changed page is a 200 for the old tag', () async {
      version = 2;
      expect((await get('/page', ifNoneMatch: tag)).status, 200);
    });

    test('weak comparison: W/ matches, and the 304 echoes it', () async {
      final r = await get('/page', ifNoneMatch: 'W/$tag');
      expect(r.status, 304);
      expect(r.headers['etag'], 'W/$tag');
    });

    test('a list matches when any tag does', () async {
      expect((await get('/page', ifNoneMatch: '"a", W/"b" ,$tag')).status, 304);
      expect((await get('/page', ifNoneMatch: '"a", W/"b"')).status, 200);
    });

    test('* matches a page that exists', () async {
      final r = await get('/page', ifNoneMatch: ' * ');
      expect(r.status, 304);
      expect(r.headers['etag'], tag);
    });

    test('an unquoted or truncated tag does not match', () async {
      final bare = tag.substring(1, tag.length - 1);
      expect((await get('/page', ifNoneMatch: bare)).status, 200);
      expect((await get('/page', ifNoneMatch: tag.substring(1))).status, 200);
      expect((await get('/page', ifNoneMatch: '')).status, 200);
    });

    test('HEAD answers 304 too', () async {
      final r = await get('/page', method: HttpMethod.head, ifNoneMatch: tag);
      expect(r.status, 304);
      expect(r.body, isEmpty);
    });

    test('POST is never a 304 (the action runs)', () async {
      for (final inm in [tag, '*']) {
        final r = await get('/page', method: HttpMethod.post, ifNoneMatch: inm);
        expect(r.status, 200);
        expect(r.text, 'page v1');
        expect(r.headers, isNot(contains('etag')));
      }
    });

    test(
      "personalized pages: each visitor's own tag, never another's",
      () async {
        final ana = await get('/me', cookie: 'user=ana');
        final bob = await get('/me', cookie: 'user=bob');
        expect(ana.text, 'hello ana');
        expect(ana.headers['etag'], isNot(bob.headers['etag']));
        final again = await get(
          '/me',
          cookie: 'user=ana',
          ifNoneMatch: ana.headers['etag'],
        );
        expect(again.status, 304);
        final other = await get(
          '/me',
          cookie: 'user=bob',
          ifNoneMatch: ana.headers['etag'],
        );
        expect(other.status, 200);
        expect(other.text, 'hello bob');
        // The shared (guest) copy is not validated by a visitor's tag.
        expect(
          (await get('/me', ifNoneMatch: ana.headers['etag'])).status,
          200,
        );
      },
    );
  });

  group('over HTTP', () {
    late HttpServer http;
    final client = HttpClient()..autoUncompress = false;

    setUp(() async {
      http = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      http.listen(
        ThorServer(
          handler: RouteHandler<String>(
            renderer: _Renderer(),
            onError: (request, error, stack) {},
            routes: [
              PageRoute<String, void>(
                path: 'big',
                build: (s) => 'big ${'x' * 4000}',
              ),
              PageRoute<String, void>(
                path: 'varies',
                load: (r) =>
                    r.response.headers[const HttpHeader('Vary')] = 'Cookie',
                build: (s) => 'varies ${'y' * 4000}',
              ),
              PageRoute<String, void>(path: 'small', build: (s) => 'small'),
            ],
          ),
        ).handleHttp,
      );
    });

    tearDown(() => http.close(force: true));

    Future<HttpClientResponse> fetch(
      String path, {
      bool gzip = false,
      String? ifNoneMatch,
      HttpMethod method = HttpMethod.get,
    }) async {
      final request = await client.open(
        method.token,
        '127.0.0.1',
        http.port,
        path,
      );
      request.headers.set('accept-encoding', gzip ? 'gzip' : 'identity');
      if (ifNoneMatch != null) {
        request.headers.set('if-none-match', ifNoneMatch);
      }
      return request.close();
    }

    Future<List<int>> read(HttpClientResponse r) =>
        r.fold(<int>[], (a, b) => a..addAll(b));

    test('gzip: weak tag on other bytes, Vary on both encodings', () async {
      final plain = await fetch('/big');
      final zipped = await fetch('/big', gzip: true);
      await read(plain);
      await read(zipped);
      final strong = plain.headers.value('etag')!;
      expect(strong, startsWith('"'));
      expect(zipped.headers.value('content-encoding'), 'gzip');
      expect(zipped.headers.value('etag'), 'W/$strong');
      expect(plain.headers.value('vary'), 'Accept-Encoding');
      expect(zipped.headers.value('vary'), 'Accept-Encoding');
    });

    test('304 to either encoding: no body, Vary and cache headers', () async {
      final strong = (await fetch('/big')).headers.value('etag')!;
      for (final (gzip, tag) in [
        (true, 'W/$strong'),
        (false, strong),
        // A cached gzip copy stays valid for a client that stops accepting
        // gzip (weak comparison): same content.
        (false, 'W/$strong'),
      ]) {
        final r = await fetch('/big', gzip: gzip, ifNoneMatch: tag);
        expect(r.statusCode, 304);
        expect(await read(r), isEmpty);
        expect(r.headers.value('etag'), tag);
        expect(r.headers.value('vary'), 'Accept-Encoding');
        expect(r.headers.value('cache-control'), 'no-cache');
        expect(r.headers.value('content-encoding'), isNull);
      }
    });

    test("the app's Vary is merged, not replaced", () async {
      final r = await fetch('/varies', gzip: true);
      await read(r);
      expect(r.headers['vary'], ['Cookie, Accept-Encoding']);
      final again = await fetch(
        '/varies',
        gzip: true,
        ifNoneMatch: r.headers.value('etag'),
      );
      expect(again.statusCode, 304);
      expect(again.headers['vary'], ['Cookie, Accept-Encoding']);
    });

    test('a small page is not compressed and keeps its strong tag', () async {
      final r = await fetch('/small', gzip: true);
      expect(utf8.decode(await read(r)), 'small');
      expect(r.headers.value('etag'), startsWith('"'));
      expect(r.headers.value('content-encoding'), isNull);
    });

    test('HEAD: tag and length, no body; 304 when it matches', () async {
      final get = await fetch('/big');
      final length = (await read(get)).length;
      final head = await fetch('/big', method: HttpMethod.head);
      expect(await read(head), isEmpty);
      expect(head.headers.value('etag'), get.headers.value('etag'));
      expect(head.contentLength, length);
      final cond = await fetch(
        '/big',
        method: HttpMethod.head,
        ifNoneMatch: get.headers.value('etag'),
      );
      expect(cond.statusCode, 304);
    });
  });
}
