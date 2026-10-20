// Adversarial render cases: Autocomplete markup with hostile
// option text, media attributes through wrapper chains, Image loading with
// dimensions from a parent, and GridView.extent(stretch: false).
@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

Future<String> _body(Widget w) async =>
    bodyOfPage(await renderDocument(ThorApp(child: w)));

void main() {
  setUpAll(initializeThorTests);

  group('Autocomplete markup', () {
    const hostile = [
      '<img src=x onerror=alert(1)>',
      'say "hi" & \'bye\'',
      '</script><script>alert(2)</script>',
      '</div></dialog><b>',
    ];

    test('option text is escaped, never markup', () async {
      final html = await _body(
        Autocomplete<String>(optionsBuilder: (v) => hostile),
      );
      expect(html, isNot(contains('<img')));
      expect(html, isNot(contains('<script')));
      expect(html, isNot(contains('<b>')));
      expect(html, contains('&lt;img src=x onerror=alert(1)&gt;'));
    });

    test('displayStringForOption text is escaped too', () async {
      final html = await _body(
        Autocomplete<int>(
          optionsBuilder: (v) => [1, 2],
          displayStringForOption: (n) => '<i onclick=x()>$n',
        ),
      );
      expect(html, isNot(contains('<i onclick')));
    });

    test('semanticLabel and initialValue are escaped in attributes', () async {
      final html = await _body(
        Autocomplete<String>(
          optionsBuilder: (v) => const [],
          semanticLabel: '"><script>alert(3)</script>',
          initialValue: const TextEditingValue(text: '"><script>x</script>'),
        ),
      );
      expect(html, isNot(contains('<script>')));
    });

    test('two on a page get distinct panel ids', () async {
      final html = await _body(
        Column(
          children: [
            Autocomplete<String>(optionsBuilder: (v) => const ['a']),
            Autocomplete<String>(optionsBuilder: (v) => const ['b']),
          ],
        ),
      );
      final ids = RegExp(
        r'<div[^>]* id="([^"]+)"[^>]*popover',
      ).allMatches(html).map((m) => m[1]).toList();
      expect(ids.length, 2, reason: html);
      expect(ids.toSet().length, 2);
    });

    test('panel has listbox role, popover manual, options have role', () async {
      final html = await _body(
        Autocomplete<String>(optionsBuilder: (v) => const ['a', 'b']),
      );
      expect(html, contains('role="listbox"'));
      expect(html, contains('popover="manual"'));
      expect(RegExp('role="option"').allMatches(html).length, 2);
    });
  });

  group('Link around ClipRRect > Image', () {
    test('href stays on <a>, src/alt on <img>', () async {
      final html = await _body(
        Link(
          href: const RouteUrl('/x'),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: const Image.network(
              '/a.png',
              width: 10,
              height: 10,
              semanticLabel: 'A "cat"',
            ),
          ),
        ),
      );
      final a = RegExp('<a[^>]*>').firstMatch(html)![0]!;
      final img = RegExp('<img[^>]*>').firstMatch(html)![0]!;
      expect(a, contains('href="/x"'));
      expect(a, isNot(contains('src=')));
      expect(a, isNot(contains('alt=')));
      expect(a, isNot(contains('loading=')));
      expect(img, contains('src="/a.png"'));
      expect(img, contains('alt='));
      expect(img, isNot(contains('href=')));
    });

    test('a wrapper mixing media and link attributes splits them', () async {
      final html = await _body(
        const Link(
          href: RouteUrl('/x'),
          child: WrapWith(
            WrapData(
              attributes: {
                'srcset': '/a.png 1x, /b.png 2x',
                'sizes': '100vw',
                'width': '33',
                'aria-describedby': 'd1',
                'data-x': 'y',
              },
            ),
            child: Image.network('/a.png'),
          ),
        ),
      );
      final a = RegExp('<a[^>]*>').firstMatch(html)![0]!;
      final img = RegExp('<img[^>]*>').firstMatch(html)![0]!;
      for (final k in ['srcset=', 'sizes=', 'width=']) {
        expect(a, isNot(contains(k)), reason: a);
        expect(img, contains(k), reason: img);
      }
      expect(a, contains('aria-describedby="d1"'));
      expect(a, contains('data-x="y"'));
    });

    test('a Link with text only has no src', () async {
      final html = await _body(
        const Link(href: RouteUrl('/x'), child: Text('hi')),
      );
      expect(RegExp('<a[^>]*>').firstMatch(html)![0]!, isNot(contains('src=')));
    });

    test(
      'Opacity > Padding with Semantics label keeps aria-label on <a>',
      () async {
        final html = await _body(
          const Semantics(
            label: 'Go home',
            child: Opacity(
              opacity: .5,
              child: Padding(
                padding: EdgeInsets.all(2),
                child: Link(href: RouteUrl('/h'), child: Text('home')),
              ),
            ),
          ),
        );
        final a = RegExp('<a[^>]*>').firstMatch(html)![0]!;
        expect(a, contains('aria-label="Go home"'));
        expect(a, contains('href="/h"'));
      },
    );
  });

  group('Image loading', () {
    test('dims from a parent SizedBox only: eager', () async {
      final html = await _body(
        const SizedBox(width: 100, height: 100, child: Image.network('/a.png')),
      );
      expect(
        RegExp('<img[^>]*>').firstMatch(html)![0]!,
        isNot(contains('loading="lazy"')),
      );
    });
  });

  group('GridView.extent stretch: false', () {
    test('no children renders without error', () async {
      final html = await _body(
        const GridView.extent(
          maxCrossAxisExtent: 100,
          stretch: false,
          children: [],
        ),
      );
      expect(html, isNotEmpty);
    });

    Future<String> grid(Widget w) => renderDocument(ThorApp(child: w));

    test(
      'with childAspectRatio: fixed tracks, tiles keep their ratio',
      () async {
        final html = await grid(
          const GridView.extent(
            maxCrossAxisExtent: 100,
            stretch: false,
            childAspectRatio: 2,
            crossAxisSpacing: 10,
            children: [Text('a'), Text('b')],
          ),
        );
        expect(
          html,
          contains('repeat(auto-fill, minmax(min(100px, 100%), 100px))'),
        );
        expect(html, contains('aspect-ratio: 2'));
        expect(html, isNot(contains('@container')));
      },
    );

    test('with autoRowHeight: no aspect ratio, fixed tracks', () async {
      final html = await grid(
        const GridView.extent(
          maxCrossAxisExtent: 100,
          stretch: false,
          autoRowHeight: true,
          children: [Text('a')],
        ),
      );
      expect(
        html,
        contains('repeat(auto-fill, minmax(min(100px, 100%), 100px))'),
      );
      expect(html, isNot(contains('aspect-ratio')));
    });
  });
}
