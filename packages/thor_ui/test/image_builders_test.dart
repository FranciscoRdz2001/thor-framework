// Image(errorBuilder:, loadingBuilder:) (Flutter's names).
@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

Future<String> _page(Widget w) => renderDocument(ThorApp(child: w));

Future<String> _body(Widget w) async => bodyOfPage(await _page(w));

Future<String> _css(Widget w) async => RegExp(
  r'<style[^>]*>([\s\S]*?)</style>',
).allMatches(await _page(w)).map((m) => m[1]).join().replaceAll(' ', '');

Widget _fallback(BuildContext c, Object e, StackTrace? s) =>
    const Text('No photo');

Widget _spinner(BuildContext c, Widget child, ImageChunkEvent? progress) =>
    progress == null ? child : const Text('Loading');

int _count(String html, String needle) => needle.allMatches(html).length;

/// How many frames (elements with `data-ib`) [html] has.
int _frames(String html) => RegExp(r'\sdata-ib[\s>=]').allMatches(html).length;

void main() {
  setUpAll(initializeThorTests);

  group('errorBuilder', () {
    test(
      'renders the fallback beside the image, hidden until it fails',
      () async {
        const w = Image.network(
          '/missing.png',
          width: 120,
          height: 80,
          errorBuilder: _fallback,
        );
        final html = await _body(w);
        // The wrapper is the frame both live in; the image reports its failure.
        expect(html, contains('data-ib'));
        expect(html, contains('src="/missing.png"'));
        expect(html, contains('onerror='));
        expect(html, contains('data-broken'));
        expect(html, contains('data-fb'));
        expect(html, contains('>No photo<'));
        // The image comes first, then the fallback.
        expect(html.indexOf('<img'), lessThan(html.indexOf('No photo')));
        final css = await _css(w);
        // Until it fails the fallback is hidden; after, the image is.
        expect(
          css,
          contains(':not([data-broken])>[data-fb]{display:none!important}'),
        );
        expect(
          css,
          contains('[data-broken]>:not([data-fb]){display:none!important}'),
        );
      },
    );

    test('the builder gets an ImageLoadError with the url', () async {
      Object? seen;
      await _body(
        Image.network(
          '/a/b.png',
          errorBuilder: (context, error, stack) {
            seen = error;
            return const Text('x');
          },
        ),
      );
      expect(seen, isA<ImageLoadError>());
      expect((seen! as ImageLoadError).url, '/a/b.png');
      expect(seen.toString(), contains('/a/b.png'));
    });

    test('Image.asset has it too', () async {
      final html = await _body(
        const Image.asset('images/x.png', errorBuilder: _fallback),
      );
      expect(html, contains('onerror='));
      expect(html, contains('>No photo<'));
    });

    test('without builders the image is what it was', () async {
      final html = await _body(const Image.network('/a.png', width: 10));
      expect(html, isNot(contains('data-ib')));
      expect(html, isNot(contains('onerror')));
      expect(html, isNot(contains('onload')));
      expect(html, startsWith('<body'));
      expect(_count(html, '<img'), 1);
    });

    test('a picture keeps one handler, on its img', () async {
      final html = await _body(
        const Image.network(
          '/a.png',
          dark: '/a-dark.png',
          errorBuilder: _fallback,
        ),
      );
      expect(_count(html, 'onerror='), 1);
      expect(_frames(html), 1);
    });

    test(
      'the fallback is any widget, and layout wrappers still fuse',
      () async {
        final html = await _body(
          const Padding(
            padding: EdgeInsets.all(8),
            child: Image.network('/a.png', errorBuilder: _fallback),
          ),
        );
        // One frame: the padding is on it, not on a second element.
        expect(_frames(html), 1);
      },
    );

    test('the handler is an attribute: no script file, no engine', () async {
      final page = await _page(
        const Image.network('/a.png', errorBuilder: _fallback),
      );
      expect(page, isNot(contains('<script src')));
      expect(page, isNot(contains('engine')));
    });
  });

  group('inline handlers (CSP hashes in docs/guia/es/sesion-y-seguridad.md)', () {
    test('their text is fixed: the guide lists its sha256', () async {
      final html = await _body(
        const Image.network(
          '/a.png',
          errorBuilder: _fallback,
          loadingBuilder: _spinner,
        ),
      );
      expect(
        html,
        contains(
          'onerror="this.closest(\'[data-ib]\').setAttribute(\'data-broken\',\'\')"',
        ),
      );
      expect(
        html,
        contains(
          'onload="this.closest(\'[data-ib]\').setAttribute(\'data-loaded\',\'\')"',
        ),
      );
    });
  });

  group('loadingBuilder', () {
    test('the placeholder sits behind the image until it loads', () async {
      const w = Image.network(
        '/big.jpg',
        width: 200,
        height: 100,
        loadingBuilder: _spinner,
      );
      final html = await _body(w);
      expect(html, contains('data-ph'));
      expect(html, contains('onload='));
      expect(html, contains('data-loaded'));
      expect(html, contains('>Loading<'));
      // Behind: the placeholder is first, the image paints over it.
      expect(html.indexOf('Loading'), lessThan(html.indexOf('<img')));
      final css = await _css(w);
      expect(css, contains('[data-loaded]>[data-ph]{display:none!important}'));
      expect(css, contains('grid-area:1/1'));
    });

    test(
      'the builder is asked for the loading state, with an empty child',
      () async {
        ImageChunkEvent? progress;
        Widget? child;
        await _body(
          Image.network(
            '/a.png',
            loadingBuilder: (context, c, p) {
              progress = p;
              child = c;
              return const Text('wait');
            },
          ),
        );
        expect(progress, isNotNull);
        expect(progress!.cumulativeBytesLoaded, 0);
        expect(progress!.expectedTotalBytes, isNull);
        // Not the image itself: the placeholder must not repeat it.
        expect(child, isA<SizedBox>());
      },
    );

    test(
      'a builder that returns the child leaves an empty placeholder',
      () async {
        final html = await _body(
          Image.network('/a.png', loadingBuilder: (context, child, p) => child),
        );
        expect(_count(html, '<img'), 1);
      },
    );

    test(
      'both builders share one frame; the failure hides the placeholder',
      () async {
        const w = Image.network(
          '/a.png',
          width: 50,
          height: 50,
          loadingBuilder: _spinner,
          errorBuilder: _fallback,
        );
        final html = await _body(w);
        expect(_frames(html), 1);
        expect(html.indexOf('Loading'), lessThan(html.indexOf('<img')));
        expect(html.indexOf('<img'), lessThan(html.indexOf('No photo')));
        expect(html, contains('onerror='));
        expect(html, contains('onload='));
        // The failure rule hides everything but the fallback: the placeholder too.
        expect(
          await _css(w),
          contains('[data-broken]>:not([data-fb]){display:none!important}'),
        );
      },
    );
  });
}
