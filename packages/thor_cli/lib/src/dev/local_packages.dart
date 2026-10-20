import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// The folders of the packages [app] depends on (directly or not) that are
/// neither in the pub cache nor in the SDK: workspace members and path
/// dependencies, the ones a developer edits (thor's own `packages/`, a
/// monorepo's shared code, a thor checkout), so `thor dev` watches them
/// too. [pubRoot] is where the resolution is (the workspace root).
///
/// Read from pub's `package_graph.json` (the dependency graph) and
/// `package_config.json` (where each package is). Without the graph, every
/// package of the workspace but the app and the root. Dev dependencies of
/// the dependencies don't count (the server doesn't load them).
List<String> localDependencies(
  String pubRoot,
  String app, {
  String? pubCache,
  String? sdk,
}) {
  final cache = p.normalize(pubCache ?? _pubCache());
  final sdkDir = p.normalize(
    sdk ?? p.dirname(p.dirname(Platform.resolvedExecutable)),
  );
  final tool = p.join(pubRoot, '.dart_tool');
  final config = File(p.join(tool, 'package_config.json'));
  if (!config.existsSync()) return const [];
  final locations = <String, String>{};
  final json = jsonDecode(config.readAsStringSync()) as Map<String, Object?>;
  for (final entry in (json['packages'] as List).cast<Map<String, Object?>>()) {
    var root = entry['rootUri'] as String;
    if (!root.endsWith('/')) root = '$root/';
    final dir = p.normalize(Uri.directory(tool).resolve(root).toFilePath());
    if (p.isWithin(cache, dir) || p.isWithin(sdkDir, dir)) continue;
    locations[entry['name'] as String] = dir;
  }
  final root = p.normalize(pubRoot);
  final graphFile = File(p.join(tool, 'package_graph.json'));
  Iterable<String> names;
  if (graphFile.existsSync()) {
    final graph =
        jsonDecode(graphFile.readAsStringSync()) as Map<String, Object?>;
    final deps = {
      for (final node
          in (graph['packages'] as List).cast<Map<String, Object?>>())
        node['name'] as String: [
          ...((node['dependencies'] as List?) ?? const []).cast<String>(),
        ],
    };
    final seen = <String>{};
    final todo = [...?deps[app]];
    while (todo.isNotEmpty) {
      final name = todo.removeLast();
      if (!seen.add(name)) continue;
      todo.addAll(deps[name] ?? const []);
    }
    names = seen;
  } else {
    names = locations.keys.where((n) => n != app);
  }
  return [
    for (final name in names)
      if (locations[name] case final dir? when dir != root) dir,
  ]..sort();
}

/// Where pub keeps downloaded packages.
String _pubCache() {
  final env = Platform.environment;
  if (env['PUB_CACHE'] case final dir? when dir.isNotEmpty) return dir;
  if (Platform.isWindows) {
    return p.join(env['LOCALAPPDATA'] ?? '', 'Pub', 'Cache');
  }
  return p.join(env['HOME'] ?? '', '.pub-cache');
}
