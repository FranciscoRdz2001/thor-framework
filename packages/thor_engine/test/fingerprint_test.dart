@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:thor_engine/fingerprint.dart';

void main() {
  late Directory site;

  setUp(() {
    site = Directory.systemTemp.createTempSync('thor-site-');
    File('${site.path}/engine.dart.js').writeAsStringSync('console.log(1)');
    File('${site.path}/hero.webp').writeAsStringSync('big');
    File('${site.path}/hero-640.webp').writeAsStringSync('small');
    File('${site.path}/favicon.png').writeAsStringSync('ico');
    File('${site.path}/og.jpg').writeAsStringSync('card');
    Directory('${site.path}/fonts').createSync();
    File('${site.path}/fonts/brand.woff2').writeAsStringSync('font');
    File('${site.path}/index.html').writeAsStringSync('''
<!DOCTYPE html>
<html><head>
<link rel="icon" href="favicon.png">
<meta property="og:image" content="og.jpg">
<style>@font-face{font-family:b;src:url("fonts/brand.woff2")}</style>
<link rel="preload" as="script" href="engine.dart.js" fetchpriority="low">
<script data-thor-engine="engine.dart.js">(()=>{})()</script>
</head><body>
<img src="hero.webp" srcset="hero-640.webp 640w, hero.webp 1250w">
<img src="https://cdn.example.com/x.png">
<a href="hero.webp">link to the picture</a>
</body></html>''');
  });

  tearDown(() => site.deleteSync(recursive: true));

  String page() => File('${site.path}/index.html').readAsStringSync();

  test('renames referenced files to content-hashed names and rewrites', () {
    final report = fingerprintSite(site.path);
    final engine = report.renamed['engine.dart.js']!;
    expect(engine, matches(RegExp(r'^engine\.dart\.[0-9a-f]{8}\.js$')));
    expect(File('${site.path}/$engine').existsSync(), isTrue);
    expect(File('${site.path}/engine.dart.js').existsSync(), isFalse);

    final html = page();
    expect(html, contains('data-thor-engine="$engine"'));
    // The engine's preload asks for the same content-hashed file.
    expect(html, contains('<link rel="preload" as="script" href="$engine"'));
    expect(html, isNot(contains('href="engine.dart.js"')));
    final hero = report.renamed['hero.webp']!;
    final small = report.renamed['hero-640.webp']!;
    expect(html, contains('src="$hero"'));
    expect(html, contains('srcset="$small 640w, $hero 1250w"'));
    expect(html, contains('url("${report.renamed['fonts/brand.woff2']}")'));
  });

  test('rewrites the url() of a linked stylesheet to the renamed file', () {
    // A page preloads a font its stylesheet declares: renaming the file for
    // the preload must not leave the @font-face pointing at the old name.
    Directory('${site.path}/_thor').createSync();
    File('${site.path}/_thor/base.css').writeAsStringSync(
      '@font-face{font-family:b;src:url("/fonts/brand.woff2")}'
      'i{background:url(../hero.webp)}'
      'u{background:url("data:image/svg+xml,%3Csvg/%3E")}',
    );
    File('${site.path}/index.html').writeAsStringSync(
      '<!DOCTYPE html><html><head>'
      '<link rel="preload" href="/fonts/brand.woff2" as="font" crossorigin>'
      '<link rel="stylesheet" href="_thor/base.css">'
      '</head><body></body></html>',
    );
    final report = fingerprintSite(site.path);
    final font = report.renamed['fonts/brand.woff2']!;
    final hero = report.renamed['hero.webp']!;
    final css = File(
      '${site.path}/${report.renamed['_thor/base.css']}',
    ).readAsStringSync();
    expect(css, contains('url("/$font")'));
    expect(css, contains('url(../$hero)'));
    expect(css, contains('url("data:image/svg+xml,%3Csvg/%3E")'));
    expect(page(), contains('href="/$font"'));
    expect(File('${site.path}/$font').existsSync(), isTrue);
  });

  group('a stylesheet is named by its rewritten content', () {
    // Same stylesheet source, same name in the build; only a font changes.
    String build(String fontBytes) {
      final dir = Directory.systemTemp.createTempSync('thor-site-css-');
      addTearDown(() => dir.deleteSync(recursive: true));
      Directory('${dir.path}/_thor').createSync();
      Directory('${dir.path}/fonts').createSync();
      File('${dir.path}/fonts/brand.woff2').writeAsStringSync(fontBytes);
      File('${dir.path}/_thor/base.67df3cfb.css').writeAsStringSync(
        '@import "theme.css";@font-face{src:url("/fonts/brand.woff2")}',
      );
      File(
        '${dir.path}/_thor/theme.css',
      ).writeAsStringSync('i{background:url(../fonts/brand.woff2)}');
      File('${dir.path}/index.html').writeAsStringSync(
        '<!DOCTYPE html><html><head>'
        '<link rel="stylesheet" href="/_thor/base.67df3cfb.css">'
        '</head><body></body></html>',
      );
      final report = fingerprintSite(dir.path);
      final sheet = report.renamed['_thor/base.67df3cfb.css']!;
      final theme = report.renamed['_thor/theme.css']!;
      final html = File('${dir.path}/index.html').readAsStringSync();
      final headers = File('${dir.path}/_headers').readAsStringSync();
      final css = File('${dir.path}/$sheet').readAsStringSync();
      expect(html, contains('href="/$sheet"'));
      expect(headers, contains('/$sheet'));
      expect(headers, isNot(contains('base.67df3cfb')));
      // The @import follows the renamed stylesheet, which follows the font.
      expect(css, contains('@import "${theme.split('/').last}"'));
      expect(css, contains(report.renamed['fonts/brand.woff2']!));
      // Running again changes nothing.
      expect(fingerprintSite(dir.path).renamed, isEmpty);
      return sheet;
    }

    test('a new font renames the hashed stylesheet that points at it', () {
      expect(build('font one'), isNot(build('font two')));
    });

    test('the same font gives the same name', () {
      expect(build('font one'), build('font one'));
    });
  });

  test('keeps names others request, external URLs and plain links', () {
    final report = fingerprintSite(site.path);
    expect(report.renamed.keys, isNot(contains('favicon.png')));
    expect(report.renamed.keys, isNot(contains('og.jpg')));
    final html = page();
    expect(html, contains('href="favicon.png"'));
    expect(html, contains('content="og.jpg"'));
    expect(html, contains('src="https://cdn.example.com/x.png"'));
    // An <a href> is navigation, not a subresource: left alone.
    expect(html, contains('<a href="hero.webp">'));
  });

  test('is idempotent', () {
    fingerprintSite(site.path);
    final once = page();
    final again = fingerprintSite(site.path);
    expect(again.renamed, isEmpty);
    expect(page(), once);
  });

  test('the hash follows the content', () {
    expect(contentHash('a'.codeUnits), isNot(contentHash('b'.codeUnits)));
    expect(contentHash('a'.codeUnits), contentHash('a'.codeUnits));
  });

  test('_headers: pages revalidate, hashed files are immutable', () {
    File('${site.path}/_headers').writeAsStringSync('/api/*\n  X-Own: 1\n');
    final report = fingerprintSite(site.path);
    final headers = File('${site.path}/_headers').readAsStringSync();
    expect(headers, contains('/api/*\n  X-Own: 1'), reason: 'app rules kept');
    expect(headers, contains('/*.html\n  Cache-Control: no-cache'));
    expect(
      headers,
      contains(
        '/_thor/*\n  Cache-Control: public, max-age=31536000, immutable',
      ),
    );
    expect(
      headers,
      contains(
        '/${report.renamed['engine.dart.js']}\n'
        '  Cache-Control: public, max-age=31536000, immutable',
      ),
    );
    // A second run replaces the generated block instead of appending.
    fingerprintSite(site.path);
    final again = File('${site.path}/_headers').readAsStringSync();
    expect('# thor: cache headers'.allMatches(again).length, 1);
  });
  test(
    'a file name that needs percent-encoding stays encoded when renamed',
    () {
      File('${site.path}/my photo.png').writeAsStringSync('spaced');
      File('${site.path}/index.html').writeAsStringSync(
        '<!DOCTYPE html><html><head>'
        '<style>i{background:url(my%20photo.png)}</style></head><body>'
        '<img src="my%20photo.png" srcset="my%20photo.png 2x">'
        '</body></html>',
      );
      final report = fingerprintSite(site.path);
      final name = report.renamed['my photo.png']!;
      expect(name, matches(RegExp(r'^my photo\.[0-9a-f]{8}\.png$')));
      final html = page();
      const encoded = r'my%20photo\.[0-9a-f]{8}\.png';
      expect(html, contains(RegExp('src="$encoded"')));
      expect(html, contains(RegExp('srcset="$encoded 2x"')));
      expect(html, contains(RegExp('url\\($encoded\\)')));
      expect(html, isNot(contains('my photo')));
    },
  );
}
