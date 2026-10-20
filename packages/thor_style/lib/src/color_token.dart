import 'color.dart';

/// A color of the app's theme, typed: it IS the theme variable a widget
/// uses (`var(--t-<name>)`, `const` like any [Color]), and it carries its
/// value in the light and in the dark theme. The name and both values are
/// written once:
///
/// ```dart
/// abstract final class AppColors {
///   static const band = ColorToken('band',
///       light: Color(0xFFF7F6F2), dark: Color(0xFF22252A));
///   static const values = [band];
/// }
///
/// ThemeData(tokens: AppColors.values)                  // light
/// ThemeData(colorScheme: ColorScheme.dark(), tokens: AppColors.values)
/// Container(color: AppColors.band)                     // follows the theme
/// ```
///
/// `// web:` the counterpart of a Flutter `ThemeExtension` holding colors:
/// a CSS variable follows the light/dark switch, a Dart value could not.
class ColorToken extends Color {
  /// The token `--t-<name>`, with its [light] and [dark] values.
  const ColorToken(this.name, {required this.light, required this.dark})
    : super.token(name);

  /// Its name in the theme (`band` → `--t-band`, `tw('bg-band')`).
  final String name;

  /// Its value in a light theme.
  final Color light;

  /// Its value in a dark theme.
  final Color dark;
}
