import 'dart:async';
import 'dart:convert';

import 'package:test/test.dart';
import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

class _User {
  const _User(this.name);
  final String name;
}

// A layout with data: seen as a `ThorLayout<Object?>` by the Group, it must
// still build with its own `PageState<_User>`.
class _SiteLayout extends ThorLayout<_User> {
  const _SiteLayout() : super(personalized: false);

  @override
  _User load(PageRequest request) => const _User('ana');

  @override
  PageMeta meta(PageState<_User> state) =>
      PageMeta(title: 'Site of ${state.data.name}', titleTemplate: '%s · Site');

  @override
  Widget build(BuildContext context, PageState<_User> state, Widget child) =>
      Column(children: [Text('hi ${state.data.name}'), child]);
}

class _ArticlePage extends ThorPage<String> {
  const _ArticlePage() : super(cache: const Duration(seconds: 30));

  @override
  Future<String> load(PageRequest request) async {
    final user = await request.parent<_User>();
    return '${request.param('slug')} for ${user.name}';
  }

  @override
  PageMeta meta(PageState<String> state) => PageMeta(title: state.data);

  Future<ActionResult?> like(PageRequest request) async =>
      const ActionResult.fail(422, 'no');

  @override
  Widget build(BuildContext context, PageState<String> state) =>
      Text('article ${state.data} ${state.form ?? ''}');
}

class _ItemPage extends ThorPage<int> {
  const _ItemPage();

  @override
  int load(PageRequest request) => request.paramInt('id') * 2;

  @override
  Widget build(BuildContext context, PageState<int> state) =>
      Text('item ${state.data}');
}

class _PlainPage extends ThorPage<void> {
  const _PlainPage();

  @override
  Widget build(BuildContext context, PageState<void> state) =>
      const Text('plain');
}

class _GuardedPage extends ThorPage<void> {
  const _GuardedPage();

  @override
  FutureOr<RouteUrl?> redirect(PageRequest request) =>
      RouteUrl(plainRoute.path);

  @override
  Widget build(BuildContext context, PageState<void> state) =>
      const Text('never');
}

class _MovedPage extends ThorPage<void> {
  const _MovedPage();

  @override
  FutureOr<RouteUrl?> redirect(PageRequest request) =>
      throw const Redirect.permanent(RouteUrl('/plain'));

  @override
  Widget build(BuildContext context, PageState<void> state) =>
      const Text('never');
}

class _UploadPage extends ThorPage<void> {
  const _UploadPage() : super(maxBodyBytes: 5000);

  Future<ActionResult?> upload(PageRequest request) async {
    await request.bytes();
    return null;
  }

  @override
  Widget build(BuildContext context, PageState<void> state) =>
      const Text('upload');
}

class _SlidePage extends ThorPage<void> {
  const _SlidePage() : super(transition: const PageTransition.slide());

  @override
  Widget build(BuildContext context, PageState<void> state) =>
      const Text('slide');
}

class _FadeLayout extends ThorLayout<void> {
  const _FadeLayout() : super(transition: const PageTransition.fadeUp());

  @override
  Widget build(BuildContext context, PageState<void> state, Widget child) =>
      child;
}

class _UserLayout extends ThorLayout<String> {
  const _UserLayout();

  @override
  String load(PageRequest request) => request.param('user');

  @override
  Widget build(BuildContext context, PageState<String> state, Widget child) =>
      Column(children: [Text('user ${state.data}'), child]);
}

class _ForgotLoad extends ThorPage<String> {
  const _ForgotLoad();

  @override
  Widget build(BuildContext context, PageState<String> state) =>
      Text(state.data);
}

final plainRoute = ThorRoute('/plain', const _PlainPage());
final articleRoute = ThorRoute('/article/:slug', const _ArticlePage());
final itemRoute = ThorRoute('/item/:id:int', const _ItemPage());
final docsRoute = ThorRoute('/docs/*rest', const _PlainPage());

