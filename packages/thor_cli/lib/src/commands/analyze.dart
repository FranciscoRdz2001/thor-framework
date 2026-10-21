import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../run.dart';
import '../workspace.dart';
import 'base.dart';

/// Where `dart analyze` and `dart format` run for [project]: from the
/// folder `dart pub get` resolves it in (the workspace root, when it joins
/// one), pointing at the project's own folder. thor_lints is a plugin of
/// the analyzer: its rules run only for an analysis started at the root of
/// the package configuration, not from inside a member.
({String root, String target}) toolLocation(Project project) {
  final root = project.pubRoot;
  final target = p.relative(project.dir, from: root);
  return (root: root, target: target);
}

/// The arguments of `dart analyze` for `thor analyze`.
List<String> analyzeArgs(String target, {bool fatalInfos = true}) => [
  'analyze',
  if (fatalInfos) '--fatal-infos',
  target,
];

/// The arguments of `dart` that check the package in the current folder
/// against the lite subset (`thor analyze --lite`): thor_builder's
/// `lite_state --check`.
List<String> liteCheckArgs() => [
  'run',
  'thor_builder:lite_state',
  '.',
  '--check',
];

/// Whether `thor analyze` also checks the lite subset: by default when the
/// project has thor_builder (an app with states the browser runs), so
/// `String.replaceAllMapped` or `Random` in code a state reaches is reported
/// here and not by the first build; always when [asked] (`--lite`), never
/// with `--no-lite`.
bool runsLiteCheck({required bool? asked, required Set<String> dependencies}) =>
    asked ?? dependencies.contains('thor_builder');

/// The file `thor analyze` drops in `lib/` while it analyzes: a state that
/// breaks the lite subset, so `thor_lite_subset` must report it when thor's
/// analyzer plugin (thor_lints) is alive.
const canaryFile = 'zz_thor_canary.dart';

/// The canary's source: needs only `thor_ui`, which every thor project has.
const canarySource = '''
import 'dart:async';

import 'package:thor_ui/thor_ui.dart';

// Written by `thor analyze` and removed when it ends: the lint rules of
// thor_lints must flag this, or the analyzer plugin is not running.
class ZzThorCanary extends ThorState {
  final a = state(0);
  Object f() => Completer<int>.sync();
}
''';

/// Whether an `analysis_options.yaml` [text] turns thor_lints on (a
/// non-comment line naming it).
bool pluginEnabledIn(String text) => text
    .split('\n')
    .any((l) => !l.trimLeft().startsWith('#') && l.contains('thor_lints'));

/// What `dart analyze` said, judged: the `problems` that make `thor analyze`
/// fail and the `report` to show (the canary and the count that included it
/// are left out).
typedef AnalysisJudgement = ({List<String> problems, String report});

final _pluginFailure = RegExp(
  'error occurred while executing an analyzer plugin|PluginServer',
  caseSensitive: false,
);
final _diagnostic = RegExp(r'^\s*(info|warning|error) - ', multiLine: true);

/// `dart analyze` exits 0 when the analyzer plugin crashes or never starts,
/// so a gate on its exit code passes with no thor_lints rule run. This
/// judges [output]: it fails when it mentions a plugin error, when the
/// canary ([expectCanary]: thor_lints is enabled) was not reported, and
/// when anything but the canary is an issue ([fatalInfos]: infos count).
AnalysisJudgement judgeAnalysis(
  String output, {
  required bool fatalInfos,
  required bool expectCanary,
}) {
  final problems = <String>[];
  if (_pluginFailure.hasMatch(output)) {
    problems.add(
      'the thor_lints analyzer plugin failed: its rules did not run.',
    );
  }
  final lines = output.split('\n');
  final mine = [
    for (final l in lines)
      if (l.contains(canaryFile)) l,
  ];
  if (expectCanary &&
      !mine.any((l) => l.contains('thor_lite_subset')) &&
      problems.isEmpty) {
    problems.add(
      'the thor_lints canary (thor_lite_subset) was not reported: the '
      'analyzer plugin did not run. Run `dart pub get` at the workspace '
      'root and analyze again.',
    );
  }
  final rest = [
    for (final l in lines)
      if (!l.contains(canaryFile) &&
          !RegExp(r'^\d+ issues? found\.$').hasMatch(l.trim()))
        l,
  ];
  final issues = [
    for (final m in _diagnostic.allMatches(rest.join('\n')))
      if (fatalInfos || m.group(1) != 'info') m.group(1),
  ];
  if (issues.isNotEmpty) {
    problems.add('${issues.length} issue(s) found.');
  }
  return (problems: problems, report: rest.join('\n').trim());
}

