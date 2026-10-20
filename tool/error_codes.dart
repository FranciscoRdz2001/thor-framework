/// The contract between thor's error codes and their pages (docs/errores):
/// every `THOR-X000` in a package's `lib/` has a page and a row in the
/// index, every page is used, and a message outside the
/// browser's engine carries its page's URL (through the package's
/// `thorError`, which holds [errorsUrl] once).
library;

import 'dart:io';

/// Where the pages are published.
const errorsUrl = 'https://thor-docs.vercel.app/errores/';

/// A package that imports or exports `thorError` from thor_style (the one
/// copy of the URL) instead of holding its own.
final _reusesStyle = RegExp(
  r"package:thor_style/errors\.dart'[^;]*\bthorError\b",
);

/// A code: a letter for the area and three digits.
final errorCode = RegExp(r'THOR-[SRLPB]\d{3}');

/// Packages whose messages carry only the code (the browser's engine: the
/// URL would cost bytes in every app).
const codeOnly = {'thor_engine', 'thor_engine_oracle'};

/// What breaks the contract in the repository at [root]; empty if nothing.
List<String> checkErrorCodes(String root) {
  final problems = <String>[];
  final used = <String, List<String>>{};
  final packages = Directory('$root/packages');
  for (final package in packages.listSync().whereType<Directory>()) {
    final name = package.uri.pathSegments.lastWhere((s) => s.isNotEmpty);
    final lib = Directory('${package.path}/lib');
    if (!lib.existsSync()) continue;
    var codes = 0;
    var url = 0;
    var reuses = false;
    for (final file in lib.listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      final text = file.readAsStringSync();
      for (final m in errorCode.allMatches(text)) {
        final at =
            '${file.path.substring(root.length + 1)}:'
            '${'\n'.allMatches(text.substring(0, m.start)).length + 1}';
        (used[m[0]!] ??= []).add(at);
        codes++;
      }
      url += errorsUrl.allMatches(text).length;
      if (_reusesStyle.hasMatch(text)) reuses = true;
    }
    if (codes == 0) continue;
    if (codeOnly.contains(name)) {
      if (url > 0) problems.add('$name: a code-only package has the URL');
    } else if (reuses) {
      // Takes `thorError` from thor_style, which holds the URL once.
      if (url > 0) {
        problems.add(
          '$name: reuses thor_style\'s `thorError`, so it must not repeat '
          'the URL (found $url)',
        );
      }
    } else if (url != 1) {
      problems.add(
        '$name: uses error codes, so it needs one `thorError` with '
        '$errorsUrl (found $url)',
      );
    }
  }

  final dir = Directory('$root/docs/errores');
  final index = File('${dir.path}/README.md');
  final indexText = index.existsSync() ? index.readAsStringSync() : '';
  final pages = <String>{};
  if (dir.existsSync()) {
    for (final file in dir.listSync().whereType<File>()) {
      final base = file.uri.pathSegments.last;
      if (base == 'README.md') continue;
      final code = base.replaceAll('.md', '');
      if (!errorCode.hasMatch(code) || errorCode.stringMatch(code) != code) {
        problems.add('docs/errores/$base: not a code');
        continue;
      }
      pages.add(code);
      final text = file.readAsStringSync();
      if (!text.startsWith('# $code · ')) {
        problems.add('docs/errores/$base: must start with "# $code · <title>"');
      }
      if (!used.containsKey(code)) {
        problems.add('docs/errores/$base: no package uses $code (delete it)');
      }
      if (!indexText.contains('[$code]($code.md)')) {
        problems.add('docs/errores/README.md: no row for $code');
      }
    }
  }
  for (final MapEntry(key: code, value: where) in used.entries) {
    if (!pages.contains(code)) {
      problems.add('$code (${where.first}) has no page docs/errores/$code.md');
    }
  }
  return problems;
}
