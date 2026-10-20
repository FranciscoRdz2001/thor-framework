import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import 'package:thor_server/thor_server.dart'
    show DevHosts, ImageManifest, ThorDev;
import 'package:watcher/watcher.dart';

import '../assets.dart';
import '../dev/builder_worker.dart';
import '../dev/change_batch.dart';
import '../dev/declarations.dart';
import '../dev/dev_runs.dart';
import '../dev/engine_failure.dart';
import '../dev/local_packages.dart';
import '../dev/overlay.dart' show SourceMap;
import '../dev/stage_timeouts.dart';
import '../dev/vm_client.dart';
import '../dev_proxy.dart';
import '../dotenv.dart';
import '../images.dart';
import '../run.dart';
import '../stop_signals.dart';
import '../workspace.dart';
import 'base.dart';

/// `thor dev`: everything a change needs, in one command.
///
/// Dependencies, the package fonts, code generation, the engine and the
/// server. On a save the server **hot reloads**: the VM loads the new code
/// into the running process (`ext.thor.reassemble`, see `ThorDev` in
/// thor_server) and open pages reload. It restarts instead when a reload
/// can't apply the change: the entry (`bin/`), a variable's initializer (a
/// value that already exists keeps it), the VM refusing it. It watches the
/// app and the packages of the workspace the app depends on. The browser
/// talks to a proxy on a free port that stays up across restarts
/// ([DevProxy]). Ctrl-C, `kill` or an error stops every process it started;
/// the server also exits on its own if `thor dev` dies.
class DevCommand extends Command<int> with ProjectCommand {
  /// The command.
  DevCommand({DevTimeouts timeouts = DevTimeouts.defaults})
    : _timeouts = timeouts {
    argParser
      ..addOption(
        'port',
        abbr: 'p',
        help:
            'Preferred port; the next free one if busy. Default: '
            'THOR_DEV_PORT in the app\'s .env (or the environment), else 4300.',
      )
      ..addMultiOption(
        'watch',
        abbr: 'w',
        help:
            'Also restart when files change in this folder (content the '
            'server reads at startup, like markdown).',
        valueHelp: 'folder',
      )
      ..addOption(
        'host',
        help:
            'Listen on this address instead of only this machine: a bare '
            '--host (or --host=0.0.0.0) opens it to your network (a phone).',
        valueHelp: 'address',
      )
      ..addMultiOption(
        'allowed-host',
        help:
            'Also answer requests for this Host name (a tunnel, a dev '
            'domain); .name allows its subdomains, * any host.',
        valueHelp: 'name',
      )
      ..addMultiOption(
        'inject',
        help:
            'Put this JavaScript file in every page the app serves (read on '
            'each request): a bridge into the page for an editor.',
        valueHelp: 'file.js',
      )
      ..addFlag(
        'json',
        negatable: false,
        help:
            'Machine output: one JSON object per line on stdout (events '
            '"log", "server", "ready" with the url, port and pid, and '
            '"result", the same JSON as GET /__thor/status after each '
            'reload).',
      )
      ..addFlag(
        'reload',
        help:
            'Hot reload the server on a change (--no-reload: restart it '
            'every time, like before).',
        defaultsTo: true,
      );
  }

  @override
  String get name => 'dev';

  @override
  String get description =>
      'Run the app: codegen, engine and server, hot reloaded on every change.';

  @override
  String get invocation => 'thor dev [project]';

  final _children = <Process>[];

  /// How long each stage may take before it counts as hung.
  final DevTimeouts _timeouts;

  /// A builder worker request got no answer (the worker was killed and the
  /// request ran with `dart run`): a new worker starts after the update.
  StageTimeout? _workerStuck;

  /// thor_builder's steps: the worker, or `dart run` if it can't start.
  BuilderSteps _steps = BuilderSteps.dartRun;

  Future<void> _startBuilder() async {
    try {
      final worker = await WorkerSteps.start(
        _app.dir,
        notice: Say.warn,
        requestTimeout: _timeouts.workerRequest,
        onStuck: _onWorkerStuck,
      );
      _steps = worker;
      _children.add(worker.process);
      _recordPids();
    } on ProcessException catch (e) {
      Say.warn(
        'no builder worker (${e.message}): running thor_builder with dart run',
      );
    }
  }

  void _onWorkerStuck(StageTimeout e) {
    _workerStuck = e;
    Say.warn('${e.message}: restarting the builder worker');
    _proxy?.problem(
      'worker',
      'The code generator hung',
      '${e.message}.\nIt restarts; save again if the page is out of date.',
    );
  }

  /// A hung worker was killed: a new one takes over (the update that found
  /// it ran with `dart run`).
  Future<void> _restartWorker() async {
    if (_workerStuck == null) return;
    _workerStuck = null;
    final old = _steps;
    if (old is WorkerSteps) {
      old.stop();
      _children.remove(old.process);
    }
    _steps = BuilderSteps.dartRun;
    await _startBuilder();
    if (_steps is WorkerSteps) {
      Say.ok('builder worker restarted');
      _proxy?.clearProblem('worker', reload: true);
    }
  }

  Process? _server;
  VmClient? _vm;
  DevProxy? _proxy;

  /// Applies a single saved file at once, a burst once it settles.
  late final _batch = ChangeBatch(() => unawaited(_update()));
  var _stopping = false;
  late Project _app;
  late bool _hotReload;
  late EngineKind _engine;

