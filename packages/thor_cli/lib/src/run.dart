import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'errors.dart';

/// Console output with the command's look.
abstract final class Say {
  /// Set by `thor dev --json`: every line below goes here as an event
  /// (`{"event":"log","level":…,"message":…}`) instead of to the terminal.
  static void Function(Map<String, Object?> event)? json;

  static bool _event(String level, String message) {
    final sink = json;
    if (sink == null) return false;
    sink({'event': 'log', 'level': level, 'message': message});
    return true;
  }

  /// A step.
  static void step(String message) {
    if (_event('step', message)) return;
    stdout.writeln('\x1B[1;36m▸ $message\x1B[0m');
  }

  /// A detail of a step.
  static void info(String message) {
    if (_event('info', message)) return;
    stdout.writeln('  $message');
  }

  /// Something that went right.
  static void ok(String message) {
    if (_event('ok', message)) return;
    stdout.writeln('\x1B[32m✓\x1B[0m $message');
  }

  /// Something to look at, not fatal.
  static void warn(String message) {
    if (_event('warn', message)) return;
    stdout.writeln('\x1B[33m!\x1B[0m $message');
  }

  /// A failure.
  static void error(String message) {
    if (_event('error', message)) return;
    stderr.writeln('\x1B[1;31m✗ $message\x1B[0m');
  }
}

/// A command that failed: its message is the whole report.
class ThorException implements Exception {
  /// A failure with [message] (and the process [exitCode]).
  ThorException(this.message, {this.exitCode = 1});

  /// What went wrong and what to do.
  final String message;

  /// The exit code of the command.
  final int exitCode;

  @override
  String toString() => message;
}

/// The port in the `--port` option ([raw]): a number from 0 to 65535, or a
/// [ThorException] that says what was given and what is expected (instead of
/// a bare `FormatException`).
int parsePort(String raw) {
  final port = int.tryParse(raw.trim());
  if (port == null || port < 0 || port > 65535) {
    throw ThorException(
      '--port takes a number from 0 to 65535, not "$raw" '
      '(for example `--port 4400`).',
      exitCode: 64,
    );
  }
  return port;
}

/// Runs [executable] in [dir], its output shown as it comes (or kept, with
/// [quiet], and shown only on failure). Throws on a non-zero exit.
Future<String> exec(
  String executable,
  List<String> args, {
  required String dir,
  bool quiet = false,
  Map<String, String>? environment,
}) async {
  final process = await Process.start(
    executable,
    args,
    workingDirectory: dir,
    environment: environment,
    mode: quiet ? ProcessStartMode.normal : ProcessStartMode.inheritStdio,
  );
  if (!quiet) {
    final code = await process.exitCode;
    if (code != 0) {
      throw ThorException('$executable ${args.join(' ')} failed ($code)');
    }
    return '';
  }
  final out = StringBuffer();
  final done = [
    process.stdout.transform(utf8.decoder).forEach(out.write),
    process.stderr.transform(utf8.decoder).forEach(out.write),
  ];
  final code = await process.exitCode;
  await Future.wait(done);
  if (code != 0) {
    throw ThorException(
      '$executable ${args.join(' ')} failed ($code)\n$out',
      exitCode: code,
    );
  }
  return out.toString();
}

/// Failures of `build_runner` that are its own cache, not the app's code
/// (a generated file whose source was deleted, a changed builder).
final _staleCache = RegExp(
  'InvalidOutputException|Failed to create merged asset graph|'
  'Invalidating asset graph|could not be deserialized|'
  'Unable to read asset graph',
);

/// All the code thor generates for the app in [dir]: `build_runner` (the
/// app's messages, generated parts such as json_serializable's) and then
/// `.dart_tool/thor/` ([writeEntries]).
///
/// What the generation finds ([diagnostics]: a closure as a button's
/// callback the browser can't run…) is a bug when it is an error: with
/// [strict] (`thor build`) it fails the generation, otherwise it is listed
/// as a warning (unless [warn] is false: `thor dev` shows it on the page).
/// A warning-level diagnostic never fails a build.
///
/// [steps] runs thor_builder's steps (`thor dev` passes its warm worker).
Future<void> generate(
  String dir, {
  bool strict = false,
  bool warn = true,
  BuilderSteps steps = BuilderSteps.dartRun,
}) async {
  if (needsBuildRunner(dir)) await buildRunner(dir);
  await writeEntries(dir, steps: steps);
  var found = diagnostics(dir);
  if (found.isEmpty) return;
  if (strict) {
    final stale = staleDiagnostics(dir);
    if (stale.isNotEmpty) {
      Say.warn(
        'Ignoring ${stale.length} finding(s) of diagnostics.txt about code '
        'that changed since (run the tool again):\n${stale.join('\n')}',
      );
      found = [
        for (final line in found)
          if (!stale.contains(line)) line,
      ];
    }
  }
  final errors = diagnosticErrors(found);
  if (strict && errors.isNotEmpty) {
    throw ThorException(
      "Code the browser can't run (the editor flags it too):\n"
      '${misuseReport(dir, errors)}',
    );
  }
  if (warn) found.forEach(Say.warn);
}

