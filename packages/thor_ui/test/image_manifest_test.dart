import 'package:test/test.dart';
import 'package:thor_ui/router.dart';
// The scope WidgetRenderer puts on each routed page (not public API).
import 'package:thor_ui/src/foundation/page_navigation.dart'
    show RoutedPageScope;
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

const _manifest = ImageManifest({
  'images/hero.jpg': ImageEntry(
    width: 2400,
    height: 1600,
    src: 'images/hero.jpg',
    variants: [
      ImageVariant(
        width: 1280,
        type: 'image/webp',
        src: 'images/hero-1280.bbbbbbbb.webp',
      ),
      ImageVariant(
        width: 640,
        type: 'image/webp',
        src: 'images/hero-640.aaaaaaaa.webp',
      ),
    ],
  ),
  'images/logo.png': ImageEntry(
    width: 300,
    height: 100,
    src: 'images/logo.png',
  ),
});

Future<String> _render(Widget image) =>
    renderHtml(ImageManifestScope(manifest: _manifest, child: image));

void main() {
  group('Image.asset with the build manifest', () {
    test('its variants become srcset (narrowest first) and sizes', () async {
      final html = await _render(const Image.asset('images/hero.jpg'));
      expect(
        html,
        contains(
          'srcset="images/hero-640.aaaaaaaa.webp 640w, '
          'images/hero-1280.bbbbbbbb.webp 1280w"',
        ),
      );
      expect(html, contains('sizes="100vw"'));
      // The original stays the fallback.
      expect(html, contains('src="images/hero.jpg"'));
    });

    test('no size written: the intrinsic one, height auto (no CLS)', () async {
      final html = await _render(const Image.asset('images/hero.jpg'));
      expect(html, contains('width="2400" height="1600"'));
      expect(html, contains('height: auto'));
      // An explicit ratio: with `height: auto` alone the browser sees a lazy
      // image without dimensions.
      expect(html, contains('aspect-ratio: 2400 / 1600'));
    });

    test('one side written: the other keeps the ratio', () async {
      final html = await _render(
        const Image.asset('images/logo.png', width: 150),
      );
      expect(html, contains('width="150" height="50"'));
      expect(html, contains('aspect-ratio: 150 / 50'));
    });

    test('both sides written: the app wins over the manifest', () async {
      final html = await _render(
        const Image.asset('images/hero.jpg', width: 60, height: 60),
      );
      expect(html, contains('width="60" height="60"'));
    });

    test('a finite width sizes the slot for the browser', () async {
      final html = await _render(
        const Image.asset('images/hero.jpg', width: 320),
      );
      expect(html, contains('sizes="(min-width: 320px) 320px, 100vw"'));
    });

    test('a root-absolute name keeps its form in every URL', () async {
      final html = await _render(const Image.asset('/images/hero.jpg'));
      expect(html, contains('src="/images/hero.jpg"'));
      expect(html, contains('/images/hero-640.aaaaaaaa.webp 640w'));
    });

    test('an image without variants gets only its sizes', () async {
      final html = await _render(const Image.asset('images/logo.png'));
      expect(html, contains('width="300" height="100"'));
      expect(html, isNot(contains('srcset')));
    });

    test('the app\'s own srcSet wins over the variants', () async {
      final html = await _render(
        const Image.asset('images/hero.jpg', srcSet: {100: 'mine.webp'}),
      );
      expect(html, contains('srcset="mine.webp 100w"'));
      expect(html, isNot(contains('aaaaaaaa')));
    });

    test('a name the manifest lacks renders as written', () async {
      final html = await _render(
        const Image.asset('images/other.png', width: 10, height: 20),
      );
      expect(html, contains('src="images/other.png"'));
      expect(html, contains('width="10" height="20"'));
      expect(html, isNot(contains('srcset')));
    });

    test('Image.network never reads the manifest', () async {
      final html = await _render(const Image.network('images/hero.jpg'));
      expect(html, isNot(contains('srcset')));
      expect(html, isNot(contains('width=')));
    });
  });

  group('priority', () {
    test('fetched first and never deferred', () async {
      final html = await renderHtml(
        const Image.asset('hero.webp', width: 10, height: 10, priority: true),
      );
      expect(html, contains('fetchpriority="high"'));
      expect(html, isNot(contains('loading=')));
    });

    test('off by default: lazy as before', () async {
      final html = await renderHtml(
        const Image.asset('hero.webp', width: 10, height: 10),
      );
      expect(html, contains('loading="lazy"'));
      expect(html, isNot(contains('fetchpriority')));
    });
  });

  group('the manifest JSON', () {
    test('reads back what it writes', () {
      final again = ImageManifest.fromJson(_manifest.toJson());
      expect(again.toJson(), _manifest.toJson());
      expect(again['/images/hero.jpg']?.width, 2400);
    });

    test('a shape it does not know throws, naming the image', () {
      expect(
        () => ImageManifest.fromJson({
          'version': 2,
          'images': <String, Object?>{},
        }),
        throwsFormatException,
      );
      expect(
        () => ImageManifest.fromJson({
          'version': 1,
          'images': {
            'images/x.png': {'width': 0, 'height': 1, 'src': 'x'},
          },
        }),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('images/x.png'),
          ),
        ),
      );
    });
  });

  // A routed page has no `<base href>`: a relative asset name there would
  // load from under the page's path (`/a/b` → `/a/images/x.jpg`).
  group('Image.asset under the router', () {
    Future<String> routed(Widget image) => renderHtml(
      RoutedPageScope(
        child: ImageManifestScope(manifest: _manifest, child: image),
      ),
    );

    test(
      'its file, its variants and its dark copy load from the site root',
      () async {
        final html = await routed(
          const Image.asset('images/hero.jpg', dark: 'images/logo.png'),
        );
        expect(html, contains('src="/images/hero.jpg"'));
        expect(html, contains('/images/hero-640.aaaaaaaa.webp 640w'));
        expect(
          html,
          isNot(contains('"images/')),
          reason: 'nothing relative left',
        );
        expect(
          html,
          isNot(contains(' images/')),
          reason: 'no relative srcset entry',
        );
      },
    );

    test('an asset outside the manifest too; a URL is left alone', () async {
      expect(
        await routed(
          const Image.asset('images/other.png', width: 10, height: 20),
        ),
        contains('src="/images/other.png"'),
      );
      expect(
        await routed(
          const Image.asset('/images/other.png', width: 10, height: 20),
        ),
        contains('src="/images/other.png"'),
      );
      expect(
        await routed(
          const Image.asset('https://cdn.test/x.png', width: 1, height: 1),
        ),
        contains('src="https://cdn.test/x.png"'),
      );
      // Image.network is the author's URL, always as written.
      expect(
        await routed(const Image.network('images/hero.jpg')),
        contains('src="images/hero.jpg"'),
      );
    });

    test('a nested route of a router app asks for the root file', () async {
      final router = ThorRouter([ThorRoute('/a/b', const _LogoPage())]);
      final handler = RouteHandler<Widget>(
        renderer: WidgetRenderer(app: (page) => ThorApp(child: page)),
        onError: (request, error, stack) {},
        routes: router.routes,
      );
      final response = await handler.handle(
        PageRequest(
          method: HttpMethod.get,
          uri: Uri.parse('http://site.test/a/b'),
          headers: const {HttpHeader.host: 'site.test'},
        ),
      );
      expect(response.status, 200);
      expect(response.text, contains('src="/images/logo.png"'));
      expect(response.text, isNot(contains('<base')));
    });

    test(
      'outside the router the name keeps its form (the page has <base href="/">)',
      () async {
        expect(
          await _render(
            const Image.asset('images/other.png', width: 10, height: 20),
          ),
          contains('src="images/other.png"'),
        );
      },
    );
  });
}

class _LogoPage extends ThorPage<void> {
  const _LogoPage();

  @override
  Widget build(BuildContext context, PageState<void> state) =>
      const Image.asset('images/logo.png', width: 10, height: 10);
}
