// `PageRequest.loaded<D>()`: what the loads returned, for the code that only
// reaches the request with `PageRequest.current` (a query function,
// `events(initial:)`). Set once every load settled, before the page draws.
import 'dart:convert';

import 'package:test/test.dart';
import 'package:thor_server/thor_server.dart';

class _Doc {
  const _Doc(this.title);
  final String title;
}

class _Shell {
  const _Shell(this.name);
  final String name;
}

/// Draws `title` of the page's data, the way a query's function would read
/// it from the request.
class _Renderer implements PageRenderer<String> {
  final seen = <String>[];

  @override
  List<int> render(String page, RenderContext context) {
    final r = context.request;
    seen
      ..add(r.loaded<_Doc>().title)
      ..add(r.loaded<_Shell>().name);
    try {
      r.loaded<int>();
    } on StateError catch (e) {
      seen.add('${e.message.contains('THOR-P037')}');
    }
    return utf8.encode(page);
  }

  @override
  String errorPage(ErrorState state) => 'error ${state.status}';
}

PageRequest _get() => PageRequest(
  method: HttpMethod.get,
  uri: Uri.parse('http://site.test/'),
  headers: {HttpHeader.host: 'site.test'},
  body: const Stream.empty(),
);

void main() {
  test('the page and its layouts data are there when the page draws', () async {
    final renderer = _Renderer();
    final handler = RouteHandler<String>(
      renderer: renderer,
      routes: [
        LayoutRoute<String, _Shell>(
          load: (_) async => const _Shell('shell'),
          build: (state, child) => child,
          children: [
            PageRoute<String, _Doc>(
              load: (_) async => const _Doc('draft'),
              build: (_) => 'home',
            ),
          ],
        ),
      ],
    );
    final response = await handler.handle(_get());
    expect(response.status, 200);
    expect(renderer.seen, ['draft', 'shell', 'true']);
  });

  test('outside a render nothing was loaded: THOR-P037', () {
    final request = _get();
    expect(
      () => request.loaded<_Doc>(),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          allOf(contains('THOR-P037'), contains('no loaded data')),
        ),
      ),
    );
    request.setLoaded(const [_Shell('a')]);
    expect(
      () => request.loaded<_Doc>(),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          allOf(contains('THOR-P037'), contains('_Shell')),
        ),
      ),
    );
  });

  test('the nearest level wins when two loads return a D', () {
    final request = _get()
      ..setLoaded(const [_Doc('layout'), _Shell('s'), _Doc('page')]);
    expect(request.loaded<_Doc>().title, 'page');
    expect(request.loaded<_Shell>().name, 's');
  });
}
