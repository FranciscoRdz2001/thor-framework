// Chromium's "Lazy-loaded images should have explicit dimensions" (the
// LazyLoadImageIssue): a lazy image needs both width and height, or a width
// and an aspect ratio, in its computed style.
@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

Future<String> _body(Widget w) async =>
    bodyOfPage(await renderDocument(ThorApp(child: w)));

String _img(String html) => RegExp('<img[^>]*>').firstMatch(html)![0]!;

void main() {
  setUpAll(initializeThorTests);

  test('width and height: lazy, with both attributes', () async {
    final img = _img(
      await _body(const Image.network('/a.png', width: 120, height: 80)),
    );
    expect(img, contains('loading="lazy"'));
    expect(img, contains('width="120"'));
    expect(img, contains('height="80"'));
  });

  test('no size at all: not lazy (the browser would warn and shift)', () async {
    final img = _img(await _body(const Image.network('/a.png')));
    expect(img, isNot(contains('loading=')));
  });

  test('one side only: not lazy', () async {
    expect(
      _img(await _body(const Image.network('/a.png', width: 120))),
      isNot(contains('loading=')),
    );
    expect(
      _img(await _body(const Image.network('/a.png', height: 80))),
      isNot(contains('loading=')),
    );
  });

  test('lazy: false stays eager, sized or not', () async {
    expect(
      _img(await _body(const Image.network('/a.png', lazy: false))),
      isNot(contains('loading=')),
    );
  });

  test('a wrapper that gives the size makes it lazy', () async {
    final both = _img(
      await _body(
        const WrapWith(
          WrapData(css: {'width': '260px', 'height': '200px'}),
          child: Image.network('/a.png'),
        ),
      ),
    );
    expect(both, contains('loading="lazy"'));
    final onlyWidth = _img(
      await _body(
        const WrapWith(
          WrapData(css: {'width': '260px'}),
          child: Image.network('/a.png'),
        ),
      ),
    );
    expect(onlyWidth, isNot(contains('loading=')));
  });

  test('a width from a wrapper and an AspectRatio-like ratio: lazy', () async {
    final img = _img(
      await _body(
        const WrapWith(
          WrapData(css: {'width': '100%', 'aspect-ratio': '1'}),
          child: Image.network('/a.png'),
        ),
      ),
    );
    expect(img, contains('loading="lazy"'));
  });

  test('a row template image (empty src) follows the same rule', () async {
    expect(
      _img(await _body(const Image.network(''))),
      isNot(contains('loading=')),
    );
    expect(
      _img(await _body(const Image.network('', width: 260, height: 200))),
      contains('loading="lazy"'),
    );
  });

  test(
    'the manifest size is explicit: an aspect ratio, so lazy is safe',
    () async {
      final html = await renderHtml(
        const ImageManifestScope(
          manifest: ImageManifest({
            'images/hero.jpg': ImageEntry(
              width: 2400,
              height: 1600,
              src: 'images/hero.jpg',
            ),
          }),
          child: Image.asset('images/hero.jpg'),
        ),
      );
      expect(html, contains('loading="lazy"'));
      expect(html, contains('aspect-ratio: 2400 / 1600'));
    },
  );

  test('priority is never lazy and keeps its fetchpriority', () async {
    final img = _img(
      await _body(const Image.network('/a.png', priority: true)),
    );
    expect(img, contains('fetchpriority="high"'));
    expect(img, isNot(contains('loading=')));
  });
}
