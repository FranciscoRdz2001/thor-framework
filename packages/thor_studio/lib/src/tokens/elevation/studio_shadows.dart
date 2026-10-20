import 'package:thor_ui/thor_ui.dart';

import '../color/studio_shadow_colors.dart';

/// Box shadows. Cards are flat (a hairline border); only what floats gets
/// one, and it follows the theme because its color is a token.
abstract final class StudioShadows {
  /// No shadow: cards and panels.
  static const List<BoxShadow> none = [];

  /// A hint of depth under a resting control (the selected segment).
  static const List<BoxShadow> soft = [
    BoxShadow(
      color: StudioShadowColors.shadowSoft,
      offset: Offset(0, 1),
      blurRadius: 2,
    ),
  ];

  /// A popover, a menu, the artboard lifting off the page.
  static const List<BoxShadow> lift = [
    BoxShadow(
      color: StudioShadowColors.shadowLift,
      offset: Offset(0, 8),
      blurRadius: 24,
      spreadRadius: -8,
    ),
  ];
}
