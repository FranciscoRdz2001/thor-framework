import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'workspace.dart';

/// Files a package publishes into the apps that use it, declared in its
/// pubspec (a design system's fonts):
///
/// ```yaml
/// thor:
///   public:
///     fonts: fonts   # its fonts/ → the app's web/fonts/
/// ```
///
/// Copied into the app's `web/` when missing or different, so a new app
/// never copies them by hand and an update reaches every app.
///
/// An app that does not use one of them says so in its own pubspec, and it
/// is not copied (a file already there stays: delete it):
///
/// ```yaml
/// thor:
///   public:
///     exclude: [scripts]   # no web/scripts/ from thor_studio
/// ```
class PublicAssets {
  /// The assets of [project]'s direct dependencies.
  PublicAssets(this.project);

  /// The project.
  final Project project;

  /// The folders of `web/` the app's own pubspec leaves out
  /// (`thor: public: exclude: [scripts]`).
  Set<String> excluded() {
    final file = File(project.path('pubspec.yaml'));
    if (!file.existsSync()) return const {};
    final thor = (loadYaml(file.readAsStringSync()) as YamlMap)['thor'];
    final public = thor is YamlMap ? thor['public'] : null;
    final exclude = public is YamlMap ? public['exclude'] : null;
    if (exclude == null) return const {};
    if (exclude is! YamlList) {
      throw FormatException(
        'thor: public: exclude in ${file.path} must be a list of folders '
        'of web/ (`exclude: [scripts]`)',
      );
    }
    return {for (final name in exclude) '$name'};
  }

  /// Folder in `web/` → source folder, for every dependency that declares
  /// some and the app does not exclude.
  Map<String, String> declared() {
    final deps = project.dependencies;
    final roots = _packageRoots();
    final out = <String, String>{};
    for (final dep in deps) {
      final root = roots[dep];
      if (root == null) continue;
      final file = File(p.join(root, 'pubspec.yaml'));
      if (!file.existsSync()) continue;
      final thor = (loadYaml(file.readAsStringSync()) as YamlMap)['thor'];
      final public = thor is YamlMap ? thor['public'] : null;
      if (public is! YamlMap) continue;
      for (final MapEntry(:key, :value) in public.entries) {
        // `exclude` is the app's own setting, never a package's folder.
        if (key == 'exclude') continue;
        out['$key'] = p.join(root, '$value');
      }
    }
    final excluded = this.excluded();
    return {
      for (final MapEntry(:key, :value) in out.entries)
        if (!excluded.contains(key)) key: value,
    };
  }

  /// Copies what is missing or changed; returns the files written
  /// (relative to the app).
  List<String> sync() {
    final written = <String>[];
    for (final MapEntry(key: dest, value: source) in declared().entries) {
      final from = Directory(source);
      if (!from.existsSync()) continue;
      for (final entity in from.listSync(recursive: true)) {
        if (entity is! File) continue;
        final relative = p.relative(entity.path, from: source);
        final target = File(project.path(p.join('web', dest, relative)));
        if (target.existsSync() && _same(entity, target)) continue;
        target.parent.createSync(recursive: true);
        entity.copySync(target.path);
        written.add(p.relative(target.path, from: project.dir));
      }
    }
    return written;
  }

  static bool _same(File a, File b) {
    if (a.lengthSync() != b.lengthSync()) return false;
    final x = a.readAsBytesSync(), y = b.readAsBytesSync();
    for (var i = 0; i < x.length; i++) {
      if (x[i] != y[i]) return false;
    }
    return true;
  }

  /// Package name → its folder, from the workspace's resolution.
  Map<String, String> _packageRoots() {
    final config = File(
      p.join(project.pubRoot, '.dart_tool', 'package_config.json'),
    );
    if (!config.existsSync()) return const {};
    final json = jsonDecode(config.readAsStringSync()) as Map<String, Object?>;
    final base = p.dirname(config.path);
    return {
      for (final pkg in json['packages']! as List<Object?>)
        if (pkg case {'name': final String name, 'rootUri': final String uri})
          name: uri.startsWith('file:')
              ? p.fromUri(Uri.parse(uri))
              : p.normalize(p.join(base, p.fromUri(Uri.parse(uri)))),
    };
  }
}