/// Whether the [diagnostics] line [misuse] is a warning
/// (`file:line:column: Warning: …`), not an error.
bool isMisuseWarning(String misuse) =>
    // The first `file:line:column: <kind>:` decides: an error may quote
    // another location in its message.
    RegExp(r'^.+?:\d+:\d+: (Warning|Error): ').firstMatch(misuse)?[1] ==
    'Warning';

/// [misuses] (see [diagnostics]) for a terminal: each line followed by the
/// source line it points at and a caret under the column, so the error
/// stands out without opening the file.
String misuseReport(String dir, List<String> misuses) {
  final out = StringBuffer();
  for (final misuse in misuses) {
    if (out.isNotEmpty) out.writeln();
    out.write(misuse);
    final frame = _codeFrame(dir, misuse);
    if (frame != null) out.write('\n$frame');
  }
  return '$out';
}

/// The files of `.dart_tool/thor/` that hold diagnostics, one per line as a
/// compiler writes it: `file:line:column: Error|Warning: message (THOR-S011
/// · url) fix`. `state_misuses.txt` is what `thor_builder:entries` finds
/// around the states; `diagnostics.txt` is for any other tool that wants
/// its findings on the page of `thor dev` (a lint, a build check): write
/// lines there and they show. `thor build` ignores (and says so) a finding
/// of `diagnostics.txt` whose file changed after the tool wrote it or is
/// gone: the code it was about is not the code that is being built.
const diagnosticFiles = ['state_misuses.txt', 'diagnostics.txt'];

/// What the last code generation of the app in [dir] found (see
/// [diagnosticFiles]): around its states, what the browser can't run
/// (THOR-S001/S011/S012/S014/S016: a closure where a state's member goes, a state
/// that is not top-level), and whatever else tools left. The state
/// detection is thor_lints', run by `thor_builder:entries`.
List<String> diagnostics(String dir) => [
  for (final name in diagnosticFiles)
    if (File(p.join(dir, '.dart_tool', 'thor', name)) case final file
        when file.existsSync())
      for (final line in file.readAsLinesSync())
        if (line.trim().isNotEmpty) line,
];

/// The lines of `diagnostics.txt` in [dir] about a file that is gone or
/// changed after the file was written: the tool ran on other code. Lines
/// that don't name a file are never stale (a build fails on them).
List<String> staleDiagnostics(String dir) {
  final file = File(p.join(dir, '.dart_tool', 'thor', 'diagnostics.txt'));
  if (!file.existsSync()) return const [];
  final written = file.lastModifiedSync();
  final out = <String>[];
  for (final line in file.readAsLinesSync()) {
    final m = RegExp(diagnosticLinePattern).firstMatch(line.trim());
    if (m == null) continue;
    final source = File(p.join(dir, m[1]!));
    if (!source.existsSync() || source.lastModifiedSync().isAfter(written)) {
      out.add(line);
    }
  }
  return out;
}

/// The [lines] of [diagnostics] that are errors (not `Warning:`): the ones
/// that fail `thor build`.
List<String> diagnosticErrors(List<String> lines) => [
  for (final line in lines)
    if (!isMisuseWarning(line)) line,
];

/// The frame of `file:line:column: …` under [dir], or null when the file or
/// the line is not there.
String? _codeFrame(String dir, String misuse) {
  final at = RegExp(r'^(.+?):(\d+):(\d+): ').firstMatch(misuse);
  if (at == null) return null;
  final file = File(p.join(dir, at[1]!));
  if (!file.existsSync()) return null;
  final lines = file.readAsLinesSync();
  final line = int.parse(at[2]!);
  final column = int.parse(at[3]!);
  if (line < 1 || line > lines.length) return null;
  var text = lines[line - 1];
  final gutter = '$line'.length;
  // A long line is cut after the column: the caret still points at it.
  if (text.length > column + 80) text = '${text.substring(0, column + 80)}…';
  // A tab stays a tab, so the caret lines up in any tab width.
  final pad = [
    for (var i = 0; i < column - 1 && i < text.length; i++)
      text[i] == '\t' ? '\t' : ' ',
  ].join();
  return '  $line | $text\n  ${' ' * gutter} | $pad^';
}

