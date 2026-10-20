// `Redirect(...).flash('Saved')`: a message for the next page that draws,
// carried by a short-lived cookie (Rails' `flash`, Phoenix's `put_flash`,
// Remix's `session.flash`).
import 'dart:convert';

import 'package:test/test.dart';
import 'package:thor_server/thor_server.dart';

class _Renderer implements PageRenderer<String> {
  int renders = 0;

  @override
  List<int> render(String page, RenderContext context) {
    renders++;
    return utf8.encode(page);
  }

  @override
  String errorPage(ErrorState state) => 'error ${state.status}';
}

PageRequest _get(String path, {Map<HttpHeader, String> headers = const {}}) =>
    PageRequest(
      method: HttpMethod.get,
      uri: Uri.parse('http://site.test$path'),
      headers: {HttpHeader.host: 'site.test', ...headers},
    );

PageRequest _post(String path) => PageRequest(
  method: HttpMethod.post,
  uri: Uri.parse('http://site.test$path'),
  headers: const {
    HttpHeader.host: 'site.test',
    HttpHeader.origin: 'http://site.test',
    HttpHeader.contentType: 'application/x-www-form-urlencoded',
  },
  body: Stream.value(const []),
);

String? _flashCookie(ThorResponse r) => r.cookies
    .where((c) => c.startsWith('$flashCookie='))
    .cast<String?>()
    .firstOrNull;

