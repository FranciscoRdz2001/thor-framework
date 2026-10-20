import 'dart:async';
import 'dart:convert';

import 'package:test/test.dart';
import 'package:thor_server/thor_server.dart';

/// Finds a main image when the page text names one (`img:<url>`), like
/// `WidgetRenderer` with an `Image(priority: true)`.
class _Renderer implements PageRenderer<String>, DiscoveredLinks {
  final _found = Expando<List<LinkHint>>();

  @override
  List<int> render(String page, RenderContext context) {
    final images = [
      for (final m in RegExp(r'img:(\S+)').allMatches(page)) m.group(1)!,
    ];
    if (images.isNotEmpty) {
      _found[context] = [
        for (final image in images)
          LinkHint.image(image, srcset: '$image 640w', sizes: '100vw'),
      ];
    }
    return utf8.encode('<!DOCTYPE html><html><body>$page</body></html>');
  }

  @override
  List<LinkHint> linksFound(RenderContext context) =>
      _found[context] ?? const [];

  @override
  String errorPage(ErrorState state) => 'error ${state.status}';
}

PageRequest _get(String path, {Map<String, String> cookies = const {}}) =>
    PageRequest(
      method: HttpMethod.get,
      uri: Uri.parse('http://site.test$path'),
      headers: {
        HttpHeader.host: 'site.test',
        if (cookies.isNotEmpty)
          HttpHeader.cookie: [
            for (final e in cookies.entries) '${e.key}=${e.value}',
          ].join('; '),
      },
    );

Future<String> _body(ThorResponse r) async {
  final stream = r.stream;
  if (stream == null) return r.text;
  return utf8.decode([for (final chunk in await stream.toList()) ...chunk]);
}

const _user = ContextKey<String>('user');

