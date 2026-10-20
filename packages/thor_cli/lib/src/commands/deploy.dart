import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../deploy.dart';
import '../run.dart';
import '../workspace.dart';

/// `thor deploy init <target>`: the configuration a host needs, written
/// into the project. It never deploys.
class DeployCommand extends Command<int> {
  /// The command and its subcommand.
  DeployCommand() {
    addSubcommand(_Init());
  }

  @override
  String get name => 'deploy';

  @override
  String get description =>
      'Write the configuration to deploy the project to a host.';
}

class _Init extends Command<int> {
  _Init() {
    argParser.addFlag(
      'force',
      negatable: false,
      help: 'Replace files that already exist.',
    );
  }

  @override
  String get name => 'init';

  @override
  String get description =>
      'Write the files for a host: '
      '${DeployTarget.values.map((t) => t.id).join(', ')}.';

  @override
  String get invocation => 'thor deploy init <target> [project]';

  @override
  Future<int> run() async {
    final rest = argResults!.rest;
    if (rest.isEmpty || rest.length > 2) {
      usageException(
        'Name a target: ${DeployTarget.values.map((t) => t.id).join(', ')}.',
      );
    }
    final target = DeployTarget.parse(rest.first);
    final project = Project.find(rest.length > 1 ? rest[1] : null);
    if (project == null) {
      throw ThorException(
        rest.length > 1
            ? 'No thor project at "${rest[1]}".'
            : 'Not inside a thor project: run it in one, or name it.',
      );
    }
    final plan = planDeploy(project, target);
    final written = writeDeployPlan(
      project,
      plan,
      force: argResults!['force'] as bool,
    );
    for (final path in written) {
      Say.ok(p.relative(project.path(path)));
    }
    Say.step('Next');
    for (final step in plan.steps) {
      Say.info(step);
    }
    return 0;
  }
}
