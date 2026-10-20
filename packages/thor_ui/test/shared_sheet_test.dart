@TestOn('vm')
library;

import 'dart:convert';
import 'dart:isolate';

import 'package:test/test.dart';
import 'package:thor_ui/html.dart' show css;
import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

/// A component of the app, drawn once as a specimen.
class Chip extends StatelessWidget implements ThorElementWidget {
  const Chip(this.color, {super.key});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    color: color,
    padding: const EdgeInsets.all(4),
    child: const Text('chip'),
  );
}

class Boom extends StatelessWidget {
  const Boom({super.key});

  @override
  Widget build(BuildContext context) => throw StateError('needs data');
}

final margin = RegExp(r'margin:\s*0');

const red = Color(0xFFFF0000);
const blue = Color(0xFF0000FF);
const green = Color(0xFF00FF00);

final appStyles = [
  css('body').props(const StyleProps(margin: EdgeInsets.zero)),
];

WidgetRenderer renderer({
  bool share = true,
  // As the pages use it (in a Column: a flex child's class holds its
  // flex values too).
  List<Widget> specimens = const [
    Column(children: [Chip(red)]),
  ],
  bool themed = true,
}) => WidgetRenderer(
  app: themed ? (page) => ThorApp(theme: ThemeData(), child: page) : null,
  styles: appStyles,
  shareStyles: share,
  specimens: specimens,
);

RouteHandler<Widget> site(WidgetRenderer r) => RouteHandler<Widget>(
  renderer: r,
  onError: (request, error, stack) {},
  routes: [
    routeLayout<void>(
      styles: [css('.outer').props(const StyleProps(opacity: .5))],
      children: [
        routePage<void>(
          path: 'a',
          build: (c, s) => const Column(children: [Chip(red), Chip(blue)]),
        ),
        routeLayout<void>(
          path: 'deep',
          styles: [css('.inner').props(const StyleProps(opacity: .25))],
          children: [
            routePage<void>(path: 'b', build: (c, s) => const Chip(green)),
          ],
        ),
      ],
    ),
  ],
);

PageRequest get(String path) => PageRequest(
  method: HttpMethod.get,
  uri: Uri.parse('http://site.test$path'),
  headers: {HttpHeader.host: 'site.test'},
);

String inlineStyles(String html) {
  final at = html.indexOf('id="thor-styles"');
  return html.substring(
    html.indexOf('>', at) + 1,
    html.indexOf('</style>', at),
  );
}

List<String> links(String html) => [
  for (final m in RegExp(
    r'<link rel="stylesheet" href="([^"]+)"',
  ).allMatches(html))
    m[1]!,
];

/// The class of the element whose background is [color].
String classOf(String html, String sheet, String color) {
  final rule = RegExp(
    r'\.(t[\w-]*)\s*\{[^}]*background-color:\s*' + color,
  ).firstMatch(sheet);
  expect(rule, isNotNull, reason: 'no class with background $color');
  return rule![1]!;
}

