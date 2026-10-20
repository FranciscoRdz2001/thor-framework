import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:thor_cli/src/run.dart' show generate;

/// Generates the app in [dir] (`.dart_tool/thor/`) once, even when several
/// test files ask at the same time: `dart test` runs files in parallel
/// processes, and a render that skips its own code generation (`codegen:
/// false`) needs the registries a clean checkout doesn't have yet (the
/// page's typed form actions). An exclusive lock on a file of the
/// app makes the others wait for the first.
Future<void> generateOnce(String dir) async {
  final lock = File(p.join(dir, '.dart_tool', 'thor_test_codegen.lock'))
    ..createSync(recursive: true);
  final file = lock.openSync(mode: FileMode.write);
  try {
    await file.lock(FileLock.blockingExclusive);
    await generate(dir);
  } finally {
    await file.unlock();
    file.closeSync();
  }
}
