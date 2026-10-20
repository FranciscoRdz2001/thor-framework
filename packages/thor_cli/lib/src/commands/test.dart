import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import '../assets.dart';
import '../dotenv.dart';
import '../run.dart';
import '../workspace.dart';

/// `thor test`: the app's tests (`dart test`) with its states registered.
///
/// A state's members are generated into `.dart_tool/thor/states.dart`
/// and the app never imports it (THOR-S010), so each test file runs
/// through a wrapper in `.dart_tool/thor/test/` that registers them and
/// then calls the file's `main`. The file's `@TestOn`, `@Tags`, `@Timeout`
/// and `@Skip` go with it. Anything that isn't a test path is passed to
/// `dart test` as is (`-p chrome`, `-n name`, `-r expanded`).
class TestCommand extends Command<int> {
  /// The command.
  TestCommand() {
    argParser
      ..addOption(
        'app',
        abbr: 'a',
        help: 'The project (a folder or a name); default: the current one.',
      )
      ..addFlag(
        'codegen',
        defaultsTo: true,
        help: 'Run code generation first (skip it when thor dev runs).',
      )
      ..addFlag(
        'record',
        negatable: false,
        help:
            'Let MockTransport.recorded call the real backends and save '
            'their responses to test/fixtures (THOR_HTTP_RECORD=1).',
      );
  }

  @override
  String get name => 'test';

  @override
  String get description =>
      "Run the app's tests with its states registered (dart test through "
      'generated wrappers).';

  @override
  String get invocation =>
      'thor test [--app <project>] [--record] [test files or folders] '
      '[dart test options]';

  @override
  String get usageFooter =>
      '\n'
      'Anything else goes to `dart test` as is, no `--` needed:\n'
      '  -N, --plain-name <text>      a plain-text substring of the test name\n'
      '  -n, --name <regexp>          a regular expression on the test name\n'
      '  -t, --tags <tags>            run only tests with these tags\n'
      '  -x, --exclude-tags <tags>    skip tests with these tags\n'
      '  -p, --platform <platform>    vm (default), chrome, ...\n'
      '  -r, --reporter <reporter>    expanded, compact, json, ...\n'
      '  -j, --concurrency <threads>  suites run at once\n'
      'See `dart test --help` for the rest.\n'
      '\n'
      'Examples:\n'
      '  thor test test/cart_test.dart -N "adds a line"\n'
      '  thor test -p chrome -r expanded\n';

  @override
  Future<int> run() async {
    final name = argResults!['app'] as String?;
    final app = Project.find(name);
    if (app == null) {
      throw ThorException(
        name == null
            ? 'Not inside a thor project: run it from the app or pass --app.'
            : 'No thor project at "$name".',
      );
    }
    // Tests that serve web/ see the packages' files, as `thor dev` does.
    PublicAssets(app).sync();
    if (argResults!['codegen'] as bool) {
      Say.step('Code generation');
      await generate(app.dir);
    }
    final targets = <String>[];
    final passThrough = <String>[];
    var valueOfOption = false;
    for (final arg in argResults!.rest) {
      final path = p.normalize(p.join(app.dir, arg));
      // The value of `-N name` is not a test path, even if a folder has
      // that name.
      if (!valueOfOption &&
          !arg.startsWith('-') &&
          (FileSystemEntity.isFileSync(path) ||
              FileSystemEntity.isDirectorySync(path))) {
        targets.add(path);
      } else {
        passThrough.add(arg);
      }
      valueOfOption = _dartTestValueOptions.contains(arg);
    }
    if (danglingValueOption(argResults!.rest) case final option?) {
      usageException('Missing value for `$option`.');
    }
    final files = testFiles(app.dir, targets);
    if (files.isEmpty) {
      Say.info('no tests (test/**_test.dart)');
      return 0;
    }
    final wrappers = writeTestWrappers(app.dir, files);
    final process = await Process.start(
      'dart',
      ['test', ...passThrough, ...wrappers],
      workingDirectory: app.dir,
      // The app's `.env`, as in thor dev: a session secret is there.
      environment: {
        ...dotEnv(app.dir),
        if (argResults!['record'] as bool) 'THOR_HTTP_RECORD': '1',
      },
      mode: ProcessStartMode.inheritStdio,
    );
    return process.exitCode;
  }
}

/// The `dart test` options that take their value as the next argument.
const _dartTestValueOptions = {
  '-n',
  '--name',
  '-N',
  '--plain-name',
  '-t',
  '--tags',
  '-x',
  '--exclude-tags',
  '-p',
  '--platform',
  '-c',
  '--compiler',
  '-P',
  '--preset',
  '-j',
  '--concurrency',
  '-r',
  '--reporter',
  '--file-reporter',
  '--timeout',
  '--total-shards',
  '--shard-index',
  '--suite-load-timeout',
  '--coverage',
  '--coverage-path',
  '--coverage-package',
  '--test-randomize-ordering-seed',
};

