/// The `thor` command: create an app, run it with everything rebuilt on
/// change, add pages and states, build, export, preview and check.
library;

import 'package:args/args.dart';
import 'package:args/command_runner.dart';

import 'src/commands/add.dart';
import 'src/commands/analyze.dart';
import 'src/commands/build.dart';
import 'src/commands/create.dart';
import 'src/commands/deploy.dart';
import 'src/commands/dev.dart';
import 'src/commands/doctor.dart';
import 'src/commands/fonts.dart';
import 'src/commands/mcp.dart';
import 'src/commands/preview.dart';
import 'src/commands/render.dart';
import 'src/commands/test.dart';

export 'src/add_plan.dart'
    show AddNote, AddPlan, planAddLayout, planAddPage, routePathPattern;
export 'src/assets.dart' show PublicAssets;
export 'src/checkout.dart'
    show
        CheckoutStatus,
        GitRunner,
        checkoutStatus,
        reportCheckout,
        runGit,
        runGitWith;
export 'src/commands/add.dart'
    show
        GroupArgumentAdded,
        GroupArgumentResult,
        GroupArgumentTaken,
        GroupNotFound,
        wireGroupArgument;
export 'src/commands/analyze.dart' show analyzeArgs, formatArgs, toolLocation;
export 'src/commands/build.dart' show buildEngine, buildStatic, staticLocales;
export 'src/commands/create.dart' show CreatePlan, planCreate, writeApp;
export 'src/commands/doctor.dart' show olderThan;
export 'src/commands/fonts.dart'
    show
        FontsCommand,
        iconCodePoints,
        latinUnicodes,
        parseUnicodes,
        unicodeRangeOf;
export 'src/commands/preview.dart' show resolveStatic, serveStatic;
export 'src/commands/test.dart'
    show
        danglingValueOption,
        expandTestArgs,
        libraryAnnotations,
        testFiles,
        testWrapper,
        writeTestWrappers;
export 'src/deploy.dart'
    show
        DeployPlan,
        DeployTarget,
        EnvVar,
        envVars,
        planDeploy,
        serverGcFlag,
        serverLauncher,
        writeDeployPlan,
        writeServerLauncher;
export 'src/dev/vm_client.dart' show VmClient;
export 'src/dev_proxy.dart' show DevProxy;
export 'src/dotenv.dart' show appEnvironment, dotEnv, parseDotEnv;
export 'src/flutter_embed.dart';
export 'src/font_metrics.dart'
    show
        FallbackMetrics,
        FontMetrics,
        ProcessRunner,
        readAnyFontMetrics,
        readFontMetrics;
export 'src/render/report.dart';
export 'src/resources.dart' show ServerResources;
export 'src/run.dart'
    show
        Say,
        ThorException,
        commandEndpointsIn,
        diagnosticErrors,
        diagnostics,
        exec,
        freePort,
        freePortPair,
        generate,
        misuseReport,
        queryEndpointsIn,
        rejectQueriesOnDartEngine,
        isMisuseWarning,
        writeEntries;
export 'src/templates.dart';
export 'src/workspace.dart';

/// The command with every subcommand.
CommandRunner<int> thorRunner() =>
    _ThorRunner(
        'thor',
        'thor: Flutter widgets rendered as HTML and CSS.\n\n'
            'Start: thor create my_app && cd my_app && thor dev',
      )
      ..addCommand(CreateCommand())
      ..addCommand(DevCommand())
      ..addCommand(AddCommand())
      ..addCommand(BuildCommand())
      ..addCommand(ExportCommand())
      ..addCommand(PreviewCommand())
      ..addCommand(DeployCommand())
      ..addCommand(RenderCommand())
      ..addCommand(TestCommand())
      ..addCommand(AnalyzeCommand())
      ..addCommand(FormatCommand())
      ..addCommand(McpCommand())
      ..addCommand(FontsCommand())
      ..addCommand(DoctorCommand());

/// `thor dev --host` alone means every interface, and an option of the
/// `args` package always takes a value: [expandBareHost] gives it one.
/// `thor test` passes the options it doesn't know to `dart test`
/// ([expandTestArgs]).
class _ThorRunner extends CommandRunner<int> {
  _ThorRunner(super.executableName, super.description);

  @override
  ArgResults parse(Iterable<String> args) =>
      super.parse(expandTestArgs(expandBareHost(args)));
}

/// [args] with a bare `--host` (last, or followed by another option) as
/// `--host=0.0.0.0`, like Vite's. Only for `thor dev`. `--host <address>` and
/// `--host=<address>` are left as they are.
List<String> expandBareHost(Iterable<String> args) {
  final list = args.toList();
  if (!list.contains('dev')) return list;
  final end = list.indexOf('--');
  for (var i = 0; i < list.length; i++) {
    if (end >= 0 && i >= end) break;
    if (list[i] == '--host' &&
        (i + 1 == list.length || list[i + 1].startsWith('-'))) {
      list[i] = '--host=0.0.0.0';
    }
  }
  return list;
}
