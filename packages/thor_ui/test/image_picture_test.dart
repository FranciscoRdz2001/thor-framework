import 'package:test/test.dart';
import 'package:thor_ui/router.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

ImageEntry _entry(String stem, {bool avif = true}) => ImageEntry(
  width: 1250,
  height: 859,
  src: 'images/$stem.webp',
  variants: [
    ImageVariant(
      width: 640,
      type: 'image/webp',
      src: 'images/$stem-640.aaaaaaaa.webp',
    ),
    if (avif)
      ImageVariant(
        width: 640,
        type: 'image/avif',
        src: 'images/$stem-640.bbbbbbbb.avif',
      ),
    if (avif)
      ImageVariant(
        width: 1250,
        type: 'image/avif',
        src: 'images/$stem-1250.cccccccc.avif',
      ),
  ],
);

final _manifest = ImageManifest({
  'images/light.webp': _entry('light'),
  'images/dark.webp': _entry('dark'),
  'images/plain.webp': _entry('plain', avif: false),
  'images/plain-dark.webp': _entry('plain-dark', avif: false),
});

Future<String> _page(Widget image) => renderDocument(
  ThorApp(
    child: ImageManifestScope(manifest: _manifest, child: image),
  ),
);

/// The tags of [html] in order, without attributes (`picture`, `source`).
List<String> _tags(String html) => [
  for (final m in RegExp(r'<(picture|source|img|span)\b').allMatches(html))
    m.group(1)!,
];

