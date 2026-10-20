import 'package:test/test.dart';
import 'package:thor_engine/thor_engine.dart' as engine;
import 'package:thor_server/thor_server.dart' as server;
import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

// The member list thor generates for [LayoutState], by hand (tests don't run the build).
abstract class _LayoutStateMembers extends ThorState {
  @override
  String get $type => 'LayoutState';

  @override
  List<ThorMember> get $members {
    final s = this as LayoutState;
    return [
      ThorMember.state('collapsed', s.collapsed),
      ThorMember(
        'isCollapsed',
        s.isCollapsed,
        call: (_) => s.isCollapsed(),
        variants: const [false, true],
      ),
      ThorMember('toggle', s.toggle, call: (_) => s.toggle()),
    ];
  }
}

class LayoutState extends _LayoutStateMembers {
  final collapsed = state(false, cookie: 'sidebar');

  bool isCollapsed() => collapsed.value;
  void toggle() => collapsed.value = !collapsed.value;
}

abstract class _SearchStateMembers extends ThorState {
  @override
  String get $type => 'SearchState';

  @override
  List<ThorMember> get $members {
    final s = this as SearchState;
    return [
      ThorMember.state('text', s.text),
      ThorMember('shown', s.shown, call: (_) => s.shown()),
    ];
  }
}

class SearchState extends _SearchStateMembers {
  final text = state('', cookie: 'search');

  String shown() => text.value;
}

final layout = LayoutState();
final search = SearchState();

void main() {
  final handler = RouteHandler<Widget>(
    renderer: WidgetRenderer(app: (page) => ThorApp(child: page)),
    onError: (request, error, stack) {},
    routes: [
      PageRoute<Widget, void>(
        cache: const Duration(minutes: 5),
        build: (_) => Column(
          children: [
            Watch(
              layout.isCollapsed,
              builder: (collapsed) =>
                  Text(collapsed ? 'Menu collapsed' : 'Menu open'),
            ),
            Watch(search.shown, builder: (v) => Text('Search [$v]')),
            FilledButton(
              onPressed: layout.toggle,
              child: const Text('Collapse'),
            ),
          ],
        ),
      ),
    ],
  );

  Future<(String, Map<String, String>)> get([String? cookie]) async {
    final r = await handler.handle(
      PageRequest(
        method: HttpMethod.get,
        uri: Uri.parse('http://site.test/'),
        headers: {HttpHeader.host: 'site.test', HttpHeader.cookie: ?cookie},
      ),
    );
    return (r.text, r.headers);
  }

  test('the page draws with the persisted state: no flash on reload', () async {
    final (html, headers) = await get('thor-s.sidebar=true');
    expect(html, contains('Menu collapsed'));
    // The engine starts from the same value.
    expect(html, contains('"LayoutState.collapsed":true'));
    // The visitor's page: never the shared page cache.
    expect(headers['cache-control'], 'private, no-cache');
  });

  test('without the cookie, or with a bad one, the code\'s value', () async {
    for (final cookie in [
      null,
      'thor-s.sidebar=%22yes%22',
      'thor-s.sidebar=',
    ]) {
      final (html, _) = await get(cookie);
      expect(html, contains('Menu open'), reason: cookie);
      expect(html, isNot(contains('LayoutState.collapsed')), reason: cookie);
    }
  });

  test(
    'one visitor\'s persisted state never reaches another\'s page',
    () async {
      final (first, _) = await get('thor-s.sidebar=true');
      final (second, _) = await get();
      expect(first, contains('Menu collapsed'));
      expect(second, contains('Menu open'));
      // The guest's page is in the shared cache now: a visitor with the
      // cookie still gets their own.
      final (third, _) = await get('thor-s.sidebar=true');
      expect(third, contains('Menu collapsed'));
    },
  );

  test('the cookie is decoded once: a value with % reads as written', () async {
    // The engine writes encodeURIComponent(JSON.stringify(value)); the
    // request's cookies are already decoded once.
    for (final value in ['50%', 'a%41']) {
      final cookie = Uri.encodeComponent('"$value"');
      final (html, _) = await get('thor-s.search=$cookie');
      expect(html, contains('Search [$value]'), reason: value);
    }
  });

  test('the engine and the server name the cookie alike', () {
    expect(
      server.persistedStateCookiePrefix,
      engine.persistedStateCookiePrefix,
    );
  });
}
