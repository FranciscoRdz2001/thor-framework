@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:thor_server/thor_server.dart';

// After a `thor build`, `build/public` holds the release engine of that
// build; `thor dev` writes the engine of the current code to `web/`. A dev
// server that served `build/public` ran a stale engine (clicks on a changed
// state did nothing, silently).
void main() {
  late Directory dir;
  late Directory before;
  final wasDev = ThorDev.enabled;
  setUp(() {
    before = Directory.current;
    dir = Directory.systemTemp.createTempSync('thor_public_');
    Directory.current = dir;
  });
  tearDown(() {
    Directory.current = before;
    dir.deleteSync(recursive: true);
    ThorDev.enabled = wasDev;
  });

  test('release: build/public once it exists, else web', () {
    ThorDev.enabled = false;
    expect(ThorServer.appPublicDir(), 'web');
    Directory('build/public').createSync(recursive: true);
    expect(ThorServer.appPublicDir(), 'build/public');
  });

  test('thor dev: always web, even after a thor build', () {
    ThorDev.enabled = true;
    Directory('build/public').createSync(recursive: true);
    expect(ThorServer.appPublicDir(), 'web');
  });
}
