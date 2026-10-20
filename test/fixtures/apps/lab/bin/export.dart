import 'dart:io';

import 'package:fixture_lab/app.dart';
import 'package:fixture_lab/router.dart';
import 'package:thor_server/thor_server.dart';

/// Exports every fixture page as a static site: `thor export` (or
/// `dart run -Dthor.release=true bin/export.dart [out]`).
Future<void> main(List<String> args) async {
  final out = args.isNotEmpty ? args[0] : 'build/site';
  final dir = Directory(out);
  if (dir.existsSync()) dir.deleteSync(recursive: true);
  final report = await exportSite(
    appHandler(),
    paths: ['/', ...fixturePaths],
    outDir: out,
  );
  for (final MapEntry(key: path, value: status) in report.failed.entries) {
    stderr.writeln('✗ $path → $status');
  }
  // The links are not checked: several fixtures link to rows and routes
  // that exist only as targets of a bound `href` (the sanitizer cases).
  stdout.writeln('${report.written.length} pages → $out');
  exit(report.failed.isEmpty ? 0 : 1);
}
