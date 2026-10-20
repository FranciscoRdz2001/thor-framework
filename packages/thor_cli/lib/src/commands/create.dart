import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../checkout.dart';
import '../deploy.dart';
import '../run.dart';
import '../templates.dart';
import '../workspace.dart';

/// `thor create <name>`: a server app ready to run.
///
/// Inside the thor repository a bare name goes to `apps/<name>` and joins
/// the workspace; anywhere else it is a project of its own, taking thor
/// from this machine's checkout (or from git with `--git`).
class CreateCommand extends Command<int> {
  /// The command.
  CreateCommand() {
    argParser
      ..addOption(
        'title',
        help: 'The home page title.',
        defaultsTo: 'Hello, Thor',
      )
      ..addOption(
        'git',
        help:
            'Take thor from this git repository instead of the local '
            'checkout (a project to share or deploy).',
        valueHelp: 'url',
      )
      ..addOption(
        'ref',
        help: 'The git branch, tag or commit.',
        defaultsTo: 'master',
      )
      ..addFlag(
        'pub',
        help: 'Resolve dependencies and generate code after writing.',
        defaultsTo: true,
      );
  }

  @override
  String get name => 'create';

  @override
  String get description =>
      'Create an app: routes, layout, error page, server and a test.';

  @override
  String get invocation => 'thor create <name>';

  @override
  Future<int> run() async {
    final rest = argResults!.rest;
    if (rest.length != 1) usageException('Give the app a name.');
    final name = p.basename(rest.single);
    if (!isPackageName(name)) {
      throw ThorException(
        '"$name" is not a valid name: lowercase letters, digits and _, '
        'starting with a letter (and not a thor package).',
      );
    }
    final plan = await planCreate(
      rest.single,
      gitUrl: argResults!['git'] as String?,
      gitRef: argResults!['ref'] as String,
    );
    final target = Directory(plan.dir);
    if (target.existsSync() && target.listSync().isNotEmpty) {
      throw ThorException('${p.relative(plan.dir)} already exists.');
    }

    await _sayThor(plan);
    Say.step('Create ${p.relative(plan.dir)}');
    final files = writeApp(
      plan.dir,
      name,
      source: plan.source,
      title: argResults!['title'] as String,
    );
    files.forEach(Say.info);
    if (plan.workspace case final w?) {
      final member = p.relative(plan.dir, from: w.root);
      if (w.addMember(member)) {
        Say.info('pubspec.yaml: $member joins the workspace');
      }
    }
    if (argResults!['pub'] as bool) {
      Say.step('Dependencies');
      await exec(
        'dart',
        ['pub', 'get'],
        dir: plan.workspace?.root ?? plan.dir,
        quiet: true,
      );
      Say.step('Code generation');
      await generate(plan.dir);
    }
    Say.ok('Ready:');
    Say.info('cd ${p.relative(plan.dir)} && thor dev');
    return 0;
  }
}

/// Says which thor the app is made from; warns when that checkout is
/// behind, dirty or on another branch (never fails, never fetches).
Future<void> _sayThor(CreatePlan plan) async {
  final source = plan.source;
  final root = switch (source) {
    MonorepoSource() => plan.workspace?.root,
    LocalSource(:final root) => root,
    GitSource() => null,
  };
  if (root == null) {
    final git = source as GitSource;
    Say.info('thor: git ${git.url} @ ${git.ref}');
    return;
  }
  reportCheckout(
    await checkoutStatus(root),
    line: Say.info,
    warn: Say.warn,
    note: Say.info,
  );
}

/// Where `thor create` writes and how the project takes thor.
class CreatePlan {
  /// A plan.
  CreatePlan(this.dir, this.source, [this.workspace]);

  /// The new project's folder.
  final String dir;

  /// Where its thor packages come from.
  final ThorSource source;

  /// The workspace it joins (the thor repository), if any.
  final Workspace? workspace;
}

/// The plan for [target] (a name or a path) from the current folder.
Future<CreatePlan> planCreate(
  String target, {
  String? gitUrl,
  String gitRef = 'master',
}) async {
  final name = p.basename(target);
  final workspace = Workspace.find();
  // Inside the thor repository, a bare name is a new app of the monorepo.
  if (gitUrl == null &&
      workspace != null &&
      workspace.isThorRepo &&
      !target.contains('/')) {
    return CreatePlan(
      p.join(workspace.root, 'apps', name),
      const MonorepoSource(),
      workspace,
    );
  }
  final dir = p.normalize(p.absolute(target));
  if (gitUrl != null) return CreatePlan(dir, GitSource(gitUrl, ref: gitRef));
  final home = await ThorHome.locate();
  if (home == null) {
    throw ThorException(
      'Where is thor? Set THOR_HOME to a thor checkout, or pass --git <url>.',
    );
  }
  return CreatePlan(dir, LocalSource(home.root));
}

/// Writes app [name]'s files into [dir]; returns their paths as shown.
List<String> writeApp(
  String dir,
  String name, {
  ThorSource source = const MonorepoSource(),
  String title = 'Hello, Thor',
}) {
  final written = <String>[];
  final files = appFiles(name, source: source, title: title);
  for (final MapEntry(key: path, value: content) in files.entries) {
    final file = File(p.join(dir, path));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
    written.add(p.relative(file.path));
  }
  written.addAll(_writeDockerfile(dir));
  return written;
}

/// The example `Dockerfile` (`thor deploy init docker`) of a new app, when
/// the image can build it: thor comes from the workspace or from git. An app
/// that takes thor from a local checkout outside the build context can't,
/// and gets none (`thor deploy init docker` says why).
List<String> _writeDockerfile(String dir) {
  final project = Project(dir);
  try {
    final plan = planDeploy(project, DeployTarget.docker);
    return [
      for (final path in writeDeployPlan(project, plan))
        p.relative(project.path(path)),
    ];
  } on ThorException {
    return const [];
  }
}
