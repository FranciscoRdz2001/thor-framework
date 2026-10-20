@TestOn('vm')
library;

// `QueryBuilder(query:, builder: (context, snapshot) => …)`, Flutter's
// FutureBuilder shape over a query. The server draws the state the query is
// in and ships the others; the browser switches on `phase`.
import 'package:test/test.dart';
import 'package:thor_engine/thor_engine.dart' show PatchOp, decodePatch;
import 'package:thor_ui/testing.dart';
import 'package:thor_ui/thor_ui.dart';

class FeedState extends ThorState {
  FeedState({super.key});

  final items = query(() async => <String>['a', 'b']);
  final broken = query<List<String>>(() async => throw StateError('lab'));
  final nobody = query<List<String>?>(() async => null);

  String itemsText() => (items.data.value ?? const <String>[]).join(',');
}

void main() {
  initializeThorTests();
  setUpAll(
    () => ThorState.register({
      FeedState: ThorStateType('FeedState', (state) {
        final s = state as FeedState;
        return [
          ...s.items.members('items'),
          ...s.broken.members('broken'),
          ...s.nobody.members('nobody'),
          ThorMember('itemsText', s.itemsText, call: (_) => s.itemsText()),
        ];
      }),
    }),
  );

  String describe(AsyncSnapshot<List<String>> snap) => snap.hasError
      ? 'error'
      : snap.hasData
      ? 'data ${snap.data!.length} ${snap.connectionState.name}'
      : 'waiting';

  Widget page(
    ServerQuery<Object?, List<String>> q, {
    List<String>? initialData,
  }) => QueryBuilder<List<String>>(
    query: q,
    initialData: initialData,
    builder: (context, snap) => Text(describe(snap)),
  );

  Future<FeedState> loaded(String key) async {
    final s = FeedState(key: key);
    await s.items.prefetch((e) => ('x', ServerErrorKind.server));
    return s;
  }

  group('first paint', () {
    test(
      'with its data: the done state is live, the others are patches',
      () async {
        final s = await loaded('a');
        final html = await renderHtml(page(s.items));
        expect(html, contains('data-tv="FeedState#a.items\$phase"'));
        expect(html, contains('data 2 done'));
        // Same structure in every state: patches of the live element.
        expect(html, isNot(contains('<template')));
        expect(decodePatch(_patch(html, 0)), [
          const PatchOp([], '#', 'waiting'),
        ]);
        // Waiting with the last value keeps the data: a call on its way.
        expect(decodePatch(_patch(html, 1)), [
          const PatchOp([], '#', 'data 2 waiting'),
        ]);
        expect(decodePatch(_patch(html, 3)), [const PatchOp([], '#', 'error')]);
      },
    );

    test('before the server ran it: waiting, and the states with data are '
        'shipped with a placeholder snapshot (#17: the browser can reach '
        'them without an initialData)', () async {
      final s = FeedState(key: 'b');
      final html = await renderHtml(page(s.items));
      expect(html, contains('>waiting<'));
      // `hasData` is true and reading `data` throws in them: the builder here
      // reads `data!.length`, which can't be drawn, so they are left out.
      expect(html, isNot(contains('data-tp-1')));
      expect(html, isNot(contains('data-tp-2')));
      expect(html, contains('data-tp-3'));

      final ok = await renderHtml(
        QueryBuilder<List<String>>(
          query: s.items,
          builder: (context, snap) => Text(
            snap.hasError
                ? 'error'
                : snap.hasData
                ? 'ready ${snap.connectionState.name}'
                : 'waiting',
          ),
        ),
      );
      expect(decodePatch(_patch(ok, 2)), [
        const PatchOp([], '#', 'ready done'),
      ]);
      expect(decodePatch(_patch(ok, 1)), [
        const PatchOp([], '#', 'ready waiting'),
      ]);
    });

    test(
      'a builder that reads the data it has no way to have is left out '
      'of the states (no error), and the states that do not read it ship',
      () async {
        final s = FeedState(key: 'b2');
        for (final read in <String Function(AsyncSnapshot<List<String>>)>[
          (snap) => snap.data!.join(),
          (snap) => snap.requireData.join(),
          (snap) => (snap.data as dynamic).length.toString(),
        ]) {
          final html = await renderHtml(
            QueryBuilder<List<String>>(
              query: s.items,
              builder: (context, snap) =>
                  Text(snap.hasData ? read(snap) : 'waiting'),
            ),
          );
          expect(html, contains('>waiting<'));
          expect(html, isNot(contains('data-tp-2')));
          expect(html, contains('data-tp-3'));
        }
      },
    );

    test('an error that is not about missing data is not swallowed', () async {
      final s = FeedState(key: 'b3');
      await expectLater(
        renderHtml(
          QueryBuilder<List<String>>(
            query: s.items,
            builder: (context, snap) => snap.hasData
                ? throw ArgumentError('a real bug')
                : const Text('waiting'),
          ),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('a failed query: the done state is shipped without initialData '
        '("Reintentar" works)', () async {
      final s = FeedState(key: 'c');
      await s.broken
          .prefetch((e) => ('It failed', ServerErrorKind.server))
          .catchError((Object _) {});
      final html = await renderHtml(
        QueryBuilder<List<String>>(
          query: s.broken,
          builder: (context, snap) =>
              Text(snap.hasError ? 'error' : (snap.hasData ? 'ready' : 'wait')),
        ),
      );
      expect(html, contains('>error<'));
      expect(decodePatch(_patch(html, 2)), [const PatchOp([], '#', 'ready')]);

      final withInitial = await renderHtml(
        page(s.broken, initialData: const <String>[]),
      );
      expect(decodePatch(_patch(withInitial, 2)), [
        const PatchOp([], '#', 'data 0 done'),
      ]);
    });

    test(
      'initialData is only for the states the server has no data for',
      () async {
        final s = await loaded('d');
        final html = await renderHtml(page(s.items, initialData: const ['x']));
        expect(html, contains('data 2 done'));
        expect(html, isNot(contains('data 1')));
      },
    );

    test('a query that answered null is done without data: its own state, '
        'not the list', () async {
      final s = FeedState(key: 'n');
      await s.nobody.prefetch((e) => ('x', ServerErrorKind.server));
      final html = await renderHtml(
        QueryBuilder<List<String>?>(
          query: s.nobody,
          builder: (context, snap) =>
              Text(snap.hasData ? 'list' : 'none ${snap.connectionState.name}'),
        ),
      );
      expect(html, contains('>none done<'));
      // The other states are ready for when data does come: a retry of it
      // must show the list (the placeholder snapshot has data), and one
      // that answers null again must come back.
      expect(decodePatch(_patch(html, 2)), [const PatchOp([], '#', 'list')]);
      expect(html, contains('data-tp-0'));
      expect(html, contains('data-tp-3'));
    });

    test('with data, the state a null answer will need is shipped', () async {
      final s = await loaded('m');
      final html = await renderHtml(
        QueryBuilder<List<String>>(
          query: s.items,
          builder: (context, snap) => Text(
            snap.hasData
                ? 'list ${snap.connectionState.name}'
                : 'none ${snap.connectionState.name}',
          ),
        ),
      );
      expect(html, contains('list done'));
      expect(decodePatch(_patch(html, 4)), [
        const PatchOp([], '#', 'none done'),
      ]);
    });

    test('a builder that returns another structure ships a template', () async {
      final s = await loaded('e');
      final html = await renderHtml(
        QueryBuilder<List<String>>(
          query: s.items,
          builder: (context, snap) => snap.hasData
              ? const Column(children: [Text('a'), Text('b')])
              : const Text('...'),
        ),
      );
      expect(html, contains('data-tvt="FeedState#e.items\$phase"'));
    });
  });

  group('HTML size: the builder runs once per state, the page does not '
      'multiply', () {
    // A list of 1000 rows in the builder: its states are patches or small
    // templates of the live one, not copies of the list.
    Widget rows(String Function(int) text) =>
        Column(children: [for (var i = 0; i < 1000; i++) Text(text(i))]);
    String row(int i) => 'row number $i of the list';

    test('the same structure in every state adds bytes for the wrapper, '
        'not for the rows', () async {
      final s = await loaded('sz1');
      final plain = (await renderHtml(rows(row))).length;
      final wrapped = (await renderHtml(
        QueryBuilder<List<String>>(
          query: s.items,
          builder: (context, snap) => rows(row),
        ),
      )).length;
      expect(wrapped - plain, lessThan(500));
    });

    test('a builder that draws something small without data keeps the list '
        'once', () async {
      final s = await loaded('sz2');
      final plain = (await renderHtml(rows(row))).length;
      final wrapped = (await renderHtml(
        QueryBuilder<List<String>>(
          query: s.items,
          builder: (context, snap) =>
              snap.hasData ? rows(row) : const Text('loading'),
        ),
      )).length;
      expect(wrapped - plain, lessThan(1500));
    });

    test('a builder that changes every row by the state: one patch of the '
        'texts per state (the anti-pattern costs, it is not multiplied by '
        'the rows)', () async {
      final s = await loaded('sz3');
      final plain = (await renderHtml(rows(row))).length;
      final wrapped = (await renderHtml(
        QueryBuilder<List<String>>(
          query: s.items,
          builder: (context, snap) =>
              rows((i) => snap.hasData ? row(i) : 'wait $i'),
        ),
      )).length;
      // Two states without data (waiting, done without data) and one with
      // an error: three patches of 1000 texts, about 16 KB each.
      expect(wrapped - plain, lessThan(plain ~/ 2));
    });

    test('with no data on the server and an initialData, the two states '
        'with data ship as two templates: about twice the list (documented '
        'in docs/guia/es/estado.md)', () async {
      final s = FeedState(key: 'sz4');
      final plain = (await renderHtml(rows(row))).length;
      final wrapped = (await renderHtml(
        QueryBuilder<List<String>>(
          query: s.items,
          initialData: const ['x'],
          builder: (context, snap) =>
              snap.hasData ? rows(row) : const Text('loading'),
        ),
      )).length;
      expect(wrapped, greaterThan(plain * 2 - 2000));
      expect(wrapped, lessThan(plain * 2 + 2000));
    });
  });

  test('the builder gets the context of the QueryBuilder', () async {
    final s = await loaded('f');
    BuildContext? seen;
    await renderHtml(
      QueryBuilder<List<String>>(
        query: s.items,
        builder: (context, snap) {
          seen ??= context;
          return const Text('x');
        },
      ),
    );
    expect(seen, isNotNull);
  });

  test('a query that is not a field of a state is a clear error', () async {
    final loose = query(() async => 1);
    await expectLater(
      renderHtml(
        QueryBuilder<int>(
          query: loose,
          builder: (context, snap) => const Text('x'),
        ),
      ),
      throwsA(
        isA<ArgumentError>().having(
          (e) => e.toString(),
          'message',
          allOf(contains('QueryBuilder'), contains('field of a ThorState')),
        ),
      ),
    );
  });

  test('QueryError binds the message of the query', () async {
    final s = FeedState(key: 'g');
    await s.broken
        .prefetch((e) => ('It failed', ServerErrorKind.server))
        .catchError((Object _) {});
    final html = await renderHtml(QueryError(s.broken));
    expect(html, contains('data-tt="FeedState#g.broken\$message"'));
    expect(html, contains('It failed'));
    final quiet = await renderHtml(QueryError(FeedState(key: 'h').broken));
    expect(quiet, contains('data-tt="FeedState#h.broken\$message"'));
    expect(quiet, isNot(contains('null')));
  });

  test('a Row inside stretches in a Center like the Row alone', () async {
    final s = await loaded('i');
    final alone = await renderHtml(
      const Center(child: Row(children: [Text('x')])),
    );
    final inside = await renderHtml(
      Center(
        child: QueryBuilder<List<String>>(
          query: s.items,
          builder: (context, snap) => const Row(children: [Text('x')]),
        ),
      ),
    );
    expect(alone, contains('align-self: stretch'));
    expect(inside, contains('align-self: stretch'));
  });
}

String _patch(String html, int index) => RegExp('data-tp-$index="([^"]*)"')
    .firstMatch(html)![1]!
    .replaceAll('&quot;', '"')
    .replaceAll('&#39;', "'")
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&amp;', '&');
