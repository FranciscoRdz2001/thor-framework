/// Flutter's listenables: objects that notify listeners when they change.
///
/// Here, not in `thor_ui`, because a `StateSignal` (a field of a `ThorState`)
/// is a [ValueNotifier]: code written for Flutter's `ValueListenableBuilder`
/// or `addListener` runs on it.
///
/// `// web:` a listener runs when the value changes in the browser: in a lite
/// state at the end of the batch that wrote it (as every effect does), not
/// inside the setter, and a listener that throws makes the write throw after
/// the other listeners ran (dart2js and the VM report it and go on, as
/// Flutter does).
library;

import 'listeners.dart';

/// An object that notifies its listeners when it changes.
abstract class Listenable {
  /// A listenable.
  const Listenable();

  /// Calls [listener] on every change.
  void addListener(void Function() listener);

  /// Stops calling [listener].
  void removeListener(void Function() listener);
}

/// A [Listenable] with a current [value].
abstract class ValueListenable<T> extends Listenable {
  /// A listenable with a value.
  const ValueListenable();

  /// The current value.
  T get value;
}

/// A [Listenable] that notifies with [notifyListeners].
class ChangeNotifier implements Listenable {
  Listeners? _listeners = Listeners();

  /// Whether anyone listens.
  bool get hasListeners => _listeners?.isNotEmpty ?? false;

  @override
  void addListener(void Function() listener) {
    assert(_listeners != null, 'A $runtimeType was used after dispose().');
    _listeners?.add(listener);
  }

  @override
  void removeListener(void Function() listener) => _listeners?.remove(listener);

  /// Calls every listener, in the order they were added. A listener added
  /// meanwhile counts from the next notification; one removed meanwhile
  /// that has not run yet is skipped; one that throws is reported and the
  /// rest still run (as in Flutter).
  void notifyListeners() {
    assert(_listeners != null, 'A $runtimeType was used after dispose().');
    _listeners?.notify();
  }

  /// Drops every listener; the notifier can't be used after this.
  void dispose() => _listeners = null;
}

/// A [ChangeNotifier] holding a [value]: setting a different one notifies.
class ValueNotifier<T> extends ChangeNotifier implements ValueListenable<T> {
  /// A notifier starting at the given value.
  ValueNotifier(this._value);

  T _value;

  @override
  T get value => _value;
  set value(T newValue) {
    if (_value == newValue) return;
    _value = newValue;
    notifyListeners();
  }

  @override
  String toString() => '$runtimeType($value)';
}
