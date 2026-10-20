import 'dart:io';

import 'package:test/test.dart';

/// What no public text names: how the framework is developed, measured or
/// decided, and the projects it was built for. A match is a line to rewrite
/// for the reader. `changes_test.dart` applies it to the changes pages too.
final privateTerms = <String, RegExp>{
  'a decision record': RegExp(r'\bADR[- ]?\d*\b|docs/adr'),
  'benchmarks or rounds': RegExp(
    r'\bbenchmarks?\b|\brondas?\b|\bdocs/history\b|\bhistory/',
    caseSensitive: false,
  ),
  'another framework': RegExp(
    r'\bSvelte(?:Kit)?\b|\bNext\.js\b|\bReact\b(?! to\b)',
  ),
  'an internal doc': RegExp(r'(?:\bdocs/|\.\./)\d\d-|\bpoc/|\bGOAL\b'),
  'a private project': RegExp(
    r'\b[Kk]iro\b|\bKIRO\b|\bForge\b|\bPOS\b|\bar3\b',
  ),
  'a point of sale': RegExp(r'punto de venta', caseSensitive: false),
  'a client or a design reference': RegExp(
    r'\bvtex\b|\bstelyt\b|\bbencho\b|\bthor-composer\b',
    caseSensitive: false,
  ),
};

/// The repository's own tools and internals: the guide teaches the
/// framework's use, not how the repository is built.
final _repository = <String, RegExp>{
  'the repo tool (tool/thor, tool/golden.sh…)': RegExp(r'\btool/'),
  'golden files': RegExp(r'golden\.sh|\bgoldens?\b', caseSensitive: false),
  'a path under apps/': RegExp(r'\bapps/[\w<{]'),
  'the .dart_tool internals': RegExp(r'\.dart_tool'),
  'the lite or dart2js engine': RegExp(
    r'dart2js|\bmotor lite\b|\blite engine\b|\bengine: (lite|dart)\b|\blite/dart\b',
    caseSensitive: false,
  ),
};

Directory _root() {
  var dir = Directory.current.absolute;
  while (true) {
    if (Directory('${dir.path}/docs/guia').existsSync()) return dir;
    final parent = dir.parent;
    if (parent.path == dir.path) fail('docs/guia not found from the cwd');
    dir = parent;
  }
}

List<File> _files(String path, bool Function(String) keep) => Directory(path)
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => keep(f.path))
    .toList();

/// Every line of [files] that matches one of [patterns], as `file:line`.
List<String> _matches(List<File> files, Map<String, RegExp> patterns) {
  final found = <String>[];
  for (final file in files) {
    final lines = file.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      for (final MapEntry(key: what, value: pattern) in patterns.entries) {
        if (pattern.hasMatch(lines[i])) {
          found.add('${file.path}:${i + 1}: $what: ${lines[i].trim()}');
        }
      }
    }
  }
  return found;
}

void main() {
  final root = _root().path;

  test('the public guide, in every language, has no repository internals', () {
    final files = _files('$root/docs/guia', (p) => p.endsWith('.md'));
    expect(files.where((f) => f.path.contains('/guia/es/')), isNotEmpty);
    expect(files.where((f) => f.path.contains('/guia/en/')), isNotEmpty);
    final found = _matches(files, {...privateTerms, ..._repository});
    expect(found, isEmpty, reason: found.join('\n'));
  });

  test('the error pages, in every language, name nothing private', () {
    final files = _files('$root/docs/errores', (p) => p.endsWith('.md'));
    expect(files.where((f) => f.path.contains('/errores/en/')), isNotEmpty);
    final found = _matches(files, privateTerms);
    expect(found, isEmpty, reason: found.join('\n'));
  });

  test('the strings of the site name nothing private', () {
    final files = [
      ..._files('$root/apps/docs/lib/l10n', (p) => p.endsWith('.arb')),
      File('$root/apps/docs/llms-intro.md'),
    ];
    expect(files.length, greaterThan(2));
    final found = _matches(files, privateTerms);
    expect(found, isEmpty, reason: found.join('\n'));
  });
}
