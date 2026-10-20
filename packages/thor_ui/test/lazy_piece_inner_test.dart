@TestOn('vm')
library;

// What a `LazyPiece` can hold: a `query()` or a `FutureBuilder`
// (waited for in the fragment, like the head of a page), another `LazyPiece`
// (its own fragment, asked for after the outer one arrived).
import 'dart:async';

import 'package:test/test.dart';
import 'package:thor_ui/router.dart';
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

class ShelfState extends ThorState {
  ShelfState({super.key});

  final items = query(() async => <String>['milk', 'eggs']);
}

void main() {
  initializeThorTests();
  setUpAll(
    () => ThorState.register({
      ShelfState: ThorStateType('ShelfState', (state) {
        final s = state as ShelfState;
        return [...s.items.members('items')];
      }),
    }),
  );

  late List<Object> errors;
  var pieceLoads = <String, int>{};

  Widget text(String s) => Text(s);

  RouteHandler<Widget> handler() => RouteHandler<Widget>(
    renderer: WidgetRenderer(app: (page) => ThorApp(child: page)),
    onError: (request, error, stack) => errors.add(error),
    routes: [
      PageRoute<Widget, void>(
        path: 'query',
        build: (s) => LazyPiece<ShelfState>(
          id: 'shelf',
          load: (r) async => ShelfState(key: 'shelf'),
          builder: (context, shelf) => QueryBuilder<List<String>>(
            query: shelf.items,
            builder: (context, snap) =>
                // a fixture: the piece's HTML is read once, with the data
                // ignore: thor_lints/query_builder_reads_data
                Text(snap.hasData ? 'got ${snap.data!.join('+')}' : 'waiting'),
          ),
          fallback: text('fb'),
        ),
      ),
      PageRoute<Widget, void>(
        path: 'future',
        build: (s) => LazyPiece<List<Future<String>>>(
          id: 'f',
          load: (r) async => [
            Future<String>.delayed(
              const Duration(milliseconds: 20),
              () => 'late value',
            ),
          ],
          builder: (context, futures) => FutureBuilder<String>(
            future: futures.single,
            builder: (context, snap) =>
                Text(snap.hasData ? 'done ${snap.data}' : 'skeleton'),
          ),
          fallback: text('fb'),
        ),
      ),
      PageRoute<Widget, void>(
        path: 'failing',
        build: (s) => LazyPiece<List<Future<String>>>(
          id: 'f',
          load: (r) async => [defer(Future<String>.error(StateError('nope')))],
          builder: (context, futures) => FutureBuilder<String>(
            future: futures.single,
            builder: (context, snap) =>
                Text(snap.hasError ? 'oops ${snap.error}' : 'skeleton'),
          ),
          fallback: text('fb'),
        ),
      ),
      PageRoute<Widget, void>(
        path: 'nested',
        build: (s) => Column(
          children: [
            const Text('page'),
            LazyPiece<String>(
              id: 'outer',
              load: (r) async {
                pieceLoads['outer'] = (pieceLoads['outer'] ?? 0) + 1;
                return 'outer data';
              },
              builder: (context, data) => Column(
                children: [
                  Text(data),
                  LazyPiece<String>(
                    id: 'inner',
                    load: (r) async {
                      pieceLoads['inner'] = (pieceLoads['inner'] ?? 0) + 1;
                      return 'inner data';
                    },
                    builder: (context, data) => Container(
                      color: const Color(0xFF445566),
                      child: Text(data),
                    ),
                    fallback: const Text('inner fallback'),
                  ),
                ],
              ),
              fallback: const Text('outer fallback'),
            ),
          ],
        ),
      ),
    ],
  );

  PageRequest get(String path) => PageRequest(
    method: HttpMethod.get,
    uri: Uri.parse('http://site.test$path'),
    headers: {HttpHeader.host: 'site.test'},
  );

  setUp(() {
    errors = [];
    pieceLoads = {};
  });

  test('a query inside a piece is waited for', () async {
    final r = await handler().handle(get('/query?thor-piece=shelf'));
    expect(r.status, 200);
    expect(r.text, contains('got milk+eggs'));
    expect(r.text, contains('>got milk+eggs<'));
    // Its values travel with the piece.
    expect(r.text, contains('data-thor-lazy-json'));
    expect(r.text, contains('["milk","eggs"]'));
    expect(errors, isEmpty);
  });

  test('a FutureBuilder inside a piece is waited for', () async {
    final r = await handler().handle(get('/future?thor-piece=f'));
    expect(r.status, 200);
    expect(r.text, contains('done late value'));
    expect(r.text, isNot(contains('skeleton')));
    expect(r.text, isNot(contains('<!--thor:')));
    expect(errors, isEmpty);
  });

  test('a FutureBuilder that fails inside a piece draws its error', () async {
    final r = await handler().handle(get('/failing?thor-piece=f'));
    expect(r.status, 200);
    expect(r.text, contains('oops'));
  });

  group('a piece inside a piece', () {
    test('the page draws the outer fallback only', () async {
      final r = await handler().handle(get('/nested'));
      expect(r.text, contains('data-thor-lazy="/nested?thor-piece=outer"'));
      expect(r.text, contains('outer fallback'));
      expect(r.text, isNot(contains('inner fallback')));
      expect(pieceLoads, isEmpty);
    });

    test(
      'the outer fragment holds the inner placeholder and its URL',
      () async {
        final r = await handler().handle(get('/nested?thor-piece=outer'));
        expect(r.status, 200);
        expect(r.text, contains('outer data'));
        expect(r.text, contains('inner fallback'));
        expect(
          r.text,
          contains('data-thor-lazy="/nested?thor-piece=outer%3Ainner"'),
        );
        expect(r.text, isNot(contains('inner data')));
        expect(pieceLoads, {'outer': 1});
      },
    );

    test('the inner fragment is its own answer', () async {
      final r = await handler().handle(get('/nested?thor-piece=outer%3Ainner'));
      expect(r.status, 200);
      expect(r.text, contains('inner data'));
      expect(r.text, isNot(contains('outer data')));
      expect(r.text.toLowerCase(), contains('445566'));
      // Both loads ran (the inner one sits in the outer one's content).
      expect(pieceLoads, {'outer': 1, 'inner': 1});
      expect(errors, isEmpty);
    });

    test('an inner piece asked for without its outer one is a 404', () async {
      final r = await handler().handle(get('/nested?thor-piece=inner'));
      expect(r.status, 404);
      final bad = await handler().handle(
        get('/nested?thor-piece=outer%3Anope'),
      );
      expect(bad.status, 404);
      final worse = await handler().handle(
        get('/nested?thor-piece=nope%3Ainner'),
      );
      expect(worse.status, 404);
    });
  });
}
