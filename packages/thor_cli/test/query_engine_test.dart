import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:thor_cli/thor_cli.dart';

// The registry code generation writes for a state with two queries.
const _withQueries = '''
final thorStates = {
  t0.ProfileState: ThorStateType('ProfileState', (state) {
    final s = state as t0.ProfileState;
    return [
      ...s.info.members('info'),
      ...s.orders.members('orders'),
      ...s.near.members('near', argToJson: (a) => {}, argFromJson: (j) => (lat: 0.0, lng: 0.0)),
      ThorMember.state('editing', s.editing),
    ];
  }),
};
''';

// The registry for a state with commands only.
const _withCommands = '''
final thorStates = {
  t0.CartState: ThorStateType('CartState', (state) {
    final s = state as t0.CartState;
    return [
      ...s.add.members('add') /* command */,
      ...s.clear.members('clear') /* command */,
    ];
  }),
};
''';

const _withoutQueries = '''
final thorStates = {
  t0.CounterState: ThorStateType('CounterState', (state) {
    final s = state as t0.CounterState;
    return [ThorMember.state('count', s.count)];
  }),
};
''';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('thor_query_engine'));
  tearDown(() => dir.deleteSync(recursive: true));

  void registry(String source) =>
      File(p.join(dir.path, '.dart_tool', 'thor', 'states.dart'))
        ..createSync(recursive: true)
        ..writeAsStringSync(source);

  test('the dart2js engine stops a build with queries', () async {
    registry(_withQueries);
    await expectLater(
      buildEngine(Project(dir.path), EngineKind.dart, out: 'build/public'),
      throwsA(
        isA<ThorException>().having(
          (e) => e.message,
          'message',
          allOf(
            contains('ProfileState.info, ProfileState.orders'),
            contains('THOR_INTERNAL_ENGINE'),
          ),
        ),
      ),
    );
    // Stopped before dart2js ran: nothing reached the output folder.
    expect(
      File(p.join(dir.path, 'build/public/engine.dart.js')).existsSync(),
      isFalse,
    );
  });

  test('commands stop a dart2js build too', () {
    registry(_withCommands);
    expect(
      () => rejectQueriesOnDartEngine(dir.path),
      throwsA(
        isA<ThorException>().having(
          (e) => e.message,
          'message',
          allOf(contains('CartState.add, CartState.clear')),
        ),
      ),
    );
  });

  test('endpoints: queries and commands apart', () {
    const both = '$_withQueries\n$_withCommands';
    expect(queryEndpointsIn(both), [
      'ProfileState.info',
      'ProfileState.orders',
      'ProfileState.near',
    ]);
    expect(commandEndpointsIn(both), ['CartState.add', 'CartState.clear']);
  });

  test('the dart2js guard lets an app without queries through', () {
    registry(_withoutQueries);
    expect(() => rejectQueriesOnDartEngine(dir.path), returnsNormally);
  });

  test('the dart2js guard needs the registry to find queries', () {
    expect(() => rejectQueriesOnDartEngine(dir.path), returnsNormally);
  });
}
