@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';

// `thor_ui.dart` must stay compilable to JavaScript, and it reaches code of
// thor_server: a 64-bit integer literal anywhere it reaches breaks dart2js.
void main() {
  test(
    'thor_ui.dart compiles with dart2js',
    () async {
      final dir = Directory('.dart_tool/web_compile_probe')
        ..createSync(recursive: true);
      addTearDown(() => dir.deleteSync(recursive: true));
      final probe = File('${dir.path}/probe.dart')
        ..writeAsStringSync('''
import 'package:thor_ui/thor_ui.dart';

void main() => print(const Text('x'));
''');
      final r = await Process.run(Platform.resolvedExecutable, [
        'compile',
        'js',
        '-O0',
        '--no-source-maps',
        '-o',
        '${dir.path}/probe.js',
        probe.path,
      ]);
      expect(r.exitCode, 0, reason: '${r.stdout}\n${r.stderr}');
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
