import 'package:thor_ui/thor_ui.dart';

/// Code highlighting colors, saturated around the indigo accent (violet
/// keywords, emerald strings, sky numbers, orange or amber types), 4.5:1 on
/// the code's canvas, the cards, the raised rows and a highlighted line in
/// both themes.
abstract final class StudioSyntaxColors {
  /// Keywords (`class`, `final`).
  static const keyword = ColorToken(
    'code-keyword',
    light: Color(0xFF7C3AED),
    dark: Color(0xFFC4B5FD),
  );

  /// String literals.
  static const string = ColorToken(
    'code-string',
    light: Color(0xFF047857),
    dark: Color(0xFF6EE7B7),
  );

  /// Numbers.
  static const number = ColorToken(
    'code-number',
    light: Color(0xFF0369A1),
    dark: Color(0xFF7DD3FC),
  );

  /// Types (capitalized names).
  static const type = ColorToken(
    'code-type',
    light: Color(0xFFC2410C),
    dark: Color(0xFFFCD34D),
  );

  /// Comments.
  static const comment = ColorToken(
    'code-comment',
    light: Color(0xFF5A5E74),
    dark: Color(0xFF8E93AA),
  );

  /// Every syntax token.
  static const values = [keyword, string, number, type, comment];
}
