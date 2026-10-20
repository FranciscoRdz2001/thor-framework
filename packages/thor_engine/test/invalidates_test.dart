// `invalidates:` evaluated on the server, adversarially: a closure
// that throws, that repeats a query, that names one from another state or
// that isn't a member of any state.
import 'package:test/test.dart';
import 'package:thor_engine/thor_engine.dart';

var _orphan = query(() async => 0);

class InvState extends ThorState {
  InvState({super.key});

  final a = query(() async => 1);
  final b = query(() async => 2);
  final c = query(() async => 3);

  final none = command(() async {});
  final onlyA = command(() async {}, invalidates: (InvState s) => [s.a]);
  final twice = command(
    () async {},
    invalidates: (InvState s) => [s.b, s.b, s.a, s.b],
  );
  final empty = command(() async {}, invalidates: (InvState s) => const []);
  final boom = command(
    () async {},
    invalidates: (InvState s) => throw StateError('closure bug'),
  );
  // Another instance's query: not this state's, but a query of the page.
  final foreign = command(
    () async {},
    invalidates: (InvState s) => [InvState.other!.a],
  );
  final stray = command(() async {}, invalidates: (InvState s) => [_orphan]);
  static InvState? other;
}

void main() {
  setUpAll(
    () => ThorState.register({
      InvState: ThorStateType('InvState', (state) {
        final s = state as InvState;
        return [
          ...s.a.members('a'),
          ...s.b.members('b'),
          ...s.c.members('c'),
          ...s.none.members('none'),
          ...s.onlyA.members('onlyA'),
          ...s.twice.members('twice'),
          ...s.empty.members('empty'),
          ...s.boom.members('boom'),
          ...s.foreign.members('foreign'),
          ...s.stray.members('stray'),
        ];
      }),
    }),
  );

  test('no `invalidates:` is null: every query the browser has', () {
    InvState(key: 'p');
    expect(ServerCommandBase.invalidatedBy('InvState#p.none'), isNull);
  });

  test('a query named twice is one id; the order does not matter', () {
    InvState(key: 'q');
    expect(ServerCommandBase.invalidatedBy('InvState#q.twice'), {
      'InvState#q.a',
      'InvState#q.b',
    });
    expect(ServerCommandBase.invalidatedBy('InvState#q.onlyA'), {
      'InvState#q.a',
    });
  });

  test('an empty list refreshes nothing, not everything', () {
    InvState(key: 'r');
    expect(ServerCommandBase.invalidatedBy('InvState#r.empty'), isEmpty);
  });

  test('a query of another state resolves to its own id', () {
    InvState(key: 's');
    InvState.other = InvState(key: 's2');
    expect(ServerCommandBase.invalidatedBy('InvState#s.foreign'), {
      'InvState#s2.a',
    });
  });

  test('a query that is no member of a state is dropped, not thrown', () {
    InvState(key: 't');
    expect(ServerCommandBase.invalidatedBy('InvState#t.stray'), isEmpty);
  });

  test('a closure that throws surfaces before anything runs', () {
    InvState(key: 'u');
    // The handler calls this before the command: a bug in `invalidates:`
    // is a 500 with nothing changed, never a half-run command.
    expect(
      () => ServerCommandBase.invalidatedBy('InvState#u.boom'),
      throwsStateError,
    );
  });

  test('ids that name nothing', () {
    for (final id in ['', '.', 'x', 'InvState.', '.a', 'InvState#nope.a']) {
      expect(ServerCommandBase.invalidatedBy(id), isNull, reason: id);
    }
  });
}
