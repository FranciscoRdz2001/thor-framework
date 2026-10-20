import 'dart:async';
import 'dart:convert';

import 'package:test/test.dart';
import 'package:thor_server/thor_server.dart';

/// Pages are strings; the "document" wraps them with the title.
class _Renderer implements PageRenderer<String> {
  @override
  List<int> render(String page, RenderContext context) =>
      utf8.encode('<title>${context.meta.title ?? ''}</title>$page');

  @override
  String errorPage(ErrorState state) => 'plain error ${state.status}';
}

PageRequest _get(String path, {Map<HttpHeader, String> headers = const {}}) =>
    PageRequest(
      method: HttpMethod.get,
      uri: Uri.parse('http://site.test$path'),
      headers: {HttpHeader.host: 'site.test', ...headers},
    );

PageRequest _post(
  String path,
  String body, {
  String origin = 'http://site.test',
  Map<HttpHeader, String> headers = const {},
}) => PageRequest(
  method: HttpMethod.post,
  uri: Uri.parse('http://site.test$path'),
  headers: {
    HttpHeader.host: 'site.test',
    HttpHeader.origin: origin,
    HttpHeader.contentType: 'application/x-www-form-urlencoded',
    ...headers,
  },
  body: Stream.value(utf8.encode(body)),
);

/// A value that knows its own result, like a failed `FormInvalid`.
class _Outcome implements ActionOutcome {
  @override
  ActionResult get actionResult => const ActionResult.fail(409, 'taken');
}

