import 'package:thor_ui/thor_ui.dart';

/// Easing curves. A strong ease-out for what responds or enters (it starts
/// fast, so the interface feels instant), an ease-in-out for what moves
/// across the screen. Never an ease-in.
abstract final class StudioCurves {
  /// `cubic-bezier(.23, 1, .32, 1)`: entering, pressing, hovering.
  static const enter = Cubic(0.23, 1, 0.32, 1);

  /// `cubic-bezier(.4, 0, .2, 1)` (Flutter's `Curves.fastOutSlowIn`):
  /// moving on screen (the segmented control's thumb). It starts at once and
  /// lands softly; a steeper in-out (`.77, 0, .175, 1`) barely moves for the
  /// first quarter and then crosses a third of the way in one frame at 60 Hz.
  static const move = Curves.fastOutSlowIn;
}
