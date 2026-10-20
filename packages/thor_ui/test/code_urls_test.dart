@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

// A URL attribute that would run code (or load a document that does) is not
// written: `Link(href: userValue)` with `javascript:` was an XSS, the one
// place a string became code. The binding side (`row.attribute`) already
// refused them (protocol.dart); the markup writers did not.
void main() {
  for (final compact in [true, false]) {
    group(compact ? 'compact markup' : 'pretty markup', () {
      setUpAll(() => initializeThorTests(compactHtml: compact));

      const code = <String>[
        'javascript:alert(1)',
        'JaVaScRiPt:alert(1)',
        ' \tjavascript:alert(1)',
        'java\tscript:alert(1)',
        'java\nscript:alert(1)',
        'javascript\r:alert(1)',
        '\n JAVASCRIPT:alert(1)',
        '\u0001javascript:alert(1)',
        'vbscript:msgbox(1)',
        'data:text/html,<script>alert(1)</script>',
      ];

      for (final url in code) {
        test(
          'a Link to ${url.replaceAll(RegExp(r'[\s\x00-\x1f]'), '_')}',
          () async {
            final html = await renderHtml(
              Link(href: RouteUrl(url), child: const Text('go')),
            );
            expect(html, contains('<a '));
            expect(html, isNot(contains('href')));
            expect(html, isNot(contains('alert')));
          },
        );
      }

      test('a code URL in the other URL attributes', () async {
        final html = await renderHtml(
          const Column(
            children: [
              Image.network('javascript:alert(1)', semanticLabel: 'x'),
              Form(action: 'javascript:alert(2)', child: SizedBox()),
            ],
          ),
        );
        expect(html, isNot(contains('javascript')));
      });

      test('what is not code stays: paths, http(s), mail, phone, anchors, '
          'other apps, images as data', () async {
        for (final url in [
          '/about',
          'about?x=1#y',
          '#top',
          '//cdn.example.com/x',
          'https://example.com/a:b',
          'http://example.com',
          'mailto:a@example.com',
          'tel:+5215555555555',
          'sms:+5215555555555',
          'whatsapp://send?text=hi',
          'geo:19.4,-99.1',
          '/a/b:c',
          '?javascript:1',
        ]) {
          final html = await renderHtml(
            Link(href: RouteUrl(url), child: const Text('go')),
          );
          expect(
            html,
            contains('href="${url.replaceAll('&', '&amp;')}"'),
            reason: url,
          );
        }
        // `data:,` is the empty favicon apps use to skip the request; plain
        // text is not a document.
        for (final url in [
          'data:,',
          'data:text/plain,hi',
          'data:image/png;base64,AAAA',
        ]) {
          final html = await renderHtml(
            Link(href: RouteUrl(url), child: const Text('go')),
          );
          expect(html, contains('href="$url"'), reason: url);
        }
        for (final url in [
          'DATA:TEXT/HTML;base64,PHNjcmlwdD4=',
          'data:image/svg+xml,<svg onload=alert(1)>',
          'data:application/xhtml+xml,<x/>',
          'data:text/javascript,alert(1)',
        ]) {
          final html = await renderHtml(
            Link(href: RouteUrl(url), child: const Text('go')),
          );
          expect(html, isNot(contains('href')), reason: url);
        }
        final img = await renderHtml(
          const Image.network(
            'data:image/png;base64,AAAA',
            semanticLabel: 'dot',
          ),
        );
        expect(img, contains('src="data:image/png;base64,AAAA"'));
      });
    });
  }
}
