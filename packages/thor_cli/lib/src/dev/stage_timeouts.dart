import 'dart:async';

/// How long each stage of a `thor dev` update may take before it counts as
/// hung. One place for the limits; tests pass short ones.
///
/// Without them one stuck stage (a VM that never answers a reload, a
/// builder worker that swallowed a request, a server that never listens)
/// blocks the serialized update queue and every later save waits in
/// silence.
class DevTimeouts {
  /// Limits for each stage.
  const DevTimeouts({
    this.reload = const Duration(seconds: 60),
    this.workerRequest = const Duration(seconds: 120),
    this.serverListening = const Duration(seconds: 60),
  });

  /// The defaults.
  static const defaults = DevTimeouts();

  /// `vm.reload()`: loading the code and reassembling.
  final Duration reload;

  /// One request to the builder worker (a cold analysis can be slow).
  final Duration workerRequest;

  /// A started server until it listens.
  final Duration serverListening;
}

/// A stage that did not finish in [limit].
class StageTimeout implements Exception {
  /// The stage that hung.
  StageTimeout(this.stage, this.limit);

  /// What was being done ("hot reload").
  final String stage;

  /// The limit that passed.
  final Duration limit;

  /// For the console and the page.
  String get message => '$stage did not finish in ${_show(limit)}';

  static String _show(Duration d) =>
      d.inMilliseconds >= 1000 ? '${d.inSeconds} s' : '${d.inMilliseconds} ms';

  @override
  String toString() => message;
}

/// [work], or a [StageTimeout] if it takes longer than [limit]. The work
/// itself is not cancelled (Dart can't): the caller discards whatever it
/// holds (the VM client, the process).
Future<T> guardStage<T>(String stage, Duration limit, Future<T> work) =>
    work.timeout(limit, onTimeout: () => throw StageTimeout(stage, limit));
