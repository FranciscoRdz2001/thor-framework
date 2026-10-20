/// The ratchet of the stringly escape hatches: how many
/// `// ignore: thor_lints/…` comments and `raw:` arguments each package and
/// app has, against a recorded baseline that may only go down
/// (`tool/ratchet_baseline.txt`, `tool/thor ratchet`).
library;

import 'dart:io';

/// What is counted per package or app.
const metrics = ['ignores', 'raw'];

/// Directories never walked: generated, vendored or not part of the
/// workspace.
const _skipDirs = {'.git', '.dart_tool', '.idea', 'build', 'node_modules'};

/// `// ignore: thor_lints/a, thor_lints/b` and `// ignore_for_file: …`.
final _ignore = RegExp(r'//\s*ignore(?:_for_file)?\s*:\s*(.*)$');
final _lintName = RegExp(r'\bthor_lints/[a-z_]+');

/// A `raw:` named argument (`raw: {…}`, `raw: _map`).
final _raw = RegExp(r'(?<![\w.$])raw\s*:');

/// The counts of one Dart [source]: the `thor_lints` ignores and the `raw:`
/// arguments in code (not in comments or strings).
({int ignores, int rawUses}) countSource(String source) {
  var ignores = 0;
  var raw = 0;
  for (final line in source.split('\n')) {
    final (:code, :comment) = _split(line);
    // `///` is documentation, which may show an ignore as an example.
    if (comment != null && !comment.startsWith('///')) {
      final match = _ignore.firstMatch(comment);
      if (match != null) {
        ignores += _lintName.allMatches(match.group(1)!).length;
      }
    }
    raw += _raw.allMatches(code).length;
  }
  return (ignores: ignores, rawUses: raw);
}

// A line split into its code (string contents blanked out) and its `//`
// comment, if any.
({String code, String? comment}) _split(String line) {
  final code = StringBuffer();
  String? quote;
  for (var i = 0; i < line.length; i++) {
    final c = line[i];
    if (quote != null) {
      if (c == r'\') {
        i++;
      } else if (c == quote) {
        quote = null;
        code.write(c);
      }
    } else if (c == "'" || c == '"') {
      quote = c;
      code.write(c);
    } else if (c == '/' && i + 1 < line.length && line[i + 1] == '/') {
      return (code: code.toString(), comment: line.substring(i));
    } else {
      code.write(c);
    }
  }
  return (code: code.toString(), comment: null);
}

/// Counts every package and app under [root]: its relative directory →
/// metric → count. A package is the nearest directory with a `pubspec.yaml`;
/// its test directories (`test/`, `tool/test/`) are not counted (tests exercise the escape hatches
/// on purpose).
Map<String, Map<String, int>> countRepo(Directory root) {
  final counts = <String, Map<String, int>>{};
  final rootPath = root.absolute.path;
  final roots = <String, bool>{};

  bool hasPubspec(String dir) =>
      roots[dir] ??= File('$dir/pubspec.yaml').existsSync();

  String? packageOf(String file) {
    var dir = File(file).parent.path;
    while (dir.length >= rootPath.length) {
      if (hasPubspec(dir)) return dir;
      final parent = Directory(dir).parent.path;
      if (parent == dir) break;
      dir = parent;
    }
    return null;
  }

  void walk(Directory dir) {
    for (final entity in dir.listSync(followLinks: false)) {
      final name = entity.uri.pathSegments.lastWhere((s) => s.isNotEmpty);
      if (entity is Directory) {
        if (_skipDirs.contains(name) || name.startsWith('.')) continue;
        walk(entity);
      } else if (entity is File && name.endsWith('.dart')) {
        if (name.endsWith('.g.dart')) continue;
        final pkg = packageOf(entity.path);
        if (pkg == null) continue;
        final inPackage = entity.path.substring(pkg.length + 1);
        final dirs = inPackage.split('/')..removeLast();
        if (dirs.contains('test') || dirs.contains('integration_test')) {
          continue;
        }
        final c = countSource(entity.readAsStringSync());
        if (c.ignores == 0 && c.rawUses == 0) continue;
        final rel = pkg == rootPath ? '.' : pkg.substring(rootPath.length + 1);
        final into = counts.putIfAbsent(
          rel,
          () => {for (final m in metrics) m: 0},
        );
        into['ignores'] = into['ignores']! + c.ignores;
        into['raw'] = into['raw']! + c.rawUses;
      }
    }
  }

  walk(root);
  return counts;
}

/// The comment at the top of the baseline file.
const baselineHeader = '''
# Escape hatches per package or app (tool/thor ratchet): `ignores` are
# `// ignore: thor_lints/…` comments, `raw` are `raw:` arguments.
# These counts only go down. After removing some, lower them with
# `tool/thor ratchet --update`; never edit a number up by hand.
''';

/// The baseline file's text: one `package<TAB>metric<TAB>count` line per
/// non-zero count, sorted.
String formatBaseline(Map<String, Map<String, int>> counts) {
  final lines = <String>[
    for (final pkg in counts.keys.toList()..sort())
      for (final m in metrics)
        if ((counts[pkg]![m] ?? 0) > 0) '$pkg\t$m\t${counts[pkg]![m]}',
  ];
  return '$baselineHeader${lines.join('\n')}\n';
}

/// Parses [formatBaseline]'s text (`#` lines and blanks are comments).
Map<String, Map<String, int>> parseBaseline(String text) {
  final out = <String, Map<String, int>>{};
  for (final line in text.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final parts = trimmed.split('\t');
    if (parts.length != 3 || !metrics.contains(parts[1])) {
      throw FormatException('Bad baseline line: "$line"');
    }
    out.putIfAbsent(parts[0], () => {})[parts[1]] = int.parse(parts[2]);
  }
  return out;
}

/// A count that went up (or down) against the baseline.
class RatchetChange {
  /// Creates a change of [metric] in [package].
  const RatchetChange(this.package, this.metric, this.baseline, this.current);

  /// The package or app directory.
  final String package;

  /// `ignores` or `raw`.
  final String metric;

  /// The recorded count.
  final int baseline;

  /// The count now.
  final int current;

  @override
  String toString() => '$package: $metric $baseline -> $current';
}

/// The counts that rose against [baseline], and those that fell.
({List<RatchetChange> rose, List<RatchetChange> fell}) compareRatchet(
  Map<String, Map<String, int>> baseline,
  Map<String, Map<String, int>> current,
) {
  final rose = <RatchetChange>[];
  final fell = <RatchetChange>[];
  final packages = {...baseline.keys, ...current.keys}.toList()..sort();
  for (final pkg in packages) {
    for (final m in metrics) {
      final was = baseline[pkg]?[m] ?? 0;
      final now = current[pkg]?[m] ?? 0;
      if (now > was) rose.add(RatchetChange(pkg, m, was, now));
      if (now < was) fell.add(RatchetChange(pkg, m, was, now));
    }
  }
  return (rose: rose, fell: fell);
}
