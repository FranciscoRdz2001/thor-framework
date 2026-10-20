import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'run.dart' show ThorException;

/// A thor project: any Dart package that depends on `thor_ui`, wherever
/// it lives (its own repository, or `apps/` of the thor monorepo).
class Project {
  /// The project at [dir].
  Project(String dir) : dir = p.normalize(p.absolute(dir));

  /// Its folder (absolute).
  final String dir;

  YamlMap get _pubspec =>
      loadYaml(File(path('pubspec.yaml')).readAsStringSync()) as YamlMap;

  /// Its package name.
  String get name => _pubspec['name'] as String;

  /// Its direct dependencies (runtime and dev).
  Set<String> get dependencies => {
    ...?(_pubspec['dependencies'] as YamlMap?)?.keys.cast<String>(),
    ...?(_pubspec['dev_dependencies'] as YamlMap?)?.keys.cast<String>(),
  };

  /// Whether its pubspec resolves with an enclosing workspace.
  bool get inWorkspace => _pubspec['resolution'] == 'workspace';

  /// The enclosing workspace (the thor monorepo or the user's own), when
  /// [inWorkspace].
  Workspace? get workspace =>
      inWorkspace ? Workspace.find(p.dirname(dir)) : null;

  /// Where `dart pub get` resolves it.
  String get pubRoot => workspace?.root ?? dir;

  /// Served by `thor_server` (file routes + `bin/server.dart`), or a
  /// static site pre-rendered by thor.
  bool get isServer => File(path('bin/server.dart')).existsSync();

  /// The app's own entry: the server (`bin/server.dart`), or a static
  /// app's page (`lib/main.server.dart`, a `Document`).
  String get appEntry => isServer ? 'bin/server.dart' : 'lib/main.server.dart';

  /// What thor runs: the generated `.dart_tool/thor/server.dart` (it
  /// registers the app's states, then runs [appEntry]), or [appEntry]
  /// before code generation wrote it.
  String get entry => File(path(generatedServerEntry)).existsSync()
      ? generatedServerEntry
      : appEntry;

  /// The server entry thor generates (`thor_builder:entries`).
  static const generatedServerEntry = '.dart_tool/thor/server.dart';

  /// The dart2js engine entry thor generates (`thor_builder:entries`).
  static const engineEntry = '.dart_tool/thor/engine.dart';

  /// Has pages with browser state (code generation wrote [engineEntry]).
  bool get hasEngine => File(path(engineEntry)).existsSync();

  /// Whether a static build or an export moves the styles most pages share
  /// into one cached stylesheet, from the pubspec:
  ///
  /// ```yaml
  /// thor:
  ///   share_styles: true
  /// ```
  ///
  /// Off by default: it saves bytes from the second page on and costs the
  /// first visit one more request before the first paint.
  bool get shareStyles {
    final thor = _pubspec['thor'];
    final value = thor is YamlMap ? thor['share_styles'] : null;
    if (value == null) return false;
    if (value is! bool) {
      throw ThorException(
        'thor.share_styles in pubspec.yaml must be true or false '
        '(got "$value").',
      );
    }
    return value;
  }

  /// The browser engine of a build. Thor ships one, lite; the
  /// dart2js engine is the internal comparison oracle of the tests,
  /// reached only through `THOR_INTERNAL_ENGINE=dart` (never
  /// through the pubspec or an option). The entry it compiles imports
  /// `thor_engine_oracle`, so only apps of this workspace can use it.
  EngineKind get engine => internalEngine();

  /// A path inside the project.
  String path(String relative) => p.join(dir, relative);

  /// Its folder as the user sees it (relative to where they are).
  String get display {
    final relative = p.relative(dir);
    return relative == '.' ? p.basename(dir) : relative;
  }

  /// Whether [dir] holds a thor project.
  static bool isProject(String dir) {
    final pubspec = File(p.join(dir, 'pubspec.yaml'));
    if (!pubspec.existsSync()) return false;
    final yaml = loadYaml(pubspec.readAsStringSync());
    if (yaml is! YamlMap) return false;
    bool has(Object? deps) => deps is YamlMap && deps.containsKey('thor_ui');
    return has(yaml['dependencies']) || has(yaml['dev_dependencies']);
  }

  /// The project named by [nameOrPath] (a folder, or an app of the
  /// enclosing monorepo: `shop` → `apps/shop`), or the one the current
  /// folder is in.
  static Project? find([String? nameOrPath]) {
    if (nameOrPath != null) {
      final candidates = [
        p.absolute(nameOrPath),
        if (Workspace.find() case final w?) ...[
          p.join(w.root, 'apps', nameOrPath),
          p.join(w.root, nameOrPath),
        ],
      ];
      for (final c in candidates) {
        if (isProject(c)) return Project(c);
      }
      return null;
    }
    var dir = p.normalize(p.absolute(Directory.current.path));
    while (true) {
      if (isProject(dir)) return Project(dir);
      final parent = p.dirname(dir);
      if (parent == dir) return null;
      dir = parent;
    }
  }
}

