// The fingerprint that decides whether `.dart_tool/thor/` is regenerated
// changes when `bin/export.dart` (or `bin/server.dart`) appears.
@TestOn('vm')
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:thor_cli/src/run.dart';

void main() {
  late Directory app;
  setUp(() {
    app = Directory.systemTemp.createTempSync('thor_fingerprint');
    Directory(p.join(app.path, 'lib')).createSync();
    File(p.join(app.path, 'lib', 'a.dart')).writeAsStringSync('void a() {}');
  });
  tearDown(() => app.deleteSync(recursive: true));

  for (final entry in ['export.dart', 'server.dart']) {
    test('adding bin/$entry changes the fingerprint', () {
      final before = inputsFingerprint(app.path);
      expect(inputsFingerprint(app.path), before);
      Directory(p.join(app.path, 'bin')).createSync();
      File(p.join(app.path, 'bin', entry)).writeAsStringSync('');
      expect(inputsFingerprint(app.path), isNot(before));
    });
  }
}