/// The arguments of `dart format` for `thor format`: [check] only lists the
/// files that would change and fails (`--set-exit-if-changed`).
List<String> formatArgs(String target, {bool check = false}) => [
  'format',
  if (check) ...['--output=none', '--set-exit-if-changed'],
  target,
];

/// `thor analyze`: `dart analyze --fatal-infos` run from the workspace root,
/// so the editor's rules (thor_lints) run as they do in the editor.
class AnalyzeCommand extends Command<int> with ProjectCommand<int> {
  /// The command.
  AnalyzeCommand() {
    argParser.addFlag(
      'fatal-infos',
      defaultsTo: true,
      help: 'Treat infos as errors, like the CI of a new project.',
    );
    argParser.addFlag(
      'lite',
      help:
          'Also check the package against the lite subset: its ThorState '
          'classes and every data class (a fromJson), as the build of an '
          'app that uses them would. On by default when thor_builder is a '
          'dependency; --no-lite skips it.',
    );
  }

  @override
  String get name => 'analyze';

  @override
  String get description =>
      'Analyze the project (dart analyze --fatal-infos) from its workspace '
      "root, so thor's own lint rules run.";

  @override
  String get invocation => 'thor analyze [project]';

  @override
  Future<int> run() async {
    final project = resolveProject();
    final (:root, :target) = toolLocation(project);
    Say.step('Analyze ${project.name}');
    final fatalInfos = argResults!['fatal-infos'] as bool;
    // The rules of thor_lints run in a plugin that can fail without
    // failing `dart analyze`: a canary state proves they ran.
    final enabled = _pluginEnabled(project.dir, root);
    final canary = File(p.join(project.dir, 'lib', canaryFile));
    final lib = canary.parent;
    final dropCanary = enabled && lib.existsSync() && !canary.existsSync();
    if (dropCanary) canary.writeAsStringSync(canarySource);
    final String output;
    try {
      final process = await Process.start(
        'dart',
        analyzeArgs(target, fatalInfos: fatalInfos),
        workingDirectory: root,
      );
      final buffer = StringBuffer();
      await Future.wait([
        process.stdout.transform(utf8.decoder).forEach(buffer.write),
        process.stderr.transform(utf8.decoder).forEach(buffer.write),
      ]);
      await process.exitCode;
      output = buffer.toString();
    } finally {
      if (dropCanary && canary.existsSync()) canary.deleteSync();
    }
    final judged = judgeAnalysis(
      output,
      fatalInfos: fatalInfos,
      expectCanary: dropCanary,
    );
    if (judged.report.isNotEmpty) stdout.writeln(judged.report);
    if (judged.problems.isNotEmpty) {
      throw ThorException('analyze: ${judged.problems.join(' ')}');
    }
    if (!enabled) {
      Say.warn(
        'thor_lints is not enabled in analysis_options.yaml: its rules did '
        'not run (see "Thor\'s rules" in '
        'https://thor-docs.vercel.app/en/test-and-deploy/cli).',
      );
    }
    Say.ok('No issues.');
    final asked = argResults!.wasParsed('lite')
        ? argResults!['lite'] as bool
        : null;
    if (runsLiteCheck(asked: asked, dependencies: project.dependencies)) {
      Say.step('Lite subset of ${project.name}');
      await exec('dart', liteCheckArgs(), dir: project.dir);
    }
    return 0;
  }

  /// Whether the project's `analysis_options.yaml` (or its workspace
  /// root's) enables thor_lints.
  static bool _pluginEnabled(String projectDir, String root) {
    for (final dir in {projectDir, root}) {
      final file = File(p.join(dir, 'analysis_options.yaml'));
      if (file.existsSync() && pluginEnabledIn(file.readAsStringSync())) {
        return true;
      }
    }
    return false;
  }
}

/// `thor format`: `dart format` on the project, run from its workspace root.
class FormatCommand extends Command<int> with ProjectCommand<int> {
  /// The command.
  FormatCommand() {
    argParser.addFlag(
      'check',
      negatable: false,
      help: 'Change nothing: fail when a file is not formatted (for CI).',
    );
  }

  @override
  String get name => 'format';

  @override
  String get description => 'Format the project (dart format) from its root.';

  @override
  String get invocation => 'thor format [--check] [project]';

  @override
  Future<int> run() async {
    final project = resolveProject();
    final (:root, :target) = toolLocation(project);
    Say.step('Format ${project.name}');
    await exec(
      'dart',
      formatArgs(target, check: argResults!['check'] as bool),
      dir: root,
    );
    return 0;
  }
}
