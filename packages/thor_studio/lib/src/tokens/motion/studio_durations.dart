/// How long things take. Nothing in the interface goes over 200 ms: motion
/// confirms an action, it never makes you wait for one.
abstract final class StudioDurations {
  /// Hover and color changes.
  static const fast = Duration(milliseconds: 120);

  /// Press feedback and small state changes.
  static const base = Duration(milliseconds: 160);

  /// Things that enter or leave: popovers, drawers.
  static const slow = Duration(milliseconds: 200);
}
