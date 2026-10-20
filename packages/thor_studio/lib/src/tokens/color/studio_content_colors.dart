import 'package:thor_ui/thor_ui.dart';

/// Text and icon colors, from the loudest to the quietest. Every one is at
/// least 4.5:1 on the surfaces it is used on (the contrast test checks the
/// pairs), except where its doc says otherwise.
abstract final class StudioContentColors {
  /// Main text.
  static const ink = ColorToken(
    'ink',
    light: Color(0xFF0A0B14),
    dark: Color(0xFFF4F5FA),
  );

  /// Strong secondary text: card titles.
  static const inkSoft = ColorToken(
    'ink-soft',
    light: Color(0xFF363A4D),
    dark: Color(0xFFD3D6E2),
  );

  /// Secondary text (4.5:1 on cards, raised rows and the canvas).
  static const muted = ColorToken(
    'muted',
    light: Color(0xFF4B4F63),
    dark: Color(0xFFA4A9BE),
  );

  /// Tertiary text: cards and raised rows only (4.5:1 there).
  static const faint = ColorToken(
    'faint',
    light: Color(0xFF5A5E74),
    dark: Color(0xFF8E93AA),
  );

  /// Every content token.
  static const values = [ink, inkSoft, muted, faint];
}
