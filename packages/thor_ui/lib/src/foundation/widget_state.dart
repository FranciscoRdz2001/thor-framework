/// Flutter's `WidgetState` / `WidgetStateProperty`: a value per
/// interactive state (selected, disabled, hovered…).
///
/// `// web:` resolved on the server for each state a widget styles, into
/// conditions of the element's one class (`[aria-selected="true"]`,
/// `:hover`…): the browser only flips attributes.
library;

/// Flutter's `WidgetStatesConstraint`: a condition on a set of
/// [WidgetState]s. A [WidgetState] is one (it holds when the set has it);
/// [WidgetState.any] always holds; `&`, `|` and `~` combine them.
abstract interface class WidgetStatesConstraint {
  /// Whether [states] satisfy this constraint.
  bool isSatisfiedBy(Set<WidgetState> states);
}

/// Flutter's `WidgetStateOperators`: `a & b`, `a | b` and `~a` on
/// constraints.
mixin WidgetStateOperators implements WidgetStatesConstraint {
  /// Holds when this and [other] hold.
  WidgetStatesConstraint operator &(WidgetStatesConstraint other) =>
      _WidgetStatesCombined((s) => isSatisfiedBy(s) && other.isSatisfiedBy(s));

  /// Holds when this or [other] holds.
  WidgetStatesConstraint operator |(WidgetStatesConstraint other) =>
      _WidgetStatesCombined((s) => isSatisfiedBy(s) || other.isSatisfiedBy(s));

  /// Holds when this does not.
  WidgetStatesConstraint operator ~() =>
      _WidgetStatesCombined((s) => !isSatisfiedBy(s));
}

class _WidgetStatesCombined with WidgetStateOperators {
  const _WidgetStatesCombined(this._test);

  final bool Function(Set<WidgetState>) _test;

  @override
  bool isSatisfiedBy(Set<WidgetState> states) => _test(states);
}

class _AnyWidgetState with WidgetStateOperators {
  const _AnyWidgetState();

  @override
  bool isSatisfiedBy(Set<WidgetState> states) => true;
}

/// Flutter's `WidgetState`.
enum WidgetState with WidgetStateOperators {
  /// The pointer is over it.
  hovered,

  /// It has the keyboard focus.
  focused,

  /// It is being pressed.
  pressed,

  /// It is being dragged.
  dragged,

  /// It is selected (a day, a chip).
  selected,

  /// Content scrolls under it.
  scrolledUnder,

  /// It doesn't respond to input.
  disabled,

  /// It has an error.
  error;

  /// Holds in every set of states (the last entry of a
  /// [WidgetStateProperty.fromMap]: the fallback).
  static const WidgetStatesConstraint any = _AnyWidgetState();

  @override
  bool isSatisfiedBy(Set<WidgetState> states) => states.contains(this);
}

/// Flutter's `WidgetStateMap`: the constraints of a
/// [WidgetStateProperty.fromMap] and the value of each.
typedef WidgetStateMap<T> = Map<WidgetStatesConstraint, T>;

/// Flutter's `WidgetPropertyResolver`.
typedef WidgetPropertyResolver<T> = T Function(Set<WidgetState> states);

/// Flutter's `WidgetStateProperty`: a value of type [T] for a set of
/// [WidgetState]s.
///
/// ```dart
/// DatePickerThemeData(
///   dayBackgroundColor: WidgetStateProperty.resolveWith((states) =>
///       states.contains(WidgetState.selected) ? Colors.teal : null),
/// )
/// ```
abstract class WidgetStateProperty<T> {
  /// Const constructor for subclasses.
  const WidgetStateProperty();

  /// The value of the first entry of [map] whose constraint the states
  /// satisfy (the declarative form of [resolveWith]: a value, not a
  /// closure, so a tool can read and write it).
  ///
  /// ```dart
  /// WidgetStateProperty.fromMap({
  ///   WidgetState.hovered: Colors.teal,
  ///   WidgetState.any: Colors.grey,
  /// })
  /// ```
  ///
  /// When no entry holds the value is null (for a nullable [T]); otherwise
  /// resolving throws an [ArgumentError], so end the map with
  /// [WidgetState.any].
  const factory WidgetStateProperty.fromMap(WidgetStateMap<T> map) =
      _WidgetStateMapper<T>;

  /// The value for [states].
  T resolve(Set<WidgetState> states);

  /// [value] in every state.
  static WidgetStateProperty<T> all<T>(T value) =>
      WidgetStatePropertyAll<T>(value);

  /// The value [callback] returns for each set of states.
  static WidgetStateProperty<T> resolveWith<T>(
    WidgetPropertyResolver<T> callback,
  ) => _WidgetStatePropertyWith<T>(callback);

  /// [value] resolved for [states] when it is a [WidgetStateProperty],
  /// else [value] itself.
  static T resolveAs<T>(T value, Set<WidgetState> states) =>
      value is WidgetStateProperty<T> ? value.resolve(states) : value;
}

/// Flutter's `WidgetStatePropertyAll`: the same value in every state.
class WidgetStatePropertyAll<T> extends WidgetStateProperty<T> {
  /// [value] in every state.
  const WidgetStatePropertyAll(this.value);

  /// The value.
  final T value;

  @override
  T resolve(Set<WidgetState> states) => value;

  @override
  bool operator ==(Object other) =>
      other is WidgetStatePropertyAll<T> && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

class _WidgetStatePropertyWith<T> extends WidgetStateProperty<T> {
  const _WidgetStatePropertyWith(this._resolve);

  final WidgetPropertyResolver<T> _resolve;

  @override
  T resolve(Set<WidgetState> states) => _resolve(states);
}

class _WidgetStateMapper<T> extends WidgetStateProperty<T> {
  const _WidgetStateMapper(this._map);

  final WidgetStateMap<T> _map;

  @override
  T resolve(Set<WidgetState> states) {
    for (final entry in _map.entries) {
      if (entry.key.isSatisfiedBy(states)) return entry.value;
    }
    try {
      return null as T;
    } on TypeError {
      throw ArgumentError(
        'None of the constraints of this WidgetStateProperty.fromMap holds '
        'for $states and $T is not nullable: end the map with '
        '`WidgetState.any`.',
      );
    }
  }

  @override
  bool operator ==(Object other) {
    if (other is! _WidgetStateMapper<T> || other._map.length != _map.length) {
      return false;
    }
    final a = _map.entries.iterator, b = other._map.entries.iterator;
    while (a.moveNext() && b.moveNext()) {
      if (a.current.key != b.current.key ||
          a.current.value != b.current.value) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll([
    for (final e in _map.entries) Object.hash(e.key, e.value),
  ]);
}
