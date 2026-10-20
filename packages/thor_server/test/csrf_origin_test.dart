import 'dart:async';
import 'dart:convert';

import 'package:test/test.dart';
import 'package:thor_server/thor_server.dart';

/// The cross-site rules of a page action (see
/// docs/guia/en/session-and-security.md): what `Origin` may say, what a
/// missing one means, what `trustedOrigins` adds, and what is never
/// looked at (`Referer`, a GET).
class _Renderer implements PageRenderer<String> {
  @override
  List<int> render(String page, RenderContext context) => utf8.encode(page);

  @override
  String errorPage(ErrorState state) => 'error ${state.status}';
}

RouteHandler<String> _handler({Set<String> trusted = const {}}) =>
    RouteHandler<String>(
      renderer: _Renderer(),
      trustedOrigins: trusted,
      routes: [
        PageRoute<String, void>(
          path: 'account',
          build: (s) => 'account',
          actions: {'save': (r) => const Redirect(RouteUrl('/account'))},
        ),
      ],
    );

PageRequest _post({
  Map<HttpHeader, String> headers = const {},
  String path = '/account?/save',
  HttpMethod method = HttpMethod.post,
  String contentType = 'application/x-www-form-urlencoded',
}) => PageRequest(
  method: method,
  uri: Uri.parse('http://site.test$path'),
  headers: {
    HttpHeader.host: 'site.test',
    HttpHeader.contentType: contentType,
    ...headers,
  },
  body: Stream.value(utf8.encode('a=1')),
);

