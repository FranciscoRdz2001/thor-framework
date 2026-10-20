import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'run.dart' show ThorException;
import 'workspace.dart';

/// Files the compiled server reads at run time, declared in a pubspec:
///
/// ```yaml
/// thor:
///   resources:        # paths relative to lib/: files or folders
///     - assets
///   sdk: true         # also bundle the Dart SDK libraries (analyzer)
/// ```
///
/// `dart compile exe` resolves no `package:` URIs and has no SDK beside it,
/// so `thor build` copies them to `build/resources/<package>/<path>` and the
/// server finds them with `thorResource('package:<package>/<path>')` and
/// `thorDartSdkPath()` (`package:thor_server/thor_server.dart`). The
/// project's own pubspec and every package it resolves may declare them.
class ServerResources {
  /// The resources [project] and its packages declare.
  ServerResources(this.project);

  /// The project.
  final Project project;

  /// Package name → its declared paths (relative to its `lib/`), only for
  /// packages that declare some.
  Map<String, List<String>> declared() {
    final out = <String, List<String>>{};
    for (final MapEntry(key: name, value: root) in _packageRoots().entries) {
      final thor = _thor(root);
      final list = thor is YamlMap ? thor['resources'] : null;
      if (list == null) continue;
      if (list is! YamlList) {
        throw ThorException(
          'thor.resources in the pubspec of $name must be a list of paths '
          'relative to lib/ (got "$list").',
        );
      }
      final paths = [for (final item in list) '$item'];
      for (final path in paths) {
        final clean = p.posix.normalize(path);
        if (p.posix.isAbsolute(clean) || clean.startsWith('..')) {
          throw ThorException(
            'thor.resources in the pubspec of $name: "$path" must stay '
            'inside lib/.',
          );
        }
      }
      if (paths.isNotEmpty) out[name] = paths;
    }
    return out;
  }

  /// Whether the project or a package it resolves declares `thor: sdk:
  /// true`.
  bool get wantsSdk {
    for (final root in {project.dir, ..._packageRoots().values}) {
      final thor = _thor(root);
      if (thor is YamlMap && thor['sdk'] == true) return true;
    }
    return false;
  }

  /// Replaces [into] (`build/resources`) with the declared files (and the
  /// SDK when [wantsSdk]). Returns the files written, relative to [into].
  List<String> copyInto(String into) {
    final dir = Directory(into);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    final written = <String>[];
    final roots = _packageRoots();
    for (final MapEntry(key: name, value: paths) in declared().entries) {
      final lib = p.join(roots[name]!, 'lib');
      for (final path in paths) {
        final source = p.join(lib, path);
        if (FileSystemEntity.isDirectorySync(source)) {
          for (final f in Directory(source).listSync(recursive: true)) {
            if (f is File) written.add(_copy(f, lib, name, into));
          }
        } else if (File(source).existsSync()) {
          written.add(_copy(File(source), lib, name, into));
        } else {
          throw ThorException(
            'thor.resources in the pubspec of $name lists "$path", which '
            'is not in its lib/.',
          );
        }
      }
    }
    if (wantsSdk) written.addAll(_copySdk(into));
    return written;
  }

  static String _copy(File file, String lib, String package, String into) {
    final relative = p.join(package, p.relative(file.path, from: lib));
    final target = File(p.join(into, relative));
    target.parent.createSync(recursive: true);
    file.copySync(target.path);
    return relative;
  }

  /// `lib/` and `version` of the SDK that runs this command: all the
  /// analyzer needs to resolve `dart:core`.
  List<String> _copySdk(String into) {
    final sdk = p.dirname(p.dirname(Platform.resolvedExecutable));
    final lib = Directory(p.join(sdk, 'lib'));
    if (!Directory(p.join(lib.path, '_internal')).existsSync()) {
      throw ThorException(
        'thor.sdk is true but no Dart SDK was found beside '
        '${Platform.resolvedExecutable}.',
      );
    }
    final written = <String>[];
    final to = p.join(into, 'dart-sdk');
    for (final f in lib.listSync(recursive: true)) {
      if (f is! File) continue;
      final relative = p.relative(f.path, from: sdk);
      final target = File(p.join(to, relative));
      target.parent.createSync(recursive: true);
      f.copySync(target.path);
      written.add(p.join('dart-sdk', relative));
    }
    final version = File(p.join(sdk, 'version'));
    if (version.existsSync()) {
      version.copySync(p.join(to, 'version'));
      written.add(p.join('dart-sdk', 'version'));
    }
    return written;
  }

  Object? _thor(String root) {
    final file = File(p.join(root, 'pubspec.yaml'));
    if (!file.existsSync()) return null;
    final yaml = loadYaml(file.readAsStringSync());
    return yaml is YamlMap ? yaml['thor'] : null;
  }

  /// The project and every package of its resolution, by name.
  Map<String, String> _packageRoots() {
    final out = <String, String>{project.name: project.dir};
    final config = File(
      p.join(project.pubRoot, '.dart_tool', 'package_config.json'),
    );
    if (!config.existsSync()) return out;
    final json = jsonDecode(config.readAsStringSync()) as Map<String, Object?>;
    final base = p.dirname(config.path);
    for (final pkg in json['packages']! as List<Object?>) {
      if (pkg case {'name': final String name, 'rootUri': final String uri}) {
        out.putIfAbsent(
          name,
          () => uri.startsWith('file:')
              ? p.fromUri(Uri.parse(uri))
              : p.normalize(p.join(base, p.fromUri(Uri.parse(uri)))),
        );
      }
    }
    return out;
  }
}
