@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:thor_engine/fingerprint.dart';
import 'package:thor_engine/optimize.dart';
import 'package:thor_engine/shared_styles.dart';
import 'package:thor_engine/src/markup.dart';

const _table =
    '<table class="t1abc"><tbody data-tl="rows" class="t2def">'
    '<template data-tlt><tr class="t1abc"><td class="t2def">x</td></tr></template>'
    '<tr><td>1</td></tr></tbody></table>';

const _sheet =
    '<style id="thor-styles">@layer thor.props{.t1abc{a:1}.t2def{b:2}}</style>';

void main() {
  group('the optimizer never restructures markup', () {
    test('a list template stays inside its tbody', () {
      final r = optimizeHtml(
        '<html><head>$_sheet</head><body>$_table</body></html>',
      );
      expect(r.renamed, 2);
      expect(
        r.html,
        contains(
          '<tbody data-tl="rows" class="b"><template data-tlt>'
          '<tr class="a"><td class="b">x</td></tr></template><tr><td>1</td></tr></tbody>',
        ),
      );
      expect(r.html, startsWith('<html><head>'));
    });

    test('nothing is added: no tbody, no html/head/body', () {
      const src =
          '<table><tr><template data-tlt><tr><td>x</td></tr></template></tr></table>';
      final r = optimizeHtml(src);
      expect(r.html, src);
    });

    test('void elements lose their XHTML slash, svg ones keep it', () {
      const src =
          '<body><br/><img src="a.png" /><svg><path d="M0"/></svg></body>';
      expect(
        optimizeHtml(src).html,
        '<body><br><img src="a.png"><svg><path d="M0"/></svg></body>',
      );
    });

    test('a select keeps its template and the doctype stays as written', () {
      const src =
          '<!doctype html><select data-tl="o"><template data-tlt><option>a</option></template>'
          '<option>b</option></select>';
      expect(optimizeHtml(src).html, src);
    });

    test('nested templates', () {
      const src =
          '<table><tbody data-tl="a"><template data-tlt><tr><td>'
          '<table><tbody data-tl="b"><template data-tlt><tr><td>i</td></tr></template></tbody></table>'
          '</td></tr></template></tbody></table>';
      expect(optimizeHtml(src).html, src);
      final doc = MarkupDoc(src);
      final templates = doc.all.where((e) => e.name == 'template').toList();
      expect(templates, hasLength(2));
      expect(templates[0].parent!.name, 'tbody');
      expect(templates[1].parent!.name, 'tbody');
      expect(templates[1].parent!.parent!.parent!.name, 'td');
    });

    test('variant templates inside a table still become patches', () {
      final r = optimizeHtml(
        '<table><tbody><tr data-tv="v" class="a"><td>x</td></tr>'
        '<template data-tvt="v" data-i="1"><tr class="b"><td>x</td></tr></template>'
        '</tbody></table>',
      );
      expect(r.patched, 1);
      expect(
        r.html,
        contains('<tr data-tv="v" class="a" data-tp-1="|class|=b">'),
      );
      expect(r.html, isNot(contains('<template')));
      expect(r.html, contains('<table><tbody><tr'));
    });

    test('a variant template inside a list template is kept as written', () {
      const src =
          '<table><tbody data-tl="r"><template data-tlt><tr data-tvf="x"><td>a</td></tr>'
          '<template data-tvft="x" data-tvi="1"><tr><td>b</td></tr></template></template>'
          '</tbody></table>';
      expect(optimizeHtml(src).html, src);
    });

    test('scripts, comments and raw text are not scanned for tags', () {
      const src =
          '<body><!-- <template data-tvt="v"> --><script>var a="<div class=\'t1abc\'>";</script>'
          '<div class="t1abc"></div></body>';
      final r = optimizeHtml(src);
      expect(
        r.html,
        contains('<script>var a="<div class=\'t1abc\'>";</script>'),
      );
    });
  });

  group('fingerprint and shared styles keep the structure', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('thor_markup'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('fingerprintSite leaves a table with a row template intact', () {
      File('${dir.path}/app.js').writeAsStringSync('1');
      final page = File('${dir.path}/index.html')
        ..writeAsStringSync(
          '<!doctype html><html><head></head><body>$_table'
          '<script src="/app.js"></script></body></html>',
        );
      fingerprintSite(dir.path);
      final out = page.readAsStringSync();
      expect(out, contains(_table));
      expect(out, matches(RegExp(r'src="/app\.[0-9a-f]{8}\.js"')));
    });

    test('shareSiteStyles leaves a table with a row template intact', () {
      for (final n in ['a', 'b']) {
        File('${dir.path}/$n.html').writeAsStringSync(
          '<!doctype html><html><head>$_sheet</head><body>$_table</body></html>',
        );
      }
      shareSiteStyles(dir.path);
      final out = File('${dir.path}/a.html').readAsStringSync();
      expect(out, contains('<tbody data-tl="rows"'));
      expect(out, contains('><template data-tlt><tr class='));
      expect(out, contains('</template><tr><td>1</td></tr></tbody>'));
    });
  });
}