/// Whether the app in [dir] needs `build_runner`: messages to generate
/// (`lib/**/*.arb`) or a generated part (`part 'x.<builder>.dart'`:
/// json_serializable's `.g.dart`, freezed's `.freezed.dart`). A new app
/// has neither, and skips the slowest step of code generation.
bool needsBuildRunner(String dir) {
  final lib = Directory(p.join(dir, 'lib'));
  if (!lib.existsSync()) return false;
  for (final f in lib.listSync(recursive: true)) {
    if (f is! File) continue;
    if (f.path.endsWith('.arb')) return true;
    if (f.path.endsWith('.dart') &&
        !f.path.endsWith('.thor.dart') &&
        _generatedPart.hasMatch(f.readAsStringSync())) {
      return true;
    }
  }
  return false;
}

/// `part 'x.g.dart';`: a file name with a builder's extension before
/// `.dart` (a hand-written `part 'x_helpers.dart'` has none).
final _generatedPart = RegExp(
  r'''^part\s+['"](?:[^'"]*/)?[^'"/.]+\.\w+\.dart['"]''',
  multiLine: true,
);

/// A fingerprint of what the app's generated code is made of: the Dart
/// files and messages under `lib/`, the resolved dependencies
/// (`pubspec.lock`) and the sources of thor's packages when they come
/// from a checkout (`path:`, the monorepo). The same fingerprint gives the
/// same output, so `thor dev` reuses it instead of building it again.
String inputsFingerprint(String dir, {String extra = ''}) {
  var hash = 0xcbf29ce484222325;
  void add(String text) {
    for (final unit in utf8.encode(text)) {
      hash ^= unit;
      // 64-bit integers wrap on overflow, as FNV-1a wants.
      hash *= 0x100000001b3;
    }
  }

  add(extra);
  // The entries exist only when these do (`bin/server.dart`,
  // `bin/export.dart`): adding one to an app already generated must not
  // leave the old registry in place.
  for (final entry in const ['bin/server.dart', 'bin/export.dart']) {
    add('$entry:${File(p.join(dir, entry)).existsSync()}');
  }
  final lib = Directory(p.join(dir, 'lib'));
  if (lib.existsSync()) {
    final files = [
      for (final f in lib.listSync(recursive: true))
        if (f is File && (f.path.endsWith('.dart') || f.path.endsWith('.arb')))
          f,
    ]..sort((a, b) => a.path.compareTo(b.path));
    for (final f in files) {
      final String source;
      try {
        source = f.readAsStringSync();
      } on FileSystemException {
        // Gone since the listing (an editor's or `sed -i`'s temp file).
        continue;
      }
      add(f.path);
      add(source);
    }
  }
  // The lock of the app, or of the workspace it belongs to.
  for (var d = Directory(dir); ; d = d.parent) {
    final lock = File(p.join(d.path, 'pubspec.lock'));
    if (lock.existsSync()) {
      add(lock.readAsStringSync());
      break;
    }
    if (d.parent.path == d.path) break;
  }
  // thor's packages from a checkout change without a new lock: their
  // sources' sizes and times stand for them.
  for (final package in _thorPackageDirs(dir)) {
    final src = Directory(p.join(package, 'lib'));
    if (!src.existsSync()) continue;
    for (final f in src.listSync(recursive: true)) {
      if (f is! File) continue;
      final stat = f.statSync();
      add('${f.path}:${stat.size}:${stat.modified.microsecondsSinceEpoch}');
    }
  }
  return hash.toRadixString(16);
}

