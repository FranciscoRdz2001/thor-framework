// `thor analyze` must not pass when thor's lint rules did not run.
@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_cli/src/commands/analyze.dart';

const _canaryLine =
    '  error - lib/$canaryFile:6:9 - The lite translator cannot write this. '
    '- thor_lite_subset';

void main() {
  group('judgeAnalysis', () {
    test('a clean run with the canary reported passes', () {
      final j = judgeAnalysis(
        'Analyzing app...\n$_canaryLine\n1 issue found.\n',
        fatalInfos: true,
        expectCanary: true,
      );
      expect(j.problems, isEmpty);
      expect(j.report, isNot(contains(canaryFile)));
      expect(j.report, isNot(contains('issue found')));
    });

    test('a plugin that crashed is a failure, whatever the exit code', () {
      final j = judgeAnalysis(
        'An error occurred while executing an analyzer plugin: boom\n'
        'No issues found!\n',
        fatalInfos: true,
        expectCanary: false,
      );
      expect(j.problems.single, contains('plugin'));
    });

    test('a PluginServer stack is a plugin failure', () {
      final j = judgeAnalysis(
        '#0 PluginServer.start (package:analysis_server_plugin/x.dart)\n',
        fatalInfos: true,
        expectCanary: false,
      );
      expect(j.problems, isNotEmpty);
    });

    test('a missing canary means the rules did not run', () {
      final j = judgeAnalysis(
        'No issues found!\n',
        fatalInfos: true,
        expectCanary: true,
      );
      expect(j.problems.single, contains('thor_lite_subset'));
      expect(j.problems.single, contains('did not run'));
    });

    test('no canary is asked when thor_lints is not enabled', () {
      final j = judgeAnalysis(
        'No issues found!\n',
        fatalInfos: true,
        expectCanary: false,
      );
      expect(j.problems, isEmpty);
    });

    test('an info is fatal only with fatal infos', () {
      const out = '   info - lib/a.dart:1:1 - Something. - some_lint\n';
      expect(
        judgeAnalysis(out, fatalInfos: true, expectCanary: false).problems,
        isNotEmpty,
      );
      expect(
        judgeAnalysis(out, fatalInfos: false, expectCanary: false).problems,
        isEmpty,
      );
    });

    test('a warning or an error always fails, the canary aside', () {
      final j = judgeAnalysis(
        '$_canaryLine\n warning - lib/a.dart:1:1 - Unused. - unused_import\n',
        fatalInfos: false,
        expectCanary: true,
      );
      expect(j.problems.single, contains('issue'));
      expect(j.report, contains('unused_import'));
    });
  });

  test('lite check arguments run the builder step on the package', () {
    expect(liteCheckArgs(), ['run', 'thor_builder:lite_state', '.', '--check']);
  });

  test('the lite check runs by default for a project with thor_builder', () {
    expect(runsLiteCheck(asked: null, dependencies: {'thor_builder'}), isTrue);
    expect(runsLiteCheck(asked: null, dependencies: {'thor_ui'}), isFalse);
    expect(runsLiteCheck(asked: true, dependencies: {'thor_ui'}), isTrue);
    expect(
      runsLiteCheck(asked: false, dependencies: {'thor_builder'}),
      isFalse,
    );
  });

  test('thor_lints enabled is read from analysis_options', () {
    expect(
      pluginEnabledIn('plugins:\n  thor_lints:\n    path: ../x\n'),
      isTrue,
    );
    expect(
      pluginEnabledIn('include: package:lints/recommended.yaml\n'),
      isFalse,
    );
    expect(pluginEnabledIn('# thor_lints is off\n'), isFalse);
  });
}
