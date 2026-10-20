// Writes what thor runs for an app, in <app>/.dart_tool/thor/ (the app
// never imports it and never sees it):
//
//   dart run thor_builder:entries <app dir> [--all-features]
//
//   states.dart  registerThorStates(): the members of every ThorState class
//   server.dart  registers them and runs bin/server.dart (or a static app's
//                lib/main.server.dart)
//   export.dart  registers them and runs bin/export.dart (thor export)
//   engine.dart  internal: the dart2js oracle's entry (THOR_INTERNAL_ENGINE=dart)
//
// `thor dev`, `thor build`, `thor test` and `thor render` run it after the
// other code generation. A file is rewritten only when its content changes
// (a hot reload doesn't restart for nothing). Exit code 1 when a state
// class can't be listed (THOR-B016), with its file.
//
// It also checks the app for code the browser can't run around a state
// (THOR-S001/S011/S012, the detection of thor_lints) and lists it in
// state_misuses.txt: thor dev shows it on the page, thor build fails.
import 'dart:io';

import 'package:thor_builder/src/app_steps.dart';

Future<void> main(List<String> argv) async {
  final allFeatures = argv.contains('--all-features');
  final args = [
    for (final a in argv)
      if (a != '--all-features') a,
  ];
  if (args.length != 1) {
    stderr.writeln(
      'usage: dart run thor_builder:entries <app dir> [--all-features]',
    );
    exit(64);
  }
  final app = Directory(args.single).resolveSymbolicLinksSync();
  if (!Directory('$app/lib').existsSync() ||
      !File('$app/pubspec.yaml').existsSync()) {
    stderr.writeln('$app is not a thor app (no lib/ or pubspec.yaml)');
    exit(66);
  }
  exitCode = await writeAppEntries(
    app,
    allFeatures: allFeatures,
    out: stdout,
    err: stderr,
  );
}
