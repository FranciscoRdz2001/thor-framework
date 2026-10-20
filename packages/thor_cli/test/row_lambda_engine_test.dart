import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:thor_cli/src/run.dart';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('thor_row_engine'));
  tearDown(() => dir.deleteSync(recursive: true));

  void registry(String source) =>
      File(p.join(dir.path, '.dart_tool', 'thor', 'states.dart'))
        ..createSync(recursive: true)
        ..writeAsStringSync(source);

  test('a row lambda goes through (the engine reads it: RowReaders)', () {
    registry('''
void registerThorStates() {
  ThorState.register({});
  registerRowProbes({
    t0.Person: (log) => _RowProbe0(log),
  });
}
''');
    expect(() => rejectDartEngineLimits(dir.path), returnsNormally);
  });

  test('an app without row lambdas goes through', () {
    registry('void registerThorStates() { ThorState.register({}); }\n');
    expect(() => rejectDartEngineLimits(dir.path), returnsNormally);
  });

  test('without the registry there is nothing to check', () {
    expect(() => rejectDartEngineLimits(dir.path), returnsNormally);
  });

  test(
    'a FutureBuilder or a LazyPiece goes through (the engine binds them)',
    () {
      File(p.join(dir.path, 'lib', 'pages', 'home.dart'))
        ..createSync(recursive: true)
        ..writeAsStringSync(
          'Widget build() => FutureBuilder<int>(future: f, builder: b);\n'
          'Widget menu() => LazyPiece<int>(id: "a", load: l, builder: b);\n',
        );
      expect(() => rejectDartEngineLimits(dir.path), returnsNormally);
    },
  );

  test('a state with dispose says what the dart2js engine does differently', () {
    File(p.join(dir.path, '.dart_tool', 'thor', 'engine.dart'))
      ..createSync(recursive: true)
      ..writeAsStringSync(
        'void main() { startThor([], features: const [LifecycleFeature()]); }',
      );
    expect(sayDartEngineDifferences(dir.path), isTrue);
    expect(sayDartEngineDifferences(dir.path), isFalse, reason: 'once');
  });

  test('without LifecycleFeature in the entry there is nothing to say', () {
    File(p.join(dir.path, '.dart_tool', 'thor', 'engine.dart'))
      ..createSync(recursive: true)
      ..writeAsStringSync(
        'void main() { startThor([], features: const [ListsFeature()]); }',
      );
    expect(sayDartEngineDifferences(dir.path), isFalse);
  });
}