/// [args] of a `thor test` call with the options `thor test` does not know
/// after a `--`, so `dart test`'s (`-N`, `-n`, `-t`, `-x`, `-p`, `-r`, `-j`…)
/// need no `--` of their own: the `args` package would reject them as
/// unknown. The command's own (`--app/-a`, `--[no-]codegen`, `--record`,
/// `--help/-h`) stay in front; everything else, in order, goes after.
/// Other commands, and a call that already has a `--`, are left alone.
List<String> expandTestArgs(Iterable<String> args) {
  final list = args.toList();
  final at = list.indexWhere((a) => !a.startsWith('-'));
  if (at < 0 || list[at] != 'test') return list;
  final head = list.sublist(0, at + 1);
  final own = <String>[];
  final theirs = <String>[];
  var i = at + 1;
  for (; i < list.length; i++) {
    final a = list[i];
    if (a == '--') {
      // The caller's own split: from here on it is theirs, as written.
      theirs.addAll(list.sublist(i + 1));
      break;
    }
    if (const {
      '--codegen',
      '--no-codegen',
      '--record',
      '--help',
      '-h',
    }.contains(a)) {
      own.add(a);
    } else if (a == '--app' || a == '-a') {
      own.add(a);
      if (i + 1 < list.length) own.add(list[++i]);
    } else if (a.startsWith('--app=')) {
      own.add(a);
    } else {
      theirs.add(a);
    }
  }
  return [...head, ...own, if (theirs.isNotEmpty) '--', ...theirs];
}

/// The last of [rest] when it is a `dart test` option that takes a value and
/// has none (`thor test -N`): `dart test` would take the first test file as
/// its value, and "no tests match ..." says nothing about it.
String? danglingValueOption(Iterable<String> rest) {
  final last = rest.lastOrNull;
  return last != null && _dartTestValueOptions.contains(last) ? last : null;
}

/// The test files of the app in [dir]: `test/**_test.dart`, or those
/// under [targets] (files or folders).
List<String> testFiles(String dir, List<String> targets) {
  final roots = targets.isEmpty ? [p.join(dir, 'test')] : targets;
  final files = <String>{};
  for (final root in roots) {
    if (FileSystemEntity.isFileSync(root)) {
      files.add(p.normalize(root));
      continue;
    }
    final folder = Directory(root);
    if (!folder.existsSync()) continue;
    for (final f in folder.listSync(recursive: true)) {
      if (f is File && f.path.endsWith('_test.dart')) {
        files.add(p.normalize(f.path));
      }
    }
  }
  return files.toList()..sort();
}

/// Writes a wrapper per test file of [files] (app in [dir]) into
/// `.dart_tool/thor/test/`, same relative path; returns their paths,
/// relative to [dir].
List<String> writeTestWrappers(String dir, List<String> files) {
  final out = p.join(dir, '.dart_tool', 'thor', 'test');
  final states = p.join(dir, '.dart_tool', 'thor', 'states.dart');
  final hasStates = File(states).existsSync();
  final actions = p.join(dir, '.dart_tool', 'thor', 'actions.dart');
  final hasActions = File(actions).existsSync();
  final wrappers = <String>[];
  for (final file in files) {
    final relative = p.relative(file, from: dir);
    final wrapper = File(p.join(out, relative));
    wrapper.parent.createSync(recursive: true);
    wrapper.writeAsStringSync(
      testWrapper(
        testImport: p.relative(file, from: wrapper.parent.path),
        statesImport: hasStates
            ? p.relative(states, from: wrapper.parent.path)
            : null,
        actionsImport: hasActions
            ? p.relative(actions, from: wrapper.parent.path)
            : null,
        annotations: libraryAnnotations(File(file).readAsStringSync()),
      ),
    );
    wrappers.add(p.relative(wrapper.path, from: dir));
  }
  return wrappers;
}

/// The wrapper of one test file: [annotations] (the file's own), the
/// registries ([statesImport], when the app has states; [actionsImport],
/// when its pages have action methods), then the file's `main`.
String testWrapper({
  required String testImport,
  String? statesImport,
  String? actionsImport,
  List<String> annotations = const [],
}) {
  final out = StringBuffer()
    ..writeln('// GENERATED BY thor test - DO NOT MODIFY.')
    ..writeln("// Registers the app's states, then runs $testImport.")
    ..writeln('// ignore_for_file: type=lint');
  for (final a in annotations) {
    out.writeln(a);
  }
  out
    ..writeln('library;')
    ..writeln();
  if (annotations.isNotEmpty) out.writeln("import 'package:test/test.dart';");
  if (actionsImport != null) out.writeln("import '$actionsImport';");
  if (statesImport != null) out.writeln("import '$statesImport';");
  out
    ..writeln("import '$testImport' as file;")
    ..writeln()
    ..writeln('void main() {');
  if (statesImport != null) out.writeln('  registerThorStates();');
  if (actionsImport != null) out.writeln('  registerThorActions();');
  out
    ..writeln('  file.main();')
    ..writeln('}');
  return '$out';
}

/// The test runner's library annotations of [source] (`@TestOn(…)`,
/// `@Tags(…)`, `@Timeout(…)`, `@Skip(…)`, `@OnPlatform(…)`), as written,
/// from before its `library` directive or first import.
List<String> libraryAnnotations(String source) {
  const names = {'TestOn', 'Tags', 'Timeout', 'Skip', 'OnPlatform'};
  final found = <String>[];
  var i = 0;
  while (i < source.length) {
    // Skip blanks and comments.
    final rest = source.substring(i);
    final blank = RegExp(r'^(\s+|//[^\n]*\n?|/\*[\s\S]*?\*/)').firstMatch(rest);
    if (blank != null && blank.end > 0) {
      i += blank.end;
      continue;
    }
    final at = RegExp(r'^@(\w+)').firstMatch(rest);
    if (at == null) break;
    // The annotation runs to its balanced closing parenthesis.
    var end = at.end;
    if (end < rest.length && rest[end] == '(') {
      var depth = 0;
      for (; end < rest.length; end++) {
        final c = rest[end];
        if (c == '(') depth++;
        if (c == ')' && --depth == 0) {
          end++;
          break;
        }
      }
    }
    if (names.contains(at.group(1))) found.add(rest.substring(0, end));
    i += end;
  }
  return found;
}
