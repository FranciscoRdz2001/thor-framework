import 'package:thor_ui/thor_ui.dart';

import '../tokens/typography/studio_font_weights.dart';
import '../tokens/typography/studio_letter_spacing.dart';
import '../tokens/typography/studio_line_heights.dart';
import '../tokens/typography/studio_type_scale.dart';

/// The studio's full Material 3 `TextTheme`: display, headline, title, body
/// and label in three sizes each, from the type tokens.
///
/// The hierarchy is size and weight (400, 500, 600), never color alone. The
/// styles carry no color: they inherit the text color of the surface they
/// sit on.
TextTheme studioTextTheme() => TextTheme(
  displayLarge: const TextStyle(
    fontSize: StudioTypeScale.display,
    height: StudioLineHeights.tight,
    fontWeight: StudioFontWeights.semibold,
    letterSpacing: StudioLetterSpacing.tight,
  ),
  displayMedium: const TextStyle(
    fontSize: StudioTypeScale.displayMedium,
    height: StudioLineHeights.tight,
    fontWeight: StudioFontWeights.semibold,
    letterSpacing: StudioLetterSpacing.tight,
  ),
  displaySmall: const TextStyle(
    fontSize: StudioTypeScale.displaySmall,
    height: StudioLineHeights.tight,
    fontWeight: StudioFontWeights.semibold,
    letterSpacing: StudioLetterSpacing.snug,
  ),
  headlineLarge: const TextStyle(
    fontSize: StudioTypeScale.headline,
    height: StudioLineHeights.tight,
    fontWeight: StudioFontWeights.semibold,
    letterSpacing: StudioLetterSpacing.tight,
  ),
  headlineMedium: const TextStyle(
    fontSize: StudioTypeScale.title,
    height: StudioLineHeights.snug,
    fontWeight: StudioFontWeights.semibold,
    letterSpacing: StudioLetterSpacing.snug,
  ),
  headlineSmall: const TextStyle(
    fontSize: StudioTypeScale.headlineSmall,
    height: StudioLineHeights.snug,
    fontWeight: StudioFontWeights.semibold,
    letterSpacing: StudioLetterSpacing.snug,
  ),
  titleLarge: const TextStyle(
    fontSize: StudioTypeScale.subtitle,
    height: StudioLineHeights.snug,
    fontWeight: StudioFontWeights.semibold,
    letterSpacing: StudioLetterSpacing.snug,
  ),
  titleMedium: const TextStyle(
    fontSize: StudioTypeScale.ui,
    height: StudioLineHeights.ui,
    fontWeight: StudioFontWeights.semibold,
  ),
  titleSmall: const TextStyle(
    fontSize: StudioTypeScale.caption,
    height: StudioLineHeights.ui,
    fontWeight: StudioFontWeights.semibold,
  ),
  bodyLarge: const TextStyle(
    fontSize: StudioTypeScale.body,
    height: StudioLineHeights.reading,
    fontWeight: StudioFontWeights.regular,
  ),
  bodyMedium: const TextStyle(
    fontSize: StudioTypeScale.ui,
    height: StudioLineHeights.ui,
    fontWeight: StudioFontWeights.regular,
  ),
  bodySmall: const TextStyle(
    fontSize: StudioTypeScale.caption,
    height: StudioLineHeights.ui,
    fontWeight: StudioFontWeights.regular,
  ),
  labelLarge: const TextStyle(
    fontSize: StudioTypeScale.ui,
    height: StudioLineHeights.ui,
    fontWeight: StudioFontWeights.medium,
  ),
  labelMedium: const TextStyle(
    fontSize: StudioTypeScale.caption,
    height: StudioLineHeights.ui,
    fontWeight: StudioFontWeights.medium,
  ),
  labelSmall: const TextStyle(
    fontSize: StudioTypeScale.micro,
    height: StudioLineHeights.ui,
    fontWeight: StudioFontWeights.medium,
  ),
);