final visits = <String>[];

class _LostPage extends ErrorPage {
  const _LostPage();

  @override
  Widget build(BuildContext context, ErrorState state) =>
      Text('lost ${state.status}');
}

class _TitledLostPage extends ErrorPage {
  const _TitledLostPage();

  @override
  Widget build(BuildContext context, ErrorState state) => const Text('titled');

  @override
  PageMeta meta(ErrorState state) => PageMeta(
    title: 'Not found (${state.status})',
    description: 'No such page.',
  );
}

class _NoUserPage extends ErrorPage {
  const _NoUserPage();

  @override
  Widget build(BuildContext context, ErrorState state) =>
      Text('no ${state.request.param('user')}');
}

class _NoItemPage extends ErrorPage {
  const _NoItemPage();

  @override
  Widget build(BuildContext context, ErrorState state) => const Text('no item');
}

final ThorRouter router = ThorRouter([
  Group(
    layout: const _SiteLayout(),
    notFound: const _LostPage(),
    children: [
      plainRoute,
      articleRoute,
      itemRoute,
      docsRoute,
      ThorRoute('/guarded', const _GuardedPage()),
      ThorRoute('/moved', const _MovedPage()),
      ThorRoute('/upload', const _UploadPage()),
      Group(
        middleware: [
          (request, next) async {
            visits.add(request.uri.path);
            return next();
          },
        ],
        personalized: true,
        children: [ThorRoute('/forgot', const _ForgotLoad())],
      ),
    ],
  ),
  SitemapRoute(
    (request) => Sitemap([
      for (final path in router.staticPaths) SitemapUrl('https://s.test$path'),
    ]),
  ),
]);

