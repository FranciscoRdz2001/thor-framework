import 'package:thor_ui/thor_ui.dart';

import '../tokens/typography/studio_font_families.dart';
import '../tokens/typography/studio_font_weights.dart';
import '../tokens/typography/studio_type_scale.dart';

/// The text styles Material's `TextTheme` has no role for: the monospace
/// ones, as a `ThemeExtension`.
///
/// ```dart
/// Text('final a = 1;', style: StudioExtraTextStyles.of(context).codeMedium)
/// ```
///
/// Every other style is a role of `Theme.of(context).textTheme` (`bodyMedium`,
/// `labelLarge`…). The styles carry no color: they inherit the text color of
/// the surface they sit on.
class StudioExtraTextStyles extends ThemeExtension<StudioExtraTextStyles> {
  /// Creates the extras; every style defaults to the studio's.
  const StudioExtraTextStyles({
    this.codeMedium = const TextStyle(
      fontFamily: StudioFontFamilies.mono,
      fontSize: StudioTypeScale.code,
      height: 1.6,
      fontWeight: StudioFontWeights.regular,
    ),
    this.codeSmall = const TextStyle(
      fontFamily: StudioFontFamilies.mono,
      fontSize: StudioTypeScale.caption,
      height: 1.5,
      fontWeight: StudioFontWeights.regular,
    ),
  });

  /// The extras with every default.
  static const standard = StudioExtraTextStyles();

  /// Code in a block (13, mono).
  final TextStyle codeMedium;

  /// Inline code and technical data (12, mono).
  final TextStyle codeSmall;

  /// The extras of the nearest theme, or [standard].
  static StudioExtraTextStyles of(BuildContext context) =>
      maybeOf(context) ?? standard;

  /// The extras of the nearest theme, or null when it has none.
  static StudioExtraTextStyles? maybeOf(BuildContext context) =>
      Theme.of(context).extension<StudioExtraTextStyles>();

  /// A copy with the given styles replaced.
  StudioExtraTextStyles copyWith({
    TextStyle? codeMedium,
    TextStyle? codeSmall,
  }) => StudioExtraTextStyles(
    codeMedium: codeMedium ?? this.codeMedium,
    codeSmall: codeSmall ?? this.codeSmall,
  );

  @override
  bool operator ==(Object other) =>
      other is StudioExtraTextStyles &&
      other.codeMedium == codeMedium &&
      other.codeSmall == codeSmall;

  @override
  int get hashCode => Object.hash(codeMedium, codeSmall);
}
