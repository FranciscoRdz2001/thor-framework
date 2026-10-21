// ignore_for_file: thor_lints/query_builder_reads_data
// The builders here read the data on purpose: that is what is tested.
@TestOn('vm')
library;

// A real bug in a `QueryBuilder` builder (a TypeError that is not a read of
// the data) was swallowed in release during the placeholder pass (dev prints
// THOR-S037). It now reaches the server's `onError`, once per builder, and the
// page that ships is the same.
import 'package:test/test.dart';
import 'package:thor_ui/router.dart';
import 'package:thor_ui/thor_ui.dart';

class _RelState extends ThorState {
  _RelState({super.key});

  // `ssr: false`: the server has no data, so it draws the done state with a
  // placeholder snapshot (the pass under test).
  final items = query(() async => <String>['a'], ssr: false);
}

final _state = _RelState(key: 'rel');

/// The bug: a cast that cannot hold, only when `hasData` (the done state).
class _BuggyPage extends ThorPage<void> {
  const _BuggyPage();

  @override
  Widget build(BuildContext context, PageState<void> state) =>
      QueryBuilder<List<String>>(
        query: _state.items,
        builder: (context, snap) => snap.hasData
            ? Text((Object() as dynamic) as String)
            : const Text('waiting'),
      );
}

/// The expected read: `data!` of a snapshot that has none.
class _ReadsDataPage extends ThorPage<void> {
  const _ReadsDataPage();

  @override
  Widget build(BuildContext context, PageState<void> state) =>
      QueryBuilder<List<String>>(
        query: _state.items,
        builder: (context, snap) =>
            snap.hasData ? Text(snap.data!.join()) : const Text('waiting'),
      );
}

/// A builder inside another's done state, with the bug in the inner one.
class _NestedPage extends ThorPage<void> {
  const _NestedPage();

  @override
  Widget build(BuildContext context, PageState<void> state) =>
      QueryBuilder<List<String>>(
        query: _state.items,
        builder: (context, outer) => outer.hasData
            ? QueryBuilder<List<String>>(
                query: _state.items,
                builder: (context, inner) => inner.hasData
                    ? Text((Object() as dynamic) as String)
                    : const Text('inner waiting'),
              )
            : const Text('outer waiting'),
      );
}

/// One builder whose bug is a bad cast with a message that carries data.
class _MessagePage extends ThorPage<void> {
  const _MessagePage();

  @override
  Widget build(BuildContext context, PageState<void> state) =>
      QueryBuilder<List<String>>(
        query: _state.items,
        builder: (context, snap) => snap.hasData
            ? Text((('secret-4711' as dynamic) as List).join())
            : const Text('waiting'),
      );
}

void main() {
  setUpAll(() {
    ThorState.register({
      _RelState: ThorStateType('RelState', (state) {
        final s = state as _RelState;
        return [...s.items.members('items')];
      }),
    });
  });

  late List<(PageRequest, Object)> reported;
  late RouteHandler<Widget> handler;

  RouteHandler<Widget> make() {
    final app = ThorApp.router(
      routerConfig: ThorRouter([
        ThorRoute('/buggy', const _BuggyPage()),
        ThorRoute('/reads', const _ReadsDataPage()),
        ThorRoute('/nested', const _NestedPage()),
        ThorRoute('/message', const _MessagePage()),
      ]),
    );
    return RouteHandler<Widget>(
      routes: app.routes,
      renderer: WidgetRenderer.router(app),
      onError: (request, error, stack) => reported.add((request, error)),
    );
  }

  Future<String> get(String path) async {
    final r = await handler.handle(
      PageRequest(
        method: HttpMethod.get,
        uri: Uri.parse('http://s.test$path'),
        headers: const {HttpHeader.host: 's.test'},
      ),
    );
    expect(r.status, 200, reason: r.text);
    return r.text;
  }

  setUp(() {
    reported = [];
    handler = make();
  });

  test('release: a real TypeError of a builder reaches onError, once per '
      'builder, and the page is the same', () async {
    final was = ThorDev.enabled;
    ThorDev.enabled = false;
    addTearDown(() => ThorDev.enabled = was);

    final html = await get('/buggy');
    expect(reported, hasLength(1));
    expect(reported.single.$1.uri.path, '/buggy');
    expect(reported.single.$2, isA<TypeError>());
    // What ships is unchanged: the done state is left out, the waiting
    // one is the page.
    expect(html, contains('waiting'));
    expect(html, isNot(contains('data-tp-2')));

    await get('/buggy');
    await get('/buggy');
    expect(reported, hasLength(1), reason: 'once per builder, not per request');
  });

  test('release: a read of the data (data!) is expected and is not '
      'reported', () async {
    final was = ThorDev.enabled;
    ThorDev.enabled = false;
    addTearDown(() => ThorDev.enabled = was);
    final html = await get('/reads');
    expect(reported, isEmpty);
    expect(html, contains('waiting'));
  });

  test('release: a bug in a builder nested in another builder\'s done state is '
      'reported too', () async {
    final was = ThorDev.enabled;
    ThorDev.enabled = false;
    addTearDown(() => ThorDev.enabled = was);
    await get('/nested');
    await get('/nested');
    expect(
      reported.map((r) => r.$2.runtimeType.toString()),
      equals(['_TypeError']),
      reason: 'the inner bug, once (a second request adds none)',
    );
  });

  test('release: what is reported is the error as thrown, once, and the '
      'page carries none of its message', () async {
    final was = ThorDev.enabled;
    ThorDev.enabled = false;
    addTearDown(() => ThorDev.enabled = was);
    final html = await get('/message');
    expect(reported, hasLength(1));
    expect(reported.single.$2, isA<TypeError>());
    expect(html, isNot(contains('secret-4711')));
  });
}