void main() {
  registerPageActions({
    _ArticlePage: [
      PageActionMethod.request('like', (p) => (p as _ArticlePage).like),
    ],
    _UploadPage: [
      PageActionMethod.request('upload', (p) => (p as _UploadPage).upload),
    ],
  });
  final handler = RouteHandler<Widget>(
    renderer: WidgetRenderer(app: (page) => ThorApp(child: page)),
    onError: (request, error, stack) {},
    routes: router.routes,
  );

  PageRequest request(String method, String path) => PageRequest(
    method: HttpMethod.tryParse(method)!,
    uri: Uri.parse('http://site.test$path'),
    headers: {
      HttpHeader.host: 'site.test',
      if (method == 'POST') ...{
        HttpHeader.origin: 'http://site.test',
        HttpHeader.contentType: 'application/x-www-form-urlencoded',
      },
    },
    body: method == 'POST' ? Stream.value(utf8.encode('')) : null,
  );

  group('the table serves', () {
    test('a page with data, its layout data and parent<T>()', () async {
      final r = await handler.handle(request('GET', '/article/hello'));
      expect(r.status, 200);
      expect(r.text, contains('hi ana'));
      expect(r.text, contains('article hello for ana'));
      expect(r.text, contains('<title>hello for ana · Site</title>'));
    });

    test('a page without data inside the layout', () async {
      final r = await handler.handle(request('GET', '/plain'));
      expect(r.status, 200);
      expect(r.text, contains('plain'));
      expect(r.text, contains('<title>Site of ana</title>'));
    });

    test(
      ':id:int: an int reaches load; anything else is a 404 first',
      () async {
        final ok = await handler.handle(request('GET', '/item/21'));
        expect(ok.text, contains('item 42'));
        final bad = await handler.handle(request('GET', '/item/abc'));
        expect(bad.status, 404);
        expect(bad.text, contains('lost 404'));
      },
    );

    test('actions and redirect work like the functions did', () async {
      final posted = await handler.handle(request('POST', '/article/x?/like'));
      expect(posted.status, 422);
      expect(posted.text, contains('article x for ana no'));
      final guarded = await handler.handle(request('GET', '/guarded'));
      expect(guarded.status, 302);
      expect(guarded.headers['location'], '/plain');
    });

    test('a guard can throw a Redirect to choose the status', () async {
      final moved = await handler.handle(request('GET', '/moved'));
      expect(moved.status, 308);
      expect(moved.headers['location'], '/plain');
    });

    test('a page can raise its own body limit', () async {
      PageRequest post(String path, int n) => PageRequest(
        method: HttpMethod.post,
        uri: Uri.parse('http://site.test$path'),
        headers: {
          HttpHeader.host: 'site.test',
          HttpHeader.origin: 'http://site.test',
          HttpHeader.contentType: 'text/plain',
        },
        body: Stream.value(List.filled(n, 97)),
      );
      expect((await handler.handle(post('/upload', 3 << 20))).status, 413);
      expect((await handler.handle(post('/upload', 5000))).status, 303);
      expect((await handler.handle(post('/upload', 5001))).status, 413);
    });

    test('a nested group runs its middleware only for its pages', () async {
      visits.clear();
      await handler.handle(request('GET', '/plain'));
      await handler.handle(request('GET', '/forgot'));
      expect(visits, ['/forgot']);
    });

    test('a ThorPage<String> without load says so (THOR-P013)', () async {
      final errors = <Object>[];
      final strict = RouteHandler<Widget>(
        renderer: WidgetRenderer(app: (page) => ThorApp(child: page)),
        onError: (request, error, stack) => errors.add(error),
        routes: router.routes,
      );
      final r = await strict.handle(request('GET', '/forgot'));
      expect(r.status, 500);
      expect('${errors.single}', contains('THOR-P013'));
      expect(
        '${errors.single}',
        contains('_ForgotLoad extends ThorPage<String>'),
      );
    });

    test('the sitemap lists the routes without parameters', () async {
      final r = await handler.handle(request('GET', '/sitemap.xml'));
      expect(r.status, 200);
      expect(r.text, contains('<loc>https://s.test/plain</loc>'));
      expect(r.text, isNot(contains(':slug')));
    });
  });

  group('settings', () {
    test('from the page class and the group reach the router', () {
      final article = router.routes.whereType<LayoutRoute<Widget, Object?>>();
      expect(article, hasLength(1));
      final layout = article.single;
      final page = layout.children
          .whereType<PageRoute<Widget, Object?>>()
          .firstWhere((p) => p.path == 'article/[slug]');
      expect(page.cache, const Duration(seconds: 30));
      final nested = layout.children
          .whereType<LayoutRoute<Widget, Object?>>()
          .single;
      expect(nested.personalized, isTrue);
    });

    test('a page without data has no load', () {
      final plain = router.routes
          .whereType<LayoutRoute<Widget, Object?>>()
          .single
          .children
          .whereType<PageRoute<Widget, Object?>>()
          .firstWhere((p) => p.path == 'plain');
      expect(plain.load, isNull);
    });
  });

  group('links', () {
    test('fill and encode each parameter', () {
      expect(plainRoute.link(), '/plain');
      expect(articleRoute.link({'slug': 'a b/c'}), '/article/a%20b%2Fc');
      expect(itemRoute.link({'id': 7}), '/item/7');
      expect(docsRoute.link({'rest': 'guia/a b'}), '/docs/guia/a%20b');
      expect(
        articleRoute.link({'slug': 'x'}, {'page': '2'}),
        '/article/x?page=2',
      );
      expect(ThorRoute('/', const _PlainPage()).link(), '/');
    });

    test('query values round-trip through queryParametersAll', () {
      final tricky = {
        'a&b=c#d': [
          'x&y',
          '=',
          '#frag',
          'caf\u00e9 \u{1F600}',
          '',
          '100%',
          '+',
        ],
        'k é': ['%20', 'a b'],
        'dup': ['same', 'same'],
        'one': 'single',
      };
      final url = articleRoute.link({'slug': 'x'}, tricky);
      final uri = Uri.parse('http://site.test$url');
      expect(uri.fragment, '');
      expect(uri.queryParametersAll, {
        'a&b=c#d': tricky['a&b=c#d'],
        'k é': ['%20', 'a b'],
        'dup': ['same', 'same'],
        'one': ['single'],
      });
      // queryParameters is still last-wins.
      expect(uri.queryParameters['dup'], 'same');
      expect(uri.queryParameters['k é'], 'a b');
      // A Set keeps its iteration order; a huge list loses nothing.
      final set = {'z', 'a', 'm'};
      expect(
        Uri.parse(
          articleRoute.link({'slug': 'x'}, {'s': set}),
        ).queryParametersAll['s'],
        ['z', 'a', 'm'],
      );
      final huge = [for (var i = 0; i < 20000; i++) 'v$i'];
      expect(
        Uri.parse(
          articleRoute.link({'slug': 'x'}, {'h': huge}),
        ).queryParametersAll['h'],
        huge,
      );
      // An empty value keeps its key.
      expect(
        Uri.parse(
          articleRoute.link({'slug': 'x'}, {'e': ''}),
        ).queryParametersAll,
        {
          'e': [''],
        },
      );
      // A null inside the list is a clear error, not "null" in the URL.
      expect(
        () => articleRoute.link(
          {'slug': 'x'},
          {
            'f': <String?>['a', null],
          },
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('a query value can repeat a key', () {
      expect(
        articleRoute.link(
          {'slug': 'x'},
          {
            'f': ['a', 'b c'],
            'page': '2',
          },
        ),
        '/article/x?f=a&f=b+c&page=2',
      );
      // An empty list writes nothing; a map of only those has no `?`.
      expect(articleRoute.link({'slug': 'x'}, {'f': <String>[]}), '/article/x');
      // A Map<String, String> still fits (the type only widened).
      final Map<String, String> plain = {'q': 'z'};
      expect(articleRoute.link({'slug': 'x'}, plain), '/article/x?q=z');
      expect(
        () => articleRoute.link({'slug': 'x'}, {'f': 3}),
        throwsA(isA<ArgumentError>()),
      );
      expect(router.staticPaths, [
        '/plain',
        '/guarded',
        '/moved',
        '/upload',
        '/forgot',
      ]);
    });

    test('a missing, unknown or mistyped parameter is THOR-P014', () {
      Matcher p014(String text) => throwsA(
        isA<ArgumentError>().having(
          (e) => '${e.message}',
          'message',
          allOf(contains('THOR-P014'), contains(text)),
        ),
      );
      expect(articleRoute.link, p014('needs :slug'));
      expect(
        () => articleRoute.link({'slug': 'x', 'id': 1}),
        p014('has no :id'),
      );
      expect(() => itemRoute.link({'id': '7'}), p014('is an int'));
      expect(() => articleRoute.link({'slug': 3}), p014('is a String'));
    });
  });

  group('patterns', () {
    Matcher bad(String text) => throwsA(
      isA<ArgumentError>().having(
        (e) => '${e.message}',
        'message',
        allOf(contains('THOR-P014'), contains(text)),
      ),
    );

    test('a malformed path is rejected where the table is written', () {
      expect(
        () => ThorRoute('plain', const _PlainPage()),
        bad('starts with /'),
      );
      expect(
        () => ThorRoute('/a//b', const _PlainPage()),
        bad('empty segment'),
      );
      expect(() => ThorRoute('/:a/:a', const _PlainPage()), bad(':a twice'));
      expect(
        () => ThorRoute('/*r/x', const _PlainPage()),
        bad('must be the last'),
      );
      expect(
        () => ThorRoute('/:id:uuid', const _PlainPage()),
        bad('the only parameter type'),
      );
      expect(() => ThorRoute('/(app)/x', const _PlainPage()), bad('static'));
      expect(() => ThorRoute('/:1x', const _PlainPage()), bad('identifier'));
    });

    test('a resource route belongs at the top level', () {
      expect(
        () => ThorRouter([
          Group(children: [SitemapRoute((r) => const Sitemap([]))]),
        ]),
        bad('top level'),
      );
    });

    test('two routes for one URL are THOR-P001', () {
      expect(
        () => RouteHandler<Widget>(
          renderer: WidgetRenderer(),
          routes: ThorRouter([
            ThorRoute('/a/:x', const _PlainPage()),
            ThorRoute('/a/:y', const _PlainPage()),
          ]).routes,
        ),
        throwsA(predicate((e) => '$e'.contains('THOR-P001'))),
      );
    });
  });

  test("a class's transition: the page's over its layout's", () async {
    final table = ThorRouter([
      Group(
        layout: const _FadeLayout(),
        children: [
          ThorRoute('/slide', const _SlidePage()),
          ThorRoute('/plain', const _PlainPage()),
        ],
      ),
    ]);
    final h = RouteHandler<Widget>(
      renderer: WidgetRenderer(
        app: (page) => ThorApp(
          navigation: const PageNavigation(viewTransition: true),
          child: page,
        ),
      ),
      routes: table.routes,
    );
    final slide = (await h.handle(request('GET', '/slide'))).text;
    expect(slide, contains(const PageTransition.slide().css));
    expect(slide, isNot(contains('t-vt-fade-up')));
    final plain = (await h.handle(request('GET', '/plain'))).text;
    expect(plain, contains(const PageTransition.fadeUp().css));
  });

  test('an error page sets its own title and description', () async {
    final table = ThorRouter([
      Group(
        prefix: '/item',
        notFound: const _TitledLostPage(),
        children: [ThorRoute('/item/:id:int', const _PlainPage())],
      ),
    ]);
    final h = RouteHandler<Widget>(
      renderer: WidgetRenderer(),
      routes: table.routes,
    );
    final r = await h.handle(request('GET', '/item/abc'));
    expect(r.status, 404);
    expect(r.text, contains('<title>Not found (404)</title>'));
    expect(r.text, contains('content="No such page."'));
  });

  test(
    "a group's 404 owns its routes' shared URL, parameters included",
    () async {
      final table = ThorRouter([
        Group(
          layout: const _UserLayout(),
          notFound: const _NoUserPage(),
          children: [
            ThorRoute('/profile/:user', const _PlainPage()),
            ThorRoute('/profile/:user/favorites', const _PlainPage()),
          ],
        ),
        Group(
          prefix: '/item',
          notFound: const _NoItemPage(),
          children: [ThorRoute('/item/:id:int', const _PlainPage())],
        ),
      ]);
      final h = RouteHandler<Widget>(
        renderer: WidgetRenderer(),
        routes: table.routes,
      );
      final nested = await h.handle(request('GET', '/profile/ana/nope'));
      expect(nested.status, 404);
      expect(nested.text, allOf(contains('no ana'), contains('user ana')));
      final item = await h.handle(request('GET', '/item/abc'));
      expect((item.status, item.text.contains('no item')), (404, true));
      expect(
        () => ThorRouter([
          Group(
            prefix: '/other',
            children: [ThorRoute('/item', const _PlainPage())],
          ),
        ]),
        throwsA(predicate((e) => '$e'.contains('THOR-P014'))),
      );
    },
  );

  test('request.param names a parameter the route has (THOR-P015)', () {
    final r = PageRequest(
      method: HttpMethod.get,
      uri: Uri.parse('http://s.test/x'),
      headers: const {HttpHeader.host: 's.test'},
    )..pathParameters = {'slug': 'x'};
    expect(r.param('slug'), 'x');
    expect(
      () => r.param('id'),
      throwsA(predicate((e) => '$e'.contains('THOR-P015'))),
    );
    expect(
      () => (r..pathParameters = {'id': 'x'}).paramInt('id'),
      throwsA(isA<NotFound>()),
    );
  });
}
