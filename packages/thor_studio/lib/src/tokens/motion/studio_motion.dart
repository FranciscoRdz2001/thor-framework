/// Motion values that are not a duration or a curve.
abstract final class StudioMotion {
  /// The scale of a pressed control (`:active`): a barely visible squeeze
  /// that tells the user the interface heard them.
  static const double pressScale = 0.97;

  /// The squeeze of a big pressable surface (a card, a pager link): the same
  /// feedback at a size where `.97` would move the edges too far.
  static const double pressScaleLarge = 0.985;

  /// The scale an entering popover starts from (never from 0).
  static const double enterScale = 0.96;

  /// How far a card or a link card rises under the pointer (px).
  static const double hoverLift = 2;

  /// How far an arrow nudges in the direction it points when its link is
  /// hovered (px).
  static const double arrowNudge = 3;

  /// How far content starts below its place when it enters (px): it rises
  /// into it.
  static const double enterRise = 8;

  /// The scale of a Level's grip while it is held or has the keyboard.
  static const double gripScale = 1.35;

  /// The scale of a Level's grip under the pointer.
  static const double gripHoverScale = 1.15;
}
