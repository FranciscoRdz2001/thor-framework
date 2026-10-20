import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:thor_server/thor_server.dart' show exportSite;
import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

class _CurrentPath extends StatelessWidget implements ThorElementWidget {
  const _CurrentPath();

  @override
  Widget build(BuildContext context) =>
      Text('at ${RequestScope.of(context).uri.path}');
}

void main() {
  final handler = RouteHandler<Widget>(
    renderer: WidgetRenderer(app: (page) => ThorApp(child: page)),
    onError: (request, error, stack) {},
    routes: [
      LayoutRoute<Widget, void>(
        build: (state, child) =>
            Column(children: [const _CurrentPath(), child]),
        meta: (state) => const PageMeta(title: 'Site'),
        error: (e) => Text('Oops ${e.status}'),
        children: [
          PageRoute<Widget, String>(
            path: 'article/[slug]',
            load: (r) => r.pathParameters['slug']!,
            meta: (s) => PageMeta(
              title: s.data,
              description: 'About ${s.data}',
              properties: {'og:title': s.data},
              canonical: RouteUrl.external(
                'https://site.test/article/${s.data}',
              ),
            ),
            build: (s) => Form(
              // The string form still works (deprecated path).
              // ignore: thor_lints/untyped_form_action
              action: '?/comment',
              child: Column(
                children: [
                  Text('Article ${s.data}'),
                  const HiddenField(name: 'id', value: '7'),
                  FilledButton(
                    onPressed: () {},
                    buttonType: ButtonType.submit,
                    child: const Text('Post'),
                  ),
                ],
              ),
            ),
            actions: {'comment': (r) => null},
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

  test('renders a routed widget page as a full document', () async {
    final r = await handler.handle(get('/article/hello'));
    expect(r.status, 200);
    final html = r.text;
    expect(html, startsWith('<!DOCTYPE html>'));
    expect(html, contains('<title>hello</title>'));
    expect(html, contains('name="description" content="About hello"'));
    expect(html, contains('property="og:title" content="hello"'));
    expect(
      html,
      matches(
        RegExp(r'<link href="https://site.test/article/hello" rel="canonical"'),
      ),
    );
    expect(html, contains('at /article/hello'));
    expect(html, contains('Article hello'));
    expect(html, matches(RegExp(r'<form[^>]*action="\?/comment"')));
    expect(html, contains('type="hidden" name="id" value="7"'));
    expect(html, matches(RegExp(r'<button[^>]*type="submit"')));
    // The page's generated stylesheet is in the head.
    expect(html.indexOf('<style'), lessThan(html.indexOf('</head>')));
  });

  test('errors render inside the layout, with its status', () async {
    final r = await handler.handle(get('/missing'));
    expect(r.status, 404);
    expect(r.text, contains('Oops 404'));
    expect(r.text, contains('at /missing'));
  });

  test('user text is escaped', () async {
    final r = await handler.handle(
      get('/article/${Uri.encodeComponent('<script>x</script>')}'),
    );
    expect(r.text, isNot(contains('<script>x')));
    expect(r.text, contains('&lt;script&gt;'));
    expect(utf8.decode(r.body).contains('<title>&lt;script'), isTrue);
  });

  test('Open Graph and JSON-LD: typed, merged by level, escaped', () async {
    final seo = RouteHandler<Widget>(
      renderer: WidgetRenderer(app: (page) => ThorApp(child: page)),
      onError: (request, error, stack) {},
      routes: [
        LayoutRoute<Widget, void>(
          build: (state, child) => child,
          meta: (s) => const PageMeta(
            openGraph: OpenGraph(siteName: 'Conduit', type: 'website'),
            jsonLd: [
              {'@type': 'Organization', 'name': 'Conduit'},
            ],
          ),
          children: [
            PageRoute<Widget, String>(
              path: 'a/[slug]',
              load: (r) => r.pathParameters['slug']!,
              meta: (s) => PageMeta(
                openGraph: OpenGraph(
                  title: s.data,
                  type: 'article',
                  twitterCard: 'summary',
                ),
                properties: const {'og:site_name': 'Override'},
                jsonLd: [
                  {'@type': 'Article', 'headline': s.data},
                ],
              ),
              build: (s) => Text(s.data),
            ),
          ],
        ),
      ],
    );
    final r = await seo.handle(
      get('/a/${Uri.encodeComponent('</script><b>')}'),
    );
    final html = r.text;
    expect(html, contains('property="og:type" content="article"'));
    expect(html, contains('property="og:site_name" content="Override"'));
    expect(html, contains('name="twitter:card" content="summary"'));
    expect(html, contains('"@type":"Organization"'));
    expect(html, contains(r'"headline":"\u003c/script>\u003cb>"'));
    expect(RegExp('application/ld\\+json').allMatches(html), hasLength(2));
    expect(html, isNot(contains('</script><b>')));
  });

  test('og:url and og:image given as a path are made absolute', () async {
    final seo = RouteHandler<Widget>(
      renderer: WidgetRenderer(app: (page) => ThorApp(child: page)),
      onError: (request, error, stack) {},
      routes: [
        PageRoute<Widget, void>(
          path: 'p',
          meta: (s) => const PageMeta(
            openGraph: OpenGraph(url: '/p', image: '/og.png'),
            properties: {'og:video': '/v.mp4'},
          ),
          build: (s) => const Text('p'),
        ),
        PageRoute<Widget, void>(
          path: 'q',
          meta: (s) => const PageMeta(
            openGraph: OpenGraph(image: 'https://cdn.test/og.png'),
          ),
          build: (s) => const Text('q'),
        ),
      ],
    );
    final p = (await seo.handle(get('/p'))).text;
    expect(p, contains('property="og:url" content="http://site.test/p"'));
    expect(
      p,
      contains('property="og:image" content="http://site.test/og.png"'),
    );
    // Only the two that must be absolute.
    expect(p, contains('property="og:video" content="/v.mp4"'));
    final q = (await seo.handle(get('/q'))).text;
    expect(q, contains('content="https://cdn.test/og.png"'));
  });

  test('Open Graph values with quotes, markup, & and emoji are escaped', () async {
    const nasty = 'He said "hi" <b>x</b> & \'y\' \u{1F600}';
    final seo = RouteHandler<Widget>(
      renderer: WidgetRenderer(app: (page) => ThorApp(child: page)),
      onError: (request, error, stack) {},
      routes: [
        PageRoute<Widget, void>(
          path: 'p',
          meta: (s) => const PageMeta(
            title: nasty,
            description: nasty,
            openGraph: OpenGraph(
              title: nasty,
              description: nasty,
              imageAlt: nasty,
              url: '/p?a=1&b="2"',
            ),
          ),
          build: (s) => const Text('p'),
        ),
        PageRoute<Widget, void>(
          path: 'plain',
          meta: (s) => const PageMeta(
            title: 'Plain',
            openGraph: OpenGraph(title: 'Plain', url: '/plain'),
          ),
          build: (s) => const Text('p'),
        ),
      ],
    );
    final p = (await seo.handle(get('/p'))).text;
    expect(p, isNot(contains('<b>x</b>')));
    expect(
      p,
      contains(
        'property="og:title" content="He said &quot;hi&quot; &lt;b&gt;x&lt;/b&gt; &amp; \'y\' \u{1F600}"',
      ),
    );
    expect(p, contains('name="description" content="He said &quot;hi&quot;'));
    expect(
      p,
      contains('property="og:image:alt" content="He said &quot;hi&quot;'),
    );
    expect(
      p,
      contains(
        'property="og:url" content="http://site.test/p?a=1&amp;b=&quot;2&quot;"',
      ),
    );
    // No description: no empty `<meta>` for it.
    final plain = (await seo.handle(get('/plain'))).text;
    expect(plain, isNot(contains('og:description')));
    expect(plain, isNot(contains('name="description"')));
    expect(plain, isNot(contains('content=""')));
  });

  test(
    'an export with a base URL puts its og:url and og:image in the site',
    () async {
      final out = await Directory.systemTemp.createTemp('thor_og_export');
      addTearDown(() => out.delete(recursive: true));
      final seo = RouteHandler<Widget>(
        renderer: WidgetRenderer(app: (page) => ThorApp(child: page)),
        onError: (request, error, stack) {},
        routes: [
          PageRoute<Widget, void>(
            meta: (s) => const PageMeta(
              openGraph: OpenGraph(url: '/', image: '/og.png'),
            ),
            build: (s) => const Text('home'),
          ),
          PageRoute<Widget, void>(
            path: 'guia/x',
            meta: (s) => const PageMeta(
              openGraph: OpenGraph(url: '/guia/x', image: '/og.png'),
            ),
            build: (s) => const Text('x'),
          ),
        ],
      );
      for (final base in [
        'https://thor-docs.vercel.app/',
        'https://x.dev/thor',
      ]) {
        final report = await exportSite(
          seo,
          paths: ['/', '/guia/x'],
          outDir: out.path,
          baseUrl: base,
        );
        final root = base.replaceFirst(RegExp(r'/$'), '');
        expect(report.ok, isTrue, reason: '$base: ${report.failed}');
        final x = File('${out.path}/guia/x.html').readAsStringSync();
        // The same URLs the sitemap lists (no trailing slash, as Vercel's
        // `cleanUrls` serves them), under the prefix when there is one.
        expect(x, contains('property="og:url" content="$root/guia/x"'));
        expect(x, contains('property="og:image" content="$root/og.png"'));
        final home = File('${out.path}/index.html').readAsStringSync();
        expect(home, contains('property="og:url" content="$root/"'));
      }
    },
  );
}
