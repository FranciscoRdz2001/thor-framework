@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_engine/optimize.dart';

void main() {
  test('a variant becomes a patch of the attributes that differ', () {
    final r = optimizeHtml(
      '<body><label class="row" data-tv="t" data-t-on="change:x">'
      '<input class="c" type="checkbox" aria-checked="mixed"><span class="s">Todos</span></label>'
      '<template data-tvt="t" data-i="1"><label class="row" data-t-on="change:x">'
      '<input class="c" type="checkbox" checked><span class="s">Todos</span></label></template></body>',
    );
    expect(r.patched, 1);
    expect(r.html, isNot(contains('<template')), reason: 'no hidden DOM');
    final patch = decodePatch(
      RegExp(r'data-tp-1="([^"]*)"').firstMatch(r.html)![1]!,
    );
    expect(patch, [
      const PatchOp([0], 'aria-checked', null),
      const PatchOp([0], 'checked', ''),
    ]);
  });

  test('texts and escaped values round-trip; bound texts are skipped', () {
    final r = optimizeHtml(
      '<body><button class="a" data-tv="v"><span data-tt="n">3</span><i>off</i></button>'
      '<template data-tvt="v" data-i="1"><button class="b|c;d"><span data-tt="n">3</span><i>on</i></button></template></body>',
    );
    final patch = decodePatch(
      RegExp(r'data-tp-1="([^"]*)"').firstMatch(r.html)![1]!,
    );
    expect(patch, [
      const PatchOp([], 'class', 'b|c;d'),
      const PatchOp([1], '#', 'on'),
    ]);
  });

  test('different structure keeps the full template', () {
    final r = optimizeHtml(
      '<body><div data-tv="v"><b>a</b></div>'
      '<template data-tvt="v" data-i="1"><div><b>a</b><b>b</b></div></template></body>',
    );
    expect(r.patched, 0);
    expect(r.html, contains('<b>b</b></div></template>'));
  });

  test('each element of a state patches from its own templates', () {
    // The same state watched twice: a chevron (patched by thor_ui) and a
    // list (another structure). The list's template is not the chevron's.
    final r = optimizeHtml(
      '<body><i class="a" data-tv="v" data-tp-1="|class|=b"></i>'
      '<p data-tv="v"><i class="a"></i></p>'
      '<template data-tvt="v" data-i="1"><i class="c"></i></template>'
      '<div data-tv="v"><b>a</b></div>'
      '<template data-tvt="v" data-i="0"><div><b>z</b></div></template>'
      '<template data-tvt="v" data-i="1"><div><b>y</b></div></template></body>',
    );
    expect(r.patched, 2, reason: 'the list; the paragraph is another tag');
    expect(r.html, contains('<i class="a" data-tv="v" data-tp-1="|class|=b">'));
    expect(r.html, contains('<p data-tv="v"><i class="a"></i></p><template'));
    expect(r.html, contains('data-tp-0="0|#|=z" data-tp-1="0|#|=y"'));
  });

  test('patchVariants: false leaves the templates thor_ui kept', () {
    final r = optimizeHtml(
      '<body><i data-tv="v">a</i>'
      '<template data-tvt="v" data-i="1"><i>b</i></template></body>',
      patchVariants: false,
    );
    expect(r.patched, 0);
    expect(r.html, contains('<template data-tvt="v" data-i="1"><i>b</i>'));
  });

  test('generated classes get short names everywhere they appear', () {
    final r = optimizeHtml(
      '<html><head><style id="thor-styles">@layer thor.props{.t1abc{a:1}.t2def:hover{b:2}}</style></head>'
      '<body><div class="st-card t1abc"></div><i class="t1abc"></i>'
      '<button class="t2def" data-tv="v"></button>'
      '<template data-tvt="v" data-i="1"><button class="t1abc"></button></template></body></html>',
    );
    expect(r.renamed, 2);
    expect(r.html, contains('.a{a:1}.b:hover{b:2}'));
    expect(r.html, contains('class="st-card a"'), reason: 'app classes kept');
    expect(r.html, contains('<button class="b" data-tv="v"'));
    expect(
      r.html,
      contains('data-tp-1="|class|=a"'),
      reason: 'patches renamed',
    );
  });

  test('short classes rename selectors only, not url() or layer names', () {
    const sheet =
        '<style id="thor-styles">@layer thor.reset,thor.tokens;'
        '@font-face{font-family:X;src:url("/fonts/Inter.ttf")format("truetype")}'
        '@layer thor.tokens{.t1abc{a:1}}</style>';
    final r = optimizeHtml(
      '<html><head>$sheet</head><body><p class="t1abc">x</p></body></html>',
    );
    expect(r.renamed, 1);
    expect(r.html, contains('url("/fonts/Inter.ttf")'));
    expect(r.html, contains('@layer thor.reset,thor.tokens;'));
    expect(r.html, contains('.a{a:1}'));
  });
}
