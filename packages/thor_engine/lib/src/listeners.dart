/// The listener list behind `ChangeNotifier` and `StateSignal`, notified as
/// Flutter's `ChangeNotifier` does (its `change_notifier_test.dart` is the
/// reference): a listener added meanwhile waits for the next notification,
/// one removed meanwhile that has not run yet is skipped (even if the same
/// function is added back: that is a new listener), and a listener that
/// throws is reported and does not stop the others.
library;

import 'dart:async' show Zone;

/// The listeners of one notifier.
final class Listeners {
  final List<void Function()?> _all = [];
  int _depth = 0;
  int _removed = 0;

  /// Whether any listener is left.
  bool get isNotEmpty => _all.length > _removed;

  /// Adds [listener] (the same function twice is called twice).
  void add(void Function() listener) => _all.add(listener);

  /// Removes one occurrence of [listener], if it is there.
  void remove(void Function() listener) {
    final i = _all.indexOf(listener);
    if (i < 0) return;
    if (_depth > 0) {
      // Not resized while notifying: the slot is emptied and swept at the end.
      _all[i] = null;
      _removed++;
    } else {
      _all.removeAt(i);
    }
  }

  /// Calls the listeners that were there when it started, in order.
  void notify() {
    final end = _all.length;
    _depth++;
    try {
      for (var i = 0; i < end; i++) {
        final listener = _all[i];
        if (listener == null) continue;
        try {
          listener();
          // A listener's failure is reported, as Flutter does, so the ones
          // after it still hear the change.
          // ignore: avoid_catches_without_on_clauses
        } catch (error, stack) {
          Zone.current.handleUncaughtError(error, stack);
        }
      }
    } finally {
      if (--_depth == 0 && _removed > 0) {
        _all.removeWhere((l) => l == null);
        _removed = 0;
      }
    }
  }
}
