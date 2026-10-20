// The long-lived worker of `thor dev`: the entries and lite-state steps on
// one analysis of the app that stays warm across saves (a state edit took
// ~5 s with a `dart run` per step, the analyzer starting from nothing):
//
//   dart run thor_builder:worker <app dir>
//
// JSON requests on stdin, one answer per line on stdout; it exits when
// stdin closes (thor dev gone, even killed). The protocol is in
// lib/src/step_worker.dart.
import 'dart:convert';
import 'dart:io';

import 'package:thor_builder/src/step_worker.dart';

Future<void> main(List<String> args) async {
  if (args.length != 1) {
    stderr.writeln('usage: dart run thor_builder:worker <app dir>');
    exit(64);
  }
  final app = Directory(args.single).resolveSymbolicLinksSync();
  if (!Directory('$app/lib').existsSync() ||
      !File('$app/pubspec.yaml').existsSync()) {
    stderr.writeln('$app is not a thor app (no lib/ or pubspec.yaml)');
    exit(66);
  }
  await serveSteps(
    StepWorker(app),
    stdin.transform(utf8.decoder).transform(const LineSplitter()),
    stdout,
  );
  exit(0);
}
