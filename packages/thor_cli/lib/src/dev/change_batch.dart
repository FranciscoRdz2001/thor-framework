import 'dart:async';

/// When `thor dev` applies the files that changed: [quick]ly for a single
/// saved file (the common case: one save, the page follows at once), after
/// [settle] with no new change for several (a checkout, a save-all, a tool
/// writing files), so one update sees all of them.
///
/// A file saved twice at once (an editor's write and touch) still counts
/// as one. A change arriving while an update runs is picked up by that
/// update's next round, which waits for [quiet] first.
class ChangeBatch {
  /// Calls [_fire] once the changes settle.
  ChangeBatch(
    this._fire, {
    this.quick = const Duration(milliseconds: 15),
    this.settle = const Duration(milliseconds: 200),
  });

  final void Function() _fire;

  /// The wait for a single file: enough for the events of one save,
  /// delivered together, to arrive.
  final Duration quick;

  /// The quiet spell that ends a burst of several files.
  final Duration settle;

  /// The files of the batch not fired yet.
  final _files = <String>{};

  /// Since the last change.
  final _since = Stopwatch();

  Timer? _timer;

  /// [file] changed.
  void add(String file) {
    _files.add(file);
    _since
      ..reset()
      ..start();
    _timer?.cancel();
    _timer = Timer(_files.length > 1 ? settle : quick, () {
      _files.clear();
      _fire();
    });
  }

  /// Completes once no change arrived for [settle] (at once when none
  /// did lately): the rest of a burst an update is about to apply.
  Future<void> quiet() async {
    while (_since.isRunning && _since.elapsed < settle) {
      await Future<void>.delayed(settle - _since.elapsed);
    }
  }

  /// Drops the pending fire (stopping).
  void cancel() {
    _timer?.cancel();
    _files.clear();
  }
}
