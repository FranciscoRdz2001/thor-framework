// The fonts a theme preloads (`FontFace(preload: true)`) are preloaded only
// by the pages whose CSS uses them, and the same ones travel in the `Link`
// header (and so in `earlyHints` / a CDN's 103) and in the document's head.
import 'package:test/test.dart';
import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

const _body = FontFace('Figtree', url: '/fonts/figtree.woff2', preload: true);
const _dark = FontFace('Night', url: '/fonts/night.woff', preload: true);

ThorApp _app({ThemeData? theme, ThemeData? dark, ThemeMode? mode}) =>
    ThorApp.router(
      routerConfig: ThorRouter(const []),
      theme: theme,
      darkTheme: dark,
      themeMode: mode ?? ThemeMode.system,
    );

Future<ThorResponse> _get(WidgetRenderer renderer, Widget page) =>
    RouteHandler<Widget>(
      renderer: renderer,
      onError: (request, error, stack) {},
      routes: [PageRoute<Widget, void>(build: (state) => page)],
    ).handle(
      PageRequest(
        method: HttpMethod.get,
        uri: Uri.parse('http://site.test/'),
        headers: {HttpHeader.host: 'site.test'},
      ),
    );

// The `<link rel=preload as=font>` hrefs of the document.
List<String> _headPreloads(String html) => [
  for (final m in RegExp(
    r'<link[^>]*rel="preload"[^>]*as="font"[^>]*>',
  ).allMatches(html))
    RegExp(r'href="([^"]*)"').firstMatch(m[0]!)![1]!,
];

// The fonts of the `Link` header.
List<String> _headerPreloads(ThorResponse r) => [
  for (final m in RegExp(
    r'<([^>]*)>; rel=preload; as=font',
  ).allMatches(r.headers['link'] ?? ''))
    m[1]!,
];

const _mono = FontFace('Mono', url: '/fonts/mono.woff2', preload: true);
const _bold = FontFace(
  'Figtree',
  url: '/fonts/figtree-bold.woff2',
  weight: FontWeight.w700,
  preload: true,
);
const _regular = FontFace(
  'Figtree',
  url: '/fonts/figtree.woff2',
  preload: true,
);

void main() {
  test('the theme\'s family is used by every page: preloaded', () async {
    final renderer = WidgetRenderer.router(
      _app(
        theme: ThemeData(
          fontFamily: 'Figtree',
          fonts: const [FontFace('Figtree', url: '/f.woff2', preload: true)],
        ),
      ),
    );
    final r = await _get(renderer, const Text('hi'));
    expect(_headPreloads(r.text), ['/f.woff2']);
    expect(r.headers['link'], contains('</f.woff2>; rel=preload; as=font'));
    expect(r.headers['link'], contains('type=font/woff2'));
  });

  test('a face the page does not use is not preloaded', () async {
    final renderer = WidgetRenderer.router(
      _app(
        theme: ThemeData(
          fontFamily: 'Figtree',
          fonts: const [
            FontFace('Figtree', url: '/f.woff2', preload: true),
            _mono,
          ],
        ),
      ),
    );
    final plain = await _get(renderer, const Text('hi'));
    expect(_headPreloads(plain.text), ['/f.woff2']);
    expect(_headerPreloads(plain), ['/f.woff2']);
    // The @font-face rule still ships: the face loads if it is ever used.
    expect(plain.text, contains('@font-face'));

    final code = await _get(
      renderer,
      const Text('x', style: TextStyle(fontFamily: 'Mono')),
    );
    expect(
      _headPreloads(code.text),
      unorderedEquals(['/f.woff2', '/fonts/mono.woff2']),
    );
    expect(
      _headerPreloads(code),
      unorderedEquals(['/f.woff2', '/fonts/mono.woff2']),
    );
  });

  test('a family used only in a variant or in a dialog counts', () async {
    final renderer = WidgetRenderer.router(
      _app(
        theme: ThemeData(
          fontFamily: 'Figtree',
          fonts: const [
            FontFace('Figtree', url: '/f.woff2', preload: true),
            _mono,
          ],
        ),
      ),
    );
    final variant = await _get(
      renderer,
      Styled(
        style: const StyleProps().when(
          // The family in a breakpoint variant is the case under test.
          // ignore: thor_lints/widget_props_in_styled
          medium: const StyleProps(textStyle: TextStyle(fontFamily: 'Mono')),
        ),
        child: const Text('x'),
      ),
    );
    expect(_headPreloads(variant.text), contains('/fonts/mono.woff2'));
    final dialog = await _get(
      renderer,
      const AlertDialog(
        content: Text('x', style: TextStyle(fontFamily: 'Mono')),
      ),
    );
    expect(_headPreloads(dialog.text), contains('/fonts/mono.woff2'));
  });

  test('a face of a family with several weights, only when used', () async {
    final renderer = WidgetRenderer.router(
      _app(
        theme: ThemeData(fontFamily: 'Figtree', fonts: const [_regular, _bold]),
      ),
    );
    final regular = await _get(renderer, const Text('hi'));
    expect(_headPreloads(regular.text), ['/fonts/figtree.woff2']);
    expect(_headerPreloads(regular), ['/fonts/figtree.woff2']);

    final bold = await _get(
      renderer,
      const Text('hi', style: TextStyle(fontWeight: FontWeight.w700)),
    );
    expect(
      _headPreloads(bold.text),
      unorderedEquals(['/fonts/figtree.woff2', '/fonts/figtree-bold.woff2']),
    );
    expect(
      _headerPreloads(bold),
      unorderedEquals(['/fonts/figtree.woff2', '/fonts/figtree-bold.woff2']),
    );
  });

  test('the dark theme\'s faces when the app is always dark', () async {
    final renderer = WidgetRenderer.router(
      _app(
        theme: ThemeData(fonts: const [_body]),
        dark: ThemeData(fontFamily: 'Night', fonts: const [_dark]),
        mode: ThemeMode.dark,
      ),
    );
    final r = await _get(renderer, const Text('hi'));
    expect(_headerPreloads(r), ['/fonts/night.woff']);
    expect(r.headers['link'], contains('type=font/woff;'));
  });

  test('no duplicate with an explicit preload of the same file', () async {
    final renderer = WidgetRenderer.router(
      _app(
        theme: ThemeData(fontFamily: 'Figtree', fonts: const [_body]),
      ),
      preload: [const LinkHint.font('/fonts/figtree.woff2')],
    );
    final r = await _get(renderer, const Text('hi'));
    expect(_headerPreloads(r), ['/fonts/figtree.woff2']);
  });

  test('a face that does not ask for a preload is not one', () async {
    final renderer = WidgetRenderer.router(
      _app(
        theme: ThemeData(
          fontFamily: 'Mono',
          fonts: const [FontFace('Mono', url: '/fonts/mono.woff2')],
        ),
      ),
    );
    final r = await _get(renderer, const Text('hi'));
    expect(_headPreloads(r.text), isEmpty);
    expect(_headerPreloads(r), isEmpty);
  });

  test('an app without a theme has no font hints', () async {
    final r = await _get(WidgetRenderer.router(_app()), const Text('hi'));
    expect(_headPreloads(r.text), isEmpty);
    expect(r.headers['link'] ?? '', isNot(contains('as=font')));
  });
}