/// The folders of the `thor_*` packages the app in [dir] resolves to
/// local paths (a checkout), from its package config.
List<String> _thorPackageDirs(String dir) {
  for (var d = Directory(dir); ; d = d.parent) {
    final config = File(p.join(d.path, '.dart_tool', 'package_config.json'));
    if (config.existsSync()) {
      final json =
          jsonDecode(config.readAsStringSync()) as Map<String, Object?>;
      final base = Uri.directory(p.join(d.path, '.dart_tool'));
      return [
        for (final package
            in (json['packages'] as List).cast<Map<String, Object?>>())
          if ((package['name'] as String).startsWith('thor_'))
            if (base.resolve(package['rootUri'] as String) case final uri
                when uri.scheme == 'file' && !uri.path.contains('/.pub-cache/'))
              uri.toFilePath(),
      ];
    }
    if (d.parent.path == d.path) return const [];
  }
}

/// Whether [output] was made from inputs with [fingerprint] (its
/// `<output>.inputs` file says so): then it needn't be made again.
bool upToDate(File output, String fingerprint) {
  final record = File('${output.path}.inputs');
  return output.existsSync() &&
      record.existsSync() &&
      record.readAsStringSync() == fingerprint;
}

/// Records that [output] was made from inputs with [fingerprint].
void recordInputs(File output, String fingerprint) =>
    File('${output.path}.inputs').writeAsStringSync(fingerprint);

/// `.dart_tool/thor/` of the app in [dir] (`thor_builder:entries`): the
/// states' registry and the server and engine entries that install it.
/// Returns the files it rewrote (their content changed).
///
/// With `thor: all_features: true` in the app's pubspec, the engine keeps
/// every feature (the app's interactive widgets live in another package,
/// where the scan of its sources can't see them).
///
/// [steps] runs `thor_builder:entries` (`thor dev`: its warm worker).
Future<Set<String>> writeEntries(
  String dir, {
  BuilderSteps steps = BuilderSteps.dartRun,
}) async {
  final pubspec = File(p.join(dir, 'pubspec.yaml'));
  final yaml = pubspec.existsSync()
      ? loadYaml(pubspec.readAsStringSync())
      : null;
  final thor = yaml is Map ? yaml['thor'] : null;
  final allFeatures = thor is Map && thor['all_features'] == true;
  // Nothing they're made of changed: the entries stay as they are.
  final states = File(p.join(dir, '.dart_tool', 'thor', 'states.dart'));
  final fingerprint = inputsFingerprint(dir, extra: 'entries:$allFeatures');
  if (upToDate(states, fingerprint)) {
    _sayQueryEndpoints(states);
    return const {};
  }
  final String out;
  try {
    out = await steps.entries(dir, allFeatures: allFeatures);
  } on ThorException catch (e) {
    throw ThorException('Code generation failed:\n${_tail(e.message)}');
  }
  if (states.existsSync()) recordInputs(states, fingerprint);
  _sayQueryEndpoints(states);
  final wrote = RegExp(r'wrote (.+)$', multiLine: true).firstMatch(out);
  return {...?wrote?.group(1)?.split(', ').map((f) => f.trim())};
}

/// Lists the endpoints the app's `query(...)` and `command(...)` fields
/// became (from the registry in [states]): a function never answers the
/// browser silently.
void _sayQueryEndpoints(File states) {
  if (!states.existsSync()) return;
  final source = states.readAsStringSync();
  for (final (kind, ids) in [
    ('query', queryEndpointsIn(source)),
    ('command', commandEndpointsIn(source)),
  ]) {
    if (ids.isEmpty) continue;
    Say.info(
      '$kind endpoints (POST to the page that uses the state, through its '
      'middleware): ${ids.join(', ')}',
    );
  }
}

/// Stops a dart2js (oracle) build of an app whose states use `query`,
/// `queryWith`, `command` or `commandWith`: the dart2js engine can't call
/// the server, and compiling the states would put each server function (and
/// every package it uses) in the browser's bundle. The lite engine leaves
/// the function out. Reads the
/// registry that code generation wrote in [dir].
void rejectQueriesOnDartEngine(String dir) {
  final states = File(p.join(dir, '.dart_tool', 'thor', 'states.dart'));
  if (!states.existsSync()) return;
  final source = states.readAsStringSync();
  final ids = [...queryEndpointsIn(source), ...commandEndpointsIn(source)];
  if (ids.isEmpty) return;
  throw ThorException(
    'the dart2js oracle engine (THOR_INTERNAL_ENGINE=dart) does not support '
    'query() or command(), and it would ship the server function to the '
    'browser: ${ids.join(', ')}. Build with the lite engine (unset '
    'THOR_INTERNAL_ENGINE)',
  );
}