void main() {
  late List<String> comments;
  late List<Object> errors;
  late RouteHandler<String> handler;

  setUp(() {
    comments = ['first'];
    errors = [];
    handler = RouteHandler<String>(
      renderer: _Renderer(),
      onError: (request, error, stack) => errors.add(error),
      onRequest: (r) => r.locals['user'] = r.cookies['user'],
      routes: [
        LayoutRoute<String, String?>(
          load: (r) => r.locals['user'] as String?,
          build: (s, child) => '<nav>${s.data ?? 'guest'}</nav>$child',
          meta: (s) => const PageMeta(title: 'Site', description: 'default'),
          error: (e) => 'error ${e.status}: ${e.message ?? ''}',
          children: [
            PageRoute<String, int>(
              load: (r) => 3,
              build: (s) => 'home ${s.data}',
            ),
            PageRoute<String, String>(
              path: 'article/[slug]',
              load: (r) {
                final slug = r.pathParameters['slug']!;
                if (slug == 'missing') throw const NotFound('No such article');
                if (slug == 'boom') throw StateError('database down');
                // Two calls awaited together that both fail.
                if (slug == 'together') {
                  return (
                    Future<String>.error(const NotFound('No such article')),
                    Future<String>.error(const NotFound('No comments')),
                  ).wait.then((r) => r.$1);
                }
                if (slug == 'moved') {
                  return [
                    Future<String>.value('x'),
                    Future<String>.error(const Redirect(RouteUrl('/'))),
                  ].wait.then((r) => r.first);
                }
                return slug;
              },
              meta: (s) => PageMeta(title: s.data),
              build: (s) =>
                  'article ${s.data} ${comments.join(',')} form=${s.form}',
              actions: {
                'comment': (r) async {
                  final form = await r.form();
                  if ((form['body'] ?? '').isEmpty) {
                    return const ActionResult.fail(422, {'error': 'blank'});
                  }
                  comments.add(form['body']!);
                  return null;
                },
                'delete': (r) => const Redirect(RouteUrl('/')),
                'outcome': (r) => _Outcome(),
                'stray': (r) => 42,
              },
            ),
            PageRoute<String, void>(
              path: 'article/new',
              build: (s) => 'editor',
            ),
            PageRoute<String, void>(
              path: 'settings',
              redirect: (r) =>
                  r.locals['user'] == null ? const RouteUrl('/login') : null,
              build: (s) => 'settings',
            ),
            PageRoute<String, void>(
              path: 'login',
              build: (s) => 'login',
              actions: {
                'default': (r) {
                  r.response.setCookie('user', 'ana');
                  return const Redirect(RouteUrl('/'));
                },
              },
            ),
            PageRoute<String, void>(
              path: 'session',
              // A GET that sets a cookie (a session started on first visit).
              load: (r) => r.response.setCookie('visit', '1'),
              build: (s) => 'session',
              actions: {
                'logout': (r) {
                  r.response.headers[const HttpHeader('Clear-Site-Data')] =
                      '"cookies"';
                  return const Redirect(RouteUrl('/'));
                },
                'wipe': (r) {
                  r.response.headers[const HttpHeader('clear-site-data')] =
                      '"*"';
                  return const Redirect(RouteUrl('/'));
                },
              },
            ),
            PageRoute<String, String>(
              path: 'docs/[...rest]',
              load: (r) => r.pathParameters['rest']!,
              build: (s) => 'docs ${s.data}',
            ),
            LayoutRoute<String, void>(
              path: '(app)/admin',
              load: (r) => throw const HttpError(403, 'Admins only'),
              build: (s, child) => '<admin>$child',
              children: [PageRoute<String, void>(build: (s) => 'dashboard')],
            ),
          ],
        ),
      ],
    );
  });

  group('routing', () {
    test('renders the page inside its layout with merged meta', () async {
      final r = await handler.handle(_get('/'));
      expect(r.status, 200);
      expect(r.text, '<title>Site</title><nav>guest</nav>home 3');
      expect(r.headers['content-type'], startsWith('text/html'));
    });

    test(
      'path parameters are decoded; a page title overrides the layout',
      () async {
        final r = await handler.handle(_get('/article/caf%C3%A9'));
        expect(r.text, contains('<title>café</title>'));
        expect(r.text, contains('article café'));
      },
    );

    test('a static segment beats a parameter', () async {
      expect(
        (await handler.handle(_get('/article/new'))).text,
        contains('editor'),
      );
    });

    test('rest segments take the remaining path', () async {
      expect(
        (await handler.handle(_get('/docs/a/b/c'))).text,
        contains('docs a/b/c'),
      );
    });

    test('groups add no URL segment', () async {
      final r = await handler.handle(_get('/admin'));
      expect(r.status, 403);
    });

    test('a trailing slash redirects to the canonical URL', () async {
      final r = await handler.handle(_get('/article/x/?a=1'));
      expect(r.status, 308);
      expect(r.headers['location'], '/article/x?a=1');
    });

    test('unknown URLs are a 404 inside the root layout', () async {
      final r = await handler.handle(_get('/nope'));
      expect(r.status, 404);
      expect(r.text, contains('<nav>guest</nav>error 404'));
    });

    test('two routes for the same URLs are rejected', () {
      expect(
        () => RouteIndex<String>([
          PageRoute<String, void>(path: '[a]', build: (s) => ''),
          PageRoute<String, void>(path: '[b]', build: (s) => ''),
        ]),
        throwsStateError,
      );
    });
  });

  group('data and errors', () {
    test(
      'NotFound from load renders the error page with its message',
      () async {
        final r = await handler.handle(_get('/article/missing'));
        expect(r.status, 404);
        expect(r.text, contains('error 404: No such article'));
      },
    );

    test(
      'calls awaited together fail with their cause: a 404, not a 500',
      () async {
        final r = await handler.handle(_get('/article/together'));
        expect(r.status, 404);
        expect(r.text, contains('error 404: No such article'));
        final moved = await handler.handle(_get('/article/moved'));
        expect(moved.status, 303);
      },
    );

    test('an exception is a 500 that hides its message', () async {
      final r = await handler.handle(_get('/article/boom'));
      expect(r.status, 500);
      expect(r.text, contains('error 500: Internal error'));
      expect(r.text, isNot(contains('database')));
    });

    test(
      'a layout load failure renders the error in the outer layout',
      () async {
        final r = await handler.handle(_get('/admin'));
        expect(r.text, contains('<nav>guest</nav>error 403: Admins only'));
        expect(r.text, isNot(contains('<admin>')));
      },
    );

    test('layout and page loads run in parallel', () async {
      final started = <String>[];
      final gate = Completer<void>();
      final h = RouteHandler<String>(
        renderer: _Renderer(),
        routes: [
          LayoutRoute<String, void>(
            load: (r) async {
              started.add('layout');
              await gate.future;
            },
            build: (s, c) => c,
            children: [
              PageRoute<String, void>(
                load: (r) async {
                  started.add('page');
                  gate.complete();
                },
                build: (s) => 'ok',
              ),
            ],
          ),
        ],
      );
      expect((await h.handle(_get('/'))).text, contains('ok'));
      expect(started, ['layout', 'page']);
    });
  });

  group('guards and session', () {
    test('a guard redirects (302 on GET)', () async {
      final r = await handler.handle(_get('/settings'));
      expect(r.status, 302);
      expect(r.headers['location'], '/login');
    });

    test('onRequest fills locals from the cookie', () async {
      final r = await handler.handle(
        _get('/settings', headers: {HttpHeader.cookie: 'user=ana'}),
      );
      expect(r.status, 200);
      expect(r.text, contains('<nav>ana</nav>settings'));
    });

    test('an action sets a cookie and redirects (secure defaults)', () async {
      final r = await handler.handle(_post('/login', 'email=a'));
      expect(r.status, 303);
      expect(r.headers['location'], '/');
      expect(r.cookies.single, 'user=ana; Path=/; SameSite=Lax; HttpOnly');
    });
  });

  group('pages fetched ahead (Clear-Site-Data)', () {
    const clear = '"prefetchCache", "prerenderCache"';
    String? header(ThorResponse r) => r.headers.entries
        .where((e) => e.key.toLowerCase() == 'clear-site-data')
        .map((e) => e.value)
        .singleOrNull;

    test('a successful action drops them (data changed)', () async {
      final r = await handler.handle(_post('/article/x?/comment', 'body=a'));
      expect(r.status, 303);
      expect(header(r), clear);
    });

    test('an action that redirects elsewhere drops them too', () async {
      final r = await handler.handle(_post('/article/x?/delete', ''));
      expect(header(r), clear);
    });

    test('a sign-in (cookie set by an action) drops them', () async {
      final r = await handler.handle(_post('/login', 'email=a'));
      expect(r.cookies, isNotEmpty);
      expect(header(r), clear);
    });

    test('a GET that sets a cookie drops them', () async {
      final r = await handler.handle(_get('/session'));
      expect(r.status, 200);
      expect(r.cookies, isNotEmpty);
      expect(header(r), clear);
    });

    test('a failed action (nothing changed) keeps them', () async {
      final r = await handler.handle(_post('/article/x?/comment', 'body='));
      expect(r.status, 422);
      expect(header(r), isNull);
    });

    test('a refused post (CSRF) keeps them', () async {
      final r = await handler.handle(
        _post('/article/x?/comment', 'body=a', origin: 'https://evil.test'),
      );
      expect(r.status, 403);
      expect(header(r), isNull);
    });

    test('plain GETs never send it (it would defeat prefetching)', () async {
      for (final path in ['/', '/article/x', '/missing', '/settings']) {
        expect(header(await handler.handle(_get(path))), isNull, reason: path);
      }
    });

    test("the app's own Clear-Site-Data is kept and extended", () async {
      final r = await handler.handle(_post('/session?/logout', ''));
      expect(
        r.headers.keys.where((k) => k.toLowerCase() == 'clear-site-data'),
        hasLength(1),
        reason: 'one header, not two spellings',
      );
      expect(header(r), '"cookies", $clear');
    });

    test('"*" already clears everything: left alone', () async {
      final r = await handler.handle(_post('/session?/wipe', ''));
      expect(header(r), '"*"');
    });
  });

  group('form actions', () {
    test(
      'a successful action redirects back to the page (post/redirect/get)',
      () async {
        final r = await handler.handle(
          _post('/article/x?/comment&keep=1', 'body=hello+there'),
        );
        expect(r.status, 303);
        expect(r.headers['location'], '/article/x?keep=1');
        expect(comments, ['first', 'hello there']);
      },
    );

    test(
      'a failed action re-renders the page with its status and data',
      () async {
        final r = await handler.handle(_post('/article/x?/comment', 'body='));
        expect(r.status, 422);
        expect(r.text, contains('form={error: blank}'));
        expect(comments, ['first']);
      },
    );

    test('an ActionOutcome renders with the result it names', () async {
      final r = await handler.handle(_post('/article/x?/outcome', ''));
      expect(r.status, 409);
      expect(r.text, contains('form=taken'));
    });

    test(
      'any other value is an error (THOR-P009), never a silent success',
      () async {
        final r = await handler.handle(_post('/article/x?/stray', ''));
        expect(r.status, 500);
        expect(errors.single.toString(), contains('THOR-P009'));
        expect(errors.single.toString(), contains('returned a int'));
      },
    );

    test('an action can redirect elsewhere', () async {
      final r = await handler.handle(_post('/article/x?/delete', ''));
      expect(r.headers['location'], '/');
    });

    test('unknown action → 404; page without actions → 405', () async {
      expect((await handler.handle(_post('/article/x?/nope', ''))).status, 404);
      expect((await handler.handle(_post('/', ''))).status, 405);
    });

    test('a form posted from another site is refused (CSRF)', () async {
      final r = await handler.handle(
        _post('/article/x?/comment', 'body=spam', origin: 'https://evil.test'),
      );
      expect(r.status, 403);
      expect(comments, ['first']);
    });

    test('a form post without Origin is refused', () async {
      final request = PageRequest(
        method: HttpMethod.post,
        uri: Uri.parse('http://site.test/login'),
        headers: {
          HttpHeader.host: 'site.test',
          HttpHeader.contentType: 'application/x-www-form-urlencoded',
        },
        body: Stream.value(utf8.encode('a=1')),
      );
      expect((await handler.handle(request)).status, 403);
    });

    test('repeated fields keep every value', () {
      final form = FormData.parse('tag=a&tag=b&title=Hi+%26+bye');
      expect(form.all('tag'), ['a', 'b']);
      expect(form['title'], 'Hi & bye');
    });

    test('a body over the limit is a 413', () async {
      final request = PageRequest(
        method: HttpMethod.post,
        uri: Uri.parse('http://site.test/article/x?/comment'),
        headers: {
          HttpHeader.host: 'site.test',
          HttpHeader.origin: 'http://site.test',
          HttpHeader.contentType: 'application/x-www-form-urlencoded',
        },
        body: Stream.value(List.filled(2000, 97)),
        maxBodyBytes: 1000,
      );
      final r = await handler.handle(request);
      expect(r.status, 413);
    });
  });

  group('page cache', () {
    test('serves the cached page and refreshes it after it expires', () async {
      var renders = 0;
      final h = RouteHandler<String>(
        renderer: _Renderer(),
        routes: [
          PageRoute<String, int>(
            load: (r) => ++renders,
            build: (s) => 'render ${s.data}',
            // Wide enough that a loaded machine (tests in parallel) does not
            // let it expire between the first two requests.
            cache: const Duration(milliseconds: 300),
          ),
        ],
      );
      expect((await h.handle(_get('/'))).text, contains('render 1'));
      expect((await h.handle(_get('/'))).text, contains('render 1'));
      await Future<void>.delayed(const Duration(milliseconds: 350));
      // Stale: served as is while it refreshes in the background.
      expect((await h.handle(_get('/'))).text, contains('render 1'));
      // The refresh lands when it lands: wait for it, not a fixed time.
      var text = '';
      final end = DateTime.now().add(const Duration(seconds: 20));
      while (!text.contains('render 2') && DateTime.now().isBefore(end)) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        text = (await h.handle(_get('/'))).text;
      }
      expect(text, contains('render 2'));
    });

    // A visitor-specific page (a session) and a shared one for everyone else.
    RouteHandler<String> personalHandler(void Function() onRender) =>
        RouteHandler<String>(
          renderer: _Renderer(),
          personalized: (r) => r.cookies.containsKey('user'),
          onRequest: (r) => r.locals['user'] = r.cookies['user'],
          routes: [
            PageRoute<String, String>(
              load: (r) {
                onRender();
                return (r.locals['user'] as String?) ?? 'guest';
              },
              build: (s) => 'hello ${s.data}',
              actions: {'default': (r) => null},
              cache: const Duration(minutes: 1),
            ),
          ],
        );

    test('personalized requests skip the cache and never fill it', () async {
      var renders = 0;
      final h = personalHandler(() => renders++);
      final ana = <HttpHeader, String>{HttpHeader.cookie: 'user=ana'};
      expect(
        (await h.handle(_get('/', headers: ana))).text,
        contains('hello ana'),
      );
      expect((await h.handle(_get('/'))).text, contains('hello guest'));
      expect((await h.handle(_get('/'))).text, contains('hello guest'));
      expect(renders, 2, reason: 'the second guest is a cache hit');
      expect(
        (await h.handle(_get('/', headers: ana))).text,
        contains('hello ana'),
      );
      expect(renders, 3, reason: 'a session always renders');
    });

    test('a successful form action clears the cache', () async {
      var renders = 0;
      final h = personalHandler(() => renders++);
      await h.handle(_get('/'));
      await h.handle(_get('/'));
      expect(renders, 1);
      final posted = await h.handle(_post('/', ''));
      expect(posted.status, 303);
      expect(h.cachedPaths, isEmpty);
      await h.handle(_get('/'));
      expect(renders, 2);
    });

    // A render that loaded its data before a form action changed it must
    // not be cached after the action cleared the cache.
    test('a render in flight during a form action is not cached', () async {
      var data = 'old';
      final loading = Completer<void>();
      final h = RouteHandler<String>(
        renderer: _Renderer(),
        routes: [
          PageRoute<String, String>(
            load: (r) async {
              final seen = data;
              if (!loading.isCompleted) await loading.future;
              return seen;
            },
            build: (s) => 'data ${s.data}',
            actions: {
              'default': (r) {
                data = 'new';
                return null;
              },
            },
            cache: const Duration(minutes: 1),
          ),
        ],
      );
      final inFlight = h.handle(_get('/'));
      await h.handle(_post('/', ''));
      loading.complete();
      expect((await inFlight).text, contains('data old'));
      expect(h.cachedPaths, isEmpty);
      expect((await h.handle(_get('/'))).text, contains('data new'));
    });

    test('an entry older than twice the TTL is rendered again', () async {
      var renders = 0;
      final h = RouteHandler<String>(
        renderer: _Renderer(),
        routes: [
          PageRoute<String, int>(
            load: (r) => ++renders,
            build: (s) => 'render ${s.data}',
            cache: const Duration(milliseconds: 10),
          ),
        ],
      );
      expect((await h.handle(_get('/'))).text, contains('render 1'));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect((await h.handle(_get('/'))).text, contains('render 2'));
    });

    test('a background refresh runs onRequest and the guards', () async {
      var visits = 0;
      var open = true;
      final h = RouteHandler<String>(
        renderer: _Renderer(),
        onRequest: (r) => r.locals['visit'] = ++visits,
        routes: [
          PageRoute<String, int>(
            redirect: (r) => open ? null : const RouteUrl('/closed'),
            load: (r) => r.locals['visit']! as int,
            build: (s) => 'visit ${s.data}',
            // Wide, with the waits below in between one TTL and two: a
            // loaded machine cannot push a wait past the second.
            cache: const Duration(milliseconds: 500),
          ),
        ],
      );
      Future<void> until(bool Function() ok) async {
        final end = DateTime.now().add(const Duration(seconds: 20));
        while (!ok() && DateTime.now().isBefore(end)) {
          await Future<void>.delayed(const Duration(milliseconds: 2));
        }
      }

      const stale = Duration(milliseconds: 650);
      expect((await h.handle(_get('/'))).text, contains('visit 1'));
      await Future<void>.delayed(stale);
      // Stale: served while the refresh runs onRequest (visit 2).
      expect((await h.handle(_get('/'))).text, contains('visit 1'));
      await until(() => visits == 2); // the refresh ran onRequest
      var text = '';
      await until(() {
        h.handle(_get('/')).then((r) => text = r.text);
        return text.contains('visit 2');
      });
      expect(text, contains('visit 2'));
      await Future<void>.delayed(stale);
      open = false;
      expect((await h.handle(_get('/'))).text, contains('visit 2'));
      await until(() => visits == 3); // the refresh ran, and met the guard
      await Future<void>.delayed(Duration.zero);
      // The refresh met the guard: its redirect is not cached, and nothing
      // rendered past the guard replaced the page.
      final r = await h.handle(_get('/'));
      expect(r.status, 200);
      expect(r.text, contains('visit 2'));
    });
  });

  test('the page cache is bounded (least recently used go first)', () async {
    final h = RouteHandler<String>(
      renderer: _Renderer(),
      maxCacheBytes: 100,
      routes: [
        PageRoute<String, String>(
          path: '[id]',
          load: (r) => r.pathParameters['id']!,
          build: (s) => s.data * 10,
          cache: const Duration(minutes: 1),
        ),
      ],
    );
    // Each page is ~25 bytes: four fit, the fifth evicts the oldest.
    for (final id in ['aa', 'bb', 'cc', 'dd']) {
      await h.handle(_get('/$id'));
    }
    await h.handle(_get('/aa')); // touch: now the most recent
    await h.handle(_get('/ee'));
    // `bb` was the least recently used.
    expect(h.cachedPaths, isNot(contains('http://site.test/bb')));
    expect(h.cachedPaths, contains('http://site.test/aa'));
    expect(h.cachedBytes, lessThanOrEqualTo(100));
  });

  group('signed cookies', () {
    final signer = SignedCookies('0123456789abcdef0123456789abcdef');

    test('round-trips and rejects tampering', () {
      final signed = signer.sign('{"user":"ana"}');
      expect(signer.verify(signed), '{"user":"ana"}');
      expect(signer.verify(signed.replaceFirst('e', 'f')), isNull);
      expect(signer.verify('garbage'), isNull);
      expect(signer.verify(null), isNull);
    });

    test('refuses a short secret', () {
      expect(() => SignedCookies('short'), throwsArgumentError);
    });

    test('remembering verified cookies changes no answer', () {
      final signer = SignedCookies('0123456789abcdef0123456789abcdef');
      final other = SignedCookies('fedcba9876543210fedcba9876543210');
      final signed = [for (var i = 0; i < 20; i++) signer.sign('{"n":$i}')];
      final saved = SignedCookies.maxVerified;
      addTearDown(() => SignedCookies.maxVerified = saved);
      for (final max in [4096, 3, 0]) {
        SignedCookies.maxVerified = max;
        for (var round = 0; round < 3; round++) {
          for (var i = 0; i < signed.length; i++) {
            expect(signer.verify(signed[i]), '{"n":$i}');
            // A tampered copy of a remembered cookie is still refused.
            expect(signer.verify('${signed[i]}x'), isNull);
            expect(signer.verify(signed[i].replaceFirst('e', 'f')), isNull);
            // Another secret never takes what this one remembered.
            expect(other.verify(signed[i]), isNull);
          }
        }
      }
    });
  });

  test('parses a Cookie header', () {
    expect(parseCookies('a=1; b="two"; c=%C3%A9'), {
      'a': '1',
      'b': 'two',
      'c': 'é',
    });
  });
}
