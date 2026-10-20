@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:thor_engine/shared_styles.dart';

const _order =
    '@layer thor.reset,thor.tokens,thor.components,thor.props,thor.overrides;';
const _theme = '@layer thor.tokens{:root{--t-a:#111111}}';

String _page(
  String classes,
  String rules, {
  String theme = _theme,
  String? app,
  String extra = '',
}) =>
    '<!DOCTYPE html><html><head><style id="thor-styles">$_order$theme'
    '@layer thor.props{$rules}$extra</style>'
    '${app == null ? '' : '<style>$app</style>'}'
    '</head><body>$classes</body></html>';

const _app =
    '@layer thor.reset{html,body{margin:0}}.prose{max-width:60ch}'
    '@keyframes rise{from{opacity:0}}';

void main() {
  late Directory site;
  setUp(() => site = Directory.systemTemp.createTempSync('thor_share'));
  tearDown(() => site.deleteSync(recursive: true));

  void write(String name, String html) =>
      File('${site.path}/$name').writeAsStringSync(html);
  String read(String name) => File('${site.path}/$name').readAsStringSync();
  String sheetOf(SharedStylesReport r) =>
      File('${site.path}/${r.sheet}').readAsStringSync();
  String baseOf(SharedStylesReport r) =>
      File('${site.path}/${r.base}').readAsStringSync();

  // .tshared is on every page; .tone and .ttwo on one page each.
  const shared =
      '.tshared{color: red}@media (min-width: 9px){.tshared{color: blue}}';

  test('the theme goes to the base sheet, frequent classes to another', () {
    write(
      'a.html',
      _page(
        '<p class="tshared">a</p><p class="tone">1</p>',
        '$shared.tone{color: green}',
      ),
    );
    write(
      'b.html',
      _page(
        '<p class="tshared">b</p><p class="ttwo">2</p>',
        '$shared.ttwo{color: pink}',
      ),
    );
    final r = shareSiteStyles(site.path);
    expect(r.sharing, 2);
    expect(r.sharedClasses, 1);
    expect(r.sheet, matches(RegExp(r'^_thor/styles\.[0-9a-f]{8}\.css$')));
    expect(r.base, matches(RegExp(r'^_thor/base\.[0-9a-f]{8}\.css$')));
    expect(baseOf(r), '$_order$_theme');
    // Short names on every page: the shared class is `a` everywhere.
    expect(
      sheetOf(r),
      '$_order@layer thor.props{.a{color: red}'
      '@media (min-width: 9px){.a{color: blue}}}',
    );
    for (final page in ['a.html', 'b.html']) {
      final html = read(page);
      // Base first, then the classes, then the page's own: the order of
      // the layers is stated before any rule.
      expect(
        html,
        contains(
          '<link rel="stylesheet" href="/${r.base}">'
          '<link rel="stylesheet" href="/${r.sheet}">'
          '<style id="thor-styles">',
        ),
      );
      expect(html, contains('<p class="a">'));
      expect(html, isNot(contains('--t-a')), reason: 'the theme is shared');
    }
    // Each page keeps its own class inline, under a name the shared sheet
    // doesn't use (even though page b doesn't use .a's rule: it would
    // apply).
    expect(read('a.html'), contains('.b{color: green}'));
    expect(read('a.html'), contains('<p class="b">1</p>'));
    expect(read('b.html'), contains('.b{color: pink}'));
  });

  test('a page never reuses a shared name it does not use', () {
    // .tshared isn't on page c, but its short name `a` is still reserved.
    write('a.html', _page('<p class="tshared">a</p>', shared));
    write('b.html', _page('<p class="tshared">b</p>', shared));
    write('c.html', _page('<p class="tthree">c</p>', '.tthree{color: gold}'));
    final r = shareSiteStyles(site.path);
    expect(r.sharing, 3);
    final c = read('c.html');
    expect(c, isNot(contains('class="a"')));
    expect(c, contains('.b{color: gold}'));
    expect(c, contains('<p class="b">c</p>'));
  });

  test('a page with another theme keeps its whole stylesheet', () {
    write('a.html', _page('<p class="tshared">a</p>', shared));
    write('b.html', _page('<p class="tshared">b</p>', shared));
    write(
      'c.html',
      _page(
        '<p class="tshared">c</p>',
        shared,
        theme: '@layer thor.tokens{:root{--t-a:#222222}}',
      ),
    );
    final r = shareSiteStyles(site.path);
    expect(r.sharing, 2);
    expect(r.named, isNot(contains(File('${site.path}/c.html').path)));
    expect(read('c.html'), isNot(contains('_thor/')));
    expect(read('c.html'), contains('.tshared{color: red}'));
  });

  test('pages that leave out unread theme roles share one theme', () {
    // thor_ui publishes only the text roles a page reads.
    write(
      'a.html',
      _page(
        '<p class="tshared">a</p>',
        shared,
        theme: '@layer thor.tokens{:root{--t-a:#111111;--t-x-size:14px}}',
      ),
    );
    write(
      'b.html',
      _page(
        '<p class="tshared">b</p>',
        shared,
        theme:
            '@layer thor.tokens{:root{--t-a:#111111;--t-y-size:16px}'
            '@media (min-width: 768px){:root{--t-y-size:20px}}}',
      ),
    );
    final r = shareSiteStyles(site.path);
    expect(r.sharing, 2);
    expect(
      baseOf(r),
      contains(
        '@layer thor.tokens{:root{--t-a:#111111;--t-x-size:14px;'
        '--t-y-size:16px}@media (min-width: 768px){:root{--t-y-size:20px}}}',
      ),
    );
    for (final page in ['a.html', 'b.html']) {
      expect(read(page), isNot(contains('thor.tokens{')));
    }
  });

  test('one page, or classes below the threshold: nothing to share', () {
    write('a.html', _page('<p class="tone">1</p>', '.tone{color: green}'));
    expect(shareSiteStyles(site.path).sheet, isNull);
    expect(read('a.html'), contains('.tone{color: green}'));
    expect(Directory('${site.path}/_thor').existsSync(), isFalse);
  });

  test('class changes in engine patches are renamed too', () {
    const patched =
        '<p class="tshared" data-tv="s:v" data-tp-1="|class|=tshared tother">a</p>';
    write('a.html', _page(patched, '$shared.tother{color: gray}'));
    write('b.html', _page(patched, '$shared.tother{color: gray}'));
    shareSiteStyles(site.path);
    final a = read('a.html');
    expect(a, contains('class="a"'));
    expect(a, isNot(contains('tshared')));
    expect(a, isNot(contains('tother')));
  });

  test('the app stylesheet every page has moves to the base sheet', () {
    for (final (name, cls) in [('a.html', 'tone'), ('b.html', 'ttwo')]) {
      write(
        name,
        _page('<p class="$cls">x</p>', '.$cls{color: green}', app: _app),
      );
    }
    final r = shareSiteStyles(site.path);
    expect(r.sharedAppStyles, isTrue);
    expect(r.sheet, isNull, reason: 'no class on enough pages');
    // Order first (the reset lands in thor.reset), the app sheet, the theme.
    expect(baseOf(r), '$_order$_app$_theme');
    for (final name in ['a.html', 'b.html']) {
      final html = read(name);
      expect(html, contains('<link rel="stylesheet" href="/${r.base}">'));
      expect(html, isNot(contains('max-width:60ch')));
      expect(html, isNot(contains('<style></style>')));
      expect(RegExp('<style').allMatches(html), hasLength(1));
    }
  });

  test('a page with another app stylesheet keeps everything inline', () {
    write('a.html', _page('<p class="tshared">a</p>', shared, app: _app));
    write('b.html', _page('<p class="tshared">b</p>', shared, app: _app));
    write(
      'c.html',
      _page('<p class="tshared">c</p>', shared, app: '.prose{max-width:70ch}'),
    );
    final r = shareSiteStyles(site.path);
    expect(r.sharing, 2);
    final c = read('c.html');
    expect(c, isNot(contains('_thor/')));
    expect(c, contains('max-width:70ch'));
    expect(c, contains('.tshared{color: red}'));
  });

  test('an app stylesheet whose keyframes clash with thor stays inline', () {
    // On the page the app's `rise` comes after thor's and wins; moved to
    // the base sheet it would come first and lose.
    for (final name in ['a.html', 'b.html']) {
      write(
        name,
        _page(
          '<p class="tshared">$name</p>',
          shared,
          app: _app,
          extra: '@keyframes rise{from{opacity:.5}}',
        ),
      );
    }
    final r = shareSiteStyles(site.path);
    expect(r.sharedAppStyles, isFalse);
    expect(baseOf(r), isNot(contains('60ch')));
    for (final name in ['a.html', 'b.html']) {
      expect(read(name), contains('<style>$_app</style>'));
    }
  });

  test('an app stylesheet right before thor stylesheet moves too', () {
    // Exported pages write the app stylesheet first: the links go right
    // where it was, so the cascade order is the same.
    for (final name in ['a.html', 'b.html']) {
      write(
        name,
        '<!DOCTYPE html><html><head><link rel="stylesheet" href="/x.css">'
        '<style>$_app</style>'
        '<style id="thor-styles">$_order$_theme@layer thor.props{$shared}'
        '@keyframes rise{from{opacity:.5}}</style></head>'
        '<body><p class="tshared">$name</p></body></html>',
      );
    }
    final r = shareSiteStyles(site.path);
    expect(r.sharedAppStyles, isTrue, reason: 'thor keyframes won already');
    final a = read('a.html');
    expect(a, isNot(contains('60ch')));
    expect(
      a.indexOf('href="/x.css"'),
      lessThan(a.indexOf('href="/${r.base}"')),
    );
  });

  test('a stylesheet not next to thor stylesheet is left where it is', () {
    for (final name in ['a.html', 'b.html']) {
      write(
        name,
        '<!DOCTYPE html><html><head><style>$_app</style>'
        '<link rel="stylesheet" href="/x.css">'
        '<style id="thor-styles">$_order$_theme@layer thor.props{$shared}'
        '</style></head><body><p class="tshared">$name</p></body></html>',
      );
    }
    final r = shareSiteStyles(site.path);
    expect(r.sharedAppStyles, isFalse);
    expect(read('a.html'), contains('<style>$_app</style>'));
  });
}
