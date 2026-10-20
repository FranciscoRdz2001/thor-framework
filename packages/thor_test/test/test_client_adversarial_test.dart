// The test client against hostile servers and RFC 6265 / browser rules: a
// scripted handler answers exactly what a test says (raw `Set-Cookie` lines,
// odd `Location`s) and records what the client sent.
@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';

import 'package:test/test.dart';
import 'package:thor_server/thor_server.dart';
import 'package:thor_test/thor_test.dart';

class _Renderer implements PageRenderer<String> {
  @override
  List<int> render(String page, RenderContext context) => utf8.encode(page);

  @override
  String errorPage(ErrorState state) => 'error ${state.status}';
}

typedef _Script = FutureOr<ThorResponse> Function(PageRequest request);

/// A handler that answers with [script] and keeps every request it saw.
class _Scripted extends RouteHandler<String> {
  _Scripted(this.script) : super(routes: const [], renderer: _Renderer());

  final _Script script;
  final seen = <PageRequest>[];
  final bodies = <String>[];

  @override
  Future<ThorResponse> handle(PageRequest request, {bool stream = true}) async {
    seen.add(request);
    // Read the body the way a server would (once).
    try {
      bodies.add(utf8.decode(await request.bytes()));
    } on HttpError {
      bodies.add('(too large)');
    }
    return script(request);
  }
}

ThorResponse _ok([List<String> cookies = const [], String body = 'ok']) =>
    ThorResponse(
      200,
      headers: {HttpHeader.contentType: 'text/plain'},
      cookies: cookies,
      body: utf8.encode(body),
    );

ThorResponse _redirect(
  String to, {
  int status = 302,
  List<String> cookies = const [],
}) => ThorResponse(
  status,
  headers: {const HttpHeader('Location'): to},
  cookies: cookies,
);

/// A client over a handler that always answers `set()` on `/set` and
/// echoes the `Cookie` header on everything else.
(_Scripted, ThorTestClient) _cookieApp({
  List<String> Function()? set,
  DateTime Function()? now,
}) {
  final handler = _Scripted(
    (r) => r.uri.path == '/set'
        ? _ok(set!())
        : _ok(const [], r.headers['cookie'] ?? '(none)'),
  );
  return (handler, handler.client(now: now));
}

