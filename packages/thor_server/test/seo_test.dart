import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:thor_server/thor_server.dart';

class _Renderer implements PageRenderer<String> {
  @override
  List<int> render(String page, RenderContext context) => utf8.encode(page);

  @override
  String errorPage(ErrorState state) => 'error ${state.status}';
}

PageRequest _req(String path, {HttpMethod method = HttpMethod.get}) =>
    PageRequest(
      method: method,
      uri: Uri.parse('http://site.test$path'),
      headers: const {
        HttpHeader.host: 'site.test',
        HttpHeader.origin: 'http://site.test',
      },
    );

void main() {
  group('Sitemap', () {
    test('absolute, escaped, with lastmod, changefreq and priority', () {
      final xml = Sitemap([
        SitemapUrl(
          '/a?x=1&y=<2>',
          lastModified: DateTime.utc(2026, 9, 26, 10),
          changeFrequency: ChangeFrequency.weekly,
          priority: 3,
        ),
        const SitemapUrl('https://cdn.test/b'),
        const SitemapUrl('c'),
      ]).toXml(Uri.parse('http://site.test/sitemap.xml'));
      expect(
        xml,
        contains(
          '<loc>http://site.test/a?x=1&amp;y=&lt;2&gt;</loc>'
          '<lastmod>2026-09-26T10:00:00.000Z</lastmod>'
          '<changefreq>weekly</changefreq><priority>1.0</priority>',
        ),
      );
      expect(xml, contains('<loc>https://cdn.test/b</loc>'));
      expect(xml, contains('<loc>http://site.test/c</loc>'));
    });

    test('baseUrl beats the request origin (behind a proxy)', () {
      final xml = const Sitemap([
        SitemapUrl('/'),
      ], baseUrl: 'https://real.test/').toXml(Uri.parse('http://10.0.0.1/'));
      expect(xml, contains('<loc>https://real.test/</loc>'));
    });
  });

  group('Robots', () {
    test('groups, allow-all by default, the sitemap line', () {
      final text = const Robots([
        RobotsRule(disallow: ['/editor']),
        RobotsRule(userAgent: 'BadBot', disallow: ['/']),
      ]).toText(Uri.parse('https://site.test/robots.txt'));
      expect(
        text,
        'User-agent: *\nDisallow: /editor\n\n'
        'User-agent: BadBot\nDisallow: /\n\n'
        'Sitemap: https://site.test/sitemap.xml\n',
      );
      expect(
        const Robots([]).toText(Uri.parse('http://x.test/')),
        startsWith('User-agent: *\nAllow: /\n'),
      );
    });

    test('a newline in a value can not add a directive', () {
      final text = const Robots([
        RobotsRule(disallow: ['/a\nAllow: /secret']),
      ], sitemap: false).toText(Uri.parse('http://x.test/'));
      expect(text, 'User-agent: *\nDisallow: /aAllow: /secret\n\n');
    });
  });

  group('ResourceRoute', () {
    late List<String> seen;
    late RouteHandler<String> handler;

    setUp(() {
      seen = [];
      handler = RouteHandler<String>(
        renderer: _Renderer(),
        onError: (r, e, s) {},
        routes: [
          LayoutRoute<String, void>(
            build: (s, child) => child,
            middleware: (r, next) async {
              seen.add(r.uri.path);
              return (await next()).withHeaders({
                const HttpHeader('x-mw'): '1',
              });
            },
            children: [
              PageRoute<String, void>(build: (s) => 'home'),
              ResourceRoute.sitemap((r) => const Sitemap([SitemapUrl('/')])),
              ResourceRoute.robots((r) => const Robots([])),
              ResourceRoute<String>(
                path: 'private.txt',
                redirect: (r) => const RouteUrl('/login'),
                respond: (r) => ThorResponse(200),
              ),
              ResourceRoute<String>(
                path: 'gone.txt',
                respond: (r) => throw const HttpError(410, 'gone'),
              ),
              ResourceRoute<String>(
                path: 'boom.txt',
                respond: (r) => throw StateError('db down'),
              ),
            ],
          ),
        ],
      );
    });

    test('answers its own body, inside the layouts\' middleware', () async {
      final r = await handler.handle(_req('/sitemap.xml'));
      expect(r.status, 200);
      expect(r.headers['content-type'], startsWith('application/xml'));
      expect(r.headers['cache-control'], 'public, max-age=3600');
      expect(r.headers['x-mw'], '1');
      expect(r.text, contains('<loc>http://site.test/</loc>'));
      expect(seen, ['/sitemap.xml']);
      final robots = await handler.handle(_req('/robots.txt'));
      expect(robots.text, contains('Sitemap: http://site.test/sitemap.xml'));
    });

    test('guards run; POST is 405; errors keep their status', () async {
      final guarded = await handler.handle(_req('/private.txt'));
      expect(guarded.status, 302);
      expect(guarded.headers['location'], '/login');
      final post = await handler.handle(
        _req('/sitemap.xml', method: HttpMethod.post),
      );
      expect(post.status, 405);
      expect(post.headers['allow'], 'GET, HEAD');
      expect((await handler.handle(_req('/gone.txt'))).status, 410);
      final boom = await handler.handle(_req('/boom.txt'));
      expect(boom.status, 500);
      expect(boom.text, isNot(contains('db down')));
    });

    test('an export writes the app\'s own sitemap and robots', () async {
      final out = await Directory.systemTemp.createTemp('thor_seo_');
      addTearDown(() => out.delete(recursive: true));
      await exportSite(
        handler,
        paths: const ['/'],
        outDir: out.path,
        baseUrl: 'https://docs.test',
      );
      final xml = File('${out.path}/sitemap.xml').readAsStringSync();
      expect(xml, contains('<loc>https://docs.test/</loc>'));
      expect(
        File('${out.path}/robots.txt').readAsStringSync(),
        contains('Sitemap: https://docs.test/sitemap.xml'),
      );
    });
  });
}
