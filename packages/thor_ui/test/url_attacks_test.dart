@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/web.dart';

// The adversarial side of code_urls_test: every attribute that holds a URL
// (raw elements take any attribute name), every disguise a browser reads
// through, and the values that must stay untouched. The reference is
// DOMPurify's URI policy (src/regexp.ts: IS_ALLOWED_URI, IS_SCRIPT_OR_DATA),
// which refuses `*script:` and `data:` outside media elements; thor's is a
// denylist of what runs (apps link to `whatsapp:`, `intent:`), so every
// scheme DOMPurify refuses for being code is refused here too.
void main() {
  for (final compact in [true, false]) {
    group(compact ? 'compact markup' : 'pretty markup', () {
      setUpAll(() => initializeThorTests(compactHtml: compact));

      Future<String> raw(String name, String value) => renderHtml(
        Box(attributes: {name: value}, children: const [Text('x')]),
      );

      const attributes = [
        'href',
        'src',
        'action',
        'formaction',
        'xlink:href',
        'poster',
        'cite',
        'data',
        'background',
        'longdesc',
        'xLink:Href',
      ];
      const payloads = [
        'javascript:alert(1)',
        'JaVaScRiPt:alert(1)',
        '\u0001javascript:alert(1)',
        '\u001f\u0000 javascript:alert(1)',
        '  \n\r\t javascript:alert(1)',
        'jav\tascr\nipt\r:alert(1)',
        'vbscript:msgbox(1)',
        'VBScript:x',
        'data:text/html,<script>alert(1)</script>',
        'data:text/html;base64,PHNjcmlwdD5hbGVydCgxKTwvc2NyaXB0Pg==',
        'DATA:Text/HTML;charset=utf-8,<b>',
        'data:image/svg+xml;utf8,<svg onload=alert(1)>',
        'data:image/svg+xml;base64,PHN2Zz4=',
        'data:application/xhtml+xml,<x/>',
        'data:text/xml,<x/>',
        'data:application/xml,<x/>',
        'data:application/mathml+xml,<math/>',
        'data:application/vnd.wap.xhtml+xml,<x/>',
        'data:text/javascript,alert(1)',
        'data:application/ecmascript,alert(1)',
        'data:text/ecmascript,alert(1)',
        'data:text/jscript,alert(1)',
        'data:text/x-javascript,alert(1)',
        'data:application/x-ecmascript,alert(1)',
        'data:text/vbscript,x',
        'data: text/html,<b>',
        'data:\ttext/html,<b>',
      ];

      test('code in any URL attribute is not written', () async {
        final leaks = <String>[];
        for (final a in attributes) {
          for (final p in payloads) {
            final html = await raw(a, p);
            if (html.toLowerCase().contains('${a.toLowerCase()}=')) {
              leaks.add('$a=${p.replaceAll(RegExp(r'[\x00-\x1f]'), '?')}');
            }
          }
        }
        expect(leaks, isEmpty);
      });

      test('an entity or an escape is text, not a scheme', () async {
        // The writer escapes `&`: the browser reads `&amp;#106;`, a literal
        // `&#106;avascript:` path, which is relative.
        final html = await raw('href', '&#106;avascript:alert(1)');
        expect(html, contains('href="&amp;#106;avascript:alert(1)"'));
        // A JavaScript escape is not a URL escape either.
        final esc = await raw(
          'href',
          '\\'
              'u006aavascript:alert(1)',
        );
        expect(esc, contains('href="\\u006aavascript:alert(1)"'));
      });

      test('what is not a URL or not code is left alone', () async {
        for (final (name, value) in const [
          ('srcset', 'a.png 1x, b.png 2x'),
          ('ping', '/track'),
          ('data-url', 'javascript:alert(1)'),
          ('title', 'javascript:alert(1)'),
          ('alt', 'data:text/html,x'),
          ('href', '/a?next=javascript:alert(1)'),
          ('href', 'a/javascript:alert(1)'),
          ('href', 'java script:alert(1)'),
          ('href', 'javascript.alert(1)'),
          ('href', 'xjavascript:alert(1)'),
          ('href', 'data-x:text/html,x'),
          ('href', 'about:blank'),
          ('src', 'data:image/gif;base64,R0lGOD'),
          ('src', 'data:audio/mpeg;base64,AAAA'),
          ('src', 'data:font/woff2;base64,AAAA'),
          ('src', 'data:application/pdf;base64,AAAA'),
          ('src', 'data:application/json,{}'),
          ('src', 'data:application/octet-stream;base64,AAAA'),
          ('src', 'data:;base64,AAAA'),
          ('src', 'blob:https://example.com/uuid'),
        ]) {
          final html = await raw(name, value);
          expect(
            html,
            contains('$name="${value.replaceAll('&', '&amp;')}"'),
            reason: '$name=$value',
          );
        }
      });

      test('an empty value or a bare name still renders', () async {
        final html = await raw('href', '');
        expect(html, contains('href'));
      });
    });
  }
}
