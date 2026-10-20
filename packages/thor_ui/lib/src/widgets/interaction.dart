import '../engine/watch.dart' show elementEventAttributes;
import '../foundation/parent_data.dart';

/// Flutter's `MouseCursor`, mapped to CSS `cursor`.
class MouseCursor {
  const MouseCursor._(this.css);

  /// The CSS `cursor` value.
  final String css;
}

/// Flutter's `SystemMouseCursors`.
abstract final class SystemMouseCursors {
  /// `cursor: default`.
  static const basic = MouseCursor._('default');

  /// `cursor: pointer`.
  static const click = MouseCursor._('pointer');

  /// `cursor: text`.
  static const text = MouseCursor._('text');

  /// `cursor: not-allowed`.
  static const forbidden = MouseCursor._('not-allowed');

  /// `cursor: wait`.
  static const wait = MouseCursor._('wait');

  /// `cursor: progress`.
  static const progress = MouseCursor._('progress');

  /// `cursor: help`.
  static const help = MouseCursor._('help');

  /// `cursor: move`.
  static const move = MouseCursor._('move');

  /// `cursor: grab`.
  static const grab = MouseCursor._('grab');

  /// `cursor: grabbing`.
  static const grabbing = MouseCursor._('grabbing');

  /// `cursor: crosshair`.
  static const precise = MouseCursor._('crosshair');

  /// `cursor: none`.
  static const none = MouseCursor._('none');

  /// `cursor: col-resize`.
  static const resizeColumn = MouseCursor._('col-resize');

  /// `cursor: row-resize`.
  static const resizeRow = MouseCursor._('row-resize');

  /// `cursor: zoom-in`.
  static const zoomIn = MouseCursor._('zoom-in');

  /// `cursor: zoom-out`.
  static const zoomOut = MouseCursor._('zoom-out');
}

/// Flutter's `MouseRegion`.
///
/// ```dart
/// MouseRegion(
///   cursor: SystemMouseCursors.click,
///   onEnter: card.hover,     // void hover()
///   onExit: card.unhover,
///   child: card,
/// )
/// ```
///
/// `// web:` [onEnter] and [onExit] are methods of a `ThorState` and run
/// in the browser once the engine is loaded (the first click, key or focus
/// loads it; hovering alone does not, so a page nobody touches ships no
/// JS): a pointer already inside then counts as entered. Only a mouse or
/// pen counts, like Flutter (a finger never hovers, so a tap on a phone
/// enters nothing and leaves nothing). Nested regions and children inside
/// the region do not flicker: moving between two elements of the same
/// region is not an exit, and leaving the window is.
class MouseRegion extends ParentDataWrapper {
  /// Wraps `child`, applying [cursor] and pointer listeners.
  const MouseRegion({
    super.key,
    this.cursor,
    this.onEnter,
    this.onExit,
    required super.child,
  });

  /// The cursor shown while hovering `child`.
  final MouseCursor? cursor;

  /// Called when the pointer enters `child`.
  final void Function()? onEnter;

  /// Called when the pointer leaves `child`.
  final void Function()? onExit;

  @override
  WrapData get wrapData => WrapData(
    css: {if (cursor != null) 'cursor': cursor!.css},
    attributes: elementEventAttributes({'enter': onEnter, 'leave': onExit}),
  );
}