/// What the dart2js engine can't do that the lite one can:
/// [rejectQueriesOnDartEngine]. (`row.text((o) => o.property)` was one until
/// the engine entry got `RowReaders`.) What it does differently is said
/// ([sayDartEngineDifferences]).
void rejectDartEngineLimits(String dir) {
  rejectQueriesOnDartEngine(dir);
  sayDartEngineDifferences(dir);
}

final _said = <String>{};

/// With the dart2js (oracle) engine a state that overrides `dispose()` is
/// the same object when the page names it again (the lite engine makes a
/// new one). Said once per app and process, from the generated engine entry
/// (it lists `LifecycleFeature` for such a state). Returns whether it said
/// it.
bool sayDartEngineDifferences(String dir) {
  final entry = File(p.join(dir, '.dart_tool', 'thor', 'engine.dart'));
  if (!entry.existsSync()) return false;
  if (!entry.readAsStringSync().contains('LifecycleFeature()')) return false;
  if (!_said.add(p.normalize(p.absolute(dir)))) return false;
  Say.warn(
    'a state of this app overrides dispose(): with the dart2js oracle engine '
    'its object stays when the page stops naming it and comes back, so its '
    'plain fields (not state(...)) keep their values where the lite engine '
    'starts a new object',
  );
  return true;
}

/// The query ids (`ProfileState.info`) in a generated `states.dart`.
List<String> queryEndpointsIn(String states) =>
    _endpointsIn(states, command: false);

/// The command ids (`CartState.add`) in a generated `states.dart`.
List<String> commandEndpointsIn(String states) =>
    _endpointsIn(states, command: true);

List<String> _endpointsIn(String states, {required bool command}) {
  final ids = <String>[];
  String? current;
  for (final line in states.split('\n')) {
    final type = RegExp(r"ThorStateType\('(\w+)'").firstMatch(line);
    if (type != null) current = type.group(1);
    // A record or class argument adds codecs after the id
    // (`members('near', argToJson: …)`).
    final found = RegExp(r"\.members\('(\w+)'[,)]").firstMatch(line);
    if (found == null || current == null) continue;
    // An events field is no endpoint (the browser's `EventSource` is).
    if (line.contains('/* events */')) continue;
    if (line.contains('/* command */') == command) {
      ids.add('$current.${found[1]}');
    }
  }
  return ids;
}

/// How thor runs thor_builder's analyzer steps on an app: a `dart run`
/// each ([dartRun], `thor build`), or `thor dev`'s long-lived worker that
/// keeps the analysis warm (`WorkerSteps`). Either returns what the step
/// printed, or throws a [ThorException] with it when the step fails.
abstract class BuilderSteps {
  /// Const for subclasses.
  const BuilderSteps();

  /// A `dart run thor_builder:<step>` per step.
  static const BuilderSteps dartRun = _DartRunSteps();

  /// `thor_builder:entries` on the app in [dir].
  Future<String> entries(String dir, {required bool allFeatures});

  /// `thor_builder:lite_state` on the app in [dir], into [out] (relative
  /// to [dir]).
  Future<String> liteState(String dir, String out, {required bool readable});

  /// `thor_engine:lite_bundle` on the app in [dir]: the engine from the
  /// states in [state] into [out] (both relative to [dir]).
  Future<String> liteBundle(
    String dir,
    String state,
    String out, {
    required bool minify,
    required bool dev,
  });

  /// The arguments of `dart` that run the lite bundle.
  static List<String> liteBundleArgs(
    String state,
    String out, {
    required bool minify,
    required bool dev,
  }) => [
    'run',
    'thor_engine:lite_bundle',
    if (!minify) '--no-minify',
    if (dev) '--dev',
    state,
    '.',
    out,
  ];

  /// The arguments of `dart` that run the entries step.
  static List<String> entriesArgs({required bool allFeatures}) => [
    'run',
    'thor_builder:entries',
    '.',
    if (allFeatures) '--all-features',
  ];

  /// The arguments of `dart` that run the lite-state step.
  static List<String> liteStateArgs(String out, {required bool readable}) => [
    'run',
    'thor_builder:lite_state',
    '.',
    out,
    if (readable) '--readable',
  ];
}

class _DartRunSteps extends BuilderSteps {
  const _DartRunSteps();

  @override
  Future<String> entries(String dir, {required bool allFeatures}) => exec(
    'dart',
    BuilderSteps.entriesArgs(allFeatures: allFeatures),
    dir: dir,
    quiet: true,
  );

