import 'dart:convert';

import 'package:test/test.dart';
import 'package:thor_server/thor_server.dart';

class _Renderer implements PageRenderer<String> {
  @override
  List<int> render(String page, RenderContext context) => utf8.encode(page);

  @override
  String errorPage(ErrorState state) => 'error ${state.status}';
}

PageRequest _req(String method, String path) => PageRequest(
  method: HttpMethod.tryParse(method)!,
  uri: Uri.parse('http://site.test$path'),
  headers: {
    HttpHeader.host: 'site.test',
    if (method == 'POST') ...{
      HttpHeader.origin: 'http://site.test',
      HttpHeader.contentType: 'application/x-www-form-urlencoded',
    },
  },
  body: method == 'POST' ? Stream.value(utf8.encode('')) : null,
);

void main() {
  RouteHandler<String> handler(Guard guard) => RouteHandler<String>(
    renderer: _Renderer(),
    onError: (request, error, stack) {},
    routes: [
      PageRoute<String, void>(
        path: 'old',
        build: (s) => 'old',
        redirect: guard,
        actions: {'default': (r) => null},
      ),
    ],
  );

  group('a guard chooses the status', () {
    test('a returned path stays a 302 (a 303 after a POST)', () async {
      final h = handler((r) => const RouteUrl('/new'));
      final get = await h.handle(_req('GET', '/old'));
      expect(get.status, 302);
      expect(get.headers['location'], '/new');
      expect((await h.handle(_req('POST', '/old'))).status, 303);
    });

    for (final status in [301, 302, 303, 307, 308]) {
      test('a thrown Redirect keeps its $status', () async {
        final h = handler(
          (r) => throw Redirect(const RouteUrl('/new'), status: status),
        );
        final get = await h.handle(_req('GET', '/old'));
        expect(get.status, status);
        expect(get.headers['location'], '/new');
        expect((await h.handle(_req('POST', '/old'))).status, status);
      });
    }

    test('Redirect.permanent / .temporary from an async guard', () async {
      final perm = handler(
        (r) async => throw const Redirect.permanent(RouteUrl('/new')),
      );
      expect((await perm.handle(_req('GET', '/old'))).status, 308);
      final temp = handler(
        (r) async => throw const Redirect.temporary(RouteUrl('/new')),
      );
      expect((await temp.handle(_req('GET', '/old'))).status, 307);
    });

    test('no guard redirect: the page renders', () async {
      final h = handler((r) => null);
      expect((await h.handle(_req('GET', '/old'))).status, 200);
    });
  });

  group('hostile targets never leave the site', () {
    final hostile = [
      '//evil.example',
      '/\\evil.example',
      '///evil.example',
      '\\\\evil.example',
      '\\/evil.example',
      '/\t/evil.example',
      '/\n/evil.example',
      ' //evil.example',
      '\t//evil.example',
      '//evil.example/a?b=//c',
    ];
    for (final target in hostile) {
      final label = jsonEncode(target);
      test('returned $label', () async {
        final r = await handler(
          (q) => RouteUrl(target),
        ).handle(_req('GET', '/old'));
        expect(r.status, 302);
        expect(r.headers['location'], matches(RegExp(r'^/(?![/\\])')));
      });
      test('thrown, with a chosen status $label', () async {
        final h = handler((q) => throw Redirect.permanent(RouteUrl(target)));
        final r = await h.handle(_req('GET', '/old'));
        expect(r.status, 308);
        expect(r.headers['location'], matches(RegExp(r'^/(?![/\\])')));
      });
    }

    test('a header-injection target has no line break', () async {
      final r = await handler(
        (q) => const RouteUrl('/ok\r\nSet-Cookie: x=1'),
      ).handle(_req('GET', '/old'));
      expect(r.headers['location'], isNot(contains('\n')));
      expect(r.headers['location'], isNot(contains('\r')));
    });

    test('an absolute URL a guard chose on purpose is kept', () async {
      final r = await handler(
        (q) => const RouteUrl('https://sso.example/login?next=/old'),
      ).handle(_req('GET', '/old'));
      expect(r.headers['location'], 'https://sso.example/login?next=/old');
    });

    test('a safe path with a query is untouched', () async {
      final r = await handler(
        (q) => const RouteUrl('/login?next=%2F%2Fevil'),
      ).handle(_req('GET', '/old'));
      expect(r.headers['location'], '/login?next=%2F%2Fevil');
    });
  });
}
