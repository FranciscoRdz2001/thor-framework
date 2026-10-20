import 'package:test/test.dart';
import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

/// Draws the visitor's `theme` cookie while the page builds (after the
/// page cache looked the page up).
class _ThemeLabel extends StatelessWidget {
  const _ThemeLabel();

  @override
  Widget build(BuildContext context) =>
      Text('theme:${RequestScope.of(context).cookies['theme'] ?? 'light'}');
}

void main() {
  late int plainLoads;
  late RouteHandler<Widget> handler;

  setUp(() {
    plainLoads = 0;
    handler = RouteHandler<Widget>(
      renderer: WidgetRenderer(app: (page) => ThorApp(child: page)),
      onError: (request, error, stack) {},
      routes: [
        PageRoute<Widget, String>(
          path: 'store',
          cache: const Duration(minutes: 5),
          load: (request) => request.cookies['store'] ?? 'none',
          build: (s) => Text('store:${s.data}'),
        ),
        PageRoute<Widget, void>(
          path: 'theme',
          cache: const Duration(minutes: 5),
          build: (_) => const _ThemeLabel(),
        ),
        PageRoute<Widget, int>(
          path: 'plain',
          cache: const Duration(minutes: 5),
          load: (_) => ++plainLoads,
          build: (s) => Text('plain:${s.data}'),
        ),
      ],
    );
  });

  Future<ThorResponse> get(String path, [String? cookie]) => handler.handle(
    PageRequest(
      method: HttpMethod.get,
      uri: Uri.parse('http://site.test$path'),
      headers: {HttpHeader.host: 'site.test', HttpHeader.cookie: ?cookie},
    ),
  );

  test('a load that reads request.cookies keeps the page out of the shared '
      'cache', () async {
    final a = await get('/store', 'store=madrid');
    expect(a.text, contains('store:madrid'));
    expect(a.headers['cache-control'], 'private, no-cache');
    final b = await get('/store', 'store=lima');
    expect(b.text, contains('store:lima'));
    // A visitor without the cookie gets neither one's page.
    final c = await get('/store');
    expect(c.text, contains('store:none'));
    expect(handler.cachedPaths, [endsWith('/store')]);
    // And the guest copy never reaches a visitor with the cookie.
    final d = await get('/store', 'store=quito');
    expect(d.text, contains('store:quito'));
  });

  test('a widget that reads a cookie while it draws makes the page the '
      'visitor\'s', () async {
    final dark = await get('/theme', 'theme=dark');
    expect(dark.text, contains('theme:dark'));
    expect(dark.headers['cache-control'], 'private, no-cache');
    expect(handler.cachedPaths, isEmpty);
    final guest = await get('/theme');
    expect(guest.text, contains('theme:light'));
    expect(guest.headers['cache-control'], 'no-cache');
  });

  test(
    'the framework\'s own cookie reads keep a page cached for everyone',
    () async {
      // The flash and persisted-state reads of the renderer see these
      // cookies, but the page itself reads none.
      final first = await get('/plain', 'theme=dark; store=lima');
      final second = await get('/plain');
      expect(first.text, contains('plain:1'));
      expect(second.text, contains('plain:1'));
      expect(first.headers['cache-control'], 'no-cache');
      expect(plainLoads, 1);
    },
  );
}