  /// Changed files not applied yet.
  final _pending = <String>{};

  /// Why the server restarts on the next update, whatever changed (a
  /// `--watch` folder, new dependencies); null: only if the code needs it.
  String? _restartBecause;

  /// The `lib/` folders of local packages being watched.
  final _watchedPackages = <String>{};

  /// Serializes updates: one at a time (two restarts at once left a
  /// server behind).
  Future<void>? _updating;

  /// The initializers of every watched Dart file, as of the last update.
  final _initializers = <String, Map<String, String>>{};

  /// Files the compiled engine is made of (dart2js' `.deps`); empty when
  /// unknown.
  var _engineFiles = <String>{};

  /// Completes when code generation is idle after a change.
  Completer<void>? _codegen;

  /// Whether `build_runner watch` runs ([_watchCodegen]): only then does
  /// a change wait for [_codegen], which only its output completes.
  var _codegenWatching = false;

  @override
  Future<int> run() async {
    // A bad --port fails before anything else.
    final flag = argResults!.wasParsed('port')
        ? argResults!['port'] as String
        : null;
    if (flag != null) parsePort(flag);
    final app = _app = resolveProject();
    final wanted = devPort(flag, dotEnv(app.dir));
    _hotReload = argResults!['reload'] as bool;
    _engine = app.engine;
    final inject = [
      for (final path in argResults!['inject'] as List<String>)
        File(path).absolute,
    ];
    for (final file in inject) {
      if (!file.existsSync()) throw ThorException('--inject: no $file');
    }
    if (argResults!['json'] as bool) {
      Say.json = (event) => stdout.writeln(jsonEncode(event));
    }

    // Bad options fail now, not after the code generation.
    final host = await _bindHost();
    for (final name in argResults!['allowed-host'] as List<String>) {
      final problem = DevHosts.problem(name);
      if (problem != null) throw ThorException('--allowed-host $problem');
    }
    _allowedHosts = [
      ...argResults!['allowed-host'] as List<String>,
      // A name given to --host is the one you mean to use.
      if (host != null &&
          InternetAddress.tryParse(argResults!['host'] as String) == null)
        argResults!['host'] as String,
    ];

    // The ports and the address are checked now too: a `--host` this machine
    // doesn't have fails in a moment, not after the code generation.
    final (port, upstream) = await freePortPair(wanted);
    await _probeBind(host, port);

    // Only the leftovers of runs that are gone; a live `thor dev` of this app
    // (another port) is told about and left alone.
    final runsDir = Directory(app.path('.dart_tool/thor'));
    reapStaleRuns(runsDir, say: Say.info);
    _runPort = port;
    _pids = DevRun.fileFor(runsDir.path, port);
    // From now on a second `thor dev` of this app sees this one alive.
    _recordPids();
    await pubGetIfStale(app.pubRoot, app.dir);
    final synced = PublicAssets(app).sync();
    if (synced.isNotEmpty) {
      Say.info('package files: ${synced.length} copied to web/');
    }

    // thor_builder's steps on an analysis that stays warm (a state edit
    // took ~5 s with a cold `dart run` per step).
    await _startBuilder();
    Say.step('Code generation');
    await generate(app.dir, warn: false, steps: _steps);
    _entry = app.entry;
    if (app.hasEngine) await _compileEngine();

    final proxy = _proxy = DevProxy(
      upstream: upstream,
      sources: SourceMap.of(app),
      hosts: DevHosts(_allowedHosts),
      injectScripts: inject,
    );
    final json = Say.json;
    if (json != null) {
      proxy.results.listen((status) => json({'event': 'result', ...status}));
    }
    try {
      await proxy.start(port, host: host);
    } on SocketException catch (e) {
      // The port was taken since the check: say so, no trace.
      await _stop(exitProcess: false);
      Say.error(_cannotListen(host, port, e));
      await Future.wait([stdout.flush(), stderr.flush()]);
      // Nothing left may keep the process alive (a watcher, a pipe).
      exit(1);
    }
    // The first build of the engine ran before the proxy existed.
    if (_engineFailure case final failure?) {
      proxy.problem('engine', failure.title, failure.detail);
    }
    _showDiagnostics();
    _listenForExit();
    try {
      await _startWatchers();
      await _startServer();
    } on Object {
      await _stop(exitProcess: false);
      rethrow;
    }
    // Up only once the app listens: a first build that fails leaves the
    // proxy serving the failure page, and saying so (not "ready") lets a
    // tool that waits for the line tell the two apart.
    final broken = devNotRunning(proxy.failure, error: proxy.firstError);
    json?.call({
      'event': 'ready',
      'url': 'http://localhost:$port',
      'port': port,
      'pid': pid,
      'ok': broken == null,
      'failure': broken,
    });
    if (broken == null) {
      Say.ok('http://localhost:$port  (Ctrl-C to stop)');
    } else {
      Say.error(
        'http://localhost:$port  is up but the app is not running: $broken '
        '(the page shows it; fix and save. Ctrl-C to stop)',
      );
    }
    if (host != null && !host.isLoopback) {
      Say.warn(
        'listening on ${host.address}: anyone who reaches this machine can '
        'read the app and its error overlay',
      );
    }
    _started = true;
    // Runs until Ctrl-C.
    await Completer<void>().future;
    return 0;
  }