void main() {
  test('a page links the shared sheet and keeps inline only its own '
      'classes', () async {
    final handler = site(renderer());
    final html = (await handler.handle(get('/a'))).text;
    final base = links(html).first;
    expect(base, matches(RegExp(r'^/_thor/base\.[0-9a-z]+\.css$')));
    final sheet = (await handler.handle(get(base))).text;
    final own = inlineStyles(html);

    // The specimen's class: in the file, not in the page.
    final redClass = classOf(html, sheet, '#ff0000');
    expect(html, contains('class="$redClass"'));
    expect(own, isNot(contains(RegExp('\\.$redClass\\s*\\{'))));
    // A style no specimen has: inline, not in the file.
    final blueClass = classOf(html, own, '#0000ff');
    expect(sheet, isNot(contains(RegExp('\\.$blueClass\\s*\\{'))));
    // Theme and app stylesheet: only in the file.
    expect(sheet, contains(RegExp(r'@layer thor\.tokens\s*\{')));
    expect(own, isNot(contains('@layer thor.tokens')));
    expect(sheet, matches(margin));
    expect(html, isNot(matches(margin)));
    expect(sheet, startsWith('@layer thor.reset,'));
  });

  test(
    'without shareStyles the layer order opens before the app rules',
    () async {
      final handler = site(renderer(share: false));
      final html = (await handler.handle(get('/a'))).text;
      final order = html.indexOf('@layer thor.reset,thor.tokens');
      expect(order, isNonNegative);
      // The app stylesheet and the module rules are unlayered: stated after
      // the order, `thor.overrides` would sit below `thor.props`.
      expect(order, lessThan(html.indexOf(margin.firstMatch(html)![0]!)));
      expect(order, lessThan(html.indexOf('opacity')));
    },
  );

  test('the file is immutable, and an unknown one is a 404', () async {
    final handler = site(renderer());
    final base = links((await handler.handle(get('/a'))).text).first;
    final r = await handler.handle(get(base));
    expect(r.status, 200);
    expect(r.headers['content-type'], startsWith('text/css'));
    expect(r.headers['cache-control'], contains('immutable'));
    expect((await handler.handle(get('/_thor/base.nope.css'))).status, 404);
  });

  test('every isolate names and fills the sheet the same', () async {
    Future<(String, String)> sheetIn() async {
      final handler = site(renderer());
      final base = links((await handler.handle(get('/a'))).text).first;
      return (base, (await handler.handle(get(base))).text);
    }

    final here = await sheetIn();
    final there = await Isolate.run(sheetIn);
    expect(there, here);
  });

  test('a page style under a name the sheet gives another style keeps '
      'its own rules', () async {
    // In debug a class is named after its component: the green Chip of
    // /deep/b and the red specimen are both `Chip`.
    final handler = site(renderer());
    final base = links((await handler.handle(get('/a'))).text).first;
    final sheet = (await handler.handle(get(base))).text;
    final html = (await handler.handle(get('/deep/b'))).text;
    final own = inlineStyles(html);
    final greenClass = classOf(html, own, '#00ff00');
    expect(greenClass, isNot(classOf(html, sheet, '#ff0000')));
    expect(html, contains('class="$greenClass"'));
  });

  test('module sheets are linked after the base, root first', () async {
    final handler = site(renderer());
    final html = (await handler.handle(get('/deep/b'))).text;
    final hrefs = links(html);
    expect(hrefs, hasLength(3));
    expect(hrefs[0], startsWith('/_thor/base.'));
    final outer = (await handler.handle(get(hrefs[1]))).text;
    final inner = (await handler.handle(get(hrefs[2]))).text;
    expect(outer, contains('.outer'));
    expect(inner, contains('.inner'));
    // The page's own <style> after every file.
    expect(html.indexOf(hrefs[2]), lessThan(html.indexOf('id="thor-styles"')));
    // A page of the outer module only gets its sheet.
    final a = links((await handler.handle(get('/a'))).text);
    expect(a, [hrefs[0], hrefs[1]]);
  });

  test(
    'the Link header preloads what the page links, before it renders',
    () async {
      final handler = site(renderer());
      final r = await handler.handle(get('/deep/b'));
      final hrefs = links(r.text);
      // The same files, in the same order, as `rel=preload; as=style`.
      expect(
        r.headers['link'],
        [for (final h in hrefs) '<$h>; rel=preload; as=style'].join(', '),
      );
      // Fonts the app declares go after them.
      final fonts = WidgetRenderer(
        app: (page) => ThorApp(theme: ThemeData(), child: page),
        shareStyles: true,
        preload: const [LinkHint.font('/fonts/geist.woff2')],
      );
      final hints = await fonts.linksFor(get('/'), const []);
      expect(hints.last.header, contains('</fonts/geist.woff2>; rel=preload'));
      // Without sharing the styles are inline: nothing to preload.
      final inline = await site(renderer(share: false)).handle(get('/deep/b'));
      expect(inline.headers['link'], isNull);
    },
  );

  test('without sharing, module rules go inline in the same order', () async {
    final handler = site(renderer(share: false));
    final html = (await handler.handle(get('/deep/b'))).text;
    expect(links(html), isEmpty);
    expect(html, matches(margin));
    final outer = html.indexOf('.outer');
    final inner = html.indexOf('.inner');
    expect(outer, greaterThan(0));
    expect(inner, greaterThan(outer));
    expect(inner, lessThan(html.indexOf('id="thor-styles"')));
    expect(inlineStyles(html), contains(RegExp(r'@layer thor\.tokens\s*\{')));
    expect((await handler.handle(get('/_thor/base.x.css'))).status, 404);
  });

  test('specimens that do not render leave the pages inline', () async {
    final handler = site(renderer(specimens: const [Boom()]));
    final html = (await handler.handle(get('/a'))).text;
    expect(html, matches(margin));
    expect(inlineStyles(html), contains(RegExp(r'@layer thor\.tokens\s*\{')));
    expect(links(html).where((l) => l.contains('base.')), isEmpty);
  });

  test('an app without ThorApp has no base sheet', () async {
    final handler = site(renderer(themed: false));
    final html = (await handler.handle(get('/a'))).text;
    expect(links(html).where((l) => l.contains('base.')), isEmpty);
    expect(html, matches(margin));
  });

  test('an export writes the files the pages link', () async {
    final r = renderer();
    final paths = [...await r.assetPaths()];
    expect(paths.first, startsWith('/_thor/base.'));
    expect(paths.where((p) => p.startsWith('/_thor/module.')), hasLength(2));
    for (final p in paths) {
      expect(await r.asset(p), isNotNull);
      expect(utf8.decode((await r.asset(p))!.body), isNotEmpty);
    }
  });
}
