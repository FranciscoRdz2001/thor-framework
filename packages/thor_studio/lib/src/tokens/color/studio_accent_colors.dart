import 'package:thor_ui/thor_ui.dart';

/// The brand accent, an electric indigo: the primary pill, focus rings, the
/// current item, links, selected text and the tinted squares behind section
/// icons. It is at least 3:1 on every surface in both themes (the ring is a
/// non-text control) and 4.5:1 where it paints text (on its tint too).
abstract final class StudioAccentColors {
  /// The primary pill, focus, the current item, links.
  static const accent = ColorToken(
    'accent',
    light: Color(0xFF4F46E5),
    dark: Color(0xFF818CF8),
  );

  /// Text on [accent].
  static const accentInk = ColorToken(
    'accent-ink',
    light: Color(0xFFFFFFFF),
    dark: Color(0xFF0B0D17),
  );

  /// The accent's tint: the current sidebar item and top bar area, the
  /// square behind a section icon.
  static const accentTint = ColorToken(
    'accent-tint',
    light: Color(0xFFE8EAFF),
    dark: Color(0xFF1E1B4B),
  );

  /// The lightest accent wash: a selected row's background.
  static const accentWash = ColorToken(
    'accent-wash',
    light: Color(0xFFF5F6FF),
    dark: Color(0xFF151732),
  );

  /// The background of selected text.
  static const selection = ColorToken(
    'selection',
    light: Color(0xFFC7D2FE),
    dark: Color(0xFF3730A3),
  );

  /// The accent's companion violet, only for soft brand light (a hero's
  /// glow, at low opacity next to [accent]): never text or a control.
  static const accentGlow = ColorToken(
    'accent-glow',
    light: Color(0xFF8B5CF6),
    dark: Color(0xFFA78BFA),
  );

  /// Every accent token.
  static const values = [
    accent,
    accentInk,
    accentTint,
    accentWash,
    selection,
    accentGlow,
  ];
}