  static String _cannotListen(
    InternetAddress? host,
    int port,
    SocketException e,
  ) =>
      'Cannot listen on ${host?.address ?? 'the loopback'}:$port '
      '(${e.osError?.message ?? e.message}).';

  /// Fails with a message when [host] can't be listened on at [port].
  Future<void> _probeBind(InternetAddress? host, int port) async {
    try {
      final probe = await ServerSocket.bind(
        host ?? InternetAddress.loopbackIPv4,
        port,
      );
      await probe.close();
    } on SocketException catch (e) {
      throw ThorException(_cannotListen(host, port, e));
    }
  }

  /// `--host`'s address; null (the default): the loopback only.
  Future<InternetAddress?> _bindHost() async {
    final value = argResults!['host'] as String?;
    if (value == null) return null;
    final address = InternetAddress.tryParse(value);
    if (address != null) return address;
    try {
      return (await InternetAddress.lookup(value)).first;
    } on SocketException {
      throw ThorException('--host $value: not an address or a known name.');
    }
  }

  /// The `--allowed-host` names (and a `--host` name), for the app.
  var _allowedHosts = const <String>[];

  /// `build_runner watch` for generated code, and watchers of the app's
  /// sources and of the workspace packages it depends on.
  Future<void> _startWatchers() async {
    final dir = _app.dir;
    // Only an app with messages or generated parts needs it.
    if (needsBuildRunner(dir)) await _watchCodegen(dir);
    await _watchSources(dir);
  }

