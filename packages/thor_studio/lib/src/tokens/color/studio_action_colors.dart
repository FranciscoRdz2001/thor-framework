import 'package:thor_ui/thor_ui.dart';

/// The primary action: the pill filled with the brand indigo (the accent's
/// hue), the strongest thing on screen in both themes. Secondary actions
/// stay neutral (an outline), so the one filled pill is where to go next.
abstract final class StudioActionColors {
  /// The filled pill (`--t-action`).
  static const action = ColorToken(
    'action',
    light: Color(0xFF4F46E5),
    dark: Color(0xFF818CF8),
  );

  /// Text and icons on [action].
  static const onAction = ColorToken(
    'action-ink',
    light: Color(0xFFFFFFFF),
    dark: Color(0xFF0B0D17),
  );

  /// The pill while the pointer is over it.
  static const actionHover = ColorToken(
    'action-hover',
    light: Color(0xFF4338CA),
    dark: Color(0xFFA5B4FC),
  );

  /// Every action token.
  static const values = [action, onAction, actionHover];
}
