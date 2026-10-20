import 'package:thor_ui/thor_ui.dart';

/// States: info, ok, warning, danger and flutter, each with a foreground (text and
/// icon, 4.5:1 on its own background and on the cards), a tinted background
/// and a border. `info` borrows the accent family.
abstract final class StudioStatusColors {
  /// Success.
  static const ok = ColorToken(
    'ok',
    light: Color(0xFF15803D),
    dark: Color(0xFF4ADE80),
  );

  /// Warnings.
  static const warn = ColorToken(
    'warn',
    light: Color(0xFFB45309),
    dark: Color(0xFFFBBF24),
  );

  /// Errors and the danger zone.
  static const danger = ColorToken(
    'danger',
    light: Color(0xFFD32020),
    dark: Color(0xFFF87171),
  );

  /// The info tone's background.
  static const infoBg = ColorToken(
    'info-bg',
    light: Color(0xFFF3F4FF),
    dark: Color(0xFF14163A),
  );

  /// The info tone's border.
  static const infoLine = ColorToken(
    'info-line',
    light: Color(0xFFC7CBF7),
    dark: Color(0xFF3A3F8F),
  );

  /// The ok tone's background.
  static const okBg = ColorToken(
    'ok-bg',
    light: Color(0xFFF0FDF4),
    dark: Color(0xFF0F2418),
  );

  /// The ok tone's border.
  static const okLine = ColorToken(
    'ok-line',
    light: Color(0xFFBBF7D0),
    dark: Color(0xFF1F5A34),
  );

  /// The warn tone's background.
  static const warnBg = ColorToken(
    'warn-bg',
    light: Color(0xFFFFFBEB),
    dark: Color(0xFF241C0B),
  );

  /// The warn tone's border.
  static const warnLine = ColorToken(
    'warn-line',
    light: Color(0xFFFDE68A),
    dark: Color(0xFF6B5314),
  );

  /// The danger tone's background.
  static const dangerBg = ColorToken(
    'danger-bg',
    light: Color(0xFFFEF2F2),
    dark: Color(0xFF2A1316),
  );

  /// The danger tone's border.
  static const dangerLine = ColorToken(
    'danger-line',
    light: Color(0xFFFECACA),
    dark: Color(0xFF7A2A2E),
  );

  /// The Flutter tone's foreground: a teal for "in Flutter you would..."
  /// notes, apart from the accent blue and the success green.
  static const flutter = ColorToken(
    'flutter',
    light: Color(0xFF0F766E),
    dark: Color(0xFF2DD4BF),
  );

  /// The Flutter tone's background.
  static const flutterBg = ColorToken(
    'flutter-bg',
    light: Color(0xFFF0FDFA),
    dark: Color(0xFF0A2321),
  );

  /// The Flutter tone's border.
  static const flutterLine = ColorToken(
    'flutter-line',
    light: Color(0xFF99F6E4),
    dark: Color(0xFF14534D),
  );

  /// Every status token.
  static const values = [
    ok,
    warn,
    danger,
    infoBg,
    infoLine,
    okBg,
    okLine,
    warnBg,
    warnLine,
    dangerBg,
    dangerLine,
    flutter,
    flutterBg,
    flutterLine,
  ];
}