/// A pub workspace (the thor monorepo, or a user's own): the folder whose
/// `pubspec.yaml` lists `workspace:`.
class Workspace {
  /// The workspace at [root].
  Workspace(this.root);

  /// Its folder (absolute).
  final String root;

  File get _pubspec => File(p.join(root, 'pubspec.yaml'));

  /// Whether it is thor's own repository.
  bool get isThorRepo =>
      Directory(p.join(root, 'packages', 'thor_ui')).existsSync();

  /// The workspace above [from] (or at it), or null.
  static Workspace? find([String? from]) {
    var dir = p.normalize(p.absolute(from ?? Directory.current.path));
    while (true) {
      final pubspec = File(p.join(dir, 'pubspec.yaml'));
      if (pubspec.existsSync() &&
          RegExp(
            r'^workspace:',
            multiLine: true,
          ).hasMatch(pubspec.readAsStringSync())) {
        return Workspace(dir);
      }
      final parent = p.dirname(dir);
      if (parent == dir) return null;
      dir = parent;
    }
  }

  /// The members listed under `workspace:` (`apps/shop`).
  List<String> get members {
    final yaml = loadYaml(_pubspec.readAsStringSync()) as YamlMap;
    return [for (final m in yaml['workspace'] as YamlList) '$m'];
  }

  /// Adds [member] (`apps/shop`) to the `workspace:` list, keeping the
  /// file as written. False if it was already there.
  bool addMember(String member) {
    final text = _pubspec.readAsStringSync();
    final updated = addWorkspaceMember(text, member);
    if (updated == text) return false;
    _pubspec.writeAsStringSync(updated);
    return true;
  }
}

/// The thor framework's checkout: where a project outside the monorepo
/// takes the packages from while they are not on pub.dev. `THOR_HOME`, or
/// the checkout this command runs from.
class ThorHome {
  ThorHome._(this.root);

  /// Its folder.
  final String root;

  /// `packages/<name>` of the checkout.
  String package(String name) => p.join(root, 'packages', name);

  /// The checkout, or null when it can't be found.
  static Future<ThorHome?> locate() async {
    final env = Platform.environment['THOR_HOME'];
    if (env != null && _isHome(env)) return ThorHome._(p.normalize(env));
    final self = await Isolate.resolvePackageUri(
      Uri.parse('package:thor_cli/thor_cli.dart'),
    );
    if (self != null && self.scheme == 'file') {
      // …/packages/thor_cli/lib/thor_cli.dart → the checkout.
      final root = p.normalize(p.join(p.fromUri(self), '..', '..', '..', '..'));
      if (_isHome(root)) return ThorHome._(root);
    }
    final workspace = Workspace.find();
    if (workspace != null && workspace.isThorRepo) {
      return ThorHome._(workspace.root);
    }
    return null;
  }

  static bool _isHome(String dir) =>
      Directory(p.join(dir, 'packages', 'thor_ui')).existsSync() &&
      Directory(p.join(dir, 'packages', 'thor_cli')).existsSync();
}

/// [pubspec] with [member] in its `workspace:` list (after the last entry
/// of the same folder, or at the end of the list); unchanged if listed.
String addWorkspaceMember(String pubspec, String member) {
  final lines = pubspec.split('\n');
  final start = lines.indexWhere((l) => l.trimRight() == 'workspace:');
  if (start < 0) throw const FormatException('no workspace: list');
  var end = start + 1;
  var afterSameFolder = -1;
  final folder = member.split('/').first;
  while (end < lines.length && lines[end].trimLeft().startsWith('- ')) {
    final entry = lines[end].trim().substring(2).trim();
    if (entry == member) return pubspec;
    if (entry.split('/').first == folder) afterSameFolder = end + 1;
    end++;
  }
  final at = afterSameFolder > 0 ? afterSameFolder : end;
  lines.insert(at, '  - $member');
  return lines.join('\n');
}

/// The browser engine of a build: the lite runtime, or, for the tests'
/// comparison oracle only, dart2js.
enum EngineKind {
  /// The engine entry (`.dart_tool/thor/engine.dart`) compiled by dart2js.
  dart,

  /// The lite runtime (JS) with the app's states translated from Dart.
  lite,
}

/// The environment variable that selects the oracle build (`dart`); thor's
/// own tests and CI set it, it is not documented for apps.
const internalEngineVariable = 'THOR_INTERNAL_ENGINE';

/// [EngineKind.dart] when [internalEngineVariable] is `dart`, else lite.
EngineKind internalEngine([Map<String, String>? environment]) =>
    (environment ?? Platform.environment)[internalEngineVariable] == 'dart'
    ? EngineKind.dart
    : EngineKind.lite;
