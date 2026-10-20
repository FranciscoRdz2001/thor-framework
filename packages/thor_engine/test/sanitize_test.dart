// sanitizeHtml: untrusted HTML (a CMS body, a catalog
// description) becomes safe markup. Cases follow the OWASP XSS filter
// evasion cheat sheet and DOMPurify/bluemonday regressions.
@TestOn('vm')
library;

import 'package:html/dom.dart';
import 'package:html/parser.dart' show parseFragment;
import 'package:test/test.dart';
import 'package:thor_engine/sanitize.dart';

/// Whether [out], parsed again, holds anything that can run code: the
/// oracle reads the markup a browser would build, so escaped text that
/// merely looks like a tag is not a hit.
bool _active(String out) {
  bool walk(Node n) {
    if (n is Element) {
      if (!const {...HtmlPolicy.defaultTags, 'h1'}.contains(n.localName)) {
        return true;
      }
      for (final MapEntry(:key, :value) in n.attributes.entries) {
        final name = key.toString();
        if (name.startsWith('on') || name == 'style' || name == 'srcdoc') {
          return true;
        }
        if (name == 'href' || name == 'src') {
          final v = value
              .replaceAll(RegExp(r'[\u0000-\u0020]'), '')
              .toLowerCase();
          if (v.startsWith('javascript:') ||
              v.startsWith('vbscript:') ||
              v.startsWith('data:text')) {
            return true;
          }
        }
      }
    }
    return n.nodes.any(walk);
  }

  return walk(parseFragment(out));
}

final isActive = predicate<String>(_active, 'runs code');

String _clean(String dirty, [HtmlPolicy policy = const HtmlPolicy()]) =>
    sanitizeHtml(dirty, policy: policy);

