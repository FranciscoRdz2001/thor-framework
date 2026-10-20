import 'dart:convert';

import 'package:test/test.dart';
import 'package:thor_server/thor_server.dart';

class _Renderer implements PageRenderer<String> {
  @override
  List<int> render(String page, RenderContext context) => utf8.encode(page);

  @override
  String errorPage(ErrorState state) => 'error ${state.status}';
}

PageRequest _get(String path, [String? cookie]) => PageRequest(
  method: HttpMethod.get,
  uri: Uri.parse('http://site.test$path'),
  headers: {HttpHeader.host: 'site.test', HttpHeader.cookie: ?cookie},
);

void main() {
  late int loads;
  late RouteHandler<String> handler;

  setUp(() {
    loads = 0;
    handler = RouteHandler<String>(
      renderer: _Renderer(),
      onError: (request, error, stack) {},
      routes: [
        PageRoute<String, String>(
          path: 'store',
          cache: const Duration(minutes: 5),
          load: (request) {
            loads++;
            return request.cookies['store'] ?? 'none';
          },
          build: (s) => 'store:${s.data}',
        ),
        PageRoute<String, int>(
          path: 'plain',
          cache: const Duration(minutes: 5),
          load: (_) => ++loads,
          build: (s) => 'plain:${s.data}',
        ),
        PageRoute<String, String>(
          path: 'all',
          cache: const Duration(minutes: 5),
          load: (request) => request.cookies.keys.join(','),
          build: (s) => 'all:${s.data}',
        ),
      ],
    );
  });

  test('a page that reads a cookie the visitor sent is theirs', () async {
    final r = await handler.handle(_get('/store', 'store=madrid'));
    expect(r.text, 'store:madrid');
    expect(r.headers['cache-control'], 'private, no-cache');
    expect(handler.cachedPaths, isEmpty);
    // The next visitor gets their own page, never the one before.
    final other = await handler.handle(_get('/store', 'store=lima'));
    expect(other.text, 'store:lima');
    expect(handler.cachedPaths, isEmpty);
  });

  test('a visitor without the cookie shares the page, only with visitors '
      'without it', () async {
    final guest = await handler.handle(_get('/store'));
    expect(guest.text, 'store:none');
    expect(guest.headers['cache-control'], 'no-cache');
    expect(handler.cachedPaths, contains(endsWith('/store')));
    // Another guest (other cookies are fine): the stored page.
    final again = await handler.handle(_get('/store', 'theme=dark'));
    expect(again.text, 'store:none');
    expect(loads, 1);
    // A visitor with the cookie: drawn for them, the guest copy kept.
    final mine = await handler.handle(_get('/store', 'store=lima'));
    expect(mine.text, 'store:lima');
    expect(mine.headers['cache-control'], 'private, no-cache');
    expect(loads, 2);
    final guestAgain = await handler.handle(_get('/store'));
    expect(guestAgain.text, 'store:none');
    expect(loads, 2);
  });

  test('a page that reads no cookie is cached for everyone', () async {
    final first = await handler.handle(_get('/plain', 'store=madrid'));
    final second = await handler.handle(_get('/plain', 'store=lima'));
    expect(first.text, 'plain:1');
    expect(second.text, 'plain:1');
    expect(first.headers['cache-control'], 'no-cache');
    expect(loads, 1);
  });

  test('looking at every cookie: shared only while there are none', () async {
    final none = await handler.handle(_get('/all'));
    expect(none.text, 'all:');
    expect(handler.cachedPaths, contains(endsWith('/all')));
    final some = await handler.handle(_get('/all', 'a=1; b=2'));
    expect(some.text, 'all:a,b');
    expect(some.headers['cache-control'], 'private, no-cache');
  });

  test('the framework\'s own cookie reads keep the page cacheable', () async {
    var renders = 0;
    final h = RouteHandler<String>(
      renderer: _Renderer(),
      onError: (request, error, stack) {},
      locales: LocaleRouting(
        supportedLocales: const [Locale('en'), Locale('es')],
        strategy: LocaleStrategy.negotiate,
      ),
      routes: [
        PageRoute<String, void>(
          path: 'about',
          cache: const Duration(minutes: 5),
          build: (s) => 'about ${++renders} ${s.request.locale}',
        ),
      ],
    );
    final first = await h.handle(_get('/about', 'locale=es'));
    final second = await h.handle(_get('/about', 'locale=es'));
    expect(first.text, 'about 1 es');
    expect(second.text, 'about 1 es');
    expect(first.headers['cache-control'], isNot(contains('private')));
    expect(h.cachedPaths, isNotEmpty);
  });
}
