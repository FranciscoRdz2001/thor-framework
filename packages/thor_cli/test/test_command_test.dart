import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:thor_cli/thor_cli.dart';

void main() {
  test("the test runner's annotations go with the wrapper", () {
    const source = '''
// A test for the browser.
@TestOn('browser')
@Tags(['slow', 'ui'])
@Timeout(Duration(minutes: 2))
@deprecated
library;

import 'package:test/test.dart';
''';
    expect(libraryAnnotations(source), [
      "@TestOn('browser')",
      "@Tags(['slow', 'ui'])",
      '@Timeout(Duration(minutes: 2))',
    ]);
    expect(libraryAnnotations('import "x.dart";\n@TestOn("vm")'), isEmpty);
  });

  test('a wrapper registers the states before the file runs', () {
    final code = testWrapper(
      testImport: '../../../test/app_test.dart',
      statesImport: '../states.dart',
      annotations: const ["@TestOn('vm')"],
    );
    expect(code, contains("@TestOn('vm')\nlibrary;"));
    expect(code, contains("import 'package:test/test.dart';"));
    expect(
      code.indexOf('registerThorStates();'),
      lessThan(code.indexOf('file.main();')),
    );
    // An app without states: nothing to register, nothing to import.
    final plain = testWrapper(testImport: 'a_test.dart');
    expect(plain, isNot(contains('registerThorStates')));
    expect(plain, isNot(contains('package:test')));
  });

  test('a wrapper registers the action methods before the file runs', () {
    final code = testWrapper(
      testImport: '../../../test/app_test.dart',
      actionsImport: '../actions.dart',
    );
    expect(code, contains("import '../actions.dart';"));
    expect(
      code.indexOf('registerThorActions();'),
      lessThan(code.indexOf('file.main();')),
    );
    expect(
      testWrapper(testImport: 'a_test.dart'),
      isNot(contains('registerThorActions')),
    );
  });

  test('wrappers mirror the test folder and import it relatively', () {
    final dir = Directory.systemTemp.createTempSync('thor_test_cmd');
    addTearDown(() => dir.deleteSync(recursive: true));
    for (final f in ['test/a_test.dart', 'test/deep/b_test.dart']) {
      File(p.join(dir.path, f))
        ..createSync(recursive: true)
        ..writeAsStringSync('void main() {}\n');
    }
    File(p.join(dir.path, 'test/helpers.dart')).writeAsStringSync('');
    File(p.join(dir.path, '.dart_tool/thor/states.dart'))
      ..createSync(recursive: true)
      ..writeAsStringSync('void registerThorStates() {}\n');

    final files = testFiles(dir.path, const []);
    expect(files.map((f) => p.relative(f, from: dir.path)), [
      'test/a_test.dart',
      'test/deep/b_test.dart',
    ]);
    final wrappers = writeTestWrappers(dir.path, files);
    expect(wrappers, [
      '.dart_tool/thor/test/test/a_test.dart',
      '.dart_tool/thor/test/test/deep/b_test.dart',
    ]);
    final deep = File(p.join(dir.path, wrappers.last)).readAsStringSync();
    expect(deep, contains("import '../../../states.dart';"));
    expect(deep, contains("import '../../../../../test/deep/b_test.dart'"));
    // One file or a folder picks those only.
    expect(testFiles(dir.path, [p.join(dir.path, 'test/deep')]), [
      p.join(dir.path, 'test/deep/b_test.dart'),
    ]);
  });
}
