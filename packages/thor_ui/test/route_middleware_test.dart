import 'dart:async';
import 'dart:convert';

import 'package:test/test.dart';
import 'package:thor_server/thor_server.dart'
    show middlewareName, namedMiddleware;
import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

class _Plain extends ThorPage<void> {
  const _Plain();

  @override
  Widget build(BuildContext context, PageState<void> state) =>
      Text('user ${state.request.context.maybeGet(_user) ?? '-'}');
}

const _user = ContextKey<String>('user');
final _log = <String>[];

Middleware _mark(String name) => namedMiddleware(name, (request, next) {
  _log.add(name);
  return next();
});

Future<ThorResponse> _session(PageRequest request, Next next) {
  _log.add('session');
  request.context.set(_user, 'ana');
  return next();
}

Future<ThorResponse> _requireUser(PageRequest request, Next next) {
  _log.add('requireUser');
  if (request.context.maybeGet(_user) == null) {
    throw const Redirect.found(RouteUrl('/login'));
  }
  return next();
}

Future<ThorResponse> _stop(PageRequest request, Next next) async {
  _log.add('stop');
  return ThorResponse(401, body: utf8.encode('stopped'));
}

Future<ThorResponse> _broken(PageRequest request, Next next) =>
    throw StateError('no database');

Future<ThorResponse> _twice(PageRequest request, Next next) async {
  await next();
  return next();
}

Middleware _requireRole(String role) =>
    namedMiddleware('requireRole($role)', (request, next) {
      _log.add('role $role');
      return next();
    });