void main() {
  late RouteHandler<String> handler;
  setUp(() => handler = _handler());

  Future<int> status(PageRequest r) async => (await handler.handle(r)).status;

  group('the Origin of a form post', () {
    test('the site itself posts', () async {
      expect(
        await status(_post(headers: {HttpHeader.origin: 'http://site.test'})),
        303,
      );
    });

    // Only the host and port are compared (a proxy that ends TLS shows the
    // app `http` while the browser says `https`).
    test('the scheme is not compared', () async {
      expect(
        await status(_post(headers: {HttpHeader.origin: 'https://site.test'})),
        303,
      );
    });

    for (final origin in [
      'https://evil.test',
      'http://site.test.evil.test',
      'http://evil.test/site.test',
      'http://site.test:8080',
      'http://user@site.test',
      'http://evil.test#@site.test',
      'null',
      'file://',
      'not a url',
      '',
      'http://SITE.test.',
    ]) {
      test(
        '${origin.isEmpty ? 'an empty Origin' : origin} is refused',
        () async {
          final r = await handler.handle(
            _post(headers: {HttpHeader.origin: origin}),
          );
          expect(r.status, 403);
          expect(utf8.decode(r.body), contains('Cross-site'));
        },
      );
    }

    test(
      'no Origin on a form post is refused, whatever the form type',
      () async {
        for (final type in [
          'application/x-www-form-urlencoded',
          'multipart/form-data; boundary=x',
          'text/plain',
        ]) {
          expect(await status(_post(contentType: type)), 403, reason: type);
        }
      },
    );

    // Not a browser form: curl, a script, a test client. A browser never
    // sends this without an Origin and cross-site it needs a CORS preflight.
    test('no Origin with JSON is a script, not a form', () async {
      final r = await handler.handle(_post(contentType: 'application/json'));
      expect(r.status, isNot(403));
    });

    test('Referer is not read: it never makes a post pass', () async {
      expect(
        await status(
          _post(headers: {HttpHeader.referer: 'http://site.test/account'}),
        ),
        403,
      );
      // ... nor fail one the Origin allows.
      expect(
        await status(
          _post(
            headers: {
              HttpHeader.origin: 'http://site.test',
              HttpHeader.referer: 'https://evil.test/',
            },
          ),
        ),
        303,
      );
    });

    test('Sec-Fetch-Site is not read either', () async {
      expect(
        await status(
          _post(headers: {const HttpHeader('sec-fetch-site'): 'same-origin'}),
        ),
        403,
      );
    });

    // A browser sets `Sec-Fetch-Site` and `Origin` itself: a page of another
    // site cannot make them disagree, so a script that sends this pair is
    // forging one of them, and the request is refused.
    test(
      'Sec-Fetch-Site: cross-site with the site\'s own Origin is a forgery',
      () async {
        expect(
          await status(
            _post(
              headers: {
                HttpHeader.origin: 'http://site.test',
                const HttpHeader('sec-fetch-site'): 'cross-site',
              },
            ),
          ),
          403,
        );
        for (final site in ['same-origin', 'same-site', 'none']) {
          expect(
            await status(
              _post(
                headers: {
                  HttpHeader.origin: 'http://site.test',
                  const HttpHeader('sec-fetch-site'): site,
                },
              ),
            ),
            303,
            reason: site,
          );
        }
      },
    );

    test('a listed origin may post cross-site', () async {
      handler = _handler(trusted: {'https://app.example'});
      expect(
        await status(
          _post(
            headers: {
              HttpHeader.origin: 'https://app.example',
              const HttpHeader('sec-fetch-site'): 'cross-site',
            },
          ),
        ),
        303,
      );
    });

    test('the type of a form is read in any case', () async {
      expect(
        await status(_post(contentType: 'Application/X-WWW-Form-Urlencoded')),
        403,
      );
      expect(
        await status(_post(contentType: 'MULTIPART/FORM-DATA; boundary=x')),
        403,
      );
      expect(await status(_post(contentType: 'Text/Plain')), 403);
    });

    test('two Origin headers joined are not the site', () async {
      expect(
        await status(
          _post(
            headers: {HttpHeader.origin: 'https://evil.test, http://site.test'},
          ),
        ),
        403,
      );
    });

    // Behind a proxy the app sees the proxy's `Host` unless it forwards the
    // original one. `X-Forwarded-Host` is a header any client can send: it is
    // never read (the `Host` and `trustedOrigins` are the whole rule).
    test('X-Forwarded-Host is not read', () async {
      expect(
        await status(
          _post(
            headers: {
              HttpHeader.origin: 'https://evil.test',
              HttpHeader.xForwardedHost: 'evil.test',
            },
          ),
        ),
        403,
      );
      expect(
        await status(
          _post(
            headers: {
              HttpHeader.host: 'app.internal:8080',
              HttpHeader.origin: 'https://site.test',
              HttpHeader.xForwardedHost: 'site.test',
              const HttpHeader('forwarded'): 'host=site.test',
            },
          ),
        ),
        403,
      );
    });

    test('a proxy that rewrites Host posts through trustedOrigins', () async {
      handler = _handler(trusted: {'https://site.test'});
      expect(
        await status(
          _post(
            headers: {
              HttpHeader.host: 'app.internal:8080',
              HttpHeader.origin: 'https://site.test',
              HttpHeader.xForwardedHost: 'site.test',
            },
          ),
        ),
        303,
      );
    });

    test('a refused post runs nothing', () async {
      var saved = 0;
      final h = RouteHandler<String>(
        renderer: _Renderer(),
        routes: [
          PageRoute<String, void>(
            path: 'account',
            build: (s) => 'account',
            actions: {
              'save': (r) {
                saved++;
                return null;
              },
            },
          ),
        ],
      );
      await h.handle(_post(headers: {HttpHeader.origin: 'https://evil.test'}));
      expect(saved, 0);
      await h.handle(_post(headers: {HttpHeader.origin: 'http://site.test'}));
      expect(saved, 1);
    });
  });

  group('trustedOrigins', () {
    setUp(() => handler = _handler(trusted: {'https://app.example'}));

    test('an origin of the list posts', () async {
      expect(
        await status(
          _post(headers: {HttpHeader.origin: 'https://app.example'}),
        ),
        303,
      );
    });

    // A list is exact strings: nothing is guessed from a prefix or a case.
    for (final origin in [
      'https://APP.example',
      'https://app.example/',
      'https://app.example:443',
      'http://app.example',
      'https://app.example.evil.test',
      'https://evil.app.example',
    ]) {
      test('$origin is not the listed one', () async {
        expect(await status(_post(headers: {HttpHeader.origin: origin})), 403);
      });
    }

    test('the site itself still posts', () async {
      expect(
        await status(_post(headers: {HttpHeader.origin: 'http://site.test'})),
        303,
      );
    });
  });

  group('what the rule is not applied to', () {
    test('a GET with a foreign Origin is a page', () async {
      final r = await handler.handle(
        PageRequest(
          method: HttpMethod.get,
          uri: Uri.parse('http://site.test/account'),
          headers: {
            HttpHeader.host: 'site.test',
            HttpHeader.origin: 'https://evil.test',
          },
        ),
      );
      expect(r.status, 200);
    });

    test('a post to nothing is a 404, not a 403', () async {
      expect(
        await status(
          _post(
            path: '/nowhere',
            headers: {HttpHeader.origin: 'https://evil.test'},
          ),
        ),
        404,
      );
    });

    test('PUT, DELETE and PATCH are not routes', () async {
      for (final method in [
        HttpMethod.put,
        HttpMethod.delete,
        HttpMethod.patch,
      ]) {
        final r = await handler.handle(
          _post(
            method: method,
            headers: {HttpHeader.origin: 'http://site.test'},
          ),
        );
        expect(r.status, 405, reason: '$method');
        expect(r.headers['allow'], contains('POST'));
      }
    });
  });
}
