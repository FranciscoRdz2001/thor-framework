/// Letter spacing in logical pixels. Big type tightens (Inter's default is
/// loose at display sizes); small type keeps its natural spacing.
abstract final class StudioLetterSpacing {
  /// Display and headline sizes.
  static const double tight = -1.0;

  /// Titles.
  static const double snug = -0.4;

  /// Everything else.
  static const double normal = 0;
}
