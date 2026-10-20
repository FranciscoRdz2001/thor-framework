/// Names an app declares at the top level that a thor facade also exports
/// (`package:thor_ui/thor_ui.dart`): a file that imports both gets an
/// `ambiguous_import` error the day thor adds that name. `thor doctor`
/// reports them with the fix (`hide`).
library;

import 'package:path/path.dart' as p;

/// The facade each snapshot import (`thor_ui`, `router`…) is imported as.
const facadeUris = {
  'thor_ui': 'package:thor_ui/thor_ui.dart',
  'router': 'package:thor_ui/router.dart',
  'html': 'package:thor_ui/html.dart',
  'server': 'package:thor_ui/server.dart',
  'testing': 'package:thor_ui/testing.dart',
};

/// The top-level public names of each facade in [snapshot]
/// (`docs/api/public_api.txt`: `import<TAB>name<TAB>signature`); members
/// (`Class.member`) and facades `thor doctor` doesn't check are left out.
Map<String, Set<String>> facadeNames(String snapshot) {
  final out = <String, Set<String>>{};
  for (final line in snapshot.split('\n')) {
    final cols = line.split('\t');
    if (cols.length < 2) continue;
    final name = cols[1];
    if (name.contains('.') || !facadeUris.containsKey(cols[0])) continue;
    out.putIfAbsent(cols[0], () => {}).add(name);
  }
  return out;
}

final _typeDecl = RegExp(
  r'^(?:(?:abstract|sealed|base|final|interface|mixin|augment)\s+)*'
  r'(?:class|mixin|enum|typedef)\s+([A-Za-z_$][\w$]*)',
);
final _extensionType = RegExp(
  r'^extension\s+type\s+(?:const\s+)?([A-Za-z_$][\w$]*)',
);
final _extension = RegExp(
  r'^extension\s+([A-Za-z_$][\w$]*)\s*(?:<[^{]*>)?\s+on\b',
);
final _accessor = RegExp(
  r'^(?:[\w$<>?,.\[\]() ]+?\s+)?(?:get|set)\s+([A-Za-z_$][\w$]*)',
);
final _valueDecl = RegExp(
  r'^(?:[\w$<>?,.\[\]() ]+?\s+)?([A-Za-z_$][\w$]*)\s*(?:<[^>(=]*>)?\s*'
  r'(?:\(|=(?![=>])|;)',
);
final _annotation = RegExp(r'^@[\w$.]+(?:\([^)]*\))?\s*');
const _notDeclarations = {
  'import',
  'export',
  'part',
  'library',
  'return',
  'if',
  'for',
  'while',
  'switch',
  'else',
  'case',
  'super',
  'this',
};

/// [source] without block comments and triple-quoted strings (what could
/// hold a `class X` at the start of a line that isn't one).
String _withoutBlocks(String source) => source
    .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
    .replaceAll(RegExp("'''[\\s\\S]*?'''|\"\"\"[\\s\\S]*?\"\"\""), "''");

/// The names [source] declares at the top level (public ones: a private
/// `_X` can't clash with anything). A light scan of the lines that start
/// in column 0 (as `dart format` leaves declarations), after the
/// annotations on them: anything it mistakes for a declaration only
/// matters if it also has a facade's name.
Set<String> topLevelNames(String source) {
  final out = <String>{};
  for (var line in _withoutBlocks(source).split('\n')) {
    if (line.isEmpty || line.startsWith(RegExp(r'[\s/})\]]'))) continue;
    while (line.startsWith('@')) {
      final annotation = _annotation.firstMatch(line);
      if (annotation == null) break;
      line = line.substring(annotation.end);
    }
    if (line.isEmpty || line.startsWith('@')) continue;
    final match =
        _typeDecl.firstMatch(line) ??
        _extensionType.firstMatch(line) ??
        _extension.firstMatch(line) ??
        _accessor.firstMatch(line) ??
        (line.startsWith('extension') ? null : _valueDecl.firstMatch(line));
    final name = match?[1];
    if (name == null || _notDeclarations.contains(name)) continue;
    if (!name.startsWith('_')) out.add(name);
  }
  return out;
}

bool _brings(String combinators, String name) {
  if (RegExp(r'\bas\s+\w').hasMatch(combinators)) return false;
  var brings = true;
  final lists = RegExp(
    r'\b(show|hide)\b([^;]*?)(?=\b(?:show|hide)\b|$)',
  ).allMatches(combinators);
  for (final c in lists) {
    final listed = RegExp(r'[\w$]+').allMatches(c[2]!).map((n) => n[0]);
    final has = listed.contains(name);
    if (c[1] == 'show' && !has) brings = false;
    if (c[1] == 'hide' && has) brings = false;
  }
  return brings;
}