void main() {
  final errors = <Object>[];
  RouteHandler<Widget> handler(List<RouteTableNode> table) =>
      RouteHandler<Widget>(
        renderer: WidgetRenderer(),
        onError: (request, error, stack) => errors.add(error),
        routes: ThorRouter(table).routes,
      );

  PageRequest get(
    String path, {
    HttpMethod method = HttpMethod.get,
    Map<HttpHeader, String>? headers,
  }) => PageRequest(
    method: method,
    uri: Uri.parse('http://s.test$path'),
    headers: {HttpHeader.host: 's.test', ...?headers},
  );

  setUp(() {
    _log.clear();
    errors.clear();
  });

  test('order: outer group, inner group, the route; left to right', () async {
    final h = handler([
      Group(
        middleware: [_mark('a'), _mark('b')],
        children: [
          Group(
            middleware: [_mark('c')],
            children: [
              ThorRoute(
                '/x',
                const _Plain(),
                middleware: [_mark('d'), _mark('e')],
              ),
            ],
          ),
          ThorRoute('/y', const _Plain()),
        ],
      ),
      ThorRoute('/z', const _Plain(), middleware: [_mark('f')]),
    ]);
    expect((await h.handle(get('/x'))).status, 200);
    expect(_log, ['a', 'b', 'c', 'd', 'e']);
    _log.clear();
    await h.handle(get('/y'));
    expect(_log, ['a', 'b'], reason: 'a route without its own list');
    _log.clear();
    await h.handle(get('/z'));
    expect(_log, ['f'], reason: 'a route with a list and no group');
  });

  test('context flows from one to the next and to the page', () async {
    final h = handler([
      Group(
        middleware: [_session, _requireUser],
        children: [ThorRoute('/me', const _Plain())],
      ),
    ]);
    final r = await h.handle(get('/me'));
    expect(r.text, contains('user ana'));
    expect(_log, ['session', 'requireUser']);
  });

  test('one in the middle ends the request: the rest never run', () async {
    final h = handler([
      Group(
        middleware: [_mark('a'), _stop, _mark('never')],
        children: [ThorRoute('/x', const _Plain())],
      ),
      Group(
        middleware: [_requireUser, _mark('never')],
        children: [ThorRoute('/y', const _Plain())],
      ),
    ]);
    final stopped = await h.handle(get('/x'));
    expect((stopped.status, stopped.text), (401, 'stopped'));
    expect(_log, ['a', 'stop']);
    _log.clear();
    final redirected = await h.handle(get('/y'));
    expect(redirected.status, 302);
    expect(redirected.headers['location'], '/login');
    expect(_log, ['requireUser']);
  });

  test('an error names the middleware, its place and its list', () async {
    final h = handler([
      Group(
        middleware: [_session, _broken],
        children: [ThorRoute('/x', const _Plain())],
      ),
      ThorRoute('/y', const _Plain(), middleware: [_twice]),
      ThorRoute(
        '/z',
        const _Plain(),
        middleware: [
          _requireRole('admin'),
          (request, next) => throw ArgumentError('anonymous'),
        ],
      ),
    ]);
    expect((await h.handle(get('/x'))).status, 500);
    final named = errors.single as MiddlewareError;
    expect(named.name, '_broken');
    expect(named.position, 2);
    expect(named.error, isA<StateError>());
    expect(
      '$named',
      allOf(
        contains('THOR-P016'),
        contains('`_broken` (2 of 2 in Group(/x))'),
        contains('no database'),
      ),
    );
    errors.clear();
    await h.handle(get('/y'));
    expect(
      '${errors.single}',
      allOf(contains('`_twice`'), contains('THOR-P004')),
    );
    errors.clear();
    _log.clear();
    await h.handle(get('/z'));
    expect('${errors.single}', contains("#2 (2 of 2 in ThorRoute('/z'))"));
    expect(_log, ['role admin']);
  });

  test('an error from below keeps its own name', () async {
    final h = handler([
      Group(
        middleware: [_mark('outer')],
        children: [
          ThorRoute('/x', const _Plain(), middleware: [_broken]),
        ],
      ),
    ]);
    await h.handle(get('/x'));
    expect((errors.single as MiddlewareError).name, '_broken');
  });

  test('configurable middleware: requireRole(...) and its name', () {
    expect(middlewareName(_requireRole('admin')), 'requireRole(admin)');
    expect(middlewareName(_session), '_session');
  });

  test('securityHeaders adds what the response lacks', () async {
    final h = handler([
      Group(
        middleware: [securityHeaders(hsts: const Duration(days: 1))],
        children: [
          ThorRoute('/x', const _Plain()),
          ThorRoute(
            '/framed',
            const _Plain(),
            middleware: [
              (request, next) async => (await next()).withHeaders({
                const HttpHeader('X-Frame-Options'): 'SAMEORIGIN',
              }),
            ],
          ),
        ],
      ),
    ]);
    final r = await h.handle(get('/x'));
    expect(r.headers['x-content-type-options'], 'nosniff');
    expect(r.headers['x-frame-options'], 'DENY');
    expect(
      r.headers['strict-transport-security'],
      'max-age=86400; includeSubDomains',
    );
    final framed = await h.handle(get('/framed'));
    expect(framed.headers['X-Frame-Options'], 'SAMEORIGIN');
    expect(framed.headers.containsKey('x-frame-options'), isFalse);
  });

  test('cors: preflight, allowed origin, other origin', () async {
    final h = handler([
      ThorRoute(
        '/api',
        const _Plain(),
        middleware: [
          cors(
            origins: ['https://app.test'],
            methods: [HttpMethod.get, HttpMethod.post],
            headers: ['content-type'],
          ),
        ],
      ),
      ThorRoute('/plain', const _Plain()),
    ]);
    final preflight = await h.handle(
      get(
        '/api',
        method: HttpMethod.options,
        headers: {
          HttpHeader.origin: 'https://app.test',
          HttpHeader.accessControlRequestMethod: 'POST',
        },
      ),
    );
    expect(preflight.status, 204);
    expect(
      preflight.headers['access-control-allow-origin'],
      'https://app.test',
    );
    expect(preflight.headers['access-control-allow-methods'], 'GET, POST');
    expect(preflight.headers['access-control-allow-headers'], 'content-type');
    final simple = await h.handle(
      get('/api', headers: {HttpHeader.origin: 'https://app.test'}),
    );
    expect(simple.status, 200);
    expect(simple.headers['access-control-allow-origin'], 'https://app.test');
    expect(simple.headers['vary'], contains('Origin'));
    final other = await h.handle(
      get('/api', headers: {HttpHeader.origin: 'https://evil.test'}),
    );
    expect(other.headers.containsKey('access-control-allow-origin'), isFalse);
    expect(other.headers['vary'], contains('Origin'));
    // OPTIONS on a route without middleware, or none that answers: 405.
    expect(
      (await h.handle(get('/plain', method: HttpMethod.options))).status,
      405,
    );
    expect(
      (await h.handle(
        get(
          '/api',
          method: HttpMethod.options,
          headers: {HttpHeader.origin: 'https://evil.test'},
        ),
      )).status,
      405,
    );
  });
}
