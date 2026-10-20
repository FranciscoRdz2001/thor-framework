// `query.snapshot` is Flutter's AsyncSnapshot over the query's signals
// (a view, no new state), and `phase` is the finite state a page switches
// on (QueryBuilder).
import 'package:test/test.dart';
import 'package:thor_engine/thor_engine.dart';

class FeedState extends ThorState {
  FeedState({super.key});

  final items = query(() async => <int>[1, 2]);
  final page = queryWith((int n) async => n, arg: 0);
}

void main() {
  setUpAll(
    () => ThorState.register({
      FeedState: ThorStateType('FeedState', (state) {
        final s = state as FeedState;
        return [...s.items.members('items'), ...s.page.members('page')];
      }),
    }),
  );

  group('AsyncSnapshot', () {
    test('has Flutter\'s shape', () {
      const none = AsyncSnapshot<int>.nothing();
      expect(none.connectionState, ConnectionState.none);
      expect(none.hasData, isFalse);
      expect(none.hasError, isFalse);
      expect(() => none.requireData, throwsStateError);

      const waiting = AsyncSnapshot<int>.waiting();
      expect(waiting.connectionState, ConnectionState.waiting);

      const done = AsyncSnapshot<int>.withData(ConnectionState.done, 3);
      expect(done.hasData, isTrue);
      expect(done.requireData, 3);
      expect(done.error, isNull);

      const failed = AsyncSnapshot<int>.withError(
        ConnectionState.done,
        'Sin conexión',
        ServerErrorKind.network,
      );
      expect(failed.hasError, isTrue);
      expect(failed.hasData, isFalse);
      expect(failed.error, 'Sin conexión');
      expect(failed.errorKind, ServerErrorKind.network);
      expect(() => failed.requireData, throwsStateError);
    });

    test('a null result is done without data, like Flutter', () {
      const done = AsyncSnapshot<int?>.withData(ConnectionState.done, null);
      expect(done.hasData, isFalse);
      expect(done.connectionState, ConnectionState.done);
    });

    test('== and toString', () {
      const a = AsyncSnapshot<int>.withData(ConnectionState.done, 1);
      const b = AsyncSnapshot<int>.withData(ConnectionState.done, 1);
      const c = AsyncSnapshot<int>.withData(ConnectionState.waiting, 1);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
      expect(a.toString(), contains('done'));
    });
  });

  group('ServerQuery.snapshot', () {
    test('a query nobody ran is waiting: the first draw of a page', () {
      final s = FeedState(key: 'a');
      expect(s.items.snapshot.connectionState, ConnectionState.waiting);
      expect(s.items.snapshot.hasData, isFalse);
      expect(s.items.phase(), 0);
    });

    test('its value is done with data', () async {
      final s = FeedState(key: 'b');
      await s.items.prefetch((e) => ('x', ServerErrorKind.server));
      final snap = s.items.snapshot;
      expect(snap.connectionState, ConnectionState.done);
      expect(snap.data, [1, 2]);
      expect(s.items.phase(), 2);
    });

    test('a null result of a query that ran is done, not waiting', () async {
      final s = FeedState(key: 'null');
      final q = queryWith((int n) async => null as int?, arg: 0);
      await q.prefetch((e) => ('x', ServerErrorKind.server));
      expect(q.snapshot.connectionState, ConnectionState.done);
      expect(q.snapshot.hasData, isFalse);
      // Done without data is its own state: a page that switches on the
      // phase draws "nothing found", not the list.
      expect(q.phase(), 4);
      expect(s, isNotNull);
    });

    test('an error has no data and carries the message and the kind', () {
      final s = FeedState(key: 'c');
      s.items.data.value = [9];
      s.items.error.value = 'Se cayó';
      s.items.errorKind.value = ServerErrorKind.server;
      final snap = s.items.snapshot;
      // Flutter's withError: the error replaces the data (the signal keeps
      // the stale value for whoever wants it).
      expect(snap.hasError, isTrue);
      expect(snap.hasData, isFalse);
      expect(snap.error, 'Se cayó');
      expect(snap.errorKind, ServerErrorKind.server);
      expect(s.items.data.value, [9]);
      expect(s.items.phase(), 3);
    });

    test('a call on its way is waiting; the stale value stays, the old '
        'error does not', () {
      final s = FeedState(key: 'd');
      s.items.data.value = [9];
      s.items.loading.value = true;
      expect(s.items.phase(), 1);
      expect(s.items.snapshot.connectionState, ConnectionState.waiting);
      expect(s.items.snapshot.data, [9]);
      s.items.error.value = 'Se cayó';
      expect(s.items.snapshot.hasError, isFalse);
      expect(s.items.phase(), 1);
      s.items.data.value = null;
      expect(s.items.phase(), 0);
    });
  });

  test('a placeholder says it has data it does not hold', () {
    const p = AsyncSnapshot<int>.placeholder(ConnectionState.done);
    expect(p.hasData, isTrue);
    expect(() => p.data, throwsA(isA<StateError>()));
    expect(p.hasError, isFalse);
    expect(p.connectionState, ConnectionState.done);
    // `requireData` of a non-nullable type has nothing to give.
    expect(() => p.requireData, throwsA(isA<StateError>()));
    // Nor does a nullable one hand back the null it holds.
    expect(
      () => const AsyncSnapshot<int?>.placeholder(
        ConnectionState.done,
      ).requireData,
      throwsA(isA<StateError>()),
    );
    expect(p, isNot(const AsyncSnapshot<int>.done()));
    expect(p, const AsyncSnapshot<int>.placeholder(ConnectionState.done));
  });

  group('members', () {
    test('phase is a finite state and message its text', () {
      final s = FeedState(key: 'e');
      final phase = s.members.firstWhere((m) => m.name == r'items$phase');
      expect(phase.variants, [0, 1, 2, 3, 4]);
      expect(ThorState.resolve(s.items.phase)!.$2, same(phase));
      final message = s.members.firstWhere((m) => m.name == r'items$message');
      expect(ThorState.resolve(s.items.message)!.$2, same(message));
      expect(message.call!(null), '');
      s.items.error.value = 'Se cayó';
      expect(message.call!(null), 'Se cayó');
    });
  });
}
