import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../assets.dart';
import '../checkout.dart';
import '../dev/facade_clashes.dart';
import '../run.dart';
import '../workspace.dart';

/// `thor doctor`: what would stop the project from running, and the fix
/// (applied with `--fix` when it is safe).
class DoctorCommand extends Command<int> {
  /// The command.
  DoctorCommand() {
    argParser
      ..addFlag('fix', help: 'Apply the safe fixes.', negatable: false)
      ..addFlag(
        'fetch',
        help:
            'git fetch the thor checkout first, so "behind" is current '
            '(updates its remote-tracking branches only).',
        negatable: false,
      );
  }

  @override
  String get name => 'doctor';

  @override
  String get description =>
      'Check the SDK, the project and its tools; --fix repairs what it can.';

  @override
  String get invocation => 'thor doctor [project]';

  @override
  Future<int> run() async {
    final fix = argResults!['fix'] as bool;
    final problems = <String>[];

    final version = Platform.version.split(' ').first;
    if (olderThan(version, '3.10.0')) {
      problems.add('Dart $version: thor needs 3.10 or newer.');
    } else {
      Say.ok('Dart $version');
    }

    final home = await ThorHome.locate();
    if (home == null) {
      Say.warn('thor checkout not found (set THOR_HOME to one).');
    } else {
      if (argResults!['fetch'] as bool) {
        await runGit(home.root, ['fetch', '-q']);
      }
      final status = await checkoutStatus(home.root);
      reportCheckout(
        status,
        line: (l) => status.warnings.isEmpty ? Say.ok(l) : Say.warn(l),
        warn: Say.warn,
        note: Say.info,
      );
    }

    final rest = argResults!.rest;
    final project = Project.find(rest.isEmpty ? null : rest.first);
    if (project == null) {
      Say.info('(no thor project here: create one with thor create <name>)');
      return _report(problems);
    }
    Say.info(
      '${project.display}: ${project.isServer ? 'server app' : 'static app'}',
    );

    final workspace = project.workspace;
    if (project.inWorkspace) {
      final member = workspace == null
          ? null
          : p.relative(project.dir, from: workspace.root);
      if (workspace == null) {
        problems.add('resolution: workspace, but no workspace above it.');
      } else if (!workspace.members.contains(member)) {
        if (fix) {
          workspace.addMember(member!);
          Say.ok('$member added to the workspace');
        } else {
          problems.add('$member is not in the workspace list (--fix adds it).');
        }
      }
    }

    final config = File(
      p.join(project.pubRoot, '.dart_tool', 'package_config.json'),
    );
    final resolved =
        config.existsSync() &&
        config.readAsStringSync().contains('"${project.name}"');
    if (resolved) {
      Say.ok('dependencies resolved');
    } else if (fix) {
      await exec('dart', ['pub', 'get'], dir: project.pubRoot, quiet: true);
      Say.ok('dependencies resolved');
    } else {
      problems.add(
        'dependencies not resolved (--fix, or thor dev, runs pub get).',
      );
    }

    if (project.isServer) {
      final table = File(project.path('lib/router.dart'));
      if (table.existsSync()) {
        Say.ok('route table: lib/router.dart');
      } else {
        problems.add('no lib/router.dart: the route table of the app.');
      }
    } else if (!File(project.path('lib/main.server.dart')).existsSync()) {
      problems.add('A static app renders lib/main.server.dart; there is none.');
    } else {
      Say.ok('static page: lib/main.server.dart');
    }

    if (!Directory(project.path('web')).existsSync()) {
      if (fix) {
        Directory(project.path('web')).createSync();
        Say.ok('web/ created');
      } else {
        problems.add('web/ missing, the public files (--fix creates it).');
      }
    }
    final assets = PublicAssets(project);
    if (assets.declared().isNotEmpty) {
      if (fix) {
        Say.ok('package files in web/ (${assets.sync().length} updated)');
      } else {
        Say.info('package files: thor dev keeps them in sync');
      }
    }

    if (fix) {
      final cache = Directory(project.path('.dart_tool/build'));
      if (cache.existsSync()) {
        cache.deleteSync(recursive: true);
        Say.ok('build cache cleared');
      }
    }

    _reportClashes(project, home);

    try {
      await freePort(4300, tries: 1);
    } on ThorException {
      Say.warn('port 4300 is busy: thor dev takes the next free one');
    }
    return _report(problems);
  }

  /// Warns about names of the app that a thor facade exports too (they
  /// break the build the day thor adds them, `ambiguous_import`).
  void _reportClashes(Project project, ThorHome? home) {
    final snapshot = home == null
        ? null
        : File(p.join(home.root, 'docs', 'api', 'public_api.txt'));
    final lib = Directory(project.path('lib'));
    if (snapshot == null || !snapshot.existsSync()) {
      // thor from pub: no snapshot of the facades to compare with.
      Say.info('facade name clashes: not checked (no thor checkout)');
      return;
    }
    if (!lib.existsSync()) return;
    final files = <String, String>{};
    for (final f in lib.listSync(recursive: true)) {
      if (f is File && f.path.endsWith('.dart')) {
        files[p.posix.joinAll(p.split(p.relative(f.path, from: project.dir)))] =
            f.readAsStringSync();
      }
    }
    final clashes = findClashes(
      files,
      package: project.name,
      facade: facadeNames(snapshot.readAsStringSync()),
    );
    if (clashes.isEmpty) {
      Say.ok('no names clash with the thor facades');
      return;
    }
    for (final c in clashes) {
      Say.warn(
        '${c.name} (${c.declaredIn}) is also exported by ${c.import}: '
        '${c.files.join(', ')} import both. Add `${c.fix}` there.',
      );
    }
  }

  int _report(List<String> problems) {
    if (problems.isEmpty) {
      Say.ok('ready');
      return 0;
    }
    problems.forEach(Say.error);
    return 1;
  }
}

/// Whether [version] (`3.12.2`, `3.9.0-1.dev`) is older than [minimum].
bool olderThan(String version, String minimum) {
  List<int> parts(String v) => [
    for (final s in v.split('-').first.split('.')) int.tryParse(s) ?? 0,
  ];
  final a = parts(version), b = parts(minimum);
  for (var i = 0; i < 3; i++) {
    if (a[i] != b[i]) return a[i] < b[i];
  }
  return false;
}
