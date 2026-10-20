import 'package:thor_ui/thor_ui.dart';

/// Shadow colors. Shadows are rare in this language (borders do the work);
/// these stay for what lifts off the page, and the scrim behind a modal.
abstract final class StudioShadowColors {
  /// A hairline of depth under a card.
  static const shadowSoft = ColorToken(
    'shadow-soft',
    light: Color(0x0A000000),
    dark: Color(0x66000000),
  );

  /// What lifts off the page: a popover, the selected segment.
  static const shadowLift = ColorToken(
    'shadow-lift',
    light: Color(0x1A000000),
    dark: Color(0x99000000),
  );

  /// The page behind a modal panel (the drawer, the search dialog): black
  /// at 40 %, 60 % in dark.
  static const scrim = ColorToken(
    'scrim',
    light: Color(0x66000000),
    dark: Color(0x99000000),
  );

  /// Every shadow token.
  static const values = [shadowSoft, shadowLift, scrim];
}