void main() {
  group('cookies (RFC 6265)', () {
    test(
      'Expires in the dashed four-digit-year form deletes the cookie',
      () async {
        // What PHP and many frameworks send to delete: not one of the three
        // formats HttpDate knows, but the one cookie-date (§5.1.1) accepts.
        final (_, app) = _cookieApp(
          set: () => ['a=; Path=/; Expires=Thu, 01-Jan-1970 00:00:00 GMT'],
        )..$2.setCookie('a', '1');
        await app.get('/set');
        expect(app.cookie('a'), isNull);
      },
    );

    test('Expires in the two-digit-year form (70 = 1970) deletes it', () async {
      final (_, app) = _cookieApp(
        set: () => ['a=; Path=/; Expires=Thursday, 01-Jan-70 00:00:00 GMT'],
      )..$2.setCookie('a', '1');
      await app.get('/set');
      expect(app.cookie('a'), isNull);
    });

    test(
      'Expires with a time zone-less or reordered date still parses',
      () async {
        final (_, app) = _cookieApp(
          set: () => ['a=1; Path=/; Expires=1 Jan 2000 00:00:00'],
        );
        await app.get('/set');
        expect(app.cookie('a'), isNull, reason: 'year 2000 is long gone');
      },
    );

    test('an Expires in the far future keeps the cookie', () async {
      final (_, app) = _cookieApp(
        set: () => ['a=1; Path=/; Expires=Fri, 31-Dec-2199 23:59:59 GMT'],
      );
      await app.get('/set');
      expect(app.cookie('a'), '1');
    });

    test('an unreadable Expires makes a session cookie, not a crash', () async {
      final (_, app) = _cookieApp(set: () => ['a=1; Path=/; Expires=soon']);
      await app.get('/set');
      expect(app.cookie('a'), '1');
    });

    test('a huge Max-Age does not wrap around and delete the cookie', () async {
      final (_, app) = _cookieApp(
        set: () => ['a=1; Path=/; Max-Age=9223372036854775807'],
      );
      await app.get('/set');
      expect(app.cookie('a'), '1');
    });

    test('a Max-Age beyond int range is far future, as in a browser', () async {
      final (_, app) = _cookieApp(
        set: () => ['a=1; Path=/; Max-Age=99999999999999999999999'],
      );
      await app.get('/set');
      expect(app.cookie('a'), '1');
    });

    test('Max-Age=-1 deletes; Max-Age=abc is ignored', () async {
      var line = 'a=1; Max-Age=-1';
      final (_, app) = _cookieApp(set: () => [line])..$2.setCookie('a', '0');
      await app.get('/set');
      expect(app.cookie('a'), isNull);
      line = 'b=1; Max-Age=abc';
      await app.get('/set');
      expect(app.cookie('b'), '1', reason: 'a bad Max-Age is not an attribute');
    });

    test('names are case-sensitive: A and a are two cookies', () async {
      final (h, app) = _cookieApp(set: () => ['A=1', 'a=2']);
      await app.get('/set');
      await app.get('/echo');
      expect(h.seen.last.headers['cookie'], 'A=1; a=2');
      expect(app.cookies, {'A': '1', 'a': '2'});
    });

    test('attribute names are case-insensitive', () async {
      final (_, app) = _cookieApp(set: () => ['a=1; PATH=/x; MAX-AGE=0']);
      app.setCookie('a', '0', path: '/x');
      await app.get('/set');
      expect(app.cookie('a'), isNull);
    });

    test(
      'a quoted value is sent back with its quotes, like a browser',
      () async {
        final (h, app) = _cookieApp(set: () => ['a="x y"']);
        await app.get('/set');
        await app.get('/echo');
        expect(h.seen.last.headers['cookie'], 'a="x y"');
      },
    );

    test('an empty value is a cookie', () async {
      final (h, app) = _cookieApp(set: () => ['a=']);
      await app.get('/set');
      await app.get('/echo');
      expect(h.seen.last.headers['cookie'], 'a=');
    });

    test('a value with = inside keeps everything after the first =', () async {
      final (h, app) = _cookieApp(set: () => ['a=b=c==']);
      await app.get('/set');
      await app.get('/echo');
      expect(h.seen.last.headers['cookie'], 'a=b=c==');
    });

    test(
      'the default path is the request directory (RFC 6265 §5.1.4)',
      () async {
        final h = _Scripted((r) => _ok(r.uri.path == '/x/y/z' ? ['a=1'] : []));
        final app = h.client();
        await app.get('/x/y/z');
        await app.get('/x/y/other');
        expect(h.seen.last.headers['cookie'], 'a=1');
        await app.get('/x/q');
        expect(h.seen.last.headers['cookie'], isNull);
        await app.get('/x/y/');
        expect(h.seen.last.headers['cookie'], 'a=1', reason: '/x/y/ → /x/y');
      },
    );

    test('a request for the bare origin still gets a / cookie', () async {
      final (h, app) = _cookieApp(set: () => ['a=1; Path=/'])
        ..$2.setCookie('s', '1');
      await app.get('http://localhost');
      expect(h.seen.last.headers['cookie'], 's=1');
      await app.get('?x=1');
      expect(h.seen.last.headers['cookie'], 's=1');
    });

    test(
      'overwriting a cookie keeps its place in the header (§5.3 step 11)',
      () async {
        var round = 0;
        final (h, app) = _cookieApp(
          set: () => round++ == 0 ? ['a=1', 'b=1'] : ['a=2'],
        );
        await app.get('/set');
        await app.get('/set');
        await app.get('/echo');
        expect(h.seen.last.headers['cookie'], 'a=2; b=1');
      },
    );

    test('the same name on two paths sends both, longest path first', () async {
      final (h, app) = _cookieApp(
        set: () => ['id=root; Path=/', 'id=admin; Path=/admin'],
      );
      await app.get('/set');
      await app.get('/admin/x');
      expect(h.seen.last.headers['cookie'], 'id=admin; id=root');
      await app.get('/other');
      expect(h.seen.last.headers['cookie'], 'id=root');
    });

    test(
      'a cookie a redirect sets is sent on the next hop of the chain',
      () async {
        final h = _Scripted(
          (r) => switch (r.uri.path) {
            '/a' => _redirect('/b', cookies: ['hop=1']),
            '/b' => _redirect('/c', cookies: ['hop2=2']),
            _ => _ok(const [], r.headers['cookie'] ?? '(none)'),
          },
        );
        final app = h.client();
        final r = await app.get('/a', follow: true);
        expect(r.text, 'hop=1; hop2=2');
        expect(r.redirects, ['/b', '/c']);
      },
    );

    test('a cookie a redirect deletes is gone on the next hop', () async {
      final h = _Scripted(
        (r) => switch (r.uri.path) {
          '/logout' => _redirect('/home', cookies: ['s=; Max-Age=0']),
          _ => _ok(const [], r.headers['cookie'] ?? '(none)'),
        },
      );
      final app = h.client()..setCookie('s', 'x');
      final r = await app.get('/logout', follow: true);
      expect(r.text, '(none)');
    });

    test(
      'SameSite=None with Secure over an http client is kept and sent',
      () async {
        // Chrome and Firefox accept Secure cookies from http://localhost; the
        // jar does too (documented: it does not model Secure).
        final (h, app) = _cookieApp(
          set: () => ['a=1; Path=/; SameSite=None; Secure'],
        );
        await app.get('/set');
        await app.get('/echo');
        expect(h.seen.last.headers['cookie'], 'a=1');
      },
    );

    test('a 4 KB-plus cookie is kept (no browser limit is modelled)', () async {
      final big = 'x' * 5000;
      final (_, app) = _cookieApp(set: () => ['a=$big']);
      await app.get('/set');
      expect(app.cookie('a'), big);
    });

    test('a Domain attribute never scopes the jar to another host', () async {
      final (h, app) = _cookieApp(set: () => ['a=1; Domain=localhost']);
      await app.get('/set');
      await app.get('/echo');
      expect(h.seen.last.headers['cookie'], 'a=1');
    });

    test('the fake clock decides: Max-Age=1 is gone at exactly +1s', () async {
      var t = DateTime.utc(2030);
      final (_, app) = _cookieApp(set: () => ['a=1; Max-Age=1'], now: () => t);
      await app.get('/set');
      t = t.add(const Duration(milliseconds: 999));
      expect(app.cookie('a'), '1');
      t = t.add(const Duration(milliseconds: 1));
      expect(app.cookie('a'), isNull);
    });
  });

  group('redirects', () {
    ThorTestClient chain(Map<String, ThorResponse> routes) => _Scripted(
      (r) =>
          routes[r.uri.path + (r.uri.hasQuery ? '?${r.uri.query}' : '')] ??
          _ok(const [], '${r.method} ${r.uri.path}?${r.uri.query}'),
    ).client();

    test(
      'a relative Location with .. resolves against the request path',
      () async {
        final app = chain({'/a/b/c': _redirect('../x')});
        final r = await app.get('/a/b/c', follow: true);
        expect(r.uri.path, '/a/x');
      },
    );

    test('a query-only Location keeps the path', () async {
      final app = chain({'/a/b': _redirect('?q=1')});
      final r = await app.get('/a/b', follow: true);
      expect(r.uri.path, '/a/b');
      expect(r.uri.query, 'q=1');
    });

    test(
      'a Location with a fragment is followed and the fragment never reaches the server',
      () async {
        final h = _Scripted(
          (r) => r.uri.path == '/a' ? _redirect('/b#top') : _ok(),
        );
        final app = h.client();
        await app.get('/a', follow: true);
        expect(h.seen.map((r) => r.uri.hasFragment), everyElement(isFalse));
        expect(app.location!.toString(), 'http://localhost/b');
      },
    );

    test(
      'a request URL with a fragment is sent without it, like a browser',
      () async {
        final h = _Scripted((r) => _ok());
        await h.client().get('/a?x=1#section');
        expect(h.seen.single.uri.hasFragment, isFalse);
        expect(h.seen.single.uri.query, 'x=1');
      },
    );

    test('301 and 302 on a POST become a GET without a body', () async {
      for (final status in [301, 302, 303]) {
        final h = _Scripted(
          (r) => r.method == HttpMethod.post
              ? _redirect('/next', status: status)
              : _ok(),
        );
        final r = await h.client().post('/go', form: {'a': '1'}, follow: true);
        expect(h.seen.last.method, HttpMethod.get, reason: '$status');
        expect(h.bodies.last, '', reason: '$status');
        expect(h.seen.last.headers.containsKey('content-type'), isFalse);
        expect(r.status, 200);
      }
    });

    test(
      '307 and 308 keep the method, the body and the content type',
      () async {
        for (final status in [307, 308]) {
          final h = _Scripted(
            (r) => r.uri.path == '/go'
                ? _redirect('/next', status: status)
                : _ok(),
          );
          await h.client().post('/go', json: {'a': 'ñ'}, follow: true);
          expect(h.seen.last.method, HttpMethod.post, reason: '$status');
          expect(h.bodies.last, '{"a":"ñ"}', reason: '$status');
          expect(h.seen.last.headers['content-type'], 'application/json');
          expect(h.seen.last.headers['origin'], 'http://localhost');
        }
      },
    );

    test(
      '307 keeps a custom header of the request, as a browser does',
      () async {
        final h = _Scripted(
          (r) => r.uri.path == '/go' ? _redirect('/next', status: 307) : _ok(),
        );
        await h.client().post(
          '/go',
          form: {'a': '1'},
          headers: {const HttpHeader('x-token'): 't'},
          follow: true,
        );
        expect(h.seen.last.headers['x-token'], 't');
      },
    );

    test(
      'the Fetch rules: a DELETE after a 302 stays, after a 303 is a GET',
      () async {
        for (final (status, method, expected) in [
          (302, 'DELETE', 'DELETE'),
          (301, 'PUT', 'PUT'),
          (303, 'PUT', 'GET'),
          (303, 'DELETE', 'GET'),
          (302, 'POST', 'GET'),
        ]) {
          final h = _Scripted(
            (r) => r.uri.path == '/go'
                ? _redirect('/next', status: status)
                : _ok(),
          );
          await h.client().send(
            HttpMethod.tryParse(method)!,
            '/go',
            body: utf8.encode('x'),
            follow: true,
          );
          expect(h.seen.last.method.token, expected, reason: '$status $method');
          expect(
            h.bodies.last,
            expected == 'GET' ? '' : 'x',
            reason: '$status $method',
          );
        }
      },
    );

    test('303 on a HEAD stays a HEAD', () async {
      final h = _Scripted(
        (r) => r.uri.path == '/go' ? _redirect('/next', status: 303) : _ok(),
      );
      await h.client().send(HttpMethod.head, '/go', follow: true);
      expect(h.seen.last.method, HttpMethod.head);
    });

    test('a redirect to another origin is returned, not followed', () async {
      for (final to in [
        'https://localhost/x',
        'http://localhost:8080/x',
        'http://evil.test/x',
        '//evil.test/x',
      ]) {
        final h = _Scripted((r) => _redirect(to));
        final r = await h.client().get('/a', follow: true);
        expect(r.status, 302, reason: to);
        expect(h.seen, hasLength(1), reason: to);
      }
    });

    test('an explicit default port is the same origin', () async {
      final h = _Scripted(
        (r) => r.uri.path == '/a' ? _redirect('http://localhost:80/b') : _ok(),
      );
      final r = await h.client().get('/a', follow: true);
      expect(r.status, 200);
      expect(r.uri.path, '/b');
    });

    test('a non-http Location is returned, never a crash', () async {
      for (final to in [
        'javascript:alert(1)',
        'mailto:a@b.c',
        'data:text/html,x',
      ]) {
        final h = _Scripted((r) => _redirect(to));
        final r = await h.client().get('/a', follow: true);
        expect(r.status, 302, reason: to);
      }
    });

    test(
      'an unparsable Location is a clear error or the redirect itself',
      () async {
        final h = _Scripted((r) => _redirect('http://[::1'));
        final app = h.client();
        final result = await app
            .get('/a', follow: true)
            .then<Object>((r) => r, onError: (Object e) => e);
        expect(result, anyOf(isA<ThorTestResponse>(), isA<StateError>()));
      },
    );

    test('a redirect loop names the chain and the way out', () async {
      final h = _Scripted((r) => _redirect(r.uri.path == '/a' ? '/b' : '/a'));
      final app = h.client(maxRedirects: 3);
      expect(
        () => app.get('/a', follow: true),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('3 redirects'),
              contains('/b → /a → /b'),
              contains('maxRedirects'),
            ),
          ),
        ),
      );
    });

    test('a redirect to itself is a loop, not a hang', () async {
      final h = _Scripted((r) => _redirect(r.uri.path));
      expect(
        () => h.client().get('/same', follow: true),
        throwsA(isA<StateError>()),
      );
      // ignore: unawaited_futures
    });

    test(
      'maxRedirects: 0 fails on the first hop, and a page is fine',
      () async {
        final h = _Scripted(
          (r) => r.uri.path == '/a' ? _redirect('/b') : _ok(),
        );
        final app = h.client(maxRedirects: 0);
        expect(() => app.get('/a', follow: true), throwsA(isA<StateError>()));
        expect((await app.get('/b', follow: true)).status, 200);
      },
    );

    test('exactly maxRedirects hops is allowed, one more is not', () async {
      final h = _Scripted((r) {
        final n = int.tryParse(r.uri.path.substring(1)) ?? 0;
        return n >= 3 ? _ok() : _redirect('/${n + 1}');
      });
      expect(
        (await h.client(maxRedirects: 3).get('/0', follow: true)).status,
        200,
      );
      expect(
        () => h.client(maxRedirects: 2).get('/0', follow: true),
        throwsA(isA<StateError>()),
      );
    });

    test('the response of a followed chain remembers every hop', () async {
      final h = _Scripted(
        (r) => switch (r.uri.path) {
          '/a' => _redirect('/b?x=1'),
          '/b' => _redirect('/c'),
          _ => _ok(),
        },
      );
      final r = await h.client().get('/a', follow: true);
      expect(r.redirects, ['/b?x=1', '/c']);
      expect(r.method, HttpMethod.get);
    });
  });

  group('forms', () {
    Future<String> body(Map<String, Object?> form) async {
      final h = _Scripted((r) => _ok());
      await h.client().post('/f', form: form);
      return h.bodies.single;
    }

    test('a repeated key keeps the order of the list', () async {
      expect(
        await body({
          'a': [3, 1, 2],
          'b': 'x',
        }),
        'a=3&a=1&a=2&b=x',
      );
    });

    test('empty values, empty lists and nulls', () async {
      expect(
        await body({'a': '', 'b': const [], 'c': null, 'd': 'x'}),
        'a=&d=x',
      );
    });

    test('a null inside a list is left out, never the text "null"', () async {
      expect(
        await body({
          'a': [1, null, 2],
        }),
        'a=1&a=2',
      );
    });

    test('any iterable repeats the field, not its toString', () async {
      expect(
        await body({
          'a': {1, 2},
        }),
        'a=1&a=2',
      );
    });

    test('unicode, emoji, plus, percent, ampersand and equals', () async {
      final b = await body({'k y': 'ñ 😀 + % & = ;'});
      expect(b, 'k+y=%C3%B1+%F0%9F%98%80+%2B+%25+%26+%3D+%3B');
      expect(Uri.splitQueryString(b), {'k y': 'ñ 😀 + % & = ;'});
    });

    test('a bool and a number are written the way a browser would', () async {
      expect(await body({'a': true, 'n': 1.5}), 'a=true&n=1.5');
    });

    test('a huge form is the server\'s 413, not a client crash', () async {
      final h = _Scripted((r) async {
        try {
          await r.text();
        } on HttpError catch (e) {
          return ThorResponse(e.status);
        }
        return _ok();
      });
      final r = await h.client().post('/f', form: {'a': 'x' * (2 << 20)});
      expect(r.status, 413);
    });

    test('raw multipart through send() gets the origin like any POST', () async {
      final h = _Scripted((r) => _ok());
      await h.client().send(
        HttpMethod.post,
        '/up',
        body: utf8.encode(
          '--b\r\nContent-Disposition: form-data; name="f"; filename="a.txt"\r\n\r\nhi\r\n--b--\r\n',
        ),
        contentType: 'multipart/form-data; boundary=b',
      );
      expect(h.seen.single.headers['origin'], 'http://localhost');
      expect(
        h.seen.single.headers['content-type'],
        startsWith('multipart/form-data'),
      );
    });

    test(
      'json: 0, false, "" and [] are sent as json, not an empty form',
      () async {
        for (final v in <Object>[0, false, '', <Object>[]]) {
          final h = _Scripted((r) => _ok());
          await h.client().post('/j', json: v);
          expect(
            h.seen.single.headers['content-type'],
            'application/json',
            reason: '$v',
          );
          expect(h.bodies.single, jsonEncode(v), reason: '$v');
        }
      },
    );
  });

  group('the client itself', () {
    test(
      'an absolute URL of another site is refused, the jar never leaves',
      () async {
        final h = _Scripted((r) => _ok());
        final app = h.client()..setCookie('session', 'secret');
        expect(
          () => app.get('http://evil.test/x'),
          throwsA(isA<ArgumentError>()),
        );
        expect(
          () => app.post('http://evil.test/x', form: {}),
          throwsA(isA<ArgumentError>()),
        );
        expect(h.seen, isEmpty);
      },
    );

    test(
      'the Origin is always the client\'s own, never another site\'s',
      () async {
        final h = _Scripted((r) => _ok());
        final app = h.client(origin: 'https://app.example.com:8443');
        await app.post('/a', form: {});
        await app.send(HttpMethod.delete, '/a');
        expect(
          h.seen.map((r) => r.headers['origin']),
          everyElement('https://app.example.com:8443'),
        );
        expect(
          h.seen.map((r) => r.headers['host']),
          everyElement('app.example.com:8443'),
        );
        expect(h.seen.map((r) => r.uri.scheme), everyElement('https'));
      },
    );

    test(
      'an origin with credentials still sends a Host the CSRF check accepts',
      () async {
        final h = _Scripted((r) => _ok());
        await h.client(origin: 'http://u:p@localhost').post('/a', form: {});
        expect(h.seen.single.headers['host'], 'localhost');
        expect(h.seen.single.headers['origin'], 'http://localhost');
      },
    );

    test('a bad origin is an ArgumentError up front', () {
      final h = _Scripted((r) => _ok());
      for (final o in ['localhost', 'ftp://localhost', '/x', '']) {
        expect(() => h.client(origin: o), throwsArgumentError, reason: o);
      }
    });

    test(
      'a header key in any case replaces the client\'s and null takes it off',
      () async {
        final h = _Scripted((r) => _ok());
        await h.client().post(
          '/a',
          form: {},
          headers: {
            const HttpHeader('Origin'): null,
            const HttpHeader('HOST'): 'x.test',
          },
        );
        expect(h.seen.single.headers.containsKey('origin'), isFalse);
        expect(h.seen.single.headers['host'], 'x.test');
      },
    );

    test('a GET carries no Origin and no content type', () async {
      final h = _Scripted((r) => _ok());
      await h.client().get('/a');
      expect(h.seen.single.headers.containsKey('origin'), isFalse);
      expect(h.seen.single.headers.containsKey('content-type'), isFalse);
    });

    test(
      'a handler that throws is the test\'s exception, and the jar survives',
      () async {
        var boom = true;
        final h = _Scripted((r) {
          if (boom) throw StateError('boom');
          return _ok(const [], r.headers['cookie'] ?? '(none)');
        });
        final app = h.client()..setCookie('a', '1');
        await expectLater(app.get('/x'), throwsA(isA<StateError>()));
        boom = false;
        expect((await app.get('/x')).text, 'a=1');
      },
    );
  });

  group('location', () {
    test('has no stray ? or # after a page', () async {
      final h = _Scripted((r) => _ok());
      final app = h.client();
      await app.get('/cart');
      expect(app.location.toString(), 'http://localhost/cart');
      await app.post('/cart?/add', form: {});
      expect(app.location.toString(), 'http://localhost/cart');
      await app.post('/cart?/add&page=2', form: {});
      expect(app.location.toString(), 'http://localhost/cart?page=2');
    });

    test(
      'a redirect that is not followed leaves the last page in place',
      () async {
        final h = _Scripted(
          (r) => r.uri.path == '/b' ? _redirect('/c') : _ok(),
        );
        final app = h.client();
        await app.get('/a');
        await app.get('/b');
        expect(app.location!.path, '/a');
        await app.get('/b', follow: true);
        expect(app.location!.path, '/c');
      },
    );

    test(
      'goTo with a relative path and a query resolves on the origin',
      () async {
        final app = _Scripted((r) => _ok()).client()..goTo('/p?x=1#f');
        expect(app.location!.path, '/p');
      },
    );
  });

  group('calls', () {
    test('a command that sets a cookie updates the jar', () async {
      final h = _Scripted(
        (r) => r.headers.containsKey('x-thor-command')
            ? ThorResponse(
                200,
                headers: {HttpHeader.contentType: 'application/json'},
                cookies: ['session=fresh; Path=/'],
                body: utf8.encode('{"result":1}'),
              )
            : _ok(const [], r.headers['cookie'] ?? '(none)'),
      );
      final app = h.client()..setCookie('session', 'old');
      app.goTo('/p');
      final r = await app.callCommand('CartState.add', arg: 1);
      expect(r.result, 1);
      expect(app.cookie('session'), 'fresh');
      expect((await app.get('/x')).text, 'session=fresh');
    });

    test(
      'an argument that is not JSON says so, not a dart:convert trace',
      () async {
        final h = _Scripted((r) => _ok());
        final app = h.client()..goTo('/p');
        await expectLater(
          app.callQuery('A.b', arg: Object()),
          throwsA(
            isA<ArgumentError>().having((e) => '$e', 'msg', contains('JSON')),
          ),
        );
        expect(h.seen, isEmpty);
      },
    );

    test(
      'a body that is a String is sent as written, even when it is not JSON',
      () async {
        final h = _Scripted((r) => _ok());
        final app = h.client()..goTo('/p');
        await app.callQuery('A.b', body: '{not json');
        expect(h.bodies.single, '{not json');
        expect(h.seen.single.headers['content-type'], 'application/json');
        expect(h.seen.single.headers['x-thor-query'], 'A.b');
      },
    );

    test(
      'a call goes to the page of path: even when the client is elsewhere',
      () async {
        final h = _Scripted((r) => _ok());
        final app = h.client()..goTo('/a');
        await app.callQuery('A.b', path: '/other?x=1');
        expect(h.seen.single.uri.path, '/other');
        expect(h.seen.single.uri.query, 'x=1');
      },
    );

    test('a call to another site through path: is refused', () async {
      final h = _Scripted((r) => _ok());
      final app = h.client()..goTo('/a');
      expect(
        () => app.callQuery('A.b', path: 'http://evil.test/x'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('a call keeps the jar of the pages: same visitor', () async {
      final h = _Scripted(
        (r) => _ok(const [], r.headers['cookie'] ?? '(none)'),
      );
      final app = h.client()..setCookie('s', '1');
      app.goTo('/a');
      final r = await app.callQuery('A.b');
      expect(r.text, 's=1');
    });

    test('concurrent calls and pages all land their cookies', () async {
      final h = _Scripted((r) {
        final id = r.headers['x-thor-command'] ?? r.uri.path.substring(1);
        return _ok(['c$id=1']);
      });
      final app = h.client()..goTo('/p');
      await Future.wait([
        for (var i = 0; i < 20; i++) app.callCommand('$i'),
        for (var i = 20; i < 40; i++) app.get('/$i'),
      ]);
      expect(app.cookies.keys, hasLength(40));
    });
  });
}
