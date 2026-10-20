// The fonts a theme preloads (`FontFace(preload: true)`) also travel in the
// `Link` header of every page (and so in `earlyHints` / a CDN's 103), not
// only as a `<link rel=preload>` in the document.
import 'package:test/test.dart';
import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

const _body = FontFace('Figtree', url: '/fonts/figtree.woff2', preload: true);
const _mono = FontFace('Mono', url: '/fonts/mono.woff2');
const _dark = FontFace('Night', url: '/fonts/night.woff', preload: true);

ThorApp _app({ThemeData? theme, ThemeData? dark, ThemeMode? mode}) =>
    ThorApp.router(
      routerConfig: ThorRouter(const []),
      theme: theme,
      darkTheme: dark,
      themeMode: mode ?? ThemeMode.system,
    );

Future<List<LinkHint>> _links(WidgetRenderer renderer) => renderer.linksFor(
  PageRequest(method: HttpMethod.get, uri: Uri.parse('http://site.test/')),
  const [],
);

void main() {
  test(
    'a preloaded face of the theme is a font hint, the rest are not',
    () async {
      final renderer = WidgetRenderer.router(
        _app(theme: ThemeData(fonts: const [_body, _mono])),
      );
      final hints = await _links(renderer);
      expect(hints.map((h) => h.header), [
        '</fonts/figtree.woff2>; rel=preload; as=font; type=font/woff2; crossorigin',
      ]);
    },
  );

  test('the dark theme\'s faces when the app is always dark', () async {
    final renderer = WidgetRenderer.router(
      _app(
        theme: ThemeData(fonts: const [_body]),
        dark: ThemeData(fonts: const [_dark]),
        mode: ThemeMode.dark,
      ),
    );
    final hints = await _links(renderer);
    expect(hints.single.href, '/fonts/night.woff');
    expect(hints.single.type, 'font/woff');
  });

  test('no duplicate with an explicit preload of the same file', () async {
    final renderer = WidgetRenderer.router(
      _app(theme: ThemeData(fonts: const [_body])),
      preload: [const LinkHint.font('/fonts/figtree.woff2')],
    );
    expect(await _links(renderer), hasLength(1));
  });

  test('a page answers them in its Link header', () async {
    final handler = RouteHandler<Widget>(
      renderer: WidgetRenderer.router(
        _app(theme: ThemeData(fonts: const [_body])),
      ),
      onError: (request, error, stack) {},
      routes: [PageRoute<Widget, void>(build: (state) => const Text('hi'))],
    );
    final r = await handler.handle(
      PageRequest(
        method: HttpMethod.get,
        uri: Uri.parse('http://site.test/'),
        headers: {HttpHeader.host: 'site.test'},
      ),
    );
    expect(r.headers['link'], contains('</fonts/figtree.woff2>; rel=preload'));
  });

  test('an app without a theme has no font hints', () async {
    expect(await _links(WidgetRenderer.router(_app())), isEmpty);
  });
}