  /// `build_runner watch`: the app's messages and generated parts.
  Future<void> _watchCodegen(String dir) async {
    final codegen = await startTied('dart', [
      'run',
      'build_runner',
      'watch',
    ], dir: dir);
    _codegenWatching = true;
    _children.add(codegen);
    _recordPids();
    // The errors of the build in progress, for the overlay.
    final errors = <String>[];
    codegen.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
          final text = line.trim();
          // Its log names files (`error.dart`): only its own failures
          // (`E …` since build_runner 2.15, `[SEVERE]` before).
          if (line.startsWith('E ') ||
              line.contains('[SEVERE]') ||
              line.contains('[ERROR]')) {
            Say.error(text);
            errors.add(text.replaceFirst(RegExp(r'^E\s+'), ''));
          }
          final ok = _codegenSucceeded.hasMatch(line);
          final failed = _codegenFailed.hasMatch(line);
          if (!ok && !failed) return;
          if (ok) {
            _proxy?.clearProblem('codegen');
          } else {
            _proxy?.problem(
              'codegen',
              'Code generation failed',
              errors.isEmpty ? text : errors.join('\n'),
            );
          }
          errors.clear();
          final done = _codegen;
          if (done != null && !done.isCompleted) done.complete();
        });
    codegen.stderr.transform(utf8.decoder).listen(stderr.write);
  }

  /// Watchers of the app's sources and of the workspace packages it
  /// depends on.
  Future<void> _watchSources(String dir) async {
    for (final folder in ['lib', 'bin', 'web']) {
      await _watchFolder(p.join(dir, folder));
    }
    final packages = await _watchNewPackages();
    if (packages > 0) Say.info('watching $packages workspace package(s)');
    // `pub get` rewrites the resolution: a package added while this runs
    // (a design system) is watched from then on, and the server restarts
    // to compile it from scratch; the running one only knows the files it
    // was told changed, and would keep the package as it first saw it.
    final resolution = File(
      p.join(_app.pubRoot, '.dart_tool', 'package_config.json'),
    );
    if (resolution.existsSync()) {
      var resolved = resolution.readAsStringSync();
      final watcher = FileWatcher(resolution.path);
      watcher.events.listen((_) async {
        // The same resolution written again (a `pub get` with nothing
        // new): no restart.
        final now = _readOrEmpty(resolution);
        if (now.isEmpty || now == resolved) return;
        resolved = now;
        final added = await _watchNewPackages();
        if (added > 0) Say.info('watching $added new package(s)');
        _restartBecause = 'the dependencies changed';
        _batch.add(resolution.path);
      });
      await watcher.ready;
    }
    for (final folder in argResults!['watch'] as List<String>) {
      final path = p.normalize(p.absolute(folder));
      if (!Directory(path).existsSync()) {
        Say.warn('--watch $folder: no such folder');
        continue;
      }
      final watcher = DirectoryWatcher(path);
      watcher.events.listen((event) {
        _restartBecause = 'a watched folder changed';
        _batch.add(event.path);
      });
      await watcher.ready;
      Say.info('watching ${p.relative(path)}');
    }
  }

  /// Watches [folder]'s Dart files and `web/` changes (if it exists).
  Future<void> _watchFolder(String folder) async {
    if (!Directory(folder).existsSync()) return;
    _snapshot(folder);
    final watcher = DirectoryWatcher(folder);
    watcher.events.listen((event) => _changed(event.path));
    await watcher.ready;
  }

  /// Watches the local packages the app depends on that aren't watched
  /// yet; returns how many.
  Future<int> _watchNewPackages() async {
    var added = 0;
    for (final package in localDependencies(_app.pubRoot, _app.name)) {
      final lib = p.join(package, 'lib');
      if (p.isWithin(_app.dir, lib) || !_watchedPackages.add(lib)) continue;
      if (!Directory(lib).existsSync()) continue;
      await _watchFolder(lib);
      added++;
    }
    return added;
  }

  /// Records the initializers of every Dart file under [folder].
  void _snapshot(String folder) {
    for (final file in Directory(folder).listSync(recursive: true)) {
      if (file is File && file.path.endsWith('.dart')) {
        _initializers[p.normalize(file.path)] = _readInitializers(file.path);
      }
    }
  }

  static Map<String, String> _readInitializers(String path) {
    try {
      return variableInitializers(File(path).readAsStringSync());
    } on FileSystemException {
      return const {};
    }
  }

  void _changed(String path) {
    // The compiled engine is our own output.
    if (p.basename(path).startsWith('engine.dart.js')) return;
    // A hidden file: an editor's or a tool's temp copy (`sed -i` writes
    // `.!123!page.dart`), gone a moment later.
    if (p.basename(path).startsWith('.')) return;
    if (!path.endsWith('.dart') && !p.isWithin(p.join(_app.dir, 'web'), path)) {
      return;
    }
    _pending.add(p.normalize(path));
    if (_steps case final WorkerSteps worker when path.endsWith('.dart')) {
      worker.changed(p.normalize(path));
    }
    // Code that generates code (a page's route, a state's glue): wait for
    // code generation before applying it.
    if (_codegenWatching && _feedsCodegen(path)) {
      final done = _codegen;
      if (done == null || done.isCompleted) _codegen = Completer<void>();
    }
    _batch.add(path);
  }

  /// Whether [path] is an input of the app's code generation: a file with
  /// a `part` (a `ThorState`'s generated glue). Routes are code: a change
  /// to them is an ordinary reload.
  bool _feedsCodegen(String path) {
    if (!path.endsWith('.dart') || path.endsWith('.thor.dart')) return false;
    final lib = p.join(_app.dir, 'lib');
    if (!p.isWithin(lib, path)) return false;
    try {
      return RegExp(
        r'''^part\s+['"]''',
        multiLine: true,
      ).hasMatch(File(path).readAsStringSync());
    } on FileSystemException {
      return true;
    }
  }

  /// Applies what changed, one update at a time; changes that arrive
  /// meanwhile are applied right after.
  Future<void> _update() async {
    if (_updating != null || _stopping) return;
    final done = Completer<void>();
    _updating = done.future;
    try {
      var round = 0;
      while ((_pending.isNotEmpty || _restartBecause != null) && !_stopping) {
        // Changes that came during the last round: the rest of a burst
        // (a checkout) settles before it applies.
        if (round++ > 0) await _batch.quiet();
        final codegen = _codegen;
        if (codegen != null && !codegen.isCompleted) {
          await codegen.future.timeout(
            const Duration(seconds: 5),
            // A wait that never ends costs once, not on every save.
            onTimeout: () {
              if (!codegen.isCompleted) codegen.complete();
            },
          );
          // Its own writes (`*.thor.dart`) arrive as changes too.
          await Future<void>.delayed(const Duration(milliseconds: 150));
        }
        final changes = {..._pending};
        _pending.clear();
        final restart = _restartBecause;
        _restartBecause = null;
        await _apply(changes, restartBecause: restart);
      }
      await _restartWorker();
    } finally {
      _updating = null;
      done.complete();
    }
    // Other tools' findings (`diagnostics.txt`) show with the next save.
    if (!_stopping) _showDiagnostics();
    if (_entriesLater && !_stopping) {
      _entriesLater = false;
      final entries = await _writeEntries();
      if (entries.contains('engine.dart') && _app.hasEngine) {
        await _compileEngine();
        _proxy?.ready();
      }
      if (entries.contains('states.dart') || entries.contains('actions.dart')) {
        await _startServer();
      }
    }
  }

  /// Whether the entries are to be checked once the update is done.
  var _entriesLater = false;

  /// Whether [files] (changed Dart files of `lib/`) may change the states'
  /// or the actions' registry: one declares or creates a state, declares a
  /// page's action method, or a file came or went.
  static bool _touchesStates(List<String> files) {
    for (final f in files) {
      final file = File(f);
      if (!file.existsSync()) return true;
      final source = file.readAsStringSync();
      if (source.contains('ThorState') || source.contains('ActionResult')) {
        return true;
      }
    }
    return false;
  }

  /// What code generation found ([diagnostics]: a closure as a button's
  /// callback does nothing in the browser…): on the page like a compile
  /// error (an error covers it, a warning is a badge) and in the console,
  /// until a save fixes it.
  void _showDiagnostics() {
    final found = diagnostics(_app.dir);
    if (found.isEmpty) {
      _proxy?.clearProblem('diagnostics', reload: true);
      return;
    }
    final errors = diagnosticErrors(found).toSet();
    for (final line in found) {
      errors.contains(line) ? Say.error(line) : Say.warn(line);
    }
    _proxy?.problem(
      'diagnostics',
      'Problem in your code',
      found.join('\n'),
      strict: true,
    );
  }

  /// `.dart_tool/thor/` again ([writeEntries]); the files it rewrote. A
  /// state class it can't list shows on the page.
  Future<Set<String>> _writeEntries() {
    // One run at a time: an older run finishing last would bring back the
    // findings of a source already fixed.
    final run = _entriesRun.then((_) => _writeEntriesNow());
    _entriesRun = run.then((_) {}, onError: (_) {});
    return run;
  }

  /// The last [_writeEntries] run; the next one waits for it.
  Future<void> _entriesRun = Future.value();

  Future<Set<String>> _writeEntriesNow() async {
    try {
      final wrote = await writeEntries(_app.dir, steps: _steps);
      _proxy?.clearProblem('entries');
      _showDiagnostics();
      return wrote;
    } on ThorException catch (e) {
      Say.error(e.message);
      _proxy?.problem('entries', 'Code generation failed', e.message);
      return const {};
    }
  }

  Future<void> _apply(Set<String> changes, {String? restartBecause}) async {
    final clock = Stopwatch()..start();
    final dart = changes.where((f) => f.endsWith('.dart')).toList();
    final lib = p.join(_app.dir, 'lib');
    final inLib = [
      for (final f in dart)
        if (p.isWithin(lib, f)) f,
    ];
    // A state's members (or a new or deleted file) change the generated
    // registry: write it before the server runs the code.
    final entries = _touchesStates(inLib) ? await _writeEntries() : <String>{};
    final hadEngine = _app.hasEngine;
    if (_app.hasEngine &&
        (changes.any(_inEngine) ||
            entries.contains('engine.dart') ||
            entries.contains('states.dart'))) {
      await _compileEngine();
    }
    // The last state went: no engine to fail.
    if (!_app.hasEngine) _engineGone();
    // A state's members (or a page's action methods) changed: the server
    // registers them again after the reload (`ThorServer.setUpIsolates`);
    // an older one restarts. A registry that appears or goes changes the
    // server entry's imports: a restart.
    final states =
        entries.contains('states.dart') || entries.contains('actions.dart');
    final reasons = <String>[
      ?restartBecause,
      if (entries.contains('server.dart')) 'the server entry changed',
      if (hadEngine != _app.hasEngine) 'the page engine appeared or went',
      ..._restartReasons(dart),
    ];
    // Any other change of lib/ may start or stop using an engine feature:
    // the entries are checked after the update, without holding it.
    if (inLib.isNotEmpty && entries.isEmpty && !_touchesStates(inLib)) {
      _entriesLater = true;
    }
    // A new or changed image: its sizes go in the dev manifest, and a hot
    // reload makes the server read it again.
    final images = changes.any(_isImage);
    if (images) _measureImages();
    if (dart.isEmpty && reasons.isEmpty && !images) {
      // Files of web/: served as they are, the pages reload.
      _proxy?.ready();
      if (_started) Say.info('updated in ${clock.elapsedMilliseconds} ms');
      return;
    }
    final vm = _vm;
    if (!_hotReload || vm == null || reasons.isNotEmpty) {
      if (_hotReload && reasons.isNotEmpty) {
        Say.info('restarting: ${reasons.first}');
      }
      await _startServer();
      return;
    }
    final ReloadOutcome outcome;
    try {
      outcome = await guardStage('hot reload', _timeouts.reload, vm.reload());
    } on StageTimeout catch (e) {
      // The VM may be wedged: its client is dropped with the server.
      Say.warn('${e.message}: restarting the server');
      _proxy?.problem(
        'stage',
        'Hot reload hung',
        '${e.message}.\nThe server restarts.',
      );
      await _startServer();
      return;
    }
    switch (outcome) {
      case Reloaded(setUps: false) when states:
        Say.info("restarting: the states' members changed");
        await _startServer();
      case Reloaded():
        _proxy?.ready();
        Say.info('reloaded in ${clock.elapsedMilliseconds} ms');
      case NotReloaded(compileError: true, :final reason):
        // The old code keeps running; the page shows the error until the
        // next save fixes it.
        Say.error(reason);
        _proxy?.failed(reason, title: 'The code does not compile');
      case NotReloaded(:final reason):
        Say.info('restarting: ${reason.split('\n').first}');
        await _startServer();
    }
  }

  /// Why [dart] (changed Dart files) need a restart rather than a reload.
  List<String> _restartReasons(List<String> dart) {
    final reasons = <String>[];
    final bin = p.join(_app.dir, 'bin');
    final entry = p.normalize(_app.path(_app.appEntry));
    final befores = <String, Map<String, String>>{};
    final afters = <String, Map<String, String>>{};
    final reported = <String>{};
    for (final file in dart) {
      final before = _initializers[file];
      befores[file] = before ?? const {};
      final after = File(file).existsSync()
          ? _readInitializers(file)
          : const <String, String>{};
      _initializers[file] = after;
      afters[file] = after;
      final name = p.relative(file, from: _app.dir);
      if (file == entry || p.isWithin(bin, file)) {
        reasons.add('$name is the entry');
        continue;
      }
      if (before == null) continue;
      final changed = changedInitializers(before, after);
      if (changed.isNotEmpty) {
        reasons.add(restartReason(changed.first, name));
      }
      reported.addAll(changed);
    }
    // A typedef or a class header that moved to another file in this save.
    for (final MapEntry(:key, value: file) in changedAcrossFiles(
      befores,
      afters,
    ).entries) {
      if (reported.contains(key)) continue;
      reasons.add(restartReason(key, p.relative(file, from: _app.dir)));
    }
    return reasons;
  }

  /// Whether `file` is one of the app's `web/images/`.
  bool _isImage(String file) =>
      p.isWithin(p.join(_app.dir, 'web', 'images'), file);

  /// The app's files the lite engine is translated from: those that
  /// declare a `ThorState` and, following their imports, the app's files
  /// they use.
  Set<String> _stateSources() {
    final lib = p.normalize(Directory(_app.path('lib')).absolute.path);
    final pending = <String>[
      for (final f in Directory(lib).listSync(recursive: true))
        if (f is File &&
            f.path.endsWith('.dart') &&
            _declaresState.hasMatch(_readOrEmpty(f)))
          p.normalize(f.absolute.path),
    ];
    final found = <String>{};
    while (pending.isNotEmpty) {
      final path = pending.removeLast();
      if (!found.add(path)) continue;
      final String source;
      try {
        source = File(path).readAsStringSync();
      } on FileSystemException {
        continue;
      }
      for (final m in _importOf.allMatches(source)) {
        final uri = m[1]!;
        final own = 'package:${_app.name}/';
        final target = uri.startsWith(own)
            ? p.join(lib, uri.substring(own.length))
            : uri.contains(':')
            ? null
            : p.join(p.dirname(path), uri);
        if (target != null && p.isWithin(lib, p.normalize(target))) {
          pending.add(p.normalize(target));
        }
      }
    }
    return found;
  }

  /// [file]'s source; empty if it went since it was listed.
  static String _readOrEmpty(File file) {
    try {
      return file.readAsStringSync();
    } on FileSystemException {
      return '';
    }
  }

  static final _declaresState = RegExp(r'extends\s+ThorState\b');
  static final _importOf = RegExp(
    r'''^(?:import|export|part)\s+['"]([^'"]+)['"]''',
    multiLine: true,
  );

  /// Whether the engine is compiled from [file].
  bool _inEngine(String file) {
    if (!file.endsWith('.dart')) return false;
    if (p.basename(file) == 'engine.dart') return true;
    if (_engineFiles.isNotEmpty) return _engineFiles.contains(file);
    // Not compiled yet: anything of the app's.
    return p.isWithin(_app.dir, file);
  }

  int? _port;

  var _started = false;

  /// What runs: the app's server, or a static app's page.
  late String _entry;

  /// The processes this run started, for the next run to stop if this
  /// one dies without cleaning up (a `kill -9`, a crash).
  File? _pids;

  /// The port this run listens on (names its record).
  int? _runPort;

  void _recordPids() {
    final file = _pids;
    if (file == null) return;
    DevRun(
      owner: pid,
      port: _runPort,
      pids: [
        for (final p in [?_server, ..._children]) p.pid,
      ],
    ).write(file);
  }

  /// Measures `web/images/` for the server (again when an image changes,
  /// before a hot reload); an image it can't read is a warning, not a
  /// stop.
  String _measureImages() {
    final path = devManifestPath(_app);
    var manifest = ImageManifest.empty;
    try {
      manifest = ImagePipeline(_app, findEncoder: false).measure();
    } on ThorException catch (e) {
      Say.warn(e.message);
    }
    writeImageManifest(manifest, path);
    return path;
  }

  /// Starts the server (stopping the one running) and waits until it
  /// listens, or exits: its error is on the console and on the page, and
  /// the next save tries again.
  Future<void> _startServer({bool retryIfHung = true}) async {
    final dir = _app.dir;
    final port = _port ??= _proxy!.upstream;
    _proxy?.restarting();
    final previousVm = _vm;
    _vm = null;
    await previousVm?.dispose().catchError((Object _) {});
    final previous = _server;
    if (previous != null) {
      _server = null;
      await stopGracefully(previous);
    }
    final clock = Stopwatch()..start();
    final images = _measureImages();
    final info = File(p.join(dir, '.dart_tool', 'thor', 'vm.json'));
    if (info.existsSync()) info.deleteSync();
    info.parent.createSync(recursive: true);
    final server = await Process.start(
      'dart',
      ['run', if (_hotReload) ...vmServiceArgs(info), _entry],
      workingDirectory: dir,
      environment: {
        // The app's `.env` (the real environment wins), then what thor
        // dev decides.
        ...dotEnv(dir),
        'PORT': '$port',
        // The app answers the same Hosts as the proxy (it listens on the
        // loopback only, but a page of another site could reach it there).
        DevHosts.envName: _allowedHosts.join(','),
        // One isolate: its log and its state are the ones you see.
        'ISOLATES': '1',
        // ThorDev (thor_server): hot reload, the error overlay, and exiting
        // when this process goes.
        'THOR_DEV': '1',
        // This process: what outlives a restart of the server (a restart is
        // a SIGTERM, like the exit; `ThorDev.devPid`).
        ThorDev.pidEnvName: '$pid',
        // The images' sizes, no variants: the page keeps its
        // release width/height without encoding on every save.
        'THOR_IMAGES': images,
      },
    );
    _server = server;
    _recordPids();
    final listening = Completer<void>();
    server.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
          if (isVmServiceLine(line)) return;
          // Its own "listening" line (a server app's, or a static page's):
          // `thor dev` says it its way.
          if (line.startsWith('thor: http') ||
              line.startsWith('Serving at http')) {
            if (!listening.isCompleted) listening.complete();
            return;
          }
          if (Say.json case final json?) {
            json({'event': 'server', 'line': line});
          } else {
            stdout.writeln(line);
          }
        });
    // What the page shows if the app doesn't start (the last lines).
    final errors = <String>[];
    server.stderr.transform(utf8.decoder).listen((text) {
      stderr.write(text);
      errors.addAll(const LineSplitter().convert(text));
      if (errors.length > 200) errors.removeRange(0, errors.length - 200);
    });
    var up = false;
    unawaited(
      server.exitCode.then((code) {
        if (!listening.isCompleted) listening.complete();
        // Stopped by us (a restart, Ctrl-C) is not a failure.
        if (!identical(_server, server) || _stopping) return;
        _proxy?.failed(
          [
            if (up)
              'The app stopped (exit code $code).'
            else
              'The app exited with code $code before listening.',
            ...errors,
          ].join('\n'),
        );
      }),
    );
    try {
      await guardStage(
        'the server listening',
        _timeouts.serverListening,
        listening.future,
      );
    } on StageTimeout catch (e) {
      // Not listening and not exited: stuck (a startup that never ends).
      // Dropped without the exit handler reporting it; once more, then the
      // next save tries again.
      if (identical(_server, server)) {
        _server = null;
        server.kill();
        // Gone before the next one binds the port.
        await server.exitCode.timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            server.kill(ProcessSignal.sigkill);
            return -1;
          },
        );
      }
      Say.warn(
        '${e.message}: ${retryIfHung ? 'restarting the server' : 'giving up'}',
      );
      if (retryIfHung) return _startServer(retryIfHung: false);
      _proxy?.failed(
        'The app did not start listening within ${e.limit.inSeconds} s.\n'
                '${errors.join('\n')}'
            .trimRight(),
        title: 'The app hung on start',
      );
      return;
    }
    if (!identical(_server, server)) return;
    // Exited before listening: the exit handler reported it.
    final exited = await server.exitCode
        .then<bool>((_) => true)
        .timeout(Duration.zero, onTimeout: () => false);
    if (exited) return;
    up = true;
    if (_hotReload) {
      try {
        _vm = await VmClient.connect(info);
      } on Object catch (e) {
        Say.warn('no hot reload for this run (restarts instead): $e');
      }
    }
    _proxy?.clearProblem('stage');
    _proxy?.ready();
    if (_started) Say.info('restarted in ${clock.elapsedMilliseconds} ms');
  }

  /// The engine for the browser, fast to compile (`thor build` writes the
  /// optimized one), with the dev-only part that keeps the page's state
  /// across reloads.
  Future<void> _compileEngine() async {
    if (_engine == EngineKind.lite) return _bundleLite();
    final out = _app.path('web/engine.dart.js');
    final fingerprint = inputsFingerprint(_app.dir, extra: 'dart2js-dev');
    if (upToDate(File(out), fingerprint) && File('$out.deps').existsSync()) {
      // Back to the code of the last good build: a failure since is over.
      _engineBuilt();
      _engineFiles = engineSources(File('$out.deps'));
      return;
    }
    Say.info('compiling the engine…');
    try {
      rejectDartEngineLimits(_app.dir);
      await exec(
        'dart',
        [
          'compile',
          'js',
          '-O1',
          // Keeps ThorState values across reloads (dev_state.dart).
          '-Dthor.dev=true',
          Project.engineEntry,
          '-o',
          'web/engine.dart.js',
        ],
        dir: _app.dir,
        quiet: true,
      );
      recordInputs(File(out), fingerprint);
      _engineBuilt();
      _engineFiles = engineSources(File('$out.deps'));
    } on ThorException catch (e) {
      // What it was made of is unknown now: any file of the app retries.
      _engineFiles = {};
      _engineFailed('engine', e.message, File(out).existsSync());
    }
  }

  /// The lite engine, unminified: the app's states translated
  /// from Dart and the runtime with every part its engine features name,
  /// plus `dev_state` (the states' values kept across the live reloads).
  /// It is made of the app's Dart files (the translator reads all of
  /// `lib/`). A construct outside the lite subset shows on the page.
  Future<void> _bundleLite() async {
    // Its own file, not `build/lite/state.js`: a `thor build` running at
    // the same time writes the release one (not readable) there.
    const state = '.dart_tool/thor/lite/state.js';
    final out = _app.path('web/engine.dart.js');
    // What the engine is made of: the states and what they import from
    // the app (their data classes and enums). A change to any other file
    // (a widget, a page) reloads without building the engine; one that
    // starts using another engine feature shows in the entries, checked
    // after the update.
    Set<String> sources() => _stateSources();
    // Nothing it's made of changed since the last one: it stays.
    final fingerprint = inputsFingerprint(_app.dir, extra: 'lite-dev');
    if (upToDate(File(out), fingerprint)) {
      // Back to the code of the last good build: a failure since is over.
      _engineBuilt();
      _engineFiles = sources();
      return;
    }
    Say.info('bundling the lite engine…');
    try {
      Directory(_app.path(p.dirname(state))).createSync(recursive: true);
      await _steps.liteState(_app.dir, state, readable: true);
      await _steps.liteBundle(
        _app.dir,
        state,
        'web/engine.dart.js',
        minify: false,
        dev: true,
      );
      for (final stale in ['$out.deps', '$out.map']) {
        if (File(stale).existsSync()) File(stale).deleteSync();
      }
      recordInputs(File(out), fingerprint);
      _engineBuilt();
      _engineFiles = sources();
    } on ThorException catch (e) {
      // A state that imports a file that is not there yet: creating it
      // must retry the build.
      _engineFiles = sources();
      _engineFailed('lite engine', e.message, File(out).existsSync());
    }
  }

  /// The engine's last build failed: what the page shows (the proxy exists
  /// only after the first build, which is replayed when it starts).
  EngineFailure? _engineFailure;

  /// The engine did not build: the page is served anyway, so it says so on
  /// the page (an error, and in the browser's console) and in the terminal
  /// (a banner line). An engine that was built before is still served.
  void _engineFailed(String name, String message, bool stale) {
    final failure = _engineFailure = EngineFailure.of(
      name,
      message,
      stale: stale,
    );
    Say.error('${failure.banner}\n$message');
    _proxy?.problem('engine', failure.title, failure.detail);
  }

  /// The page has no engine anymore (its last state went): a failure of the
  /// one it had is over.
  void _engineGone() {
    _engineFailure = null;
    _proxy?.clearProblem('engine');
  }

  /// The engine built (or is the one of the last good build).
  void _engineBuilt() {
    if (_engineFailure != null) {
      _engineFailure = null;
      Say.ok('the engine built: the page has its interactivity again');
    }
    _proxy?.clearProblem('engine');
  }

  void _listenForExit() {
    for (final signal in stopSignals()) {
      signal.watch().listen((_) => _stop());
    }
  }

  Future<void> _stop({bool exitProcess = true}) async {
    if (_stopping) return;
    _stopping = true;
    _batch.cancel();
    await _vm?.dispose().catchError((Object _) {});
    await _proxy?.close();
    for (final process in [?_server, ..._children]) {
      process.kill();
    }
    await Future.wait([
      for (final process in [?_server, ..._children]) process.exitCode,
    ]).timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        // Still there: no more asking.
        for (final process in [?_server, ..._children]) {
          process.kill(ProcessSignal.sigkill);
        }
        return const [];
      },
    );
    if (_pids case final f? when f.existsSync()) f.deleteSync();
    Say.info('stopped');
    if (exitProcess) exit(0);
  }
}

