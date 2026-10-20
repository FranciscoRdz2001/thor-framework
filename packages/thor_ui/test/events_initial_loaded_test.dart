@TestOn('vm')
library;

// `events(initial:)` (and any query's function) reads what the page's `load`
// returned with `PageRequest.current.loaded<D>()`: the page draws with a value
// that comes from its data, not from a singleton of the server.
import 'dart:convert';

import 'package:test/test.dart';
import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

class _Doc {
  const _Doc(this.title);
  final String title;
}

class DraftState extends ThorState {
  DraftState({super.key});

  // The page's load, read from the request the query function runs for.
  final draft = events<String>(
    '/draft/stream',
    event: 'draft',
    initial: () => PageRequest.current.loaded<_Doc>().title,
  );
  final other = query(() => PageRequest.current.loaded<_Doc>().title.length);

  String text() => draft.data.value ?? '-';
  String size() => '${other.data.value ?? '-'}';
}

class _DraftPage extends ThorPage<_Doc> {
  const _DraftPage();

  @override
  Future<_Doc> load(PageRequest request) async =>
      _Doc('draft of ${request.uri.queryParameters['who'] ?? 'nobody'}');

  @override
  Widget build(BuildContext context, PageState<_Doc> state) {
    final s = DraftState();
    return Column(
      children: [
        Text('page ${state.data.title}'),
        Watch(s.text),
        Watch(s.size),
      ],
    );
  }
}

void main() {
  setUpAll(
    () => ThorState.register({
      DraftState: ThorStateType('DraftState', (state) {
        final s = state as DraftState;
        return [
          ...s.draft.members('draft'),
          ...s.other.members('other'),
          ThorMember('text', s.text, call: (_) => s.text()),
          ThorMember('size', s.size, call: (_) => s.size()),
        ];
      }),
    }),
  );
  registerPageActions(const {});
  final app = ThorApp.router(
    routerConfig: ThorRouter([ThorRoute('/', const _DraftPage())]),
  );
  final handler = RouteHandler<Widget>(
    routes: app.routes,
    renderer: WidgetRenderer.router(app),
  );

  Future<String> get(String query) async {
    final r = await handler.handle(
      PageRequest(
        method: HttpMethod.get,
        uri: Uri.parse('http://s.test/$query'),
        headers: const {HttpHeader.host: 's.test'},
        body: const Stream.empty(),
      ),
    );
    expect(r.status, 200);
    return utf8.decode(r.body);
  }

  test('initial gets the page data of its own request', () async {
    final a = await get('?who=ana');
    expect(a, contains('page draft of ana'));
    expect(a, contains(r'"DraftState.draft$data":"draft of ana"'));
    // The same function in a `query`.
    expect(a, contains(r'"DraftState.other$data":12'));
    final b = await get('?who=beto');
    expect(b, contains(r'"DraftState.draft$data":"draft of beto"'));
    expect(b, isNot(contains('draft of ana')));
  });
}
