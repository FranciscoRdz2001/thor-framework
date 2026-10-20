// Writes an app's ThorState classes as JS for the lite engine:
//
//   dart run thor_builder:lite_state <app dir> [<out file>] [--readable]
//     → <app dir>/build/lite/state.js by default
//   dart run thor_builder:lite_state <package dir> --check
//     → writes nothing: whether the package fits the lite subset
//
// Locals, parameters and the states' own members get short names (the
// release bundle); `--readable` keeps the Dart names (thor dev).
//
// `thor build` and `thor dev` run it for every app (lite is the only
// engine), then thor_engine's lite_bundle.
// Resolves every library in the app's lib/ and translates the states and
// the code they use. Anything outside the lite subset is an error with its
// file and line (exit code 1) and nothing is written.
//
// `--check` (what `thor analyze --lite` runs) also translates every data
// class (a `fromJson`) of the package, named by a state of it or not: a
// protocol package declares the classes of other packages' `events<T>`,
// `query` and `state<T>`, and is checked before an app uses it.
import 'dart:io';

import 'package:thor_builder/src/app_steps.dart';

Future<void> main(List<String> argv) async {
  final readable = argv.contains('--readable');
  final check = argv.contains('--check');
  final args = [
    for (final a in argv)
      if (a != '--readable' && a != '--check') a,
  ];
  if (args.isEmpty || args.length > (check ? 1 : 2)) {
    stderr.writeln(
      'usage: dart run thor_builder:lite_state <app dir> [<out file>] '
      '[--readable]\n'
      '       dart run thor_builder:lite_state <package dir> --check',
    );
    exit(64);
  }
  final app = Directory(args.first).resolveSymbolicLinksSync();
  if (!Directory('$app/lib').existsSync()) {
    stderr.writeln('$app/lib does not exist');
    exit(66);
  }
  if (check) {
    exitCode = await checkLitePackage(app, out: stdout, err: stderr);
    return;
  }
  exitCode = await writeLiteStates(
    app,
    outPath: args.length == 2 ? args[1] : '$app/build/lite/state.js',
    readable: readable,
    out: stdout,
    err: stderr,
  );
}
