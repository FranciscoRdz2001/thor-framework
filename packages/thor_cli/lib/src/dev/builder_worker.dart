import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../run.dart';
import 'stage_timeouts.dart';

/// thor_builder's steps through its long-lived worker
/// (`dart run thor_builder:worker`, protocol in thor_builder's
/// `lib/src/step_worker.dart`): the analysis of the app stays warm across
/// saves, so a state edit costs tens of milliseconds instead of a cold
/// analyzer per step (~2 s each).
///
/// Same output and same failures as [BuilderSteps.dartRun]. If the worker
/// dies or can't answer, it says so once and runs the steps with
/// `dart run` from then on: never a stale result.
class WorkerSteps extends BuilderSteps {
  WorkerSteps._(
    this._process, {
    required void Function(String) notice,
    required this.requestTimeout,
    this.onStuck,
  }) : _notice = notice {
    _process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(_answer, onDone: () => _gone('its output closed'));
    _process.stderr.transform(utf8.decoder).listen(_log.write);
    unawaited(_process.exitCode.then((code) => _gone('it exited ($code)')));
    // A write after it died: the request falls back, not thor dev.
    unawaited(_process.stdin.done.catchError((Object _) {}));
  }

  /// Starts the worker for the app in [dir]; [notice] tells the console
  /// when it falls back to `dart run`.
  ///
  /// A request that gets no answer in [requestTimeout] means the worker is
  /// stuck: it is killed, the request runs with `dart run` (the update goes
  /// on) and [onStuck] hears about it, to start a new worker.
  static Future<WorkerSteps> start(
    String dir, {
    required void Function(String) notice,
    Duration requestTimeout = const Duration(seconds: 120),
    void Function(StageTimeout)? onStuck,
  }) async {
    final process = await Process.start('dart', [
      'run',
      'thor_builder:worker',
      '.',
    ], workingDirectory: dir);
    return WorkerSteps._(
      process,
      notice: notice,
      requestTimeout: requestTimeout,
      onStuck: onStuck,
    );
  }

  /// A worker over an already started [process] (tests: a fake one).
  WorkerSteps.over(
    Process process, {
    required void Function(String) notice,
    required Duration requestTimeout,
    void Function(StageTimeout)? onStuck,
  }) : this._(
         process,
         notice: notice,
         requestTimeout: requestTimeout,
         onStuck: onStuck,
       );

  /// How long a request may wait for its answer.
  final Duration requestTimeout;

  /// Told when a request got no answer in time (the worker is killed).
  final void Function(StageTimeout)? onStuck;

  final Process _process;
  final void Function(String) _notice;

  /// The process (its pid goes in `dev-<port>.pids`).
  Process get process => _process;

  /// Why the worker is not used any more; null while it is.
  String? _down;

  /// What it wrote on stderr (the report when it stops).
  final _log = StringBuffer();
  final _waiting = <int, Completer<Map<String, Object?>>>{};
  var _id = 0;

  /// Whether the fall back to `dart run` was told.
  var _noticed = false;

  /// Files changed outside the app's `lib/` since the last request (the
  /// worker finds those of `lib/` itself).
  final _changed = <String>{};

  /// Tells the worker [path] changed (a workspace package's file).
  void changed(String path) => _changed.add(path);

  /// Whether requests still go to the worker.
  bool get alive => _down == null;

  void _answer(String line) {
    final Object? answer;
    try {
      answer = jsonDecode(line);
    } on FormatException {
      _log.writeln(line);
      return;
    }
    if (answer is! Map<String, Object?>) return;
    final id = answer['id'];
    final waiting = id is int ? _waiting.remove(id) : null;
    waiting?.complete(answer);
  }

  void _gone(String why) {
    _down ??= why;
    for (final w in _waiting.values) {
      w.completeError(_WorkerDown(why));
    }
    _waiting.clear();
  }

  /// Stops the worker (it also stops by itself when this process goes:
  /// its stdin closes).
  void stop() {
    _down ??= 'stopped';
    _process.kill();
  }

  Future<String> _run(
    Map<String, Object?> request,
    List<String> dartArgs,
    Future<String> Function() fallback,
  ) async {
    if (_down == null) {
      final id = ++_id;
      final done = Completer<Map<String, Object?>>();
      _waiting[id] = done;
      try {
        final changed = [..._changed];
        _changed.clear();
        _process.stdin.writeln(
          jsonEncode({'id': id, ...request, 'changed': changed}),
        );
        final answer = await guardStage(
          'builder worker request (${request['cmd']})',
          requestTimeout,
          done.future,
        );
        if (answer['error'] case final String error) {
          throw _WorkerDown(error.split('\n').first);
        }
        final output = answer['output'] as String? ?? '';
        final code = answer['exit'] as int? ?? 1;
        if (code == 0) return output;
        // The message `exec` gives for the same failure.
        throw ThorException(
          'dart ${dartArgs.join(' ')} failed ($code)\n$output',
          exitCode: code,
        );
      } on StageTimeout catch (e) {
        _waiting.remove(id);
        _fallBack('no answer: ${e.message}');
        onStuck?.call(e);
      } on _WorkerDown catch (e) {
        _waiting.remove(id);
        _fallBack(e.reason);
      } on StateError catch (e) {
        // stdin gone with the process.
        _waiting.remove(id);
        _fallBack(e.message);
      }
    } else if (!_noticed && _down != 'stopped') {
      _fallBack(_down!);
    }
    return fallback();
  }

  void _fallBack(String reason) {
    _down ??= reason;
    if (!_noticed) {
      _noticed = true;
      final log = _log.toString().trim();
      _notice(
        'builder worker stopped ($reason): running thor_builder with '
        'dart run${log.isEmpty ? '' : '\n$log'}',
      );
    }
    _process.kill();
  }

  @override
  Future<String> entries(String dir, {required bool allFeatures}) => _run(
    {'cmd': 'entries', 'allFeatures': allFeatures},
    BuilderSteps.entriesArgs(allFeatures: allFeatures),
    () => BuilderSteps.dartRun.entries(dir, allFeatures: allFeatures),
  );

  @override
  Future<String> liteState(String dir, String out, {required bool readable}) =>
      _run(
        {'cmd': 'lite_state', 'out': out, 'readable': readable},
        BuilderSteps.liteStateArgs(out, readable: readable),
        () => BuilderSteps.dartRun.liteState(dir, out, readable: readable),
      );

  @override
  Future<String> liteBundle(
    String dir,
    String state,
    String out, {
    required bool minify,
    required bool dev,
  }) => _run(
    {
      'cmd': 'lite_bundle',
      'state': state,
      'out': out,
      'minify': minify,
      'dev': dev,
    },
    BuilderSteps.liteBundleArgs(state, out, minify: minify, dev: dev),
    () => BuilderSteps.dartRun.liteBundle(
      dir,
      state,
      out,
      minify: minify,
      dev: dev,
    ),
  );
}

class _WorkerDown implements Exception {
  _WorkerDown(this.reason);
  final String reason;
}
