import 'dart:io';

import 'package:cells/app.dart';
import 'package:cells/router.dart';
import 'package:thor_server/thor_server.dart';

/// Exports the sheet as a static site: `thor export` (what
/// `test/e2e/checks/cells_check.mjs` serves).
Future<void> main(List<String> args) async {
  final out = args.isNotEmpty ? args[0] : 'build/site';
  final dir = Directory(out);
  if (dir.existsSync()) dir.deleteSync(recursive: true);
  final report = await exportSite(
    appHandler(),
    paths: router.staticPaths,
    outDir: out,
  );
  for (final MapEntry(key: path, value: status) in report.failed.entries) {
    stderr.writeln('✗ $path → $status');
  }
  stdout.writeln('${report.written.length} pages → $out');
  exit(report.ok ? 0 : 1);
}
