import 'dart:io';

import 'package:test/test.dart';

// thor_ui.dart imports thor_server, so the dart2js engine (`thor: engine:
// dart`) compiles this package for the web: code that dart2js's front end
// rejects (an int literal JS can't represent) breaks every such app, even
// if the browser never runs it.
void main() {
  test(
    'thor_server compiles with dart2js',
    () {
      final dir = Directory.systemTemp.createTempSync('thor_server_web');
      addTearDown(() => dir.deleteSync(recursive: true));
      final entry = File('${dir.path}/main.dart')
        ..writeAsStringSync(
          "import 'package:thor_server/thor_server.dart';\n"
          'void main() => print(RouteHandler);\n',
        );
      final r = Process.runSync(Platform.resolvedExecutable, [
        'compile',
        'js',
        '--packages=${File('../../.dart_tool/package_config.json').absolute.path}',
        '-o',
        '${dir.path}/main.js',
        entry.path,
      ]);
      expect(r.exitCode, 0, reason: '${r.stdout}\n${r.stderr}');
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