void main() {
  group('LinkHint.image', () {
    test('its srcset, sizes and media quoted, high priority', () {
      expect(
        const LinkHint.image(
          'images/a.webp',
          srcset: 'images/a-640.avif 640w, images/a-1250.avif 1250w',
          sizes: '(min-width: 600px) 600px, 100vw',
          type: 'image/avif',
          media: '(prefers-color-scheme: dark)',
        ).header,
        '<images/a.webp>; rel=preload; as=image; type=image/avif; '
        'imagesrcset="images/a-640.avif 640w, images/a-1250.avif 1250w"; '
        'imagesizes="(min-width: 600px) 600px, 100vw"; '
        'media="(prefers-color-scheme: dark)"; fetchpriority=high',
      );
    });

    for (final bad in ['a" , </evil>; rel=x', 'a\r\nset-cookie: x', r'a\"']) {
      test('a value that could end the quotes or the header: $bad', () {
        expect(
          () => LinkHint.image('a.webp', srcset: bad).header,
          throwsArgumentError,
        );
      });
    }
  });

  group('links found by the render', () {
    late String page;
    late Completer<String>? slow;
    String? slowPage;

    RouteHandler<String> handler() => RouteHandler<String>(
      renderer: _Renderer(),
      earlyHintsAfter: const Duration(milliseconds: 10),
      routes: [
        LayoutRoute<String, void>(
          build: (s, child) => child,
          earlyHints: true,
          middleware: (request, next) {
            if (request.cookies['user'] case final u?) {
              request.context.set(_user, u);
            }
            return next();
          },
          children: [
            PageRoute<String, String>(
              path: 'hero',
              load: (r) => slow?.future ?? page,
              build: (s) => s.data,
            ),
            PageRoute<String, String>(
              path: 'article/[slug]',
              load: (r) async {
                final slug = r.pathParameters['slug']!;
                if (slow case final wait?) await wait.future;
                // A banner every article has, and each one's own cover.
                return slowPage ??
                    'img:/images/banner.webp img:/covers/$slug.webp';
              },
              build: (s) => s.data,
            ),
            PageRoute<String, String>(
              path: 'mine',
              load: (r) => 'img:/avatars/${r.context.maybeGet(_user)}.webp',
              build: (s) => s.data,
            ),
          ],
        ),
      ],
    );

    setUp(() {
      page = 'img:/images/hero.webp';
      slow = null;
    });

    test('in the Link header of the response that found them', () async {
      final r = await handler().handle(_get('/hero'));
      expect(r.status, 200);
      expect(r.headers['link'], contains('</images/hero.webp>; rel=preload'));
    });

    test('learned: the next slow request answers early with them', () async {
      final h = handler();
      await h.handle(_get('/hero'));
      slow = Completer();
      final r = h.handle(_get('/hero'));
      final early = await r;
      expect(early.stream, isNotNull, reason: 'answered before the data');
      expect(early.headers['link'], contains('</images/hero.webp>'));
      slow!.complete('img:/images/hero.webp');
      expect(await _body(early), contains('img:/images/hero.webp'));
    });

    test('never learned from a page a visitor makes theirs', () async {
      final h = handler();
      final mine = await h.handle(_get('/mine', cookies: {'user': 'ana'}));
      // Ana's own response may carry it…
      expect(mine.headers['link'], contains('/avatars/ana.webp'));
      // …the next visitor's never does.
      final next = await h.handle(_get('/mine', cookies: {'user': 'bob'}));
      expect(next.headers['link'], isNot(contains('ana')));
    });

    test('a page that drops its image stops hinting it', () async {
      final h = handler();
      await h.handle(_get('/hero'));
      page = 'no image now';
      await h.handle(_get('/hero'));
      page = 'still none';
      final r = await h.handle(_get('/hero'));
      expect(r.headers['link'], isNull);
    });

    test('one entry per URL, the same hint never twice', () async {
      final h = handler();
      await h.handle(_get('/hero'));
      final r = await h.handle(_get('/hero'));
      expect(
        RegExp('</images/hero.webp>').allMatches(r.headers['link']!),
        hasLength(1),
      );
    });

    group('per route pattern', () {
      // A request whose loads wait: (its response, whether it answered
      // before the data — only a request that learned links does).
      //
      // A request that should answer early gets a long wait for it (it ends
      // the moment it answers); one that should not only needs to outlast
      // the 10 ms after which it would, so it waits briefly, and a stall
      // can only make it look later, never early.
      Future<(ThorResponse, bool)> slowGet(
        RouteHandler<String> h,
        String path, {
        bool expectEarly = false,
      }) async {
        final wait = slow = Completer();
        final response = h.handle(_get(path));
        final early = await Future.any([
          response.then((_) => true),
          Future.delayed(
            expectEarly
                ? const Duration(seconds: 20)
                : const Duration(milliseconds: 300),
            () => false,
          ),
        ]);
        if (!wait.isCompleted) wait.complete('');
        final r = await response;
        await _body(r);
        return (r, early);
      }

      test('two articles agree on the banner: a third answers early '
          'with it, never with their covers', () async {
        final h = handler();
        await h.handle(_get('/article/a'));
        await h.handle(_get('/article/b'));
        final (r, early) = await slowGet(h, '/article/c', expectEarly: true);
        expect(early, isTrue, reason: 'answered before the data');
        final link = r.headers['link']!;
        expect(link, contains('</images/banner.webp>'));
        expect(link, isNot(contains('/covers/a.webp')));
        expect(link, isNot(contains('/covers/b.webp')));
      });

      test('one article alone teaches only its own URL', () async {
        final h = handler();
        await h.handle(_get('/article/a'));
        await h.handle(_get('/article/a'));
        final (_, other) = await slowGet(h, '/article/c');
        expect(other, isFalse, reason: 'nothing learned for another slug');
        final (again, own) = await slowGet(h, '/article/a', expectEarly: true);
        expect(own, isTrue);
        expect(again.headers['link'], contains('</covers/a.webp>'));
      });

      test(
        'an article a visitor makes theirs never teaches the pattern',
        () async {
          final h = handler();
          await h.handle(_get('/article/a', cookies: {'user': 'ana'}));
          await h.handle(_get('/article/b', cookies: {'user': 'ana'}));
          final (_, early) = await slowGet(h, '/article/c');
          expect(early, isFalse);
        },
      );

      test('a later article without the banner stops it spreading', () async {
        final h = handler();
        await h.handle(_get('/article/a'));
        await h.handle(_get('/article/b'));
        slowPage = 'img:/covers/d.webp';
        await h.handle(_get('/article/d'));
        slowPage = null;
        final (_, early) = await slowGet(h, '/article/e');
        expect(early, isFalse);
      });
    });
  });
}
