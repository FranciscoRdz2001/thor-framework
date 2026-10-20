// dart run thor_engine:optimize build/site/index.html [more.html…]
import 'dart:io';

import 'package:thor_engine/optimize.dart';

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('usage: dart run thor_engine:optimize <file.html>...');
    exitCode = 64;
    return;
  }
  for (final path in args) {
    final file = File(path);
    final before = file.readAsStringSync();
    // thor_ui already rendered the variants as patches.
    final report = optimizeHtml(before, patchVariants: false);
    file.writeAsStringSync(report.html);
    stdout.writeln(
      '$path: ${before.length} → ${report.html.length} bytes, '
      '${report.renamed} classes renamed',
    );
  }
}
