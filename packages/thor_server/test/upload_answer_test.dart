// A POST sent by XMLHttpRequest for the upload progress (`x-thor-upload`):
// the request must not follow a redirect (its `GET` would run twice
// and use up a flash), so it is a `200` with `x-thor-location`, cookies kept.
// Every other answer goes as it is, with the header back.
import 'dart:convert';

import 'package:test/test.dart';
import 'package:thor_server/src/cache_bus.dart';
import 'package:thor_server/src/upload_results.dart';
import 'package:thor_server/thor_server.dart';

class _Renderer implements PageRenderer<String> {
  @override
  List<int> render(String page, RenderContext context) => utf8.encode(page);

  @override
  String errorPage(ErrorState state) => 'error ${state.status}';
}

PageRequest _post(String path, {bool upload = true}) => PageRequest(
  method: HttpMethod.post,
  uri: Uri.parse('http://site.test$path'),
  headers: {
    HttpHeader.host: 'site.test',
    HttpHeader.origin: 'http://site.test',
    HttpHeader.contentType: 'application/x-www-form-urlencoded',
    if (upload) const HttpHeader('x-thor-upload'): '1',
  },
  body: Stream.value(const []),
);

void main() {
  final handler = RouteHandler<String>(
    renderer: _Renderer(),
    onError: (request, error, stack) {},
    routes: [
      PageRoute<String, void>(
        path: '/p',
        build: (s) => 'page',
        actions: {
          'ok': (r) => const Redirect(RouteUrl('/done')).flash('Saved'),
          'js': (r) => const Redirect(RouteUrl('javascript:alert(1)')),
          'bad': (r) => const ActionResult.fail(422, 'no'),
          'boom': (r) => throw StateError('boom'),
        },
      ),
    ],
  );

  test('a redirect becomes a 200 with its target, cookies kept', () async {
    final r = await handler.handle(_post('/p?/ok'));
    expect(r.status, 200);
    expect(r.headers['x-thor-location'], '/done');
    expect(r.headers['x-thor-upload'], '1');
    expect(
      r.headers.keys.map((k) => k.toLowerCase()),
      isNot(contains('location')),
    );
    expect(r.cookies.any((c) => c.startsWith('$flashCookie=')), isTrue);
    expect(r.body, isEmpty);
  });

  test('without the header it is the plain 303', () async {
    final r = await handler.handle(_post('/p?/ok', upload: false));
    expect(r.status, 303);
    expect(r.headers['location'], '/done');
    expect(r.headers.containsKey('x-thor-location'), isFalse);
  });

  test('the target goes through safeLocation (never javascript:)', () async {
    final r = await handler.handle(_post('/p?/js'));
    expect(r.headers['x-thor-location'], isNot(contains('javascript')));
  });

  String? cookieOf(ThorResponse r) => r.cookies
      .where((c) => c.startsWith('thor-upload='))
      .map((c) => c.split(';').first.substring('thor-upload='.length))
      .firstOrNull;

  PageRequest get(String path, {String? cookie, String? referer}) =>
      PageRequest(
        method: HttpMethod.get,
        uri: Uri.parse('http://site.test$path'),
        headers: {
          HttpHeader.host: 'site.test',
          HttpHeader.cookie: ?cookie == null ? null : 'thor-upload=$cookie',
          HttpHeader.referer: ?referer,
        },
      );

  setUp(UploadResults.reset);

  test('a 422 page is stored: the answer is a 200 with the address of the '
      'result, its status and a cookie of the visitor', () async {
    final r = await handler.handle(_post('/p?/bad'));
    expect(r.status, 200);
    expect(r.headers['x-thor-upload'], '1');
    final to = r.headers['x-thor-location']!;
    expect(to, startsWith('/_thor/upload-result/'));
    expect(r.headers['cache-control'], 'no-store');
    final token = cookieOf(r)!;
    expect(to, endsWith(token));
    final cookie = r.cookies.firstWhere((c) => c.startsWith('thor-upload='));
    expect(cookie, contains('HttpOnly'));
    expect(cookie, contains('Path=/_thor/upload-result'));
    expect(cookie, contains('SameSite=Lax'));
  });

  test('the result is served once, with its status, never cached', () async {
    final r = await handler.handle(_post('/p?/bad'));
    final token = cookieOf(r)!;
    final to = r.headers['x-thor-location']!;
    final shown = await handler.handle(get(to, cookie: token));
    expect(shown.status, 422);
    expect(shown.headers['content-type'], startsWith('text/html'));
    expect(shown.headers['cache-control'], 'no-store');
    final plain = await handler.handle(_post('/p?/bad', upload: false));
    expect(shown.text, plain.text); // the answer a plain post gets
    // Used up: the cookie goes and the address is spent.
    expect(
      shown.cookies.any(
        (c) => c.startsWith('thor-upload=') && c.contains('Max-Age=0'),
      ),
      isTrue,
    );
    final again = await handler.handle(
      get(to, cookie: token, referer: 'http://site.test/p'),
    );
    expect(again.status, 303);
    expect(again.headers['location'], '/p');
    expect(again.headers['cache-control'], 'no-store');
  });

  test('a 200 page and a 5xx page are stored too', () async {
    final r = await handler.handle(_post('/p?/boom'));
    expect(r.status, 200);
    expect(r.headers['x-thor-location'], startsWith('/_thor/upload-result/'));
    final shown = await handler.handle(
      get(r.headers['x-thor-location']!, cookie: cookieOf(r)),
    );
    expect(shown.status, 500);
  });

  test('another visitor (no cookie, another cookie) gets nothing', () async {
    final r = await handler.handle(_post('/p?/bad'));
    final to = r.headers['x-thor-location']!;
    for (final cookie in [null, 'AAAA', '${cookieOf(r)}x']) {
      final got = await handler.handle(get(to, cookie: cookie));
      expect(got.status, 303, reason: '$cookie');
      expect(got.body, isEmpty, reason: '$cookie');
    }
    // The wrong tries did not use it up.
    expect((await handler.handle(get(to, cookie: cookieOf(r)))).status, 422);
  });

  test('a miss goes to the referer of the same site, else to /', () async {
    const to = '/_thor/upload-result/nope';
    final foreign = await handler.handle(
      get(to, cookie: 'nope', referer: 'http://evil.test/x'),
    );
    expect(foreign.headers['location'], '/');
    final own = await handler.handle(
      get(to, cookie: 'nope', referer: 'http://site.test/a?b=1'),
    );
    expect(own.headers['location'], '/a?b=1');
    expect((await handler.handle(get(to))).headers['location'], '/');
  });

  test(
    'a protocol-relative referer path is not an off-site Location',
    () async {
      const to = '/_thor/upload-result/nope';
      final r = await handler.handle(
        get(to, cookie: 'nope', referer: 'http://site.test//evil.example/x'),
      );
      expect(r.headers['location'], isNot(startsWith('//')));
      expect(r.headers['location'], '/evil.example/x');
    },
  );

  test('the result cookie follows secureCookies', () async {
    final secure = RouteHandler<String>(
      renderer: _Renderer(),
      onError: (request, error, stack) {},
      secureCookies: true,
      routes: [
        PageRoute<String, void>(
          path: '/p',
          build: (s) => 'page',
          actions: {'bad': (r) => const ActionResult.fail(422, 'no')},
        ),
      ],
    );
    final r = await secure.handle(_post('/p?/bad'));
    final cookie = r.cookies.firstWhere((c) => c.startsWith('thor-upload='));
    expect(cookie, contains('Secure'));
  });

  test('it expires', () async {
    UploadResults.ttl = Duration.zero;
    addTearDown(UploadResults.reset);
    final r = await handler.handle(_post('/p?/bad'));
    final got = await handler.handle(
      get(r.headers['x-thor-location']!, cookie: cookieOf(r)),
    );
    expect(got.status, 303);
  });

  test('memory is bounded: the oldest result goes first', () async {
    UploadResults.capacity = 3;
    addTearDown(UploadResults.reset);
    final all = [
      for (var i = 0; i < 5; i++) await handler.handle(_post('/p?/bad')),
    ];
    Future<int> status(ThorResponse r) async => (await handler.handle(
      get(r.headers['x-thor-location']!, cookie: cookieOf(r)),
    )).status;
    expect(await status(all[0]), 303);
    expect(await status(all[1]), 303);
    expect(await status(all[4]), 422);
    expect(UploadResults.length, lessThanOrEqualTo(3));
  });

  test('a page over the limit is not stored: it goes as it is', () async {
    UploadResults.maxBytes = 2;
    addTearDown(UploadResults.reset);
    final r = await handler.handle(_post('/p?/bad'));
    expect(r.status, 422);
    expect(r.headers['x-thor-upload'], '1');
    expect(r.headers.containsKey('x-thor-location'), isFalse);
  });

  test('a result another isolate stored is served here (CacheBus)', () async {
    final r = await handler.handle(_post('/p?/bad'));
    final to = r.headers['x-thor-location']!;
    final token = cookieOf(r)!;
    final message = UploadResults.takeMessage(token)!;
    UploadResults.reset();
    CacheBus.inbox.send(message);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect((await handler.handle(get(to, cookie: token))).status, 422);
  });

  test('a GET with the header is not touched', () async {
    final r = await handler.handle(
      PageRequest(
        method: HttpMethod.get,
        uri: Uri.parse('http://site.test/p'),
        headers: const {
          HttpHeader.host: 'site.test',
          HttpHeader('x-thor-upload'): '1',
        },
      ),
    );
    expect(r.headers.containsKey('x-thor-upload'), isFalse);
  });
}
