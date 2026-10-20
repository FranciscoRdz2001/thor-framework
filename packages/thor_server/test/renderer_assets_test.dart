import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:thor_server/thor_server.dart';

/// A renderer with one file of its own (a shared stylesheet).
class _Renderer implements PageRenderer<String>, RendererAssets {
  var asked = 0;

  @override
  List<int> render(String page, RenderContext context) => utf8.encode(
    '<!DOCTYPE html><html><head>'
    '<link rel="stylesheet" href="/_thor/base.abc.css"></head>'
    '<body>$page</body></html>',
  );

  @override
  String errorPage(ErrorState state) => 'error ${state.status}';

  @override
  RendererAsset? asset(String path) {
    asked++;
    return path == '/_thor/base.abc.css'
        ? RendererAsset.css('body{margin:0}')
        : null;
  }

  @override
  List<String> assetPaths() => ['/_thor/base.abc.css'];
}

PageRequest _req(
  String path, {
  HttpMethod method = HttpMethod.get,
  String? etag,
}) => PageRequest(
  method: method,
  uri: Uri.parse('http://site.test$path'),
  headers: {HttpHeader.host: 'site.test', HttpHeader.ifNoneMatch: ?etag},
);

void main() {
  late _Renderer renderer;
  late RouteHandler<String> handler;
  setUp(() {
    renderer = _Renderer();
    handler = RouteHandler<String>(
      renderer: renderer,
      onError: (r, e, s) {},
      routes: [
        PageRoute<String, void>(build: (s) => 'home'),
        // A page under /_thor/ that the renderer doesn't own still works.
        PageRoute<String, void>(path: '_thor/about', build: (s) => 'about'),
      ],
    );
  });

  test('a renderer file is served immutable, with an ETag', () async {
    final r = await handler.handle(_req('/_thor/base.abc.css'));
    expect(r.status, 200);
    expect(r.text, 'body{margin:0}');
    expect(r.headers['content-type'], 'text/css; charset=utf-8');
    expect(r.headers['cache-control'], 'public, max-age=31536000, immutable');
    final again = await handler.handle(
      _req('/_thor/base.abc.css', etag: r.headers['etag']),
    );
    expect(again.status, 304);
    expect(again.body, isEmpty);
  });

  test(
    'a path the renderer does not have falls through to the routes',
    () async {
      expect((await handler.handle(_req('/_thor/base.old.css'))).status, 404);
      final page = await handler.handle(_req('/_thor/about'));
      expect(page.status, 200);
      expect(page.text, contains('about'));
    },
  );

  test('only GET and HEAD reach the renderer files', () async {
    final post = await handler.handle(
      _req('/_thor/base.abc.css', method: HttpMethod.post),
    );
    expect(post.status, isNot(200));
    expect(renderer.asked, 0);
    final head = await handler.handle(
      _req('/_thor/base.abc.css', method: HttpMethod.head),
    );
    expect(head.status, 200);
  });

  test('an export writes the files next to the pages', () async {
    final out = await Directory.systemTemp.createTemp('thor_assets');
    addTearDown(() => out.delete(recursive: true));
    final report = await exportSite(handler, paths: ['/'], outDir: out.path);
    expect(report.ok, isTrue);
    expect(
      File('${out.path}/_thor/base.abc.css').readAsStringSync(),
      'body{margin:0}',
    );
  });
}
