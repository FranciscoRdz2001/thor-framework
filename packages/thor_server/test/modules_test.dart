import 'dart:async';
import 'dart:convert';

import 'package:test/test.dart';
import 'package:thor_server/thor_server.dart';

class _Renderer implements PageRenderer<String> {
  @override
  List<int> render(String page, RenderContext context) =>
      utf8.encode('<title>${context.meta.title ?? ''}</title>$page');

  @override
  String errorPage(ErrorState state) => 'plain error ${state.status}';
}

PageRequest _req(
  String path, {
  HttpMethod method = HttpMethod.get,
  Map<HttpHeader, String> headers = const {},
}) => PageRequest(
  method: method,
  uri: Uri.parse('http://site.test$path'),
  headers: {
    HttpHeader.host: 'site.test',
    HttpHeader.origin: 'http://site.test',
    if (method == HttpMethod.post)
      HttpHeader.contentType: 'application/x-www-form-urlencoded',
    ...headers,
  },
  body: Stream.value(utf8.encode('')),
);

void main() {
  late List<String> log;
  late int loads;
  late RouteHandler<String> handler;

  setUp(() {
    log = [];
    loads = 0;
    handler = RouteHandler<String>(
      renderer: _Renderer(),
      onError: (request, error, stack) => log.add('error $error'),
      personalized: (r) => r.cookies.containsKey('session'),
      routes: [
        LayoutRoute<String, void>(
          build: (s, child) => '<site>$child</site>',
          meta: (s) =>
              const PageMeta(title: 'Acme', titleTemplate: '%s · Acme'),
          error: (e) => 'root error ${e.status}',
          cache: const Duration(minutes: 1),
          children: [
            PageRoute<String, void>(build: (s) => 'home'),
            PageRoute<String, int>(
              path: 'about',
              load: (r) => ++loads,
              meta: (s) => const PageMeta(title: 'About'),
              build: (s) => 'about ${s.data}',
            ),
            PageRoute<String, void>(
              path: 'login',
              prerender: true,
              build: (s) => 'login',
            ),
            LayoutRoute<String, void>(
              path: '(app)',
              build: (s, child) => '<app>$child</app>',
              personalized: true,
              prerender: true,
              meta: (s) => const PageMeta(titleTemplate: '%s · Admin'),
              middleware: (request, next) {
                log.add('app middleware');
                return next();
              },
              redirect: (r) => r.cookies['session'] == null
                  ? const RouteUrl('/login')
                  : null,
              error: (e) => 'app error ${e.status}',
              notFound: (e) => 'app not found',
              children: [
                PageRoute<String, int>(
                  path: 'clients',
                  load: (r) => ++loads,
                  meta: (s) => const PageMeta(title: 'Clients'),
                  build: (s) => 'clients ${s.data}',
                ),
                PageRoute<String, void>(
                  path: 'clients/[id]',
                  load: (r) {
                    if (r.pathParameters['id'] == 'gone') {
                      throw const NotFound();
                    }
                  },
                  build: (s) => 'client',
                ),
                PageRoute<String, void>(
                  path: 'deploy',
                  prerender: false,
                  build: (s) => 'deploy',
                  actions: {
                    'default': (r) => throw const HttpError(409, 'busy'),
                  },
                ),
                PageRoute<String, void>(
                  path: 'public',
                  personalized: false,
                  prerender: false,
                  build: (s) => 'public',
                ),
              ],
            ),
            LayoutRoute<String, void>(
              path: '(auth)',
              build: (s, child) => '<auth>$child</auth>',
              children: [
                PageRoute<String, void>(
                  path: 'register',
                  build: (s) => 'register',
                ),
              ],
            ),
          ],
        ),
      ],
    );
  });

  group('404 of the folder that owns the URL', () {
    test('runs inside that folder, after its middleware and guards', () async {
      final guest = await handler.handle(_req('/clients/1/x'));
      expect(guest.status, 302);
      expect(guest.headers['location'], '/login');
      expect(log, ['app middleware']);

      final r = await handler.handle(
        _req('/clients/1/x', headers: {HttpHeader.cookie: 'session=a'}),
      );
      expect(r.status, 404);
      expect(r.text, contains('<site><app>app not found</app></site>'));
    });

    test('not_found wins over error for a 404 thrown by a load', () async {
      final r = await handler.handle(
        _req('/clients/gone', headers: {HttpHeader.cookie: 'session=a'}),
      );
      expect(r.status, 404);
      expect(r.text, contains('app not found'));
    });

    test('a URL no folder owns is the root 404', () async {
      final r = await handler.handle(_req('/nothing/here'));
      expect(r.status, 404);
      expect(r.text, contains('<site>root error 404</site>'));
      expect(log, isEmpty);
    });

    test('a POST to an unknown URL is a 404, never an action', () async {
      final r = await handler.handle(_req('/nope', method: HttpMethod.post));
      expect(r.status, 404);
      final put = await handler.handle(_req('/nope', method: HttpMethod.put));
      expect(put.status, 404);
    });

    test(
      'an unknown URL under a known page is not found, not the page',
      () async {
        expect((await handler.handle(_req('/about/x'))).status, 404);
        expect(
          handler.router.matchNotFound('/clients/x/y')!.entry.layouts,
          hasLength(2),
        );
        // (auth) shares the root's URL space: it owns only what its pages
        // start with.
        expect(
          handler.router.matchNotFound('/register/x')!.entry.layouts.last.path,
          '(auth)',
        );
      },
    );
  });

  group('an HttpError from an action', () {
    test('renders the nearest error page, inside its layouts', () async {
      final r = await handler.handle(
        _req(
          '/deploy',
          method: HttpMethod.post,
          headers: {HttpHeader.cookie: 'session=a'},
        ),
      );
      expect(r.status, 409);
      expect(r.text, contains('<site><app>app error 409</app></site>'));
      expect(log.where((l) => l.startsWith('error')), isEmpty);
    });

    test('with the data the layouts loaded', () async {
      final h = RouteHandler<String>(
        renderer: _Renderer(),
        routes: [
          LayoutRoute<String, String>(
            load: (r) => 'Ana',
            build: (s, child) => '<site user=${s.data}>$child</site>',
            error: (e) => 'error ${e.status}: ${e.message}',
            children: [
              PageRoute<String, void>(
                path: 'deploy',
                build: (s) => 'deploy',
                actions: {'default': (r) => throw const HttpError(409, 'busy')},
              ),
            ],
          ),
        ],
      );
      final r = await h.handle(_req('/deploy', method: HttpMethod.post));
      expect(r.status, 409);
      expect(r.text, contains('<site user=Ana>error 409: busy</site>'));
    });
  });

  group('config inherited from layouts', () {
    test('cache comes from the root layout', () async {
      await handler.handle(_req('/about'));
      final hit = await handler.handle(_req('/about'));
      expect(hit.text, contains('about 1'));
      expect(loads, 1);
    });

    test(
      'personalized: true never shares and marks the response private',
      () async {
        final a = await handler.handle(
          _req('/clients', headers: {HttpHeader.cookie: 'session=a'}),
        );
        await handler.handle(
          _req('/clients', headers: {HttpHeader.cookie: 'session=b'}),
        );
        expect(loads, 2);
        expect(a.headers['cache-control'], 'private, no-cache');
      },
    );

    test('personalized: false shares even with a session', () async {
      await handler.handle(
        _req('/public', headers: {HttpHeader.cookie: 'session=a'}),
      );
      expect(handler.cachedPaths, contains('http://site.test/public'));
    });

    test('prerenderPaths lists the static pages that ask for it', () {
      expect(
        handler.router.prerenderPaths,
        unorderedEquals(['/login', '/clients']),
      );
    });
  });

  group('titleTemplate', () {
    test("the nearest template shows a lower level's title", () async {
      final about = await handler.handle(_req('/about'));
      expect(about.text, startsWith('<title>About · Acme</title>'));
      final clients = await handler.handle(
        _req('/clients', headers: {HttpHeader.cookie: 'session=a'}),
      );
      expect(clients.text, startsWith('<title>Clients · Admin</title>'));
    });

    test("a level's own title is not templated", () async {
      final home = await handler.handle(_req('/'));
      expect(home.text, startsWith('<title>Acme</title>'));
    });
  });

  group('typed parameters', () {
    final router = RouteIndex<String>([
      PageRoute<String, void>(path: 'item/[id=int]', build: (s) => ''),
      PageRoute<String, void>(path: 'item/[id=int]/edit', build: (s) => ''),
    ]);

    test('match only values of their type', () {
      expect(router.match('/item/12')!.pathParameters, {'id': '12'});
      expect(router.match('/item/-3')!.pathParameters, {'id': '-3'});
      for (final bad in ['abc', '+1', '1.5', '-', '99999999999999999999']) {
        expect(router.match('/item/$bad'), isNull, reason: bad);
      }
      expect(router.match('/item/abc/edit'), isNull);
      expect(router.entries.first.pattern, startsWith('/item/[id=int]'));
    });

    test('an unknown type is an error when the routes are built', () {
      expect(
        () => RouteIndex<String>([
          PageRoute<String, void>(path: 'x/[id=uuid]', build: (s) => ''),
        ]),
        throwsA(
          isA<ArgumentError>().having(
            (e) => '${e.message}',
            'message',
            contains('a parameter is a String or an int'),
          ),
        ),
      );
    });

    test('a value of the wrong type is a 404 before any load', () async {
      var loads = 0;
      final h = RouteHandler<String>(
        renderer: _Renderer(),
        routes: [
          PageRoute<String, void>(
            path: 'item/[id=int]',
            load: (r) => loads++,
            build: (s) => 'item',
          ),
        ],
      );
      expect((await h.handle(_req('/item/abc'))).status, 404);
      expect(loads, 0);
      expect((await h.handle(_req('/item/7'))).status, 200);
    });
  });
}
