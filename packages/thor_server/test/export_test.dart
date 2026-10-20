import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:thor_server/thor_server.dart';

class _Renderer implements PageRenderer<String> {
  @override
  List<int> render(String page, RenderContext context) =>
      utf8.encode('<title>${context.meta.title ?? ''}</title>$page');

  @override
  String errorPage(ErrorState state) => 'error ${state.status}';
}

void main() {
  late Directory out;
  setUp(() async => out = await Directory.systemTemp.createTemp('thor_export'));
  tearDown(() => out.delete(recursive: true));

  final handler = RouteHandler<String>(
    renderer: _Renderer(),
    onError: (r, e, s) {},
    routes: [
      PageRoute<String, void>(build: (s) => 'home'),
      PageRoute<String, String>(
        path: 'guide/[slug]',
        load: (r) {
          final slug = r.pathParameters['slug']!;
          if (slug == 'missing') throw const NotFound();
          return slug;
        },
        meta: (s) => PageMeta(title: s.data),
        build: (s) => 'guide ${s.data}',
      ),
      PageRoute<String, void>(
        path: 'old',
        redirect: (r) => const RouteUrl('/'),
        build: (s) => 'never',
      ),
    ],
  );

  test('writes each page where a static host serves it', () async {
    final report = await exportSite(
      handler,
      paths: ['/', '/guide/state', '/guide/motor'],
      outDir: out.path,
    );
    expect(report.ok, isTrue);
    expect(report.written, {
      '/': 'index.html',
      '/guide/state': 'guide/state.html',
      '/guide/motor': 'guide/motor.html',
    });
    expect(
      await File('${out.path}/guide/state.html').readAsString(),
      '<title>state</title>guide state',
    );
    expect(File('${out.path}/sitemap.xml').existsSync(), isFalse);
  });

  test('a page that is not a 200 is reported, not written', () async {
    final report = await exportSite(
      handler,
      paths: ['/guide/missing', '/old', '/nope', '/'],
      outDir: out.path,
    );
    expect(report.ok, isFalse);
    expect(report.failed, {'/guide/missing': 404, '/old': 302, '/nope': 404});
    expect(report.written.keys, ['/']);
    expect(File('${out.path}/guide/missing.html').existsSync(), isFalse);
  });

  test('with a base URL: sitemap of the written pages and robots', () async {
    await exportSite(
      handler,
      paths: ['/', '/guide/state', '/guide/missing'],
      outDir: out.path,
      baseUrl: 'https://docs.example.com/',
    );
    final sitemap = await File('${out.path}/sitemap.xml').readAsString();
    expect(sitemap, contains('<loc>https://docs.example.com/</loc>'));
    expect(
      sitemap,
      contains('<loc>https://docs.example.com/guide/state</loc>'),
    );
    expect(sitemap, isNot(contains('missing')));
    expect(
      await File('${out.path}/robots.txt').readAsString(),
      contains('Sitemap: https://docs.example.com/sitemap.xml'),
    );
  });

  test('404.html is the site\'s error page', () async {
    final report = await exportSite(
      handler,
      paths: ['/'],
      outDir: out.path,
      notFoundPath: '/__missing__',
    );
    expect(report.ok, isTrue);
    expect(
      await File('${out.path}/404.html').readAsString(),
      contains('error 404'),
    );
    // A "not found" path that exists is a mistake, reported.
    final wrong = await exportSite(
      handler,
      paths: const [],
      outDir: out.path,
      notFoundPath: '/',
    );
    expect(wrong.failed, {'/': 200});
  });

  test(
    'internal links must reach a page, its anchor or a static file',
    () async {
      final pages = {
        '':
            '<h2 id="uno">1</h2><a href="#uno">a</a><a href="/b#dos">b</a>'
            '<a href="b">rel</a><a href="https://x.dev/nada">ext</a>'
            '<a href="/logo.png">f</a>',
        'b':
            '<h2 id="dos">2</h2><a href="/#falta">x</a><a href="/c">y</a>'
            '<a href="/nada.png">z</a>',
      };
      final site = RouteHandler<String>(
        renderer: _Renderer(),
        onError: (r, e, s) {},
        routes: [
          for (final MapEntry(:key, :value) in pages.entries)
            PageRoute<String, void>(path: key, build: (s) => value),
        ],
      );
      final assets = await Directory.systemTemp.createTemp('thor_assets');
      addTearDown(() => assets.delete(recursive: true));
      File('${assets.path}/logo.png').writeAsBytesSync([0]);
      final report = await exportSite(
        site,
        paths: ['/', '/b'],
        outDir: out.path,
        staticDir: assets.path,
      );
      expect(report.failed, isEmpty);
      expect(report.brokenLinks, {
        '/b': ['/#falta', '/c', '/nada.png'],
      });
      expect(report.ok, isFalse);
    },
  );

  test('file names: index, nested, trailing slash; no escaping the folder', () {
    expect(fileForPath('/'), 'index.html');
    expect(fileForPath('/a'), 'a.html');
    expect(fileForPath('/a/b'), 'a/b.html');
    expect(fileForPath('/a/'), 'a/index.html');
    expect(() => fileForPath('/../etc/passwd'), throwsArgumentError);
    expect(() => fileForPath('/a/../'), throwsArgumentError);
    expect(() => fileForPath('/../'), throwsArgumentError);
    expect(fileForPath('/a..b'), 'a..b.html'); // a name, not a parent
  });

  test('with a base URL the pages are asked as the site itself', () async {
    final seen = <String>[];
    final spy = RouteHandler<String>(
      renderer: _Renderer(),
      onError: (r, e, s) {},
      routes: [
        PageRoute<String, void>(
          path: 'where',
          meta: (s) {
            seen.add(s.request.uri.toString());
            return const PageMeta(title: 'where');
          },
          build: (s) => 'where',
        ),
      ],
    );
    await exportSite(
      spy,
      paths: ['/where'],
      outDir: out.path,
      baseUrl: 'https://docs.example.com/',
    );
    expect(seen, ['https://docs.example.com/where']);
  });

  group('percent-encoded paths', () {
    final encoded = RouteHandler<String>(
      renderer: _Renderer(),
      onError: (r, e, s) {},
      routes: [
        PageRoute<String, void>(
          path: 'p/[slug]',
          build: (s) =>
              '<a href="/p/caf%C3%A9">self</a><a href="/p/a%20b">space</a>',
        ),
      ],
    );

    test(
      'are written under the decoded name and their links resolve',
      () async {
        final report = await exportSite(
          encoded,
          paths: ['/p/caf%C3%A9', '/p/a%20b'],
          outDir: out.path,
        );
        expect(report.brokenLinks, isEmpty);
        expect(report.ok, isTrue);
        expect(report.written, {
          '/p/caf%C3%A9': 'p/caf\u00e9.html',
          '/p/a%20b': 'p/a b.html',
        });
        expect(File('${out.path}/p/caf\u00e9.html').existsSync(), isTrue);
        expect(File('${out.path}/p/a b.html').existsSync(), isTrue);
      },
    );
  });
}
