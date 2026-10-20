import 'package:thor_ui/thor_ui.dart';

/// The three weights of the hierarchy: it is made of size and these, not of
/// bold everywhere (Inter is variable, so 500 and 600 are real weights).
abstract final class StudioFontWeights {
  /// Reading text.
  static const regular = FontWeight.w400;

  /// Controls, labels and navigation.
  static const medium = FontWeight.w500;

  /// Titles.
  static const semibold = FontWeight.w600;
}
