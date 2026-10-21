// html.link: the icon and preload attributes a document <head> needs.
@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/html.dart' as html;
import 'package:thor_ui/testing.dart';

void main() {
  setUpAll(initializeThorTests);

  test('link writes sizes, media and crossorigin', () async {
    final out = await renderHtml(
      const html.link(
        href: '/apple.png',
        rel: 'apple-touch-icon',
        sizes: '180x180',
        media: '(min-width: 600px)',
        crossOrigin: 'anonymous',
      ),
    );
    expect(out, contains('rel="apple-touch-icon"'));
    expect(out, contains('sizes="180x180"'));
    expect(out, contains('media="(min-width: 600px)"'));
    expect(out, contains('crossorigin="anonymous"'));
  });

  test('absent attributes are not written', () async {
    final out = await renderHtml(const html.link(href: '/a.css', rel: 'x'));
    expect(out, isNot(contains('sizes')));
    expect(out, isNot(contains('crossorigin')));
  });
}
