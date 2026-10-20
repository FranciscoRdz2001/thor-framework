// `dart pub publish --dry-run` for every package under packages/ (or the ones
// named), without touching them: a package here is private (`publish_to:
// none`), in the workspace (`resolution: workspace`) and depends on its
// siblings by path, and none of that can be published. So each package is
// copied to a temporary folder where
//
//   * `publish_to` and `resolution` are gone,
//   * a sibling's `path:` dependency is `^<its version>` (what pub.dev
//     would have after publishing it), and
//   * `dependency_overrides` points those versions at the other copies, so
//     pub can resolve them before they exist on pub.dev,
//
// and `dart pub publish --dry-run` runs there. It never publishes: the flag
// is not optional in this script.
//
//   dart tool/publish_check.dart [package…]   (default: all, in publish order)
import 'dart:io';

final _root = Directory(Platform.script.toFilePath()).parent.parent.path;
final _packages = _join(_root, 'packages');

/// The sibling `path:` dependency of a pubspec:
/// `  thor_style:\n    path: ../thor_style`.
final _pathDep = RegExp(
  r'^( *)(thor_\w+):[ \t]*\n[ \t]+path:[ \t]*\.\./(thor_\w+)[ \t]*$',
  multiLine: true,
);

/// A name and its version out of a pubspec's text.
String? _field(String pubspec, String key) =>
    RegExp('^$key:\\s*(\\S+)', multiLine: true).firstMatch(pubspec)?[1];

/// What a package needs from its siblings (their names).
Set<String> _siblings(String pubspec) => {
  for (final m in _pathDep.allMatches(pubspec)) m[3]!,
};

/// The packages with the ones they depend on published first.
List<String> publishOrder(Map<String, Set<String>> deps) {
  final order = <String>[];
  final visiting = <String>{};
  void visit(String name) {
    if (order.contains(name)) return;
    if (!visiting.add(name)) throw StateError('Dependency cycle at $name');
    for (final dep in deps[name] ?? const <String>{}) {
      if (deps.containsKey(dep)) visit(dep);
    }
    visiting.remove(name);
    order.add(name);
  }

  (deps.keys.toList()..sort()).forEach(visit);
  return order;
}

/// The pubspec of a staged copy: publishable, with its siblings as hosted
/// dependencies resolved to the other staged copies.
String stagedPubspec(
  String pubspec,
  Map<String, String> versions,
  Map<String, String> stagedPaths,
  Map<String, Set<String>> deps,
) {
  // Every sibling the package reaches, not only the direct ones: pub
  // resolves the whole tree, and none of them is on pub.dev yet.
  final reached = <String>{};
  void reach(String name) {
    if (!reached.add(name)) return;
    (deps[name] ?? const <String>{}).forEach(reach);
  }

  _siblings(pubspec).forEach(reach);
  var text = pubspec
      .replaceAll(RegExp(r'^publish_to:.*\n', multiLine: true), '')
      .replaceAll(RegExp(r'^resolution:.*\n', multiLine: true), '')
      .replaceAllMapped(_pathDep, (m) => '${m[1]}${m[2]}: ^${versions[m[3]!]}');
  final overrides = [
    for (final dep in reached.toList()..sort())
      '  $dep:\n    path: ${stagedPaths[dep]}\n',
  ];
  if (overrides.isNotEmpty) {
    text = '$text\ndependency_overrides:\n${overrides.join()}';
  }
  return text;
}

void _copy(Directory from, Directory to) {
  to.createSync(recursive: true);
  for (final entity in from.listSync(followLinks: false)) {
    final name = _basename(entity.path);
    if (const {'.dart_tool', 'build', 'node_modules'}.contains(name) ||
        name == 'pubspec.lock') {
      continue;
    }
    final target = _join(to.path, name);
    if (entity is Directory) {
      _copy(entity, Directory(target));
    } else if (entity is File) {
      entity.copySync(target);
    }
  }
}

Future<void> main(List<String> args) async {
  final pubspecs = {
    for (final dir in Directory(_packages).listSync().whereType<Directory>())
      // thor_engine_oracle is internal (a test oracle): never published.
      if (_basename(dir.path) != 'thor_engine_oracle' &&
          File(_join(dir.path, 'pubspec.yaml')).existsSync())
        _basename(dir.path): File(
          _join(dir.path, 'pubspec.yaml'),
        ).readAsStringSync(),
  };
  final versions = {
    for (final e in pubspecs.entries) e.key: _field(e.value, 'version') ?? '',
  };
  final deps = {for (final e in pubspecs.entries) e.key: _siblings(e.value)};
  final order = publishOrder(deps);
  final unknown = args.where((a) => !pubspecs.containsKey(a)).toList();
  if (unknown.isNotEmpty) {
    stderr.writeln('No such package: ${unknown.join(', ')}');
    exit(64);
  }
  final chosen = args.isEmpty
      ? order
      : [
          for (final name in order)
            if (args.contains(name)) name,
        ];

  final stage = Directory.systemTemp.createTempSync('thor_publish_check');
  final failed = <String>[];
  try {
    final stagedPaths = {
      for (final name in order) name: _join(stage.path, name),
    };
    for (final name in order) {
      _copy(Directory(_join(_packages, name)), Directory(stagedPaths[name]!));
      File(_join(stagedPaths[name]!, 'pubspec.yaml')).writeAsStringSync(
        stagedPubspec(pubspecs[name]!, versions, stagedPaths, deps),
      );
    }
    for (final name in chosen) {
      stdout.writeln('\n== $name ${versions[name]}');
      final result = await Process.start(
        'dart',
        ['pub', 'publish', '--dry-run'],
        workingDirectory: stagedPaths[name],
        mode: ProcessStartMode.inheritStdio,
      );
      if (await result.exitCode != 0) failed.add(name);
    }
  } finally {
    stage.deleteSync(recursive: true);
  }
  stdout.writeln('\nPublish order: ${order.join(' -> ')}');
  if (failed.isEmpty) {
    stdout.writeln('dry-run clean: ${chosen.join(', ')}');
  } else {
    stderr.writeln('dry-run failed: ${failed.join(', ')}');
    exit(1);
  }
}

String _join(String a, String b) => '$a${Platform.pathSeparator}$b';

String _basename(String path) => path.split(Platform.pathSeparator).last;
