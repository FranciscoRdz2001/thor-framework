// dart run thor_engine:fingerprint build/site
import 'dart:io';

import 'package:thor_engine/fingerprint.dart';

void main(List<String> args) {
  if (args.length != 1) {
    stderr.writeln('usage: dart run thor_engine:fingerprint <site dir>');
    exitCode = 64;
    return;
  }
  final report = fingerprintSite(args.single);
  stdout.writeln(
    '${args.single}: ${report.renamed.length} files content-hashed '
    'across ${report.pages} pages',
  );
}
