// An attribute aimed at the child element must not migrate to an ancestor
// tag that nests around it.
@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

Widget _prio(Widget child) => WrapWith(
  const WrapData(attributes: {'fetchpriority': 'high'}),
  child: child,
);

Future<String> _body(Widget w) async =>
    bodyOfPage(await renderDocument(ThorApp(child: w)));

String _tag(String html, String name) =>
    RegExp('<$name[^>]*>').firstMatch(html)![0]!;

void main() {
  setUpAll(initializeThorTests);

  for (final (name, build) in <(String, Widget Function(Widget))>[
    ('Opacity', (c) => Opacity(opacity: .5, child: c)),
    ('Padding', (c) => Padding(padding: const EdgeInsets.all(4), child: c)),
    ('Align', (c) => Align(alignment: Alignment.topLeft, child: c)),
    (
      'ClipRRect',
      (c) => ClipRRect(borderRadius: BorderRadius.circular(4), child: c),
    ),
    (
      'Opacity > Padding > ClipRRect',
      (c) => Opacity(
        opacity: .5,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: ClipRRect(child: c),
        ),
      ),
    ),
  ]) {
    test(
      'fetchpriority through Link > $name > Image reaches the <img>',
      () async {
        final html = await _body(
          Link(
            href: const RouteUrl('/p'),
            child: build(_prio(const Image.network(''))),
          ),
        );
        expect(_tag(html, 'a'), isNot(contains('fetchpriority=')));
        expect(_tag(html, 'a'), contains('href="/p"'));
        expect(_tag(html, 'img'), contains('fetchpriority="high"'));
        expect('<a'.allMatches(html), hasLength(1));
        expect('<img'.allMatches(html), hasLength(1));
      },
    );
  }

  test('the Link keeps its own attributes and the image its own', () async {
    final html = await _body(
      const Link(
        href: RouteUrl('/p'),
        label: 'Open',
        newTab: true,
        child: WrapWith(
          WrapData(attributes: {'poster': 'Cover', 'width': '40'}),
          child: Image.network('/x.png'),
        ),
      ),
    );
    final a = _tag(html, 'a');
    expect(a, contains('aria-label="Open"'));
    expect(a, contains('target="_blank"'));
    expect(a, isNot(contains('poster=')));
    expect(a, isNot(contains('width=')));
    expect(_tag(html, 'img'), contains('poster="Cover"'));
  });

  test(
    'without a nesting tag the attributes still fuse into one element',
    () async {
      final html = await _body(
        Padding(
          padding: const EdgeInsets.all(2),
          child: _prio(const Image.network('')),
        ),
      );
      expect('<img'.allMatches(html), hasLength(1));
      expect(_tag(html, 'img'), contains('fetchpriority="high"'));
    },
  );
}
