import 'package:thor_ui/thor_ui.dart';

/// Hairlines. Borders carry the structure instead of shadows: one pixel,
/// barely there, a notch stronger on hover.
abstract final class StudioBorderColors {
  /// Borders and separators.
  static const line = ColorToken(
    'line',
    light: Color(0xFFE3E5EE),
    dark: Color(0xFF242838),
  );

  /// A stronger border: the hover of a field, a dashed placeholder.
  static const lineStrong = ColorToken(
    'line-strong',
    light: Color(0xFFCBCFDC),
    dark: Color(0xFF363B52),
  );

  /// The border of a form control (an input, a select): the one hairline
  /// that must be seen to find the control, so it keeps 3:1 against the
  /// page, the canvas and the raised surfaces in both themes (WCAG 1.4.11).
  static const field = ColorToken(
    'field-line',
    light: Color(0xFF7D8297),
    dark: Color(0xFF787E98),
  );

  /// Every border token.
  static const values = [line, lineStrong, field];
}
