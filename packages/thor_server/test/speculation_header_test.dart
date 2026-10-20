// The `Speculation-Rules` response header (strict CSP: no inline
// `<script type="speculationrules">`) and the per-route opt-out.
import 'dart:async';
import 'dart:convert';

import 'package:test/test.dart';
import 'package:thor_server/thor_server.dart';

class _Renderer implements PageRenderer<String>, EarlyHints, RendererAssets {
  @override
  List<int> render(String page, RenderContext context) => utf8.encode(page);

  @override
  String errorPage(ErrorState state) => 'error ${state.status}';

  @override
  FutureOr<List<LinkHint>> linksFor(
    PageRequest request,
    List<LayoutRoute<Object?, Object?>> layouts,
  ) => const [
    LinkHint.style('/_thor/base.css'),
    LinkHint.speculationRules('/_thor/speculation.abc.json'),
  ];

  @override
  FutureOr<RendererAsset?> asset(String path) => path.endsWith('.json')
      ? RendererAsset(
          'application/speculationrules+json',
          utf8.encode('{"prefetch":[]}'),
        )
      : null;

  @override
  FutureOr<Iterable<String>> assetPaths() => const [];
}

PageRequest _get(String path) => PageRequest(
  method: HttpMethod.get,
  uri: Uri.parse('http://site.test$path'),
  headers: {HttpHeader.host: 'site.test'},
);

void main() {
  late RouteHandler<String> handler;

  setUp(() {
    handler = RouteHandler<String>(
      renderer: _Renderer(),
      routes: [
        PageRoute<String, void>(path: 'a', build: (s) => 'a'),
        PageRoute<String, void>(path: 'b', build: (s) => 'b', prefetch: false),
        PageRoute<String, void>(
          path: 'c',
          build: (s) => 'c',
          prefetch: false,
          cache: const Duration(minutes: 1),
        ),
        LayoutRoute<String, void>(
          path: 'quiet',
          prefetch: false,
          build: (s, child) => child,
          children: [
            PageRoute<String, void>(path: 'x', build: (s) => 'x'),
            PageRoute<String, void>(
              path: 'y',
              build: (s) => 'y',
              prefetch: true,
            ),
            LayoutRoute<String, void>(
              path: 'deep',
              build: (s, child) => child,
              children: [PageRoute<String, void>(path: 'z', build: (s) => 'z')],
            ),
          ],
        ),
      ],
    );
  });

  test('a page gets the header, a quoted URL, and no Link for it', () async {
    final r = await handler.handle(_get('/a'));
    expect(r.headers['speculation-rules'], '"/_thor/speculation.abc.json"');
    expect(r.headers['link'], '</_thor/base.css>; rel=preload; as=style');
  });

  test('prefetch: false sends no rules, keeps the other hints', () async {
    final r = await handler.handle(_get('/b'));
    expect(r.headers.containsKey('speculation-rules'), isFalse);
    expect(r.headers['link'], '</_thor/base.css>; rel=preload; as=style');
  });

  test(
    'a page with prefetch: false served from the cache has no header',
    () async {
      for (var i = 0; i < 3; i++) {
        final r = await handler.handle(_get('/c'));
        expect(
          r.headers.containsKey('speculation-rules'),
          isFalse,
          reason: '$i',
        );
      }
      expect(handler.cachedPaths.any((p) => p.endsWith('/c')), isTrue);
    },
  );

  test('a layout with prefetch: false covers the pages below it', () async {
    for (final path in ['/quiet/x', '/quiet/deep/z']) {
      final r = await handler.handle(_get(path));
      expect(r.headers.containsKey('speculation-rules'), isFalse, reason: path);
      expect(r.headers['link'], contains('base.css'));
    }
  });

  test('a page can opt back in under a quiet layout', () async {
    final r = await handler.handle(_get('/quiet/y'));
    expect(r.headers['speculation-rules'], isNotNull);
  });

  test(
    'the rules file is served as application/speculationrules+json',
    () async {
      final r = await handler.handle(_get('/_thor/speculation.abc.json'));
      expect(r.status, 200);
      expect(r.headers['content-type'], 'application/speculationrules+json');
    },
  );

  test('a URL that could forge another entry is refused', () {
    expect(
      () => const LinkHint.speculationRules('/x", "https://evil/').header,
      throwsArgumentError,
    );
  });
}
