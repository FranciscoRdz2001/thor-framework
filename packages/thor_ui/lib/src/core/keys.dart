part of 'framework.dart';

/// Identifies a component among its siblings (see [Widget.key]).
abstract class Key {
  /// A key.
  const Key();
}

/// A key made of a [value]: equal values, equal keys.
class ValueKey<T> extends Key {
  /// A key for [value].
  const ValueKey(this.value);

  /// What identifies the component.
  final T value;

  @override
  bool operator ==(Object other) =>
      other is ValueKey<T> &&
      other.runtimeType == runtimeType &&
      other.value == value;

  @override
  int get hashCode => Object.hash(runtimeType, value);

  @override
  String toString() => 'ValueKey<$T>($value)';
}

/// A key equal only to itself.
class UniqueKey extends Key {
  // Not const: every instance is a different key.
  // ignore: prefer_const_constructors_in_immutables
  /// A key equal only to itself.
  UniqueKey();

  @override
  String toString() => 'UniqueKey#${identityHashCode(this).toRadixString(16)}';
}

/// Flutter's global key. `// web:` the server keeps no tree between
/// builds, so [currentState] and [currentContext] are always null.
class GlobalKey<T extends State> extends Key {
  // Not const: every instance is a different key.
  // ignore: prefer_const_constructors_in_immutables
  /// A global key (see the class).
  GlobalKey();

  /// Always null on the server (see the class).
  T? get currentState => null;

  /// Always null on the server (see the class).
  BuildContext? get currentContext => null;
}
