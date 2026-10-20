// sanitizeHtml, second round: mutation XSS, URL tricks, DOM clobbering,
// policy overrides, denial of service and idempotency, written from the
// documented promises.
@TestOn('vm')
library;

import 'dart:math';

import 'package:html/dom.dart';
import 'package:html/parser.dart' show parseFragment;
import 'package:test/test.dart';
import 'package:thor_engine/sanitize.dart';

String _clean(String dirty, [HtmlPolicy policy = const HtmlPolicy()]) =>
    sanitizeHtml(dirty, policy: policy);

/// Elements and attributes of [out] as a browser-like parser builds them.
List<Element> _elements(String out) {
  final all = <Element>[];
  void walk(Node n) {
    if (n is Element) all.add(n);
    n.nodes.forEach(walk);
  }

  walk(parseFragment(out));
  return all;
}

const _corpus = <String>[
  '<p>a</p>',
  '<a href="javascript:alert(1)">x</a>',
  '<a href="java&#x09;script:alert(1)">x</a>',
  '<a href="&#106;avascript:alert(1)">x</a>',
  '<a href="javascript&colon;alert(1)">x</a>',
  '<a href="JaVaScRiPt:alert(1)">x</a>',
  '<a href="  javascript:alert(1)">x</a>',
  '<a href="\u0001javascript:alert(1)">x</a>',
  '<a href="jav\u0000ascript:alert(1)">x</a>',
  '<a href="vbscript:x">x</a>',
  '<a href="data:text/html,<script>alert(1)</script>">x</a>',
  '<a title="</p><img src=x onerror=alert(1)>" href="/a">x</a>',
  '<a href="/a" title=\'"><script>alert(1)</script>\'>x</a>',
  '<a href=x><a href=y>z</a></a>',
  '<pre><span>\n\nx</span></pre>',
  '<a href=x><table><tr><td><a href=y>z</a></td></tr></table></a>',
  '<table><tr><td>a</td></tr>text<script>alert(1)</script></table>',
  '<table>foster<tr><td>x</td></tr></table>',
  '<noscript><p title="</noscript><img src=x onerror=alert(1)>"></noscript>',
  '<textarea></textarea><img src=x onerror=alert(1)></textarea>',
  '<title></title><img src=x onerror=alert(1)>',
  '<select><style></select><img src=x onerror=alert(1)></style>',
  '<svg><p><style><a title="</style><img src=x onerror=alert(1)>">',
  '<math><mtext><table><mglyph><style><img src=x onerror=alert(1)>',
  '<form><math><mtext></form><form><mglyph><style></math><img src=x onerror=alert(1)>',
  '<image src=x onerror=alert(1)>',
  '<img src="x" alt="a&quot; onerror=alert(1) x=&quot;">',
  '<img src=`x` alt=``onerror=alert(1)>',
  '<xmp><p title="</xmp><img src=x onerror=alert(1)>">',
  '<listing>\n\n<img src=x onerror=alert(1)></listing>',
  '<pre>\n\nx</pre>',
  '<p>&lt;img src=x onerror=alert(1)&gt;</p>',
  '<p>&amp;lt;b&amp;gt;</p>',
  '<base href="//evil.example/"><a href="x">x</a>',
  '<meta http-equiv="refresh" content="0;url=//evil.example">',
  '<link rel=stylesheet href=//evil.example/x.css>',
  '<p>\u0000<scr\u0000ipt>alert(1)</scr\u0000ipt></p>',
  '<!--><img src=x onerror=alert(1)>-->',
  '<!--[if IE]><img src=x onerror=alert(1)><![endif]-->',
  '<![CDATA[<img src=x onerror=alert(1)>]]>',
  '<p/><br/>x<hr/>',
  '<ul><li>a<ul><li>b</ul></ul>',
  '<p>a<p>b<div>c<p>d',
  '<b><p>x</b>y</p>',
  '<td>a</td><tr><th>b',
  '<col><colgroup><col span=2>',
  '<h1>x</h1><h2>y</h2>',
  '&nbsp;&#160;  a',
  '\u{1F600}<p>\u{1F600}</p>',
];

