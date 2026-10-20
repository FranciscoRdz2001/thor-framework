import 'dart:io';

import 'package:docs/app.dart';
import 'package:docs/core/content/llms.dart';
import 'package:docs/core/content/redirects.dart';
import 'package:docs/core/i18n/docs_locale.dart';
import 'package:thor_server/thor_server.dart';

/// Exports the site as static files: `dart run -Dthor.release=true
/// bin/export.dart [out] [base-url]` (default `build/site`). Every page must
/// answer 200 and every internal link and anchor must land: a broken page or
/// link fails the build. Every page is written once per language
/// (`es/empezar/instalacion.html`), `/` is the page that picks one, and the
/// old addresses (`/guia/<slug>`, `/api`…) are small pages that redirect.
Future<void> main(List<String> args) async {
  final out = args.isNotEmpty ? args[0] : 'build/site';
  final baseUrl = args.length > 1 ? args[1] : null;
  final dir = Directory(out);
  if (dir.existsSync()) dir.deleteSync(recursive: true);
  await _copy(Directory('web'), dir);
  // The guide as Markdown for readers that aren't browsers:
  // `<locale>/<section>/<slug>.md` (the pages link to them), `llms.txt`
  // and `llms-full.txt`.
  writeMarkdownFiles(out, intro: 'llms-intro.md', baseUrl: baseUrl ?? '');
  final report = await exportSite(
    docsHandler(baseUrl: baseUrl),
    paths: sitePaths(),
    outDir: out,
    baseUrl: baseUrl,
    notFoundPath: '/$defaultLocale/__missing__',
    // The files a page may link: `web/` and the Markdown just written.
    staticDir: out,
  );
  for (final MapEntry(key: path, value: status) in report.failed.entries) {
    stderr.writeln('✗ $path → $status');
  }
  for (final MapEntry(key: path, value: links) in report.brokenLinks.entries) {
    for (final link in links) {
      stderr.writeln('✗ $path → broken link $link');
    }
  }
  final redirects = await _writeRedirects(out, baseUrl, report);
  stdout.writeln(
    '${report.written.length} pages and $redirects redirects → $out',
  );
  exit(report.ok && exitCode == 0 ? 0 : 1);
}

/// The old addresses as pages that redirect (a static host serves
/// `guia/tutorial.html` for `/guia/tutorial`), each to a page of this
/// export: one that is not there would be a broken link of its own.
Future<int> _writeRedirects(
  String out,
  String? baseUrl,
  ExportReport report,
) async {
  final prefix = baseUrl == null ? '' : Uri.parse(baseUrl).path;
  var count = 0;
  for (final MapEntry(key: old, value: target) in {
    ...legacyRedirects(sitePaths()),
    ...localizedIndexRedirects(),
  }.entries) {
    final external = target.startsWith('http');
    final page = target.split(RegExp('[#?]')).first;
    if (!external && !report.written.containsKey(page)) {
      stderr.writeln('✗ $old → redirects to $target, which is not a page');
      exitCode = 1;
      continue;
    }
    final file = File('$out$old.html');
    await file.parent.create(recursive: true);
    await file.writeAsString(
      redirectPage(external ? target : '$prefix$target'),
    );
    count++;
  }
  return count;
}

Future<void> _copy(Directory from, Directory to) async {
  await for (final entity in from.list(recursive: true)) {
    if (entity is! File) continue;
    final target = File(
      '${to.path}/${entity.path.substring(from.path.length + 1)}',
    );
    await target.parent.create(recursive: true);
    await entity.copy(target.path);
  }
}
