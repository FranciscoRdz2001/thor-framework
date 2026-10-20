// Adversarial cases for the flash: the flash across HEAD, error pages, odd cookies and
// multibyte messages.
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

PageRequest _req(
  String method,
  String path, {
  Map<HttpHeader, String> headers = const {},
}) => PageRequest(
  method: HttpMethod.tryParse(method)!,
  uri: Uri.parse('http://site.test$path'),
  headers: {HttpHeader.host: 'site.test', ...headers},
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
          build: (s) => 'orders',
          actions: {
            'emoji': (r) => const Redirect(
              RouteUrl('/orders'),
            ).flash('${'x' * 299}\u{1F600}!'),
            'cjk': (r) => const Redirect(RouteUrl('/orders')).flash('注' * 400),
          },
        ),
      ],
    );
  });

  test(
    'a message cut inside an emoji does not end in a broken character',
    () async {
      final post = PageRequest(
        method: HttpMethod.post,
        uri: Uri.parse('http://site.test/orders?/emoji'),
        headers: const {
          HttpHeader.host: 'site.test',
          HttpHeader.origin: 'http://site.test',
          HttpHeader.contentType: 'application/x-www-form-urlencoded',
        },
        body: Stream.value(const []),
      );
      final r = await handler.handle(post);
      final cookie = _flashCookie(r)!;
      final value = Uri.decodeComponent(
        cookie.substring(cookie.indexOf('=') + 1, cookie.indexOf(';')),
      );
      expect(value.contains('�'), isFalse);
      // A cookie fits 4096 bytes whole.
      expect(cookie.length, lessThan(4000));
    },
  );

  test('a cjk message at the limit still fits one cookie', () async {
    final post = PageRequest(
      method: HttpMethod.post,
      uri: Uri.parse('http://site.test/orders?/cjk'),
      headers: const {
        HttpHeader.host: 'site.test',
        HttpHeader.origin: 'http://site.test',
        HttpHeader.contentType: 'application/x-www-form-urlencoded',
      },
      body: Stream.value(const []),
    );
    final r = await handler.handle(post);
    expect(_flashCookie(r)!.length, lessThan(4096));
  });

  test('prefetch variants of other browsers are declined too', () async {
    for (final h in <Map<HttpHeader, String>>[
      {const HttpHeader('purpose'): 'prefetch'},
      {const HttpHeader('x-moz'): 'prefetch'},
      {const HttpHeader('sec-purpose'): 'prefetch;prerender'},
    ]) {
      final r = await handler.handle(
        _req(
          'GET',
          '/orders',
          headers: {HttpHeader.cookie: '$flashCookie=info%3AHi', ...h},
        ),
      );
      expect(r.status, 503, reason: '$h');
    }
  });
}