void main() {
  group('allowlist', () {
    test('keeps the formatting a description needs', () {
      const html =
          '<p>One <strong>two</strong> <em>three</em><br>four</p>'
          '<ul><li>a</li><li>b</li></ul><h2>Title</h2>'
          '<table><thead><tr><th>A</th></tr></thead>'
          '<tbody><tr><td colspan="2">1</td></tr></tbody></table>';
      expect(_clean(html), html);
    });

    test('unknown tags are unwrapped, their text stays', () {
      expect(
        _clean('<section><u>hi</u> <font color=red>x</font></section>'),
        '<u>hi</u> x',
      );
    });

    test('h1 becomes h2 (the page owns the h1)', () {
      expect(_clean('<h1>T</h1>'), '<h2>T</h2>');
    });

    test('entities are normalized and text is escaped', () {
      expect(
        _clean('a &amp; b &lt;i&gt; &copy; <3 > 2'),
        'a &amp; b &lt;i&gt; © &lt;3 &gt; 2',
      );
      expect(
        _clean('&lt;script&gt;alert(1)&lt;/script&gt;'),
        '&lt;script&gt;alert(1)&lt;/script&gt;',
      );
    });

    test('empty, whitespace and non-html input', () {
      expect(_clean(''), '');
      expect(_clean('   '), '   ');
      expect(_clean('plain'), 'plain');
    });

    test('is idempotent', () {
      const dirty =
          '<p onclick=x>a<img src=x onerror=y><a href="http://a/?q=1&b=2">l</a>'
          '<table><tr><td>1</table>';
      final once = _clean(dirty);
      expect(_clean(once), once);
    });
  });

  group('script-bearing elements are dropped with their content', () {
    for (final dirty in [
      '<script>alert(1)</script>',
      '<SCRIPT SRC=//evil/x.js></SCRIPT>',
      '<script/xss src=//evil/x.js>',
      '<<script>alert(1)//<</script>',
      '<style>body{background:url(javascript:alert(1))}</style>',
      '<iframe src="javascript:alert(1)"></iframe>',
      '<iframe srcdoc="<script>alert(1)</script>">',
      '<object data="javascript:alert(1)"></object>',
      '<embed src="x.swf">',
      '<svg onload=alert(1)>',
      '<svg><script>alert(1)</script></svg>',
      '<svg><style><img src=x onerror=alert(1)></style></svg>',
      '<math><mi xlink:href="javascript:alert(1)">x</mi></math>',
      '<math><mtext><table><mglyph><style><img src=x onerror=alert(1)>',
      '<form action="javascript:alert(1)"><input name=x></form>',
      '<link rel=stylesheet href="javascript:alert(1)">',
      '<meta http-equiv="refresh" content="0;url=javascript:alert(1)">',
      '<base href="javascript:alert(1)//">',
      '<template><script>alert(1)</script></template>',
      '<noscript><p title="</noscript><img src=x onerror=alert(1)>">',
      '<xmp><img src=x onerror=alert(1)></xmp>',
      '<plaintext><img src=x onerror=alert(1)>',
      '<textarea></textarea><img src=x onerror=alert(1)>',
      '<title></title><img src=x onerror=alert(1)>',
      '<noembed><img src=x onerror=alert(1)></noembed>',
      '<noframes><img src=x onerror=alert(1)></noframes>',
      '<!--><script>alert(1)</script>-->',
      '<!-- <img src=x onerror=alert(1)> -->',
      '<!DOCTYPE html><script>alert(1)</script>',
    ]) {
      test(dirty, () {
        final out = _clean(dirty);
        expect(out, isNot(isActive), reason: out);
        expect(
          out,
          isNot(contains('alert')),
          reason: 'dropped content must not leak as text: $out',
        );
      });
    }
  });

  group('event handlers and style', () {
    test('on* attributes in every form are removed', () {
      for (final dirty in [
        '<img src=x onerror=alert(1)>',
        '<img src=x ONERROR="alert(1)">',
        "<img src=x onerror='alert(1)'>",
        '<img src=x onerror = alert(1) >',
        '<img/src=x/onerror=alert(1)>',
        '<img src=x onerror=alert(1)//',
        '<p onmouseover=alert(1)>a</p>',
        '<a href="/x" onclick="alert(1)">a</a>',
        '<img src="x" `onerror=alert(1)`>',
        '<img src=x\fonerror=alert(1)>',
        '<img """><script>alert(1)</script>">',
        '<body onload=alert(1)>',
        '<details open ontoggle=alert(1)>',
        '<video><source onerror=alert(1)>',
        '<a href="/" onfocus=alert(1) autofocus>a</a>',
      ]) {
        final out = _clean(dirty);
        expect(out, isNot(isActive), reason: '$dirty -> $out');
      }
    });

    test('style attributes are removed (no CSS strings, no expression())', () {
      final out = _clean(
        '<p style="background:url(javascript:alert(1))">a</p>',
      );
      expect(out, '<p>a</p>');
      expect(_clean('<p style="width:expression(alert(1))">a</p>'), '<p>a</p>');
    });

    test('a policy cannot allow on*, style, srcdoc or script', () {
      const loose = HtmlPolicy(
        tags: {'p', 'img', 'script', 'iframe', 'style'},
        attributes: {
          '*': {'onclick', 'style', 'srcdoc'},
          'img': {'src', 'onerror'},
        },
      );
      final out = _clean(
        '<p onclick=a style="x:y" srcdoc=z>q</p>'
        '<img src="/a.png" onerror=b><script>alert(1)</script><iframe src=x></iframe>',
        loose,
      );
      expect(out, isNot(isActive), reason: out);
      expect(out, contains('<img'));
    });
  });

  group('URLs', () {
    String href(String url) => _clean('<a href="$url">x</a>');

    test('safe schemes and relative URLs pass', () {
      for (final url in [
        'http://a.com/p?q=1&r=2',
        'https://a.com',
        'HTTPS://A.COM',
        'mailto:a@b.co',
        'tel:+5255',
        '/path/x',
        'rel/x',
        '../x',
        '#anchor',
        '?q=1',
        '//cdn.example.com/x',
        '/a:b',
        'a/b:c',
      ]) {
        expect(href(url), contains('href='), reason: url);
      }
    });

    test('javascript: in every disguise is removed', () {
      for (final url in [
        'javascript:alert(1)',
        'JaVaScRiPt:alert(1)',
        ' javascript:alert(1)',
        '\tjavascript:alert(1)',
        'java\tscript:alert(1)',
        'java\nscript:alert(1)',
        'java\rscript:alert(1)',
        'java&#x09;script:alert(1)',
        'java&#x0A;script:alert(1)',
        'java&#9;script:alert(1)',
        '&#106;avascript:alert(1)',
        '&#x6A;&#x61;&#x76;&#x61;&#x73;&#x63;&#x72;&#x69;&#x70;&#x74;:alert(1)',
        '&#0000106&#0000097&#0000118&#0000097&#0000115&#0000099&#0000114&#0000105&#0000112&#0000116&#0000058alert(1)',
        'javascript&colon;alert(1)',
        'javascript&#58;alert(1)',
        '&#x1;javascript:alert(1)',
        '\u0001javascript:alert(1)',
        '\u0000javascript:alert(1)',
        'jav\u0000ascript:alert(1)',
        'javascript\u0000:alert(1)',
        ' javascript:alert(1)',
        ' javascript:alert(1)',
        'vbscript:msgbox(1)',
        'data:text/html,<script>alert(1)</script>',
        'data:text/html;base64,PHNjcmlwdD5hbGVydCgxKTwvc2NyaXB0Pg==',
        'data:image/svg+xml,<svg onload=alert(1)>',
        'file:///etc/passwd',
        'blob:https://a.com/x',
        'view-source:https://a.com',
        'ftp://a.com/x',
        'x:y',
      ]) {
        final out = href(url);
        expect(out, 'x', reason: '$url -> $out');
      }
    });

    test('the emitted URL is the one a browser would read', () {
      // Tabs and newlines inside a URL are ignored by browsers: the output
      // has them removed, so the check and the browser agree.
      expect(href('ht\ttp://a.com/x\ny'), contains('href="http://a.com/xy"'));
      expect(href('  /x  '), contains('href="/x"'));
    });

    test('attribute breakouts stay inside the quotes', () {
      final out = _clean('<a href=\'/x" onmouseover="alert(1)\'>x</a>');
      expect(out, isNot(isActive), reason: out);
      expect(out, contains('&quot;'));
      final unquoted = _clean('<a href=/x onmouseover=alert(1)>x</a>');
      expect(unquoted, isNot(isActive), reason: unquoted);
    });

    test('attribute values are escaped, < and > included', () {
      final out = _clean(
        '<a href="/x" title="</a><img src=x onerror=alert(1)>">x</a>',
      );
      expect(out, isNot(contains('<img')), reason: out);
      expect(out, contains('title="&lt;/a&gt;'));
    });

    test('img: src is checked, srcset and unknown attrs dropped', () {
      expect(_clean('<img src="javascript:alert(1)" alt="a">'), '');
      expect(
        _clean('<img src="/p.png" alt="a" srcset="javascript:alert(1) 1x">'),
        '<img src="/p.png" alt="a" loading="lazy" decoding="async">',
      );
      expect(_clean('<img>'), '');
      expect(_clean('<img src="data:image/png;base64,AAAA">'), '');
    });

    test('eagerImages: the first images load with the page', () {
      const policy = HtmlPolicy(eagerImages: 1);
      expect(
        _clean('<p><img src="/a.png"></p><img src="/b.png">', policy),
        '<p><img src="/a.png"></p>'
        '<img src="/b.png" loading="lazy" decoding="async">',
      );
      // A dropped image does not use up the count.
      expect(
        _clean('<img src="javascript:x"><img src="/b.png">', policy),
        '<img src="/b.png">',
      );
    });

    test('data:image is opt-in, never svg, never other types', () {
      const policy = HtmlPolicy(allowDataImages: true);
      expect(
        _clean('<img src="data:image/png;base64,AAAA">', policy),
        contains('data:image/png;base64,AAAA'),
      );
      expect(_clean('<img src="data:image/svg+xml;base64,AAAA">', policy), '');
      expect(_clean('<img src="data:text/html;base64,AAAA">', policy), '');
      expect(_clean('<a href="data:image/png;base64,AAAA">x</a>', policy), 'x');
    });
  });

  group('links', () {
    test('target and rel come from the policy, not from the author', () {
      expect(
        _clean('<a href="/x" target="_blank" rel="opener">x</a>'),
        '<a href="/x">x</a>',
      );
      expect(
        _clean(
          '<a href="https://a.com" target="_top">x</a>',
          const HtmlPolicy(linkTarget: '_blank'),
        ),
        '<a href="https://a.com" target="_blank" rel="noopener noreferrer">x</a>',
      );
      expect(
        _clean(
          '<a href="/x">x</a>',
          const HtmlPolicy(linkTarget: '_blank', nofollow: true),
        ),
        '<a href="/x" target="_blank" rel="noopener noreferrer nofollow">x</a>',
      );
      expect(
        _clean('<a href="/x">x</a>', const HtmlPolicy(nofollow: true)),
        '<a href="/x" rel="nofollow">x</a>',
      );
    });

    test('an invalid linkTarget is rejected', () {
      expect(() => HtmlPolicy(linkTarget: 'evil"x'), throwsA(anything));
    });

    test(
      'a policy that allows target/rel still cannot let the author set them',
      () {
        final out = _clean(
          '<a href="/x" target="_blank" rel="opener">x</a>',
          const HtmlPolicy(
            attributes: {
              'a': {'href', 'target', 'rel'},
            },
          ),
        );
        expect(out, '<a href="/x">x</a>');
      },
    );
  });

  group('malformed and mutation inputs', () {
    test(
      'unclosed, nested and misnested tags are repaired by the HTML parser',
      () {
        expect(_clean('<p><b>a<i>b</b>c</i>d'), isNot(contains('<script')));
        expect(_clean('<b><b><b>x'), '<b><b><b>x</b></b></b>');
        expect(_clean('<p>a<p>b'), '<p>a</p><p>b</p>');
        expect(
          _clean('<scr<script>ipt>alert(1)</scr</script>ipt>'),
          isNot(isActive),
        );
        expect(_clean('<<img src=x onerror=alert(1)>'), isNot(isActive));
        expect(_clean('<img src=x onerror=alert(1)'), isNot(isActive));
        expect(_clean('<a href="/x'), isNot(isActive));
      },
    );

    test('table foster parenting cannot smuggle markup out', () {
      for (final dirty in [
        '<table><script>alert(1)</script><tr><td>x</td></tr></table>',
        '<table><style><img src=x onerror=alert(1)></style></table>',
        '<table><img src=x onerror=alert(1)><td>x',
        '<table><svg><desc><img src=x onerror=alert(1)></desc></svg></table>',
      ]) {
        final out = _clean(dirty);
        expect(out, isNot(isActive), reason: out);
        expect(out, isNot(contains('alert')), reason: out);
      }
    });

    test('output reparsed and cleaned again does not change (mXSS guard)', () {
      for (final dirty in [
        '<svg></p><style><a title="</style><img src onerror=alert(1)>">',
        '<math><mtext></p><style></style><img src onerror=alert(1)>',
        '<form><math><mtext></form><form><mglyph><style></math><img src onerror=alert(1)>',
        '<p><svg><desc><p></svg></p><img src onerror=alert(1)>',
        '<noscript><p title="</noscript><img src=x onerror=alert(1)>">',
        '<listing>&lt;img src=x onerror=alert(1)&gt;</listing>',
        '<pre>\n<img src=x onerror=alert(1)></pre>',
        '<a href="/x"><a href="/y">x</a></a>',
      ]) {
        final out = _clean(dirty);
        expect(out, isNot(isActive), reason: out);
        expect(_clean(out), out, reason: dirty);
      }
    });

    test('CDATA and processing instructions are comments in HTML', () {
      for (final dirty in [
        '<![CDATA[<script>alert(1)</script>]]>',
        '<? <script>alert(1)</script> ?>',
      ]) {
        final out = _clean(dirty);
        expect(out, isNot(isActive), reason: out);
        expect(_clean(out), out);
      }
    });

    test('unicode and null bytes', () {
      expect(_clean('<p>héllo \u{1F600} ñ</p>'), '<p>héllo \u{1F600} ñ</p>');
      expect(_clean('<sc\u0000ript>alert(1)</sc\u0000ript>'), isNot(isActive));
      expect(_clean('<p>a\u0000b</p>'), isNot(contains('\u0000')));
      expect(_clean('<p>\u202e</p>'), contains('<p>'));
    });

    test('very deep nesting is cut, not a crash', () {
      final deep = '${'<div>' * 50000}x${'</div>' * 50000}';
      final out = _clean(deep);
      expect(out.length, lessThan(deep.length));
      final bomb = '<div>' * 200000;
      final clock = Stopwatch()..start();
      _clean(bomb);
      expect(clock.elapsedMilliseconds, lessThan(10000));
      final deepB = '<b>' * 50000 + 'x';
      expect(_clean(deepB, const HtmlPolicy(maxDepth: 10)), contains('<b>'));
    });

    test('input over maxTags is cut before the extra tag', () {
      final out = _clean('<p>a</p>' * 10, const HtmlPolicy(maxTags: 6));
      expect(out, '<p>a</p><p>a</p><p>a</p>');
    });

    test('input over maxLength is truncated', () {
      final big = '<p>${'a' * 5000}</p>';
      expect(
        _clean(big, const HtmlPolicy(maxLength: 100)).length,
        lessThan(200),
      );
    });

    test('a hostile attribute count and length stay linear', () {
      final attrs = List.generate(5000, (i) => 'a$i=x').join(' ');
      final out = _clean('<p $attrs>y</p>');
      expect(out, '<p>y</p>');
    });
  });

  group('policy', () {
    test('tags and attributes can be narrowed or widened', () {
      const narrow = HtmlPolicy(tags: {'p', 'a'});
      expect(_clean('<p><strong>a</strong></p>', narrow), '<p>a</p>');
      const wide = HtmlPolicy(
        tags: {'p', 'span'},
        attributes: {
          'span': {'class', 'title'},
        },
      );
      expect(
        _clean('<span class="a b" title="t" id="x">q</span>', wide),
        '<span class="user-a user-b" title="t">q</span>',
      );
      expect(
        _clean('<span class="a&quot; onclick=&quot;x">q</span>', wide),
        isNot(isActive),
      );
    });

    test('copyWith keeps the rest', () {
      final p = const HtmlPolicy(nofollow: true).copyWith(linkTarget: '_blank');
      expect(p.nofollow, isTrue);
      expect(p.linkTarget, '_blank');
    });
  });
}