/// Whether [source] imports [uri] in a way that brings [name] in: not
/// prefixed, not behind a `show` without it, not in its `hide`.
bool importsFacade(String source, String uri, String name) {
  final import = RegExp('''import\\s+['"]${RegExp.escape(uri)}['"]([^;]*);''');
  return import.allMatches(source).any((m) => _brings(m[1]!, name));
}

/// One collision: [name], declared in [declaredIn], is also exported by
/// [import]; [files] import both.
class FacadeClash {
  /// A collision.
  const FacadeClash({
    required this.name,
    required this.declaredIn,
    required this.import,
    required this.files,
  });

  /// The name.
  final String name;

  /// The app's file that declares it (relative to the project).
  final String declaredIn;

  /// The facade that exports it too.
  final String import;

  /// Files that import both without `hide`, `show` or a prefix.
  final List<String> files;

  /// The import that settles it, for [files].
  String get fix => "import '$import' hide $name;";
}

/// The collisions in [files] (project-relative path to source, the files
/// of `lib/`) of the app named [package] with the [facade] names: a name
/// a file brings in from another one (`package:` or relative import,
/// through `export` barrels and `part` files) next to the facade.
List<FacadeClash> findClashes(
  Map<String, String> files, {
  required String package,
  required Map<String, Set<String>> facade,
}) {
  final directive = RegExp(
    r'''^\s*(import|export|part\s+of|part)\s+['"]([^'"]+)['"]([^;]*);''',
    multiLine: true,
  );
  // A part file belongs to the library that includes it.
  final libraryOf = {for (final path in files.keys) path: path};
  final exports = <String, List<(String, String)>>{};
  final imports = <String, List<(String, String)>>{};
  for (final MapEntry(key: path, value: source) in files.entries) {
    for (final m in directive.allMatches(_withoutBlocks(source))) {
      final target = _resolve(m[2]!, from: path, package: package);
      if (target == null || !files.containsKey(target)) continue;
      final kind = m[1]!.replaceAll(RegExp(r'\s+'), ' ');
      if (kind == 'part of') libraryOf[path] = target;
      if (kind == 'export') (exports[path] ??= []).add((target, m[3]!));
      if (kind == 'import') (imports[path] ??= []).add((target, m[3]!));
    }
  }
  final declared = <String, Map<String, String>>{}; // library: name -> file
  for (final MapEntry(key: path, value: source) in files.entries) {
    final library = declared.putIfAbsent(libraryOf[path]!, () => {});
    for (final name in topLevelNames(source)) {
      library.putIfAbsent(name, () => path);
    }
  }
  // What importing [library] brings: its names and what it exports.
  Map<String, String> visible(String library, Set<String> seen) {
    if (!seen.add(library)) return const {};
    final out = {...?declared[library]};
    for (final (target, combinators)
        in exports[library] ?? const <(String, String)>[]) {
      final reexported = visible(libraryOf[target]!, seen);
      for (final MapEntry(:key, :value) in reexported.entries) {
        if (_brings(combinators, key)) out.putIfAbsent(key, () => value);
      }
    }
    return out;
  }

  final out = <FacadeClash>[];
  for (final MapEntry(key: kind, value: names) in facade.entries) {
    final uri = facadeUris[kind]!;
    final users = <(String, String), Set<String>>{}; // (name, file): users
    for (final MapEntry(key: path, value: source) in files.entries) {
      if (libraryOf[path] != path) continue; // a part has no imports
      for (final (target, combinators)
          in imports[path] ?? const <(String, String)>[]) {
        final brought = visible(libraryOf[target]!, {});
        for (final MapEntry(key: name, value: file) in brought.entries) {
          if (!names.contains(name) ||
              !_brings(combinators, name) ||
              !importsFacade(source, uri, name) ||
              declared[path]!.containsKey(name)) {
            continue;
          }
          (users[(name, file)] ??= {}).add(path);
        }
      }
    }
    for (final MapEntry(:key, :value) in users.entries) {
      out.add(
        FacadeClash(
          name: key.$1,
          declaredIn: key.$2,
          import: uri,
          files: value.toList()..sort(),
        ),
      );
    }
  }
  out.sort((a, b) => a.name.compareTo(b.name));
  return out;
}

String? _resolve(String uri, {required String from, required String package}) {
  if (uri.startsWith('package:$package/')) {
    return p.posix.join('lib', uri.substring('package:$package/'.length));
  }
  if (uri.contains(':')) return null;
  return p.posix.normalize(p.posix.join(p.posix.dirname(from), uri));
}