void main() {
  late _Renderer renderer;
  late RouteHandler<String> handler;

  setUp(() {
    renderer = _Renderer();
    handler = RouteHandler<String>(
      renderer: renderer,
      routes: [
        PageRoute<String, void>(
          path: 'orders',
          cache: const Duration(minutes: 5),
          build: (s) => 'orders',
          actions: {
            'delete': (r) => const Redirect(
              RouteUrl('/orders'),
            ).flash('Order deleted', kind: FlashKind.success),
            'html': (r) => const Redirect(
              RouteUrl('/orders'),
            ).flash('<script>alert(1)</script>\r\nSet-Cookie: x=1'),
            'long': (r) =>
                const Redirect(RouteUrl('/orders')).flash('xxxxxxxxxx' * 500),
            'empty': (r) => const Redirect(RouteUrl('/orders')).flash('  '),
            'found': (r) =>
                const Redirect.found(RouteUrl('/orders')).flash('Moved'),
            'plain': (r) => const Redirect(RouteUrl('/orders')),
            'reset': (r) => const Redirect(
              RouteUrl('/orders/?page=1'),
              resetScroll: true,
            ).flash('Hi'),
            'resetPlain': (r) => Redirect.back(r, resetScroll: true),
          },
        ),
        PageRoute<String, void>(path: 'about', build: (s) => 'about'),
      ],
    );
  });

  group('Redirect resetScroll', () {
    String? scrollCookie(ThorResponse r) => r.cookies
        .where((c) => c.startsWith('thor-scroll='))
        .cast<String?>()
        .firstOrNull;

    PageRequest post(String path, {String? tab, String? scheme}) {
      final uri = Uri.parse('${scheme ?? 'http'}://site.test$path');
      return PageRequest(
        method: HttpMethod.post,
        uri: uri,
        headers: {
          HttpHeader.host: 'site.test',
          HttpHeader.origin: '${uri.scheme}://site.test',
          HttpHeader.contentType: 'application/x-www-form-urlencoded',
          if (tab != null) HttpHeader.cookie: 'thor-tab=$tab',
        },
        body: Stream.value(const []),
      );
    }

    test('echoes the tab that posted, for the script to read', () async {
      final r = await handler.handle(post('/orders?/reset', tab: 'k3j9x0a'));
      expect(r.status, 303);
      final cookie = scrollCookie(r)!;
      expect(cookie, startsWith('thor-scroll=k3j9x0a;'));
      expect(cookie, contains('Max-Age=20'));
      expect(cookie, isNot(contains('HttpOnly')));
      expect(cookie, contains('Path=/'));
      expect(cookie, contains('SameSite=Lax'));
      expect(_flashCookie(r), isNotNull, reason: 'the flash still rides');
    });

    test('is Secure over HTTPS, straight or behind a proxy', () async {
      final direct = await handler.handle(
        post('/orders?/reset', tab: 'k3j9x0a', scheme: 'https'),
      );
      expect(scrollCookie(direct), contains('; Secure'));
      final plain = await handler.handle(
        post('/orders?/reset', tab: 'k3j9x0a'),
      );
      expect(scrollCookie(plain), isNot(contains('Secure')));
    });

    test(
      'a path of any shape cannot break it: the cookie is the tab',
      () async {
        for (final location in [
          '?page=1',
          'archive',
          '/p/caf\u00e9',
          '/a;b,c d',
          '/${'x' * 6000}',
          'https://other.example/x',
        ]) {
          final h = RouteHandler<String>(
            renderer: renderer,
            routes: [
              PageRoute<String, void>(
                path: 'orders',
                build: (s) => 'orders',
                actions: {
                  'go': (r) => Redirect(RouteUrl(location), resetScroll: true),
                },
              ),
            ],
          );
          final r = await h.handle(post('/orders?/go', tab: 'k3j9x0a'));
          expect(r.status, 303, reason: location);
          expect(
            scrollCookie(r),
            startsWith('thor-scroll=k3j9x0a;'),
            reason: location,
          );
          expect(scrollCookie(r)!.length, lessThan(200), reason: location);
        }
      },
    );

    test('no tab, or a value that is not one: no cookie', () async {
      expect(
        scrollCookie(await handler.handle(post('/orders?/reset'))),
        isNull,
      );
      for (final bad in ['', 'x' * 100, 'a b', '%00']) {
        final r = await handler.handle(post('/orders?/reset', tab: bad));
        expect(scrollCookie(r), isNull, reason: bad);
        expect(r.status, 303);
      }
    });

    test('Redirect.back takes it too, and by default there is none', () async {
      final r = await handler.handle(post('/orders?/resetPlain', tab: 'abc'));
      expect(scrollCookie(r), startsWith('thor-scroll=abc;'));
      expect(
        scrollCookie(await handler.handle(post('/orders?/plain', tab: 'abc'))),
        isNull,
      );
    });

    test('a redirect from a GET (a guard) is never cached with it', () async {
      final h = RouteHandler<String>(
        renderer: renderer,
        routes: [
          PageRoute<String, void>(
            path: 'guarded',
            cache: const Duration(minutes: 5),
            load: (r) =>
                throw const Redirect(RouteUrl('/orders'), resetScroll: true),
            build: (s) => 'guarded',
          ),
        ],
      );
      final get = PageRequest(
        method: HttpMethod.get,
        uri: Uri.parse('http://site.test/guarded'),
        headers: {
          HttpHeader.host: 'site.test',
          HttpHeader.cookie: 'thor-tab=abc',
        },
      );
      final first = await h.handle(get);
      final second = await h.handle(
        PageRequest(
          method: HttpMethod.get,
          uri: Uri.parse('http://site.test/guarded'),
          headers: {
            HttpHeader.host: 'site.test',
            HttpHeader.cookie: 'thor-tab=zzz',
          },
        ),
      );
      expect(scrollCookie(first), startsWith('thor-scroll=abc;'));
      expect(scrollCookie(second), startsWith('thor-scroll=zzz;'));
    });
  });

  group('Redirect.flash', () {
    test('sets a short-lived cookie the server reads and clears', () async {
      final r = await handler.handle(_post('/orders?/delete'));
      expect(r.status, 303);
      expect(r.headers['location'], '/orders');
      final cookie = _flashCookie(r)!;
      expect(cookie, startsWith('$flashCookie=success%3AOrder%20deleted'));
      expect(cookie, contains('Max-Age=120'));
      expect(cookie, contains('HttpOnly'));
      expect(cookie, contains('SameSite=Lax'));
      expect(cookie, contains('Path=/'));
    });

    test('keeps the redirect status of the variant', () async {
      final r = await handler.handle(_post('/orders?/found'));
      expect(r.status, 302);
      expect(_flashCookie(r), isNotNull);
    });

    test('a redirect without a flash sets no cookie', () async {
      final r = await handler.handle(_post('/orders?/plain'));
      expect(_flashCookie(r), isNull);
    });

    test('a blank message sets no cookie', () async {
      final r = await handler.handle(_post('/orders?/empty'));
      expect(_flashCookie(r), isNull);
    });

    test('HTML and header injection travel as inert text', () async {
      final r = await handler.handle(_post('/orders?/html'));
      final cookie = _flashCookie(r)!;
      expect(cookie, isNot(contains('<')));
      expect(cookie, isNot(contains('\r')));
      expect(cookie, isNot(contains('\n')));
      expect(r.cookies, hasLength(1));
      final value = cookie.substring(
        cookie.indexOf('=') + 1,
        cookie.indexOf(';'),
      );
      expect(
        Uri.decodeComponent(value),
        'info:<script>alert(1)</script>\r\nSet-Cookie: x=1',
      );
    });

    test('a long message is cut to fit a cookie', () async {
      final r = await handler.handle(_post('/orders?/long'));
      final cookie = _flashCookie(r)!;
      expect(cookie.length, lessThan(600));
    });
  });

  group('reading it', () {
    test('a page with a flash is never the shared cached one', () async {
      await handler.handle(_get('/orders'));
      await handler.handle(_get('/orders'));
      expect(renderer.renders, 1, reason: 'cached for everyone else');
      final r = await handler.handle(
        _get('/orders', headers: {HttpHeader.cookie: '$flashCookie=info%3AHi'}),
      );
      expect(renderer.renders, 2);
      expect(r.headers['cache-control'], contains('private'));
      // And it did not replace the shared copy.
      final plain = await handler.handle(_get('/orders'));
      expect(renderer.renders, 2);
      expect(plain.headers['cache-control'], isNot(contains('private')));
    });

    test('a prefetch never takes the flash: it is declined', () async {
      final r = await handler.handle(
        _get(
          '/about',
          headers: {
            HttpHeader.cookie: '$flashCookie=info%3AHi',
            const HttpHeader('sec-purpose'): 'prefetch',
          },
        ),
      );
      expect(r.status, 503);
      expect(_flashCookie(r), isNull, reason: 'the cookie stays for the visit');
      expect(renderer.renders, 0);
    });

    test('a prefetch without a flash is served as always', () async {
      final r = await handler.handle(
        _get('/about', headers: {const HttpHeader('sec-purpose'): 'prefetch'}),
      );
      expect(r.status, 200);
    });

    test('a redirect never consumes it', () async {
      final r = await handler.handle(
        _get(
          '/orders/',
          headers: {HttpHeader.cookie: '$flashCookie=info%3AHi'},
        ),
      );
      expect(r.status, 308);
      expect(_flashCookie(r), isNull);
    });
  });

  group('FlashMessage.parse', () {
    test('reads kind and text, anything else is info', () {
      expect(FlashMessage.parse('success:Done')!.kind, FlashKind.success);
      expect(FlashMessage.parse('success:Done')!.message, 'Done');
      expect(FlashMessage.parse('nope:Hi')!.kind, FlashKind.info);
      expect(FlashMessage.parse('nope:Hi')!.message, 'Hi');
      expect(FlashMessage.parse('no colon')!.message, 'no colon');
      expect(FlashMessage.parse('error:a:b')!.message, 'a:b');
    });

    test('empty or absent is none; a huge one is cut', () {
      expect(FlashMessage.parse(null), isNull);
      expect(FlashMessage.parse(''), isNull);
      expect(FlashMessage.parse('error:   '), isNull);
      expect(FlashMessage.parse('info:${'y' * 9999}')!.message.length, 300);
    });
  });
}
