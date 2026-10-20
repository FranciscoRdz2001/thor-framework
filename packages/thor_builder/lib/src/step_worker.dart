/// The long-lived worker of `thor dev` (`bin/worker.dart`): the entries and
/// lite-state steps ([writeAppEntries], [writeLiteStates]) on one analysis
/// of the app that stays warm across saves. Run one-shot, each step spends
/// ~2 s resolving the SDK and thor's packages from nothing; here only what
/// changed is analyzed again.
///
/// Protocol: one JSON object per line on stdin, one answer per line on
/// stdout, in order.
///
/// ```text
/// {"id": 1, "cmd": "entries", "allFeatures": false, "changed": [...]}
/// {"id": 2, "cmd": "lite_state", "out": "build/lite/state.js",
///  "readable": true, "changed": [...]}
/// {"id": 3, "cmd": "lite_bundle", "state": "build/lite/state.js",
///  "out": "web/engine.dart.js", "minify": false, "dev": true}
/// → {"id": 1, "exit": 0, "output": "<what the command prints>"}
/// → {"id": 2, "error": "<why the request could not run>"}
/// ```
///
/// `changed` lists files changed outside the app's `lib/` (a workspace
/// package); the worker finds the app's own changes itself. `output` is
/// the command's stdout and stderr as `dart run thor_builder:<cmd>` (or
/// `thor_engine:lite_bundle`) prints them, `exit` its exit code. The worker exits when stdin closes.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:thor_engine/lite.dart' show writeLiteBundle;

import 'app_steps.dart';

/// One app's warm analysis, and the steps run on it.
class StepWorker {
  /// A worker for the app in [app] (absolute, symlinks resolved).
  StepWorker(this.app) : _lib = '$app/lib';

  /// The app's folder.
  final String app;
  final String _lib;
  AnalysisContextCollection? _analysis;

  /// The size and time of every Dart file of `lib/` as last analyzed.
  var _stamps = <String, String>{};

  /// The time of the package config the analysis was made with.
  String? _config;

  /// The requests, one at a time.
  Future<void> _queue = Future.value();

  /// Resolves every library of `lib/` once, so the first request finds
  /// the analysis warm.
  Future<void> warm() => _serial(() async {
    final analysis = await _fresh(const []);
    for (final context in analysis.contexts) {
      for (final path in context.contextRoot.analyzedFiles()) {
        if (!path.endsWith('.dart')) continue;
        await context.currentSession.getResolvedLibrary(path);
      }
    }
  });

  /// Answers [request] (see the library's doc).
  Future<Map<String, Object?>> handle(Map<String, Object?> request) =>
      _serial(() async {
        final id = request['id'];
        try {
          final changed = [
            for (final path in (request['changed'] as List?) ?? const [])
              path as String,
          ];
          final analysis = await _fresh(changed);
          final output = StringBuffer();
          final int code;
          switch (request['cmd']) {
            case 'entries':
              code = await writeAppEntries(
                app,
                allFeatures: request['allFeatures'] == true,
                out: output,
                err: output,
                analysis: analysis,
              );
            case 'lite_state':
              final out = request['out'] as String? ?? 'build/lite/state.js';
              code = await writeLiteStates(
                app,
                // Relative to the app, like the command run in it.
                outPath: File(out).isAbsolute ? out : '$app/$out',
                readable: request['readable'] == true,
                out: output,
                err: output,
                analysis: analysis,
              );
            case 'lite_bundle':
              // No analysis: thor_engine's bundle, without a `dart run`.
              String abs(String path) =>
                  File(path).isAbsolute ? path : '$app/$path';
              output.writeln(
                await writeLiteBundle(
                  statePath: abs(request['state'] as String),
                  appDir: app,
                  outPath: abs(request['out'] as String),
                  minify: request['minify'] != false,
                  dev: request['dev'] == true,
                ),
              );
              code = 0;
            case final cmd:
              return {'id': id, 'error': 'unknown cmd: $cmd'};
          }
          return {'id': id, 'exit': code, 'output': '$output'};
        } on Object catch (e, stack) {
          return {'id': id, 'error': '$e\n$stack'};
        }
      });

  Future<T> _serial<T>(Future<T> Function() task) {
    final result = _queue.then((_) => task());
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }

  /// The analysis, up to date with the files on disk: the files of `lib/`
  /// that came, went or changed, and [changed] (outside `lib/`). A new
  /// package config (`pub get`) starts it over.
  Future<AnalysisContextCollection> _fresh(List<String> changed) async {
    final config = _packageConfig();
    final stamp = config == null ? null : _stamp(config);
    var analysis = _analysis;
    if (analysis == null || stamp != _config) {
      await analysis?.dispose();
      analysis = _analysis = appAnalysis(_lib);
      _config = stamp;
      _stamps = _libStamps();
      return analysis;
    }
    final now = _libStamps();
    final paths = {
      ...changed,
      for (final e in now.entries)
        if (_stamps[e.key] != e.value) e.key,
      for (final path in _stamps.keys)
        if (!now.containsKey(path)) path,
    };
    _stamps = now;
    if (paths.isEmpty) return analysis;
    for (final context in analysis.contexts) {
      paths.forEach(context.changeFile);
      await context.applyPendingFileChanges();
    }
    return analysis;
  }

  Map<String, String> _libStamps() => {
    for (final f in Directory(_lib).listSync(recursive: true))
      if (f is File && f.path.endsWith('.dart')) f.path: _stamp(f),
  };

  static String _stamp(File f) {
    final stat = f.statSync();
    return '${stat.size}:${stat.modified.microsecondsSinceEpoch}';
  }

  File? _packageConfig() {
    for (var d = Directory(app); ; d = d.parent) {
      final f = File('${d.path}/.dart_tool/package_config.json');
      if (f.existsSync()) return f;
      if (d.parent.path == d.path) return null;
    }
  }

  /// Stops the analysis.
  Future<void> dispose() async => _analysis?.dispose();
}

/// Serves [worker] on [input] (request lines), answering on [output];
/// completes when [input] ends.
Future<void> serveSteps(
  StepWorker worker,
  Stream<String> input,
  StringSink output,
) async {
  unawaited(worker.warm().catchError((Object _) {}));
  final answers = <Future<void>>[];
  await for (final line in input) {
    if (line.trim().isEmpty) continue;
    Map<String, Object?> request;
    try {
      request = jsonDecode(line) as Map<String, Object?>;
    } on Object catch (e) {
      output.writeln(jsonEncode({'error': 'not a request: $e'}));
      continue;
    }
    // Queued in order by the worker: answers come out in order.
    answers.add(
      worker.handle(request).then((a) => output.writeln(jsonEncode(a))),
    );
  }
  await Future.wait(answers);
  await worker.dispose();
}