void main() {
  group('idempotency', () {
    for (final input in _corpus) {
      test(input.replaceAll('\n', r'\n'), () {
        final once = _clean(input);
        expect(_clean(once), once);
      });
    }
    test('with the permissive policy too', () {
      const policy = HtmlPolicy(
        linkTarget: '_blank',
        nofollow: true,
        allowDataImages: true,
      );
      for (final input in _corpus) {
        final once = _clean(input, policy);
        expect(_clean(once, policy), once, reason: input);
      }
    });
  });

  group('forbidden things never survive a re-parse', () {
    const allowed = {...HtmlPolicy.defaultTags};
    for (final input in _corpus) {
      test(input.replaceAll('\n', r'\n'), () {
        final out = _clean(input);
        for (final el in _elements(out)) {
          expect(allowed, contains(el.localName), reason: out);
          expect(el.namespaceUri, 'http://www.w3.org/1999/xhtml');
          for (final k in el.attributes.keys) {
            final name = k.toString();
            expect(name.startsWith('on'), isFalse, reason: out);
            expect(name, isNot(anyOf('style', 'srcdoc', 'id', 'name')));
          }
          for (final k in ['href', 'src']) {
            final v = (el.attributes[k] ?? '')
                .replaceAll(RegExp(r'[\u0000- ]'), '')
                .toLowerCase();
            expect(v.startsWith('javascript:'), isFalse, reason: out);
            expect(v.startsWith('vbscript:'), isFalse, reason: out);
            expect(v.startsWith('data:'), isFalse, reason: out);
          }
        }
      });
    }
  });

  group('output is a fixed point of the parser', () {
    test('a renamed or unwrapped element cannot leave a tree a browser '
        'would rebuild differently', () {
      // <details> is unwrapped and <h1> renamed: a naive walk writes an
      // <h2> inside an <h2>, which a second parse turns into siblings.
      final out = _clean('<h2><details><h1>x</h1></details></h2>');
      expect(out, '<h2></h2><h2>x</h2>');
      expect(_clean(out), out);
    });
    test('seeded fuzz: stable, nothing outside the allowlist', () {
      const frags = [
        '<a href="',
        '<a href=javascript:1>',
        '<img src=x onerror=1>',
        '<p>',
        '</p>',
        '<b>',
        '</b>',
        '<table>',
        '<tr>',
        '<td>',
        '<pre>',
        '\n',
        '<svg>',
        '<math>',
        '<mtext>',
        '<style>',
        '<select>',
        '<textarea>',
        '<noscript>',
        '<title>',
        '<xmp>',
        '<form>',
        '<template>',
        '<desc>',
        '"',
        '>',
        '<',
        '&',
        '&amp;',
        '\u0000',
        '<!--',
        '-->',
        '<li>',
        '<h1>',
        '<h2>',
        '<details>',
        '<image src=x>',
        'x',
        '<a>',
        '</a>',
        '<div>',
      ];
      final r = Random(42);
      for (var i = 0; i < 1500; i++) {
        final src = StringBuffer();
        for (var j = r.nextInt(12) + 1; j > 0; j--) {
          src.write(frags[r.nextInt(frags.length)]);
        }
        final out = _clean(src.toString());
        expect(_clean(out), out, reason: src.toString());
        for (final el in _elements(out)) {
          expect(HtmlPolicy.defaultTags, contains(el.localName), reason: out);
        }
      }
    });
  });

  group('URLs', () {
    String? href(String raw, [HtmlPolicy policy = const HtmlPolicy()]) {
      final out = _clean('<a href="$raw">x</a>', policy);
      return _elements(out).firstOrNull?.attributes['href'];
    }

    test('encoded and cased javascript is refused', () {
      for (final raw in [
        'javascript:alert(1)',
        'JaVaScRiPt:alert(1)',
        '&#106;avascript:alert(1)',
        '&#x6A;avascript:alert(1)',
        'javascript&colon;alert(1)',
        'java&Tab;script:alert(1)',
        'java&NewLine;script:alert(1)',
        '&#9;javascript:alert(1)',
        '&#32;javascript:alert(1)',
        '\u0001javascript:alert(1)',
        'jav\u0000ascript:alert(1)',
        'jav\u000Bascript:alert(1)',
        'javascript :alert(1)',
        ' javascript:alert(1)',
        '﻿javascript:alert(1)',
        'ja​vascript:alert(1)',
        'ıavascript:alert(1)',
        'vbscript:x',
        'data:text/html;base64,PHNjcmlwdD4=',
        'blob:https://x/y',
        'file:///etc/passwd',
        'view-source:https://x',
        'x-javascript:1',
        'javascript:',
      ]) {
        expect(href(raw), isNull, reason: raw);
      }
    });

    test('colon tricks that are relative stay relative', () {
      expect(href('/a:b'), '/a:b');
      expect(href('?x=javascript:1'), '?x=javascript:1');
      expect(href('#javascript:1'), '#javascript:1');
      expect(href('./javascript:1'), './javascript:1');
    });

    test('protocol-relative and backslash forms are plain links', () {
      expect(href('//example.org/x'), '//example.org/x');
    });

    test('very long URLs do not break', () {
      final long = 'a' * 200000;
      expect(href('https://x/$long'), 'https://x/$long');
      expect(href('${'j' * 200000}:x'), isNull);
    });

    test('data images only for img, only raster, only with the flag', () {
      const on = HtmlPolicy(allowDataImages: true);
      const png = 'data:image/png;base64,iVBORw0KGgo=';
      expect(_clean('<img src="$png">'), '');
      expect(_clean('<img src="$png">', on), contains('src="$png"'));
      expect(href(png, on), isNull);
      for (final bad in [
        'data:image/svg+xml;base64,PHN2Zz4=',
        'data:image/svg+xml,<svg onload=alert(1)>',
        'data:image/png;base64,AAAA" onerror="x',
        'data:image/png;base64,AAAA\n<script>',
        'data:image/png,<script>',
        'data:text/html;base64,AAAA',
        'DATA:image/png;charset=x;base64,AAAA',
        'data:image/png;base64,AAAA#<svg>',
      ]) {
        final out = _clean('<img src="${bad.replaceAll('"', '&quot;')}">', on);
        expect(out, isNot(contains('svg')), reason: bad);
        expect(out, isNot(contains('script')), reason: bad);
        expect(out, isNot(contains('onerror=')), reason: bad);
      }
    });

    test('a scheme the policy adds is honoured, nothing else', () {
      const p = HtmlPolicy(schemes: {'https', 'ftp'});
      expect(href('ftp://x/y', p), 'ftp://x/y');
      expect(href('mailto:a@b', p), isNull);
      expect(href('javascript:1', p), isNull);
    });
  });

  group('attributes the policy can never open', () {
    const wide = HtmlPolicy(
      tags: {...HtmlPolicy.defaultTags, 'form', 'input', 'button', 'details'},
      attributes: {
        '*': {
          'style',
          'onclick',
          'onerror',
          'srcdoc',
          'srcset',
          'formaction',
          'ping',
          'target',
          'rel',
          'xlink:href',
          'xmlns',
          'xml:base',
          'href',
          'src',
          'action',
          'poster',
          'data',
          'cite',
          'OnClick',
        },
      },
    );
    test('style, on*, srcdoc survive no override', () {
      final out = _clean(
        '<p style="x:y" onclick="a()" OnClick="a()" onerror=a srcdoc="x" '
        'srcset="a.png 1x" ping="//e" target=_blank rel=opener xlink:href=x '
        'xmlns="x" xml:base="x">t</p>'
        '<a href=/x target=_blank rel="opener" onclick=a()>l</a>',
        wide,
      );
      for (final bad in [
        'style',
        'onclick',
        'onerror',
        'srcdoc',
        'srcset',
        'ping',
        'xlink',
        'xmlns',
        'xml:',
        'opener',
        '_blank',
      ]) {
        expect(out.toLowerCase(), isNot(contains(bad)), reason: out);
      }
    });
    test('url attributes in an override are still checked', () {
      final out = _clean(
        '<p cite="javascript:1" poster="javascript:1" data="javascript:1" '
        'action="javascript:1">t</p><a href="javascript:1" cite=x>a</a>',
        wide,
      );
      expect(out, isNot(contains('javascript')));
    });
    test('script/style/svg stay dropped when named in tags', () {
      const p = HtmlPolicy(
        tags: {'script', 'style', 'svg', 'math', 'iframe', 'template', 'p'},
      );
      expect(
        _clean(
          '<p>a</p><script>alert(1)</script><style>*{}</style>'
          '<svg><desc>b</desc></svg><iframe src=x></iframe>'
          '<template><p>c</p></template>',
          p,
        ),
        '<p>a</p>',
      );
    });
    test('a tag named in a different case does not reopen anything', () {
      const p = HtmlPolicy(tags: {'SCRIPT', 'Script', 'p'});
      expect(_clean('<script>alert(1)</script><p>x</p>', p), '<p>x</p>');
    });
    test('linkTarget replaces the author target and rel', () {
      const p = HtmlPolicy(linkTarget: '_blank', nofollow: true);
      final out = _clean(
        '<a href="/x" target="_self" rel="opener me">l</a>',
        p,
      );
      expect(out, contains('target="_blank"'));
      expect(out, contains('rel="noopener noreferrer nofollow"'));
      expect(out, isNot(contains('opener me')));
    });
  });

  group('DOM clobbering', () {
    test('id and name are dropped by default', () {
      final out = _clean(
        '<a id=__proto__ name=x href=/a>a</a><img name=getElementById id=x src=/i>'
        '<form id=cookie><input name=cookie></form><p id=body>t</p>',
      );
      expect(out, isNot(contains('id=')));
      expect(out, isNot(contains('name=')));
    });
    test('and an override cannot reopen them', () {
      const p = HtmlPolicy(
        tags: {...HtmlPolicy.defaultTags, 'form', 'input'},
        attributes: {
          '*': {'id', 'name', 'form'},
        },
      );
      final out = _clean(
        '<a id=__proto__ name=x href=/a>a</a><img name=getElementById src=/i>'
        '<form id=cookie><input name=cookie></form><p id=body>t</p>',
        p,
      );
      expect(out, isNot(contains('id=')));
      expect(out, isNot(contains('name=')));
    });
    test('class is not a way in either: only plain tokens, when allowed', () {
      const p = HtmlPolicy(
        attributes: {
          '*': {'class'},
        },
      );
      final out = _clean(
        '<p class="a b&quot; onclick=x c<d e\u0000f ok">t</p>',
        p,
      );
      final cls = _elements(out).first.attributes['class'];
      expect(cls, isNot(contains('"')));
      expect(cls, isNot(contains('<')));
    });
    test('class tokens never collide with generated ones', () {
      const p = HtmlPolicy(
        attributes: {
          '*': {'class'},
        },
      );
      final out = _clean('<p class="t0 _a a1 hidden">t</p>', p);
      // Every token is prefixed: the page's own classes are out of reach.
      expect(_elements(out).first.attributes['class'], isNotNull);
      for (final tok in _elements(out).first.attributes['class']!.split(' ')) {
        expect(tok, startsWith('user-'));
      }
    });
  });

  group('serializer', () {
    test('text with quotes, angle brackets and ampersands round-trips', () {
      const text = 'a "q" \'s\' < > & &amp; &lt;';
      final out = _clean(
        '<p>${text.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;')}</p>',
      );
      expect(parseFragment(out).text, text);
    });
    test('attribute values with every special char round-trip', () {
      const v = '"\'<>&amp;`=\n\t x';
      final out = _clean(
        '<a href="/p" title="${v.replaceAll('&', '&amp;').replaceAll('"', '&quot;')}">t</a>',
      );
      expect(_elements(out).first.attributes['title'], v);
    });
    test('no double encoding: &amp;amp; stays one level', () {
      expect(_clean('<p>&amp;amp;</p>'), '<p>&amp;amp;</p>');
      expect(_clean('<p>&amp;</p>'), '<p>&amp;</p>');
      expect(
        _clean('<a href="/a?x=1&amp;y=2">t</a>'),
        '<a href="/a?x=1&amp;y=2">t</a>',
      );
    });
    test('raw-text elements are dropped whole, text stays out of markup', () {
      for (final tag in [
        'textarea',
        'title',
        'xmp',
        'noscript',
        'noembed',
        'noframes',
        'plaintext',
        'style',
        'script',
        'iframe',
      ]) {
        final out = _clean('<$tag><img src=x onerror=alert(1)></$tag><p>k</p>');
        expect(out, isNot(contains('onerror')), reason: tag);
        expect(out, isNot(contains('<img')), reason: tag);
      }
    });
    test('pre keeps its leading newlines through a second pass', () {
      final once = _clean('<pre>\n\nx</pre>');
      expect(_clean(once), once);
      expect(parseFragment(once).text, '\nx');
    });
  });

  group('limits', () {
    test('deep nesting under maxTags returns quickly and balanced', () {
      final sw = Stopwatch()..start();
      final out = _clean('${'<div>' * 3000}x${'</div>' * 3000}');
      expect(sw.elapsed, lessThan(const Duration(seconds: 10)));
      expect('<div>'.allMatches(out).length, '</div>'.allMatches(out).length);
    });
    test('nested inline formatting (adoption agency) is bounded', () {
      final sw = Stopwatch()..start();
      _clean('<b><i><p>' * 3000);
      expect(sw.elapsed, lessThan(const Duration(seconds: 10)));
    });
    test('a million attributes', () {
      final sw = Stopwatch()..start();
      final out = _clean(
        '<p ${List.generate(100000, (i) => 'a$i=x').join(' ')}>t</p>',
      );
      expect(out, '<p>t</p>');
      expect(sw.elapsed, lessThan(const Duration(seconds: 10)));
    });
    test('many duplicate attributes', () {
      final out = _clean(
        '<a href="/a" ${'href="javascript:1" ' * 50000}>t</a>',
      );
      expect(out, contains('href="/a"'));
    });
    test('entity floods stay linear', () {
      final sw = Stopwatch()..start();
      final out = _clean('<p>${'&amp;' * 200000}</p>');
      expect(out.length, 5 * 200000 + 7);
      expect(sw.elapsed, lessThan(const Duration(seconds: 10)));
    });
    test('quadratic text: unclosed tags and many <', () {
      final sw = Stopwatch()..start();
      _clean('<' * 9000);
      _clean('<a ' * 9000);
      _clean('<!--' * 9000);
      _clean('&#' * 100000);
      _clean('<p title="' * 5000);
      expect(sw.elapsed, lessThan(const Duration(seconds: 20)));
    });
    test('the cap on tags counts text that only looks like a tag', () {
      final out = _clean('<p>a</p>' * 20000);
      expect('<p>'.allMatches(out).length, lessThanOrEqualTo(10000));
    });
    test('table nesting and foster parenting are bounded', () {
      final sw = Stopwatch()..start();
      _clean('<table><tr><td>' * 3000);
      _clean('<table>x<b>' * 3000);
      expect(sw.elapsed, lessThan(const Duration(seconds: 20)));
    });
    test('maxDepth drops, never leaves open tags', () {
      const p = HtmlPolicy(maxDepth: 5);
      final out = _clean('${'<div>' * 20}x${'</div>' * 20}', p);
      expect('<div>'.allMatches(out).length, '</div>'.allMatches(out).length);
    });
    test('empty and degenerate inputs', () {
      expect(_clean(''), '');
      expect(_clean('\u0000'), '');
      expect(_clean('<'), '&lt;');
      expect(_clean('<>'), '&lt;&gt;');
      expect(_clean('</'), '&lt;/');
      expect(_clean('</p>'), '<p></p>'); // the spec's own quirk
      expect(_clean('<p'), '');
    });
  });
}
