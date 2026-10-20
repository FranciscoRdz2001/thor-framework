import 'package:thor_engine/thor_engine.dart' show splitArgs;
import 'package:thor_style/thor_style.dart';

Offset _offset(String? arg) {
  final parts = splitArgs(arg, 2);
  return Offset(double.tryParse(parts[0]) ?? 0, double.tryParse(parts[1]) ?? 0);
}

/// Flutter's `TapDownDetails`: where the pointer went down.
///
/// A callback of a `GestureDetector` that takes it is a method of a
/// `ThorState`:
///
/// ```dart
/// void down(TapDownDetails details) => at.value = details.localPosition;
/// ```
///
/// `// web:` only [localPosition] is reported (CSS pixels from the
/// element's top-left corner). Flutter's `globalPosition` and `kind` are
/// not: the page is not told where the element is.
class TapDownDetails {
  /// Details of a pointer that went down at [localPosition].
  const TapDownDetails({this.localPosition = Offset.zero});

  /// What the browser reports as `x~y`; the page builds the details with it.
  factory TapDownDetails.fromArg(String? arg) =>
      TapDownDetails(localPosition: _offset(arg));

  /// The position inside the element, from its top-left corner.
  final Offset localPosition;
}

/// Flutter's `TapUpDetails`: where the pointer was released as a tap.
///
/// `// web:` only [localPosition] is reported, like [TapDownDetails].
class TapUpDetails {
  /// Details of a tap that ended at [localPosition].
  const TapUpDetails({this.localPosition = Offset.zero});

  /// What the browser reports as `x~y`; the page builds the details with it.
  factory TapUpDetails.fromArg(String? arg) =>
      TapUpDetails(localPosition: _offset(arg));

  /// The position inside the element, from its top-left corner.
  final Offset localPosition;
}

/// Flutter's `DragUpdateDetails`: how far the pointer moved since the last
/// update.
///
/// `// web:` only [delta] is reported, at most once per animation frame
/// (the moves in between add up). Flutter's `localPosition`,
/// `globalPosition` and `primaryDelta` are not.
class DragUpdateDetails {
  /// Details of a drag that moved by [delta].
  const DragUpdateDetails({this.delta = Offset.zero});

  /// What the browser reports as `dx~dy`; the page builds the details with
  /// it.
  factory DragUpdateDetails.fromArg(String? arg) =>
      DragUpdateDetails(delta: _offset(arg));

  /// The pixels moved since the last update.
  final Offset delta;
}

/// Flutter's `Velocity`: a speed in logical pixels per second.
class Velocity {
  /// A velocity of [pixelsPerSecond].
  const Velocity({required this.pixelsPerSecond});

  /// No movement.
  static const zero = Velocity(pixelsPerSecond: Offset.zero);

  /// The speed along each axis, in pixels per second.
  final Offset pixelsPerSecond;

  @override
  bool operator ==(Object other) =>
      other is Velocity && other.pixelsPerSecond == pixelsPerSecond;

  @override
  int get hashCode => pixelsPerSecond.hashCode;

  @override
  String toString() =>
      'Velocity(${pixelsPerSecond.dx.toStringAsFixed(1)}, '
      '${pixelsPerSecond.dy.toStringAsFixed(1)})';
}

/// Flutter's `DragEndDetails`: how a drag ended.
///
/// ```dart
/// void released(DragEndDetails details) {
///   if (details.velocity.pixelsPerSecond.dx.abs() > 600) dismiss();
/// }
/// ```
///
/// `// web:` [velocity] is measured over the pointer's last 100 ms and
/// clamped to 8000 px/s (Flutter's maximum fling velocity); the positions
/// are where the pointer let go, from the element's top-left corner where
/// it rests, not where the drag drew it ([localPosition]), and from the
/// viewport's ([globalPosition], CSS pixels). [primaryVelocity] is null: a pan has no primary axis, as in
/// Flutter.
class DragEndDetails {
  /// Details of a drag that ended at [localPosition] with [velocity].
  const DragEndDetails({
    this.velocity = Velocity.zero,
    this.primaryVelocity,
    this.globalPosition = Offset.zero,
    Offset? localPosition,
  }) : localPosition = localPosition ?? globalPosition;

  /// What the browser reports as `vx~vy~lx~ly~gx~gy`; the page builds the
  /// details with it.
  factory DragEndDetails.fromArg(String? arg) {
    final p = splitArgs(arg, 6);
    double n(int i) => double.tryParse(p[i]) ?? 0;
    return DragEndDetails(
      velocity: Velocity(pixelsPerSecond: Offset(n(0), n(1))),
      localPosition: Offset(n(2), n(3)),
      globalPosition: Offset(n(4), n(5)),
    );
  }

  /// The speed when the pointer let go.
  final Velocity velocity;

  /// The speed along the drag's main axis (null for a pan).
  final double? primaryVelocity;

  /// Where the pointer was, in the viewport.
  final Offset globalPosition;

  /// Where the pointer was, from the element's top-left corner.
  final Offset localPosition;
}
