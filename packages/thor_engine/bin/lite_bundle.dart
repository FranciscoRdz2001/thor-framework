// dart run thor_engine:lite_bundle [--no-minify] [--dev] [--per-page] <state.js> <app dir> <out file> [<site dir>]
//
// Writes the lite engine's bundle: the runtime, the optional
// parts the app uses and its states (thor_builder's lite_state), minified.
// With <site dir> (a static site) a feature's part ships only if a page
// has its markup; without it (a server app) every part the app's engine
// features name ships. `--dev` (thor dev) adds the part that keeps the
// states' values across the live reloads. With `--per-page` (and a <site dir>)
// each page gets its own bundle, `engine.dart.<hash>.js` next to <out file>,
// with the states and parts that page needs, and the pages are pointed at it.
import 'dart:io';

import 'package:thor_engine/lite.dart';

Future<void> main(List<String> arguments) async {
  final minify = !arguments.contains('--no-minify');
  final dev = arguments.contains('--dev');
  final perPage = arguments.contains('--per-page');
  final args = [
    for (final a in arguments)
      if (a != '--no-minify' && a != '--dev' && a != '--per-page') a,
  ];
  if (args.length < 3 || args.length > 4) {
    stderr.writeln(
      'usage: dart run thor_engine:lite_bundle [--no-minify] [--dev] [--per-page] '
      '<state.js> '
      '<app dir> '
      '<out file> [<site dir>]',
    );
    exitCode = 64;
    return;
  }
  final [statePath, appDir, outPath, ...rest] = args;
  if (perPage && rest.isNotEmpty) {
    stdout.writeln(
      await writeLiteSiteBundles(
        statePath: statePath,
        appDir: appDir,
        outPath: outPath,
        siteDir: rest.single,
        minify: minify,
      ),
    );
    return;
  }
  stdout.writeln(
    await writeLiteBundle(
      statePath: statePath,
      appDir: appDir,
      outPath: outPath,
      siteDir: rest.isEmpty ? null : rest.single,
      minify: minify,
      dev: dev,
    ),
  );
}
