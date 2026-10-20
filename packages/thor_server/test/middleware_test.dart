import 'dart:async';
import 'dart:convert';

import 'package:test/test.dart';
import 'package:thor_server/thor_server.dart';

class _Renderer implements PageRenderer<String> {
  @override
  List<int> render(String page, RenderContext context) => utf8.encode(page);

  @override
  String errorPage(ErrorState state) => 'plain error ${state.status}';
}

PageRequest _get(String path, {Map<HttpHeader, String> headers = const {}}) =>
    PageRequest(
      method: HttpMethod.get,
      uri: Uri.parse('http://site.test$path'),
      headers: {HttpHeader.host: 'site.test', ...headers},
    );

PageRequest _post(String path, String body) => PageRequest(
  method: HttpMethod.post,
  uri: Uri.parse('http://site.test$path'),
  headers: {
    HttpHeader.host: 'site.test',
    HttpHeader.origin: 'http://site.test',
    HttpHeader.contentType: 'application/x-www-form-urlencoded',
  },
  body: Stream.value(utf8.encode(body)),
);

const _user = ContextKey<String>('user');

void main() {
  late List<String> log;
  late List<Object> errors;
  late int loads;
  late RouteHandler<String> handler;

  RouteHandler<String> build(List<RouteNode<String>> routes) =>
      RouteHandler<String>(
        renderer: _Renderer(),
        onError: (request, error, stack) => errors.add(error),
        routes: routes,
      );

  setUp(() {
    log = [];
    errors = [];
    loads = 0;
    handler = build([
      LayoutRoute<String, void>(
        build: (s, child) => '<main>$child</main>',
        error: (e) => 'error ${e.status}',
        middleware: (request, next) async {
          log.add('root in');
          final response = await next();
          log.add('root out');
          return response.withHeaders({const HttpHeader('x-root'): 'yes'});
        },
        children: [
          PageRoute<String, void>(build: (s) => 'home'),
          PageRoute<String, int>(
            path: 'public',
            cache: const Duration(minutes: 1),
            load: (r) => ++loads,
            build: (s) => 'public ${s.data}',
          ),
          LayoutRoute<String, void>(
            path: 'account',
            build: (s, child) => child,
            middleware: (request, next) async {
              log.add('account in');
              final user = request.cookies['user'];
              if (user == null) throw const Redirect.found(RouteUrl('/login'));
              if (user == 'banned') {
                return ThorResponse(403, body: utf8.encode('banned'));
              }
              if (user == 'gone') throw const HttpError(410, 'Gone');
              request.context.set(_user, user);
              final response = await next();
              log.add('account out');
              return response;
            },
            children: [
              PageRoute<String, String>(
                cache: const Duration(minutes: 1),
                load: (r) {
                  loads++;
                  return r.context.get(_user);
                },
                build: (s) => 'hello ${s.data}',
                actions: {
                  'default': (r) async {
                    log.add('action ${r.context.get(_user)}');
                    return null;
                  },
                },
              ),
            ],
          ),
          LayoutRoute<String, void>(
            path: 'twice',
            build: (s, child) => child,
            middleware: (request, next) async {
              await next();
              return next();
            },
            children: [PageRoute<String, void>(build: (s) => 'twice')],
          ),
          PageRoute<String, String>(
            path: 'missing-key',
            load: (r) => r.context.get(_user),
            build: (s) => s.data,
          ),
        ],
      ),
    ]);
  });

  test('runs root to leaf, and the response goes back leaf to root', () async {
    final r = await handler.handle(
      _get('/account', headers: {HttpHeader.cookie: 'user=ana'}),
    );
    expect(r.text, '<main>hello ana</main>');
    expect(log, ['root in', 'account in', 'account out', 'root out']);
    expect(r.headers['x-root'], 'yes');
  });

  test("a folder's middleware only wraps the pages below it", () async {
    final r = await handler.handle(_get('/'));
    expect(r.text, '<main>home</main>');
    expect(log, ['root in', 'root out']);
  });

  test('a thrown Redirect ends the request before any load', () async {
    final r = await handler.handle(_get('/account'));
    expect(r.status, 302);
    expect(r.headers['location'], '/login');
    expect(loads, 0);
    expect(log, ['root in', 'account in']);
  });

  test('a response returned without next() ends the request', () async {
    final r = await handler.handle(
      _get('/account', headers: {HttpHeader.cookie: 'user=banned'}),
    );
    expect(r.status, 403);
    expect(r.text, 'banned');
    expect(loads, 0);
    // The outer middleware still sees it on the way back.
    expect(r.headers['x-root'], 'yes');
  });

  test('an HttpError renders the error page in the root layout', () async {
    final r = await handler.handle(
      _get('/account', headers: {HttpHeader.cookie: 'user=gone'}),
    );
    expect(r.status, 410);
    expect(r.text, '<main>error 410</main>');
    expect(errors, isEmpty);
  });

  test('calling next() twice is a 500 and a reported error', () async {
    final r = await handler.handle(_get('/twice'));
    expect(r.status, 500);
    expect(errors.single, isA<StateError>());
    expect('${errors.single}', contains('next() called twice'));
    expect('${errors.single}', contains('THOR-P004'));
  });

  test('reading a key no middleware set names it', () async {
    final r = await handler.handle(_get('/missing-key'));
    expect(r.status, 500);
    expect('${errors.single}', contains('no user in the request context'));
    expect('${errors.single}', contains('THOR-P005'));
  });

  test('the context belongs to one request', () async {
    final a = await handler.handle(
      _get('/account', headers: {HttpHeader.cookie: 'user=ana'}),
    );
    final b = await handler.handle(
      _get('/account', headers: {HttpHeader.cookie: 'user=bea'}),
    );
    expect(a.text, '<main>hello ana</main>');
    expect(b.text, '<main>hello bea</main>');
  });

  test('form posts go through the chain', () async {
    final blocked = await handler.handle(_post('/account', 'x=1'));
    expect(blocked.status, 302);
    expect(blocked.headers['location'], '/login');
    expect(log, isNot(contains(startsWith('action'))));

    final r = await handler.handle(
      _post('/account', 'x=1')..headers[HttpHeader.cookie] = 'user=ana',
    );
    expect(r.status, 303);
    expect(log, contains('action ana'));
  });

  test('middleware runs on cached pages too', () async {
    await handler.handle(_get('/public'));
    final hit = await handler.handle(_get('/public'));
    expect(hit.text, '<main>public 1</main>');
    expect(loads, 1);
    expect(log.where((l) => l == 'root in'), hasLength(2));
    expect(hit.headers['x-root'], 'yes');
  });

  test('a page that reads the context is never cached', () async {
    await handler.handle(
      _get('/account', headers: {HttpHeader.cookie: 'user=ana'}),
    );
    final r = await handler.handle(
      _get('/account', headers: {HttpHeader.cookie: 'user=bea'}),
    );
    expect(r.text, '<main>hello bea</main>');
    expect(loads, 2);
    expect(handler.cachedPaths, isNot(contains(endsWith('/account'))));
  });

  group('context and the page cache', () {
    const config = ContextKey<String>('config', personal: false);
    late int renders;

    RouteHandler<String> site({bool routePersonalizedFalse = false}) {
      renders = 0;
      return build([
        LayoutRoute<String, void>(
          build: (s, child) => child,
          middleware: (request, next) {
            request.context.set(config, 'es');
            final user = request.cookies['user'];
            if (user != null) request.context.set(_user, user);
            return next();
          },
          children: [
            PageRoute<String, void>(
              path: 'feed',
              cache: const Duration(minutes: 1),
              personalized: routePersonalizedFalse ? false : null,
              build: (s) {
                renders++;
                final who = s.request.context.maybeGet(_user) ?? 'guest';
                return '$who ${s.request.context.get(config)}';
              },
            ),
          ],
        ),
      ]);
    }

    test('guests share the page even though it asks for the user', () async {
      final h = site();
      await h.handle(_get('/feed'));
      final r = await h.handle(_get('/feed'));
      expect(r.text, 'guest es');
      expect(renders, 1);
    });

    test('a visitor with a value never gets the guest copy', () async {
      final h = site();
      await h.handle(_get('/feed'));
      final r = await h.handle(
        _get('/feed', headers: {HttpHeader.cookie: 'user=ana'}),
      );
      expect(r.text, 'ana es');
      expect(r.headers['cache-control'], 'private, no-cache');
      // Nor is theirs stored for the next guest.
      final guest = await h.handle(_get('/feed'));
      expect(guest.text, 'guest es');
      expect(renders, 2);
    });

    test('a personal value wins over personalized: false', () async {
      final h = site(routePersonalizedFalse: true);
      await h.handle(_get('/feed', headers: {HttpHeader.cookie: 'user=ana'}));
      final r = await h.handle(
        _get('/feed', headers: {HttpHeader.cookie: 'user=bea'}),
      );
      expect(r.text, 'bea es');
      expect(h.cachedPaths, isEmpty);
    });

    test('a value marked personal: false keeps the cache', () async {
      final h = site();
      await h.handle(_get('/feed'));
      await h.handle(_get('/feed'));
      expect(h.cachedPaths, contains(endsWith('/feed')));
    });
  });

  group('cookies', () {
    RouteHandler<String> withCookies(Middleware middleware) => build([
      LayoutRoute<String, void>(
        build: (s, child) => child,
        middleware: middleware,
        children: [
          PageRoute<String, void>(build: (s) => 'home'),
          PageRoute<String, void>(
            path: 'cached',
            cache: const Duration(minutes: 1),
            build: (s) => 'cached',
          ),
          PageRoute<String, void>(
            path: 'own',
            build: (s) {
              s.request.response.setCookie('page', '1');
              return 'own';
            },
          ),
        ],
      ),
    ]);

    test('a cookie set after next() reaches the browser', () async {
      final h = withCookies((request, next) async {
        final response = await next();
        request.response.setCookie('seen', '1');
        return response;
      });
      final r = await h.handle(_get('/'));
      expect(r.cookies, [startsWith('seen=1;')]);
      // A new cookie drops what the browser rendered ahead.
      expect(r.headers['clear-site-data'], contains('prefetchCache'));
    });

    test('cookies from before and after next() both go, once each', () async {
      final h = withCookies((request, next) async {
        request.response.setCookie('before', '1');
        final response = await next();
        request.response.setCookie('after', '1');
        return response;
      });
      final r = await h.handle(_get('/own'));
      expect(r.cookies.map((c) => c.split('=').first), [
        'before',
        'page',
        'after',
      ]);
    });

    test('a cached page still carries the cookie of this request', () async {
      var n = 0;
      final h = withCookies((request, next) async {
        final response = await next();
        request.response.setCookie('visit', '${++n}');
        return response;
      });
      final first = await h.handle(_get('/cached'));
      final hit = await h.handle(_get('/cached'));
      expect(h.cachedPaths, contains(endsWith('/cached')));
      expect(first.cookies, [startsWith('visit=1;')]);
      expect(hit.cookies, [startsWith('visit=2;')]);
      // The cached copy keeps no visitor's cookie.
      final third = await h.handle(_get('/cached'));
      expect(third.cookies, [startsWith('visit=3;')]);
    });

    test('a response the middleware builds keeps its cookies', () async {
      final h = withCookies((request, next) async {
        request.response.setCookie('ctx', '1');
        return ThorResponse(200, cookies: ['own=1; Path=/'], body: [111]);
      });
      final r = await h.handle(_get('/'));
      expect(r.cookies.first, 'own=1; Path=/');
      expect(r.cookies.last, startsWith('ctx=1;'));
    });

    test('a late cookie turns off the 304', () async {
      final h = withCookies((request, next) async {
        final response = await next();
        if (request.cookies.containsKey('late')) {
          request.response.setCookie('late', '2');
        }
        return response;
      });
      final first = await h.handle(_get('/'));
      final tag = first.headers['etag'];
      expect(tag, isNotNull);
      final r = await h.handle(
        _get(
          '/',
          headers: {HttpHeader.ifNoneMatch: tag!, HttpHeader.cookie: 'late=1'},
        ),
      );
      expect(r.status, 200);
      expect(r.cookies, [startsWith('late=2;')]);
    });
  });

  group('signInOn401', () {
    RouteHandler<String> guarded() => build([
      LayoutRoute<String, void>(
        build: (s, child) => child,
        error: (e) => 'error ${e.status}',
        middleware: signInOn401('/login'),
        children: [
          PageRoute<String, void>(
            path: 'orders',
            // What a repository throws when the backend says 401.
            load: (r) => throw const HttpError(401),
            build: (s) => 'orders',
          ),
          PageRoute<String, void>(path: 'fine', build: (s) => 'fine'),
          PageRoute<String, void>(
            path: 'closed',
            load: (r) => throw const HttpError(403),
            build: (s) => 'closed',
          ),
        ],
      ),
    ]);

    test('a 401 from a load is a redirect to the sign-in with next', () async {
      final r = await guarded().handle(_get('/orders?page=2'));
      expect(r.status, 303);
      expect(r.headers['location'], '/login?next=%2Forders%3Fpage%3D2');
    });

    test('other answers pass: a page, a 403', () async {
      final h = guarded();
      expect((await h.handle(_get('/fine'))).text, 'fine');
      expect((await h.handle(_get('/closed'))).status, 403);
    });

    test('next= keeps a sign-in URL that already has a query', () async {
      final h = build([
        LayoutRoute<String, void>(
          build: (s, child) => child,
          middleware: signInOn401('/login?from=app', next: 'back'),
          children: [
            PageRoute<String, void>(
              load: (r) => throw const HttpError(401),
              build: (s) => 'x',
            ),
          ],
        ),
      ]);
      final r = await h.handle(_get('/'));
      expect(r.headers['location'], '/login?from=app&back=%2F');
    });
  });

  test('withHeaders replaces a header whatever its case', () {
    final r = ThorResponse(
      200,
      headers: {const HttpHeader('Cache-Control'): 'no-cache'},
    ).withHeaders({HttpHeader.cacheControl: 'private'});
    expect(r.headers, {'cache-control': 'private'});
  });
}
