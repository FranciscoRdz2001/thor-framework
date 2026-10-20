// `thor export` ends like `thor build` does: the files pages ask for get
// content-hashed names (and `_headers`), so a static host can cache them
// forever. A real export of test/fixtures/apps/intl_store.
@TestOn('vm')
@Timeout(Duration(minutes: 5))
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:thor_cli/thor_cli.dart';

void main() {
  final app = p.normalize(p.absolute('../../test/fixtures/apps/intl_store'));
  final site = Directory(p.join(app, 'build', 'site'));

  // A leftover build/site makes the E2E lite step treat this server app
  // as a static one (it picks the site over build/server), so the test
  // removes the export it made.
  final hadSite = site.existsSync();
  tearDownAll(() {
    if (!hadSite && site.existsSync()) site.deleteSync(recursive: true);
  });

  test(
    'the exported site has content-hashed files and a _headers file',
    () async {
      final code = await thorRunner().run(['export', app]);
      expect(code, 0);
      final names = [
        for (final f in site.listSync().whereType<File>()) p.basename(f.path),
      ];
      expect(names, isNot(contains('engine.dart.js')));
      expect(
        names.where(
          (n) => RegExp(r'^engine\.dart\.[0-9a-f]{8}\.js$').hasMatch(n),
        ),
        hasLength(1),
      );
      expect(names, contains('_headers'));
      final index = File(p.join(site.path, 'index.html')).readAsStringSync();
      expect(index, isNot(contains('"/engine.dart.js"')));
    },
  );
}
