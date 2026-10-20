@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:thor_ui/testing.dart';

void main() {
  late Directory app;

  setUp(() {
    // Inside the workspace: the wrapper imports thor_server.
    app = (Directory(
      '.dart_tool/test_apps',
    )..createSync(recursive: true)).createTempSync('run_script');
    File('${app.path}/test/fixtures/page.dart')
      ..createSync(recursive: true)
      ..writeAsStringSync(
        "void main(List<String> args) => print('ran ${r'${args.join()}'}');\n",
      );
  });
  tearDown(() => app.deleteSync(recursive: true));

  test('an app script runs with the states registered first', () async {
    File('${app.path}/.dart_tool/thor/states.dart')
      ..createSync(recursive: true)
      ..writeAsStringSync(
        "void registerThorStates() => print('registered');\n",
      );
    final r = await runAppScript(
      'test/fixtures/page.dart',
      args: ['x'],
      appDir: app.path,
    );
    expect(r.exitCode, 0, reason: '${r.stderr}');
    expect((r.stdout as String).trim().split('\n'), ['registered', 'ran x']);
  });

  test('without generated states it just runs', () async {
    final r = await runAppScript('./test/fixtures/page.dart', appDir: app.path);
    expect(r.exitCode, 0, reason: '${r.stderr}');
    expect((r.stdout as String).trim(), 'ran');
  });
}