// The end of a build of `build_runner watch` (2.15+, and before).
final _codegenSucceeded = RegExp('Built with build_runner|Succeeded after');
final _codegenFailed = RegExp('Failed to build with build_runner|Failed after');

/// Why `thor dev` must not say "ready" yet, or null when it can: the app
/// exited or does not compile ([failure], the last lines it printed), or a
/// build step failed ([error], the first one: the engine, code generation,
/// a THOR-B finding).
String? devNotRunning(String? failure, {String? error}) {
  if (failure != null) {
    final lines = failure
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty);
    return lines.isEmpty ? 'it did not start' : lines.first;
  }
  return error;
}

/// The source files (absolute paths) of a dart2js output, from its `.deps`
/// file (one `file:` URI per line); empty if there is none.
Set<String> engineSources(File deps) {
  if (!deps.existsSync()) return const {};
  return {
    for (final line in deps.readAsLinesSync())
      if (line.startsWith('file:')) p.normalize(Uri.parse(line).toFilePath()),
  };
}

/// The port `thor dev` prefers: `--port` ([flag]) if given, else
/// `THOR_DEV_PORT` of the app (its `.env` [dotEnv], or the real
/// environment, which wins like everywhere), else 4300.
int devPort(
  String? flag,
  Map<String, String> dotEnv, [
  Map<String, String>? env,
]) {
  if (flag != null) return parsePort(flag);
  final value =
      (env ?? Platform.environment)['THOR_DEV_PORT'] ?? dotEnv['THOR_DEV_PORT'];
  if (value == null || value.trim().isEmpty) return 4300;
  try {
    return parsePort(value);
  } on ThorException {
    throw ThorException(
      'THOR_DEV_PORT takes a number from 0 to 65535, not "$value" '
      '(it comes from the app\'s .env or the environment).',
      exitCode: 64,
    );
  }
}

