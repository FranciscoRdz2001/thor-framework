// HtmlWidget: sanitized HTML inside one element, styled by the theme.
// (The sanitizer itself: packages/thor_engine/test/sanitize_test.dart.)
@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

void main() {
  setUpAll(initializeThorTests);

  group('HtmlWidget', () {
    test('renders sanitized HTML inside one element', () async {
      final html = await renderHtml(
        const HtmlWidget(
          '<p onclick=x>Hi <b>there</b></p><script>alert(1)</script>',
        ),
      );
      expect(html, contains('<p>Hi <b>there</b></p>'));
      expect(html, isNot(contains('alert')));
      expect(html, isNot(contains('onclick')));
    });

    test(
      'inline: a span with text-level tags only, safe inside a <p>',
      () async {
        final html = await renderHtml(
          const HtmlWidget(
            '<div><p>One <b>two</b></p><ul><li>three</li></ul></div>'
            '<a href="/x">l</a><br><script>x</script>',
            inline: true,
          ),
        );
        expect(html, contains('<span'));
        expect(html, isNot(contains('<div')));
        expect(html, isNot(contains('<p>')));
        expect(html, isNot(contains('<ul')));
        expect(html, isNot(contains('<li')));
        expect(html, contains('One <b>two</b>'));
        expect(html, contains('three'));
        expect(html, contains('<a href="/x">l</a>'));
        expect(html, isNot(contains('<script')));
      },
    );

    test('inline keeps no block margins in its stylesheet', () async {
      final doc = await renderDocument(
        const ThorApp(child: HtmlWidget('<p>a</p>', inline: true)),
      );
      final css = RegExp(
        r'<style[^>]*>([\s\S]*?)</style>',
      ).allMatches(doc).map((m) => m[1]).join().replaceAll(' ', '');
      expect(css, isNot(contains('blockquote')));
      expect(css, contains('--t-primary'));
    });

    test(
      'styles come from the theme through one class, no inline CSS',
      () async {
        final doc = await renderDocument(
          const ThorApp(
            child: HtmlWidget('<h2>T</h2><p>a</p><a href="/x">l</a>'),
          ),
        );
        expect(doc, isNot(contains('style="')));
        final css = RegExp(
          r'<style[^>]*>([\s\S]*?)</style>',
        ).allMatches(doc).map((m) => m[1]).join().replaceAll(' ', '');
        // Descendant rules, stopped at thor elements.
        expect(css, contains('h2'));
        expect(css, contains('--t-primary'));
      },
    );

    test('policy and linkTarget reach the output', () async {
      final html = await renderHtml(
        const HtmlWidget(
          '<a href="https://a.com">x</a>',
          policy: HtmlPolicy(linkTarget: '_blank'),
        ),
      );
      expect(html, contains('rel="noopener noreferrer"'));
    });

    test('empty input renders an empty element', () async {
      expect(await renderHtml(const HtmlWidget('')), contains('<div'));
    });
  });
}