void main() {
  group('Image with a choice of files: a <picture>', () {
    test('no AVIF, no dark: still one <img> (the output of before)', () async {
      final html = await _page(const Image.asset('images/plain.webp'));
      expect(html, isNot(contains('<picture')));
      expect(html, contains('<img'));
    });

    test('AVIF variants: a <source type=image/avif> before the <img>, '
        'the WebP srcset on the <img>', () async {
      final html = await _page(const Image.asset('images/light.webp'));
      expect(_tags(html), containsAllInOrder(['picture', 'source', 'img']));
      expect(
        html,
        contains(
          '<source type="image/avif" srcset="images/light-640.bbbbbbbb.avif '
          '640w, images/light-1250.cccccccc.avif 1250w" sizes="100vw"',
        ),
      );
      expect(html, contains('srcset="images/light-640.aaaaaaaa.webp 640w"'));
      expect(html, contains('width="1250" height="859"'));
      // One class each: the box and the image inside.
      final picture = RegExp(r'<picture class="([^"]+)"').firstMatch(html)!;
      expect(picture.group(1)!.split(' '), hasLength(1));
    });

    test('the <img> keeps its size rules (no CLS, shrinks in a narrow '
        'parent); the box only hugs it', () async {
      final html = await _page(
        const Image.asset('images/light.webp', width: 600),
      );
      expect(html, contains('aspect-ratio: 600 / 412'));
      expect(html, contains('width: 600px'));
      expect(html, contains('width: fit-content'));
      // The box never carries a fixed width: a narrow parent would then
      // have to grow to it (an <img> with max-width: 100% shrinks).
      expect(RegExp('(?<![-a-z])width: 600px').allMatches(html), hasLength(1));
    });

    test('an infinite width: the box fills its parent too', () async {
      final html = await _page(
        const Image.asset('images/light.webp', width: double.infinity),
      );
      expect(html, isNot(contains('fit-content')));
    });

    test('a dark picture: the system one in a <picture>, and lazy twins '
        'for a flipped switch', () async {
      final html = await _page(
        const Image.asset(
          'images/light.webp',
          dark: 'images/dark.webp',
          lazy: false,
        ),
      );
      expect(
        _tags(html),
        containsAllInOrder([
          'span', 'picture', 'source', 'source', 'source', 'img', //
          'picture', 'source', 'img', 'picture', 'source', 'img',
        ]),
      );
      final picture = RegExp(
        '<picture[^>]*>(.*?)</picture>',
        dotAll: true,
      ).firstMatch(html)!.group(1)!;
      // The system's scheme picks: dark files when it prefers dark.
      expect(
        picture,
        contains(
          'media="(prefers-color-scheme: dark)" '
          'srcset="images/dark-640.bbbbbbbb.avif',
        ),
      );
      expect(picture, contains('src="images/light.webp"'));
      expect(picture, isNot(contains('loading="lazy"')));
      // The twins: after the picture, each its AVIF <source> with no
      // `media` (a matching `media` makes the preload scanner fetch it) and
      // a lazy <img>: nothing downloads until the switch shows one.
      final twins = RegExp(
        '<picture[^>]*>(.*?)</picture>',
        dotAll: true,
      ).allMatches(html).skip(1).map((m) => m.group(1)!).toList();
      expect(twins, hasLength(2));
      expect(twins[0], contains('srcset="images/dark-640.bbbbbbbb.avif'));
      expect(twins[0], contains('src="images/dark.webp"'));
      expect(twins[1], contains('srcset="images/light-640.bbbbbbbb.avif'));
      expect(twins[1], contains('src="images/light.webp"'));
      for (final t in twins) {
        expect(t, isNot(contains('media=')));
        expect(t, contains('loading="lazy"'));
      }
      // Shown only while the switch flips the system's scheme.
      expect(
        html,
        contains(
          '@media not all and (prefers-color-scheme: dark)'
          '{:where(:root:has(#thor-theme:checked))',
        ),
      );
      expect(html, contains(':root:has(#thor-theme:checked)'));
    });

    test('twins without AVIF files stay a plain lazy <img>', () async {
      final html = await _page(
        const Image.asset(
          'images/plain.webp',
          dark: 'images/plain-dark.webp',
          lazy: false,
        ),
      );
      final after = html.substring(html.indexOf('</picture>'));
      expect(after, isNot(contains('<picture')));
      expect('<img'.allMatches(after), hasLength(2));
    });

    test('a dark URL with no manifest: a source with that URL', () async {
      final html = await _page(
        const Image.network('/a.png', dark: '/a-dark.png', lazy: false),
      );
      expect(
        html,
        contains(
          '<source media="(prefers-color-scheme: dark)" srcset="/a-dark.png"',
        ),
      );
      expect(html, contains('src="/a.png"'));
    });
  });

  group('Image(priority: true): preloaded', () {
    test('its best files in a <link rel=preload as=image> in the <head>, '
        'high priority', () async {
      final html = await _page(
        const Image.asset('images/light.webp', priority: true),
      );
      final head = html.substring(0, html.indexOf('</head>'));
      expect(head, contains('rel="preload" as="image"'));
      expect(head, contains('imagesrcset="images/light-640.bbbbbbbb.avif'));
      expect(head, contains('type="image/avif"'));
      expect(head, contains('fetchpriority="high"'));
      expect(html, contains('fetchpriority="high"'));
    });

    test('with a dark picture: one preload per theme, by media', () async {
      final html = await _page(
        const Image.asset(
          'images/light.webp',
          dark: 'images/dark.webp',
          priority: true,
        ),
      );
      final head = html.substring(0, html.indexOf('</head>'));
      expect(RegExp('rel="preload" as="image"').allMatches(head), hasLength(2));
      expect(head, contains('media="(prefers-color-scheme: dark)"'));
      expect(
        head,
        contains('media="not all and (prefers-color-scheme: dark)"'),
      );
    });

    test('not priority: nothing preloaded', () async {
      final html = await _page(const Image.asset('images/light.webp'));
      expect(html, isNot(contains('as="image"')));
    });

    test('the same image twice: one preload', () async {
      final html = await _page(
        const Column(
          children: [
            Image.asset('images/plain.webp', priority: true),
            Image.asset('images/plain.webp', priority: true),
          ],
        ),
      );
      expect(RegExp('as="image"').allMatches(html), hasLength(1));
    });
  });

  test('a server page reports its main image for the Link header', () async {
    final handler = RouteHandler<Widget>(
      renderer: WidgetRenderer(
        app: (page) => ThorApp(child: page),
        images: _manifest,
      ),
      routes: [
        PageRoute<Widget, void>(
          build: (s) => const Image.asset('images/plain.webp', priority: true),
        ),
      ],
    );
    final r = await handler.handle(
      PageRequest(
        method: HttpMethod.get,
        uri: Uri.parse('http://site.test/'),
        headers: const {HttpHeader.host: 'site.test'},
      ),
    );
    // From the site root: a `Link` header resolves against the request's
    // URL, so a relative one would preload the wrong file on `/a/b`.
    expect(
      r.headers['link'],
      '</images/plain.webp>; rel=preload; as=image; '
      'imagesrcset="/images/plain-640.aaaaaaaa.webp 640w"; '
      'imagesizes="100vw"; fetchpriority=high',
    );
  });
}