/// Starts [executable] so that it stops when this process does, even if
/// this one is killed (`kill -9`): on macOS and Linux a small `sh` waits for
/// its standard input to close (this process gone) or for a signal, and
/// stops it. The returned process is that `sh`.
///
/// For children that don't watch their standard input themselves
/// (`build_runner watch`); the app's server does (`ThorDev`).
Future<Process> startTied(
  String executable,
  List<String> args, {
  required String dir,
}) {
  if (Platform.isWindows) {
    return Process.start(executable, args, workingDirectory: dir);
  }
  // Waits for the child (not for the reader): if it exits by itself the
  // `sh` exits too, with its code. The watcher kills the child when stdin
  // closes (this process gone).
  const script = r'''
"$@" </dev/null & child=$!
exec 3<&0
{
  cat <&3 >/dev/null & reader=$!
  trap 'kill $reader 2>/dev/null; exit 0' TERM
  wait $reader
  kill $child 2>/dev/null
} & watcher=$!
trap 'kill $child $watcher 2>/dev/null; wait $child; exit 0' TERM INT HUP
wait $child
code=$?
kill $watcher 2>/dev/null
exit $code
''';
  return Process.start('sh', [
    '-c',
    script,
    'thor-dev',
    executable,
    ...args,
  ], workingDirectory: dir);
}

/// Asks [process] to stop (SIGTERM) and waits for it; one that is still
/// there after [grace] (it ignores the signal, or hangs shutting down) is
/// killed. Without the limit a server that never exits would keep the
/// proxy on its restart page forever.
Future<void> stopGracefully(
  Process process, {
  Duration grace = const Duration(seconds: 5),
}) async {
  process.kill();
  await process.exitCode.timeout(
    grace,
    onTimeout: () {
      process.kill(ProcessSignal.sigkill);
      return process.exitCode;
    },
  );
}