  @override
  Future<String> liteState(String dir, String out, {required bool readable}) =>
      exec(
        'dart',
        BuilderSteps.liteStateArgs(out, readable: readable),
        dir: dir,
        quiet: true,
      );

  @override
  Future<String> liteBundle(
    String dir,
    String state,
    String out, {
    required bool minify,
    required bool dev,
  }) => exec(
    'dart',
    BuilderSteps.liteBundleArgs(state, out, minify: minify, dev: dev),
    dir: dir,
    quiet: true,
  );
}

/// `dart run build_runner build` in [dir]; a stale build cache (the error
/// is its own, not the code's) is cleared and the build retried once.
Future<void> buildRunner(String dir) async {
  const args = ['run', 'build_runner', 'build', '--delete-conflicting-outputs'];
  try {
    await exec('dart', args, dir: dir, quiet: true);
  } on ThorException catch (e) {
    if (!_staleCache.hasMatch(e.message)) {
      throw ThorException('Code generation failed:\n${_tail(e.message)}');
    }
    Say.info('stale build cache: cleared, building again');
    await Directory(p.join(dir, '.dart_tool', 'build')).delete(recursive: true);
    try {
      await exec('dart', args, dir: dir, quiet: true);
    } on ThorException catch (e) {
      throw ThorException('Code generation failed:\n${_tail(e.message)}');
    }
  }
}

String _tail(String output, [int lines = 30]) {
  final all = output.trimRight().split('\n');
  return all.skip(all.length > lines ? all.length - lines : 0).join('\n');
}

/// The highest TCP port.
const maxPort = 65535;

/// Whether nobody listens on [port]: any IPv4 address and the IPv6 loopback
/// (the dev proxy also binds `::1`; a machine without IPv6 doesn't count).
Future<bool> portIsFree(int port) async {
  for (final address in [
    InternetAddress.anyIPv4,
    InternetAddress.loopbackIPv6,
  ]) {
    try {
      final socket = await ServerSocket.bind(address, port);
      await socket.close();
    } on SocketException catch (e) {
      // No IPv6 on this machine: not a busy port.
      if (address.type == InternetAddressType.IPv6 &&
          !(e.osError?.message.toLowerCase().contains('in use') ?? false)) {
        continue;
      }
      return false;
    }
  }
  return true;
}

/// The first port from [preferred] up with nobody listening.
Future<int> freePort(
  int preferred, {
  int tries = 20,
  Future<bool> Function(int port) isFree = portIsFree,
}) async {
  for (
    var port = preferred;
    port < preferred + tries && port <= maxPort;
    port++
  ) {
    if (await isFree(port)) return port;
  }
  throw ThorException(
    'No free port from $preferred to ${preferred + tries - 1}.',
  );
}

/// A port and a second one derived from it ([offset] away: the app behind
/// the dev proxy), both free and both valid. From [preferred] up; the second
/// goes above the first, or below it when that would pass [maxPort].
Future<(int, int)> freePortPair(
  int preferred, {
  int offset = 1000,
  int tries = 20,
  Future<bool> Function(int port) isFree = portIsFree,
}) async {
  for (
    var port = preferred;
    port < preferred + tries && port <= maxPort;
    port++
  ) {
    final other = port + offset <= maxPort ? port + offset : port - offset;
    if (other < 1024 || other == port) continue;
    if (await isFree(port) && await isFree(other)) return (port, other);
  }
  throw ThorException(
    'No free port pair from $preferred to ${preferred + tries - 1}.',
  );
}

/// `dart pub get` at the workspace [root] when an app's resolution is
/// older than its pubspec (a new dependency, a new app).
Future<void> pubGetIfStale(String root, String appDir) async {
  final config = File(p.join(root, '.dart_tool', 'package_config.json'));
  final pubspec = File(p.join(appDir, 'pubspec.yaml'));
  final rootPubspec = File(p.join(root, 'pubspec.yaml'));
  if (config.existsSync() &&
      !config.lastModifiedSync().isBefore(pubspec.lastModifiedSync()) &&
      !config.lastModifiedSync().isBefore(rootPubspec.lastModifiedSync()) &&
      config.readAsStringSync().contains('"${_packageName(pubspec)}"')) {
    return;
  }
  Say.step('Dependencies');
  await exec('dart', ['pub', 'get'], dir: root, quiet: true);
}

String _packageName(File pubspec) => RegExp(
  r'^name:\s*(\S+)',
  multiLine: true,
).firstMatch(pubspec.readAsStringSync())![1]!;
