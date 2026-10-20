import 'dart:io';

import 'package:intl_store/handler.dart';
import 'package:thor_server/thor_server.dart';

/// Exports both languages as a static site: `thor export` (or
/// `dart run -Dthor.release=true bin/export.dart [out] [base-url]`).
Future<void> main(List<String> args) async {
  final out = args.isNotEmpty ? args[0] : 'build/site';
  final baseUrl = args.length > 1 ? args[1] : null;
  final dir = Directory(out);
  if (dir.existsSync()) dir.deleteSync(recursive: true);
  final report = await exportSite(
    storeHandler(baseUrl: baseUrl),
    paths: sitePaths(),
    outDir: out,
    baseUrl: baseUrl,
    notFoundPath: '/en/__missing__',
    staticDir: 'web',
  );
  final web = Directory('web');
  if (web.existsSync()) {
    await for (final f in web.list(recursive: true)) {
      if (f is! File || f.path.endsWith('.dart')) continue;
      final target = File('$out/${f.path.substring(web.path.length + 1)}');
      await target.parent.create(recursive: true);
      await f.copy(target.path);
    }
  }
  for (final MapEntry(key: path, value: status) in report.failed.entries) {
    stderr.writeln('✗ $path → $status');
  }
  for (final MapEntry(key: path, value: links) in report.brokenLinks.entries) {
    for (final link in links) {
      stderr.writeln('✗ $path → broken link $link');
    }
  }
  stdout.writeln('${report.written.length} pages → $out');
  exit(report.ok ? 0 : 1);
}
