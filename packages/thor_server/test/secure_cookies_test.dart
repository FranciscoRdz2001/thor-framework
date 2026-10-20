// `Secure` on cookies: by default it follows the request (HTTPS, straight or
// behind a proxy that says so); `secureCookies` true or false decides for
// every request.
import 'dart:convert';

import 'package:test/test.dart';
import 'package:thor_server/thor_server.dart';

class _Renderer implements PageRenderer<String> {
  @override
  List<int> render(String page, RenderContext context) => utf8.encode(page);

  @override
  String errorPage(ErrorState state) => 'error ${state.status}';
}

void _session(PageRequest r) => r.locals['user'] = r.cookies['user'];

List<RouteNode<String>> _routes() => [
  PageRoute<String, String?>(
    load: (r) => r.locals['user'] as String?,
    build: (s) => 'hello ${s.data ?? 'nobody'}',
  ),
  PageRoute<String, void>(
    path: 'login',
    build: (_) => 'login',
    actions: {
      'default': (r) {
        r.response.setCookie('user', 'ana');
        return const Redirect(RouteUrl('/'));
      },
    },
  ),
  PageRoute<String, void>(
    path: 'visit',
    // A GET that sets a cookie.
    load: (r) => r.response.setCookie('visit', '1'),
    build: (_) => 'visit',
  ),
];

/// The default: `secureCookies` not given.
RouteHandler<String> _auto() =>
    RouteHandler(renderer: _Renderer(), onRequest: _session, routes: _routes());

RouteHandler<String> _with(bool secure) => RouteHandler(
  renderer: _Renderer(),
  onRequest: _session,
  secureCookies: secure,
  routes: _routes(),
);

PageRequest _login({
  String scheme = 'http',
  String host = 'site.test',
  Map<HttpHeader, String> headers = const {},
}) => PageRequest(
  method: HttpMethod.post,
  uri: Uri.parse('$scheme://$host/login'),
  headers: {
    HttpHeader.host: host,
    HttpHeader.origin: '$scheme://$host',
    HttpHeader.contentType: 'application/x-www-form-urlencoded',
    ...headers,
  },
  body: Stream.value(utf8.encode('a=1')),
);

PageRequest _visit({
  String scheme = 'http',
  Map<HttpHeader, String> headers = const {},
}) => PageRequest(
  method: HttpMethod.get,
  uri: Uri.parse('$scheme://site.test/visit'),
  headers: {HttpHeader.host: 'site.test', ...headers},
);

bool _secure(ThorResponse r, String name) {
  final header = r.cookies.singleWhere((c) => c.startsWith('$name='));
  return header.split('; ').contains('Secure');
}

void main() {
  group('by default (follows the request)', () {
    test('HTTPS: an action\'s cookie is Secure', () async {
      final r = await _auto().handle(_login(scheme: 'https'));
      expect(_secure(r, 'user'), isTrue);
    });

    test('HTTPS: a GET\'s cookie is Secure', () async {
      final r = await _auto().handle(_visit(scheme: 'https'));
      expect(_secure(r, 'visit'), isTrue);
    });

    test('behind a proxy: X-Forwarded-Proto https is Secure', () async {
      final r = await _auto().handle(
        _login(headers: {HttpHeader.xForwardedProto: 'https'}),
      );
      expect(_secure(r, 'user'), isTrue);
    });

    test('behind a proxy: Forwarded proto=https is Secure', () async {
      final r = await _auto().handle(
        _visit(
          headers: {
            const HttpHeader('forwarded'):
                'for=1.2.3.4;proto=https;by=10.0.0.1',
          },
        ),
      );
      expect(_secure(r, 'visit'), isTrue);
    });

    test('the header is read in any case, and only its first hop', () async {
      final a = await _auto().handle(
        _login(headers: {HttpHeader.xForwardedProto: 'HTTPS'}),
      );
      expect(_secure(a, 'user'), isTrue);
      final b = await _auto().handle(
        _login(headers: {HttpHeader.xForwardedProto: 'https, http'}),
      );
      expect(_secure(b, 'user'), isTrue);
      // The first hop is what the client used: this one came over http.
      final c = await _auto().handle(
        _login(headers: {HttpHeader.xForwardedProto: 'http, https'}),
      );
      expect(_secure(c, 'user'), isFalse);
    });

    test('junk in the header is not HTTPS', () async {
      for (final junk in [
        '',
        'ws',
        'httpss',
        'https;',
        'javascript',
        ' , https',
      ]) {
        final r = await _auto().handle(
          _login(headers: {HttpHeader.xForwardedProto: junk}),
        );
        expect(_secure(r, 'user'), isFalse, reason: 'x-forwarded-proto: $junk');
      }
      final r = await _auto().handle(
        _login(
          headers: {const HttpHeader('forwarded'): 'proto=http, proto=https'},
        ),
      );
      expect(_secure(r, 'user'), isFalse);
    });

    test(
      'dev on localhost over http: no Secure, and the session works',
      () async {
        final h = _auto();
        final login = await h.handle(
          _login(scheme: 'http', host: 'localhost:8080'),
        );
        expect(_secure(login, 'user'), isFalse);
        final cookie = login.cookies.single.split(';').first;
        expect(cookie, 'user=ana');
        final home = await h.handle(
          PageRequest(
            method: HttpMethod.get,
            uri: Uri.parse('http://localhost:8080/'),
            headers: {
              HttpHeader.host: 'localhost:8080',
              HttpHeader.cookie: cookie,
            },
          ),
        );
        expect(home.text, contains('hello ana'));
      },
    );

    test('a cookie that chose for itself keeps its choice', () async {
      final h = RouteHandler<String>(
        renderer: _Renderer(),
        routes: [
          PageRoute<String, void>(
            path: 'visit',
            load: (r) {
              r.response.setCookie('a', '1', secure: false);
              r.response.setCookie('b', '1', secure: true);
            },
            build: (_) => 'x',
          ),
        ],
      );
      final https = await h.handle(_visit(scheme: 'https'));
      expect(_secure(https, 'a'), isFalse);
      expect(_secure(https, 'b'), isTrue);
      final http = await h.handle(_visit());
      expect(_secure(http, 'a'), isFalse);
      expect(_secure(http, 'b'), isTrue);
    });
  });

  group('secureCookies decides for every request', () {
    test('false wins over HTTPS and a proxy saying https', () async {
      final h = _with(false);
      expect(_secure(await h.handle(_login(scheme: 'https')), 'user'), isFalse);
      expect(
        _secure(
          await h.handle(
            _visit(headers: {HttpHeader.xForwardedProto: 'https'}),
          ),
          'visit',
        ),
        isFalse,
      );
    });

    test('true is Secure even over plain http', () async {
      final h = _with(true);
      expect(_secure(await h.handle(_login()), 'user'), isTrue);
      expect(_secure(await h.handle(_visit()), 'visit'), isTrue);
    });
  });
}
