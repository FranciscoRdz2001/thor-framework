@TestOn('vm')
library;

// Adversarial checks of `LazyPiece`: what a fragment request may
// reach, what it must not store, what it escapes.
import 'dart:io';

import 'package:test/test.dart';
import 'package:thor_server/thor_server.dart' show exportSite;
import 'package:thor_ui/router.dart';
import 'package:thor_ui/src/engine/prefetch_script.dart'
    show prefetchLoaderScript;
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

class HostileState extends ThorState {
  HostileState();
  final text = state('');
  String label() => text.value;
}

final hostile = HostileState();

Widget piece(
  String id, {
  String text = 'secret',
  Future<String> Function(PageRequest)? load,
}) => LazyPiece<String>(
  id: id,
  load: load ?? (request) async => text,
  builder: (context, t) => Text(t),
  fallback: const Text('fallback'),
);

void main() {
  initializeThorTests();
  setUpAll(
    () => ThorState.register({
      HostileState: ThorStateType('HostileState', (state) {
        final s = state as HostileState;
        return [
          ThorMember.state('text', s.text),
          ThorMember('label', s.label, call: (_) => s.label()),
        ];
      }),
    }),
  );

  late List<Object> errors;
  var guarded = 0;
  var renders = 0;

  RouteHandler<Widget> handler() => RouteHandler<Widget>(
    renderer: WidgetRenderer(app: (page) => ThorApp(child: page)),
    onError: (request, error, stack) => errors.add(error),
    routes: [
      PageRoute<Widget, void>(
        path: 'open',
        build: (s) => Column(
          children: [
            piece('a', text: 'piece a <b>x</b> & "q"'),
            piece('b.c-d_e', text: 'dotted'),
          ],
        ),
      ),
      PageRoute<Widget, void>(
        path: 'other',
        build: (s) => piece('only-other', text: 'other secret'),
      ),
      PageRoute<Widget, void>(
        path: 'admin',
        redirect: (r) {
          guarded++;
          return r.headers['cookie'] == 'session=ok'
              ? null
              : const RouteUrl('/login');
        },
        build: (s) => piece('vault', text: 'admin secret'),
      ),
      LayoutRoute<Widget, void>(
        path: 'members',
        middleware: (request, next) async {
          if (request.headers['cookie'] != 'session=ok') {
            throw const HttpError(401);
          }
          return next();
        },
        build: (s, child) => child,
        children: [
          PageRoute<Widget, void>(
            path: 'area',
            build: (s) => piece('member', text: 'member secret'),
          ),
        ],
      ),
      PageRoute<Widget, void>(
        path: 'cached',
        cache: const Duration(minutes: 5),
        load: (r) => renders++,
        build: (s) => Column(
          children: [
            const Text('the whole page'),
            piece('c', text: 'cached piece'),
          ],
        ),
      ),
      PageRoute<Widget, void>(
        path: 'hostile',
        load: (r) {
          hostile.text.value = '</script><script>alert(1)</script><!-- \u2028';
        },
        build: (s) => LazyPiece<void>(
          id: 'h',
          load: (r) async {},
          builder: (context, _) => Watch(hostile.label),
        ),
      ),
      PageRoute<Widget, void>(
        path: 'mine',
        personalized: true,
        build: (s) => piece('p', text: 'private piece'),
      ),
    ],
  );

  PageRequest get(String path, {Map<HttpHeader, String> headers = const {}}) =>
      PageRequest(
        method: HttpMethod.get,
        uri: Uri.parse('http://site.test$path'),
        headers: {HttpHeader.host: 'site.test', ...headers},
      );

  setUp(() {
    errors = [];
    guarded = 0;
    renders = 0;
  });

  group('what a fragment request may reach', () {
    test('an id of another page is a 404 on this one', () async {
      final r = await handler().handle(get('/open?thor-piece=only-other'));
      expect(r.status, 404);
      expect(r.text, isNot(contains('other secret')));
    });

    for (final id in [
      '../other',
      '..%2Fother',
      '%2e%2e%2f',
      'a/../b',
      'a%00',
      'a%20',
      'A',
      '',
      'a&thor-piece=b.c-d_e',
      'a%26x',
      '<script>',
      'a%0d%0aSet-Cookie:x=1',
      'a.',
      '__proto__',
      'toString',
    ]) {
      test(
        'the odd id "$id" answers nothing or a 404, never an error',
        () async {
          final r = await handler().handle(get('/open?thor-piece=$id'));
          // `a&thor-piece=b…` repeats the parameter: the last one wins, and it
          // names a real piece; every other one names none.
          expect(r.status, anyOf(200, 404), reason: id);
          expect(
            r.headers.keys.map((k) => k.toLowerCase()),
            isNot(contains('set-cookie')),
          );
          expect(errors, isEmpty, reason: id);
        },
      );
    }

    test('an empty id is the page, not a fragment', () async {
      final r = await handler().handle(get('/open?thor-piece='));
      expect(r.status, anyOf(200, 404));
      expect(errors, isEmpty);
    });

    test('a guarded page redirects its fragment like the page', () async {
      final page = await handler().handle(get('/admin'));
      expect(page.status, 302);
      final r = await handler().handle(get('/admin?thor-piece=vault'));
      expect(r.status, 302);
      expect(r.headers['location'], '/login');
      expect(r.text, isNot(contains('admin secret')));
      expect(guarded, 2);
    });

    test('a guarded page answers its fragment to who may see it', () async {
      final r = await handler().handle(
        get(
          '/admin?thor-piece=vault',
          headers: {HttpHeader.cookie: 'session=ok'},
        ),
      );
      expect(r.status, 200);
      expect(r.text, contains('admin secret'));
    });

    test('a middleware stops the fragment too', () async {
      final r = await handler().handle(get('/members/area?thor-piece=member'));
      expect(r.status, 401);
      expect(r.text, isNot(contains('member secret')));
      final ok = await handler().handle(
        get(
          '/members/area?thor-piece=member',
          headers: {HttpHeader.cookie: 'session=ok'},
        ),
      );
      expect(ok.status, 200);
      expect(ok.text, contains('member secret'));
    });

    test('the id of a missing page is a 404 page, not a fragment', () async {
      final r = await handler().handle(get('/nope?thor-piece=a'));
      expect(r.status, 404);
      expect(r.text, isNot(contains('piece a')));
    });

    test('a POST with thor-piece is no fragment', () async {
      final r = await handler().handle(
        PageRequest(
          method: HttpMethod.post,
          uri: Uri.parse('http://site.test/open?thor-piece=a'),
          headers: {
            HttpHeader.host: 'site.test',
            HttpHeader.origin: 'http://site.test',
            HttpHeader.contentType: 'application/x-www-form-urlencoded',
          },
        ),
      );
      expect(r.text, isNot(contains('piece a')));
    });

    test('a HEAD answers headers of the page, no fragment body', () async {
      final r = await handler().handle(
        PageRequest(
          method: HttpMethod.head,
          uri: Uri.parse('http://site.test/open?thor-piece=a'),
          headers: {HttpHeader.host: 'site.test'},
        ),
      );
      expect(r.status, anyOf(200, 404));
      expect(errors, isEmpty);
    });
  });

  group('what the fragment says', () {
    test('the piece is escaped like any text', () async {
      final r = await handler().handle(get('/open?thor-piece=a'));
      expect(r.status, 200);
      expect(r.text, contains('piece a &lt;b&gt;x&lt;/b&gt; &amp;'));
      expect(r.text, isNot(contains('<b>x</b>')));
    });

    test(
      'a state value that closes the script cannot leave its element',
      () async {
        final r = await handler().handle(get('/hostile?thor-piece=h'));
        expect(r.status, 200);
        final text = r.text;
        // The state's own element, the engine loader's and the prefetch
        // fallback loader that rides with the engine: no more.
        expect(RegExp('</script>').allMatches(text), hasLength(3));
        expect(text, contains(prefetchLoaderScript));
        expect(text, contains(r'\u003c/script>'));
        expect(text, isNot(contains('<script>alert')));
      },
    );

    test('a dotted id works', () async {
      final r = await handler().handle(get('/open?thor-piece=b.c-d_e'));
      expect(r.status, 200);
      expect(r.text, contains('dotted'));
    });

    test(
      'a fragment is not indexed and not stored by a shared cache',
      () async {
        final r = await handler().handle(get('/open?thor-piece=a'));
        expect(r.headers['x-robots-tag'], contains('noindex'));
        final cc = (r.headers['cache-control'] ?? '').toLowerCase();
        expect(cc, isNot(contains('public')));
        expect(cc, isNot(contains('max-age')));
      },
    );

    test('a fragment of a personal page is private', () async {
      final r = await handler().handle(get('/mine?thor-piece=p'));
      expect(r.status, 200);
      expect(r.headers['cache-control'], contains('private'));
    });
  });

  group('the page cache', () {
    test(
      'the fragment is never served as the page, nor the page as it',
      () async {
        final h = handler();
        final frag = await h.handle(get('/cached?thor-piece=c'));
        expect(frag.text, contains('cached piece'));
        expect(frag.text, isNot(contains('the whole page')));
        final page = await h.handle(get('/cached'));
        expect(page.text, contains('the whole page'));
        expect(page.text, isNot(contains('cached piece')));
        // And the other way: the page cached first.
        final h2 = handler();
        final page2 = await h2.handle(get('/cached'));
        expect(page2.text, contains('the whole page'));
        final frag2 = await h2.handle(get('/cached?thor-piece=c'));
        expect(frag2.text, contains('cached piece'));
        expect(frag2.text, isNot(contains('the whole page')));
      },
    );

    test('a fragment of the cached page does not run the load again', () async {
      final h = handler();
      await h.handle(get('/cached?thor-piece=c'));
      await h.handle(get('/cached?thor-piece=c'));
      expect(renders, 1);
    });

    test('a fragment from the cache is still noindex', () async {
      final h = handler();
      await h.handle(get('/cached?thor-piece=c'));
      final again = await h.handle(get('/cached?thor-piece=c'));
      expect(again.headers['x-robots-tag'], contains('noindex'));
    });

    test('a piece id that does not exist is not cached as a hit', () async {
      final h = handler();
      expect((await h.handle(get('/cached?thor-piece=zzz'))).status, 404);
      expect((await h.handle(get('/cached?thor-piece=zzz'))).status, 404);
      expect((await h.handle(get('/cached'))).status, 200);
    });
  });

  group('a static export', () {
    test('keeps the fallback and no URL nor loader to nowhere', () async {
      final out = await Directory.systemTemp.createTemp('thor_lazy_export');
      addTearDown(() => out.delete(recursive: true));
      final report = await exportSite(
        handler(),
        paths: ['/open'],
        outDir: out.path,
      );
      expect(report.ok, isTrue);
      final html = File('${out.path}/open.html').readAsStringSync();
      expect(html, contains('fallback'));
      expect(html, isNot(contains('data-thor-lazy')));
      expect(html, isNot(contains('thor-piece')));
    });
  });
}
