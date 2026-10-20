import 'package:thor_ui/thor_ui.dart';

import '../tokens/color/studio_accent_colors.dart';
import '../tokens/color/studio_action_colors.dart';
import '../tokens/color/studio_border_colors.dart';
import '../tokens/color/studio_content_colors.dart';
import '../tokens/color/studio_surface_colors.dart';
import '../tokens/color/studio_tone.dart';
import '../tokens/color/studio_tone_colors.dart';

/// The studio's colors that Material's `ColorScheme` has no role for, as a
/// `ThemeExtension` like the ones a Flutter app writes for its own palette:
/// the neutral hover, the two quieter text tones, the stronger hairline, the
/// primary pill under the pointer, the accent wash and the colors of each
/// [StudioTone].
///
/// ```dart
/// final extra = StudioExtraColors.of(context);
/// ColoredBox(color: extra.hover, child: Text('x', style: TextStyle(color: extra.onSurfaceFaint)))
/// ```
///
/// Everything else is a role of `Theme.of(context).colorScheme` (`surface`,
/// `onSurfaceVariant`, `outlineVariant`…, plus the accent as
/// [StudioAccentRoles]). Each field is a `ColorToken` that carries its light
/// and its dark value, so the dark theme swaps them in the browser.
///
/// `// web:` Flutter's `ThemeExtension` interpolates two themes with `lerp`;
/// here a theme change is CSS (`light-dark()`), so `lerp` is the base class's
/// step.
class StudioExtraColors extends ThemeExtension<StudioExtraColors> {
  /// Creates the extras; every color defaults to the studio's token.
  const StudioExtraColors({
    this.hover = StudioSurfaceColors.hover,
    this.onSurfaceSoft = StudioContentColors.inkSoft,
    this.onSurfaceFaint = StudioContentColors.faint,
    this.lineStrong = StudioBorderColors.lineStrong,
    this.primaryHover = StudioActionColors.actionHover,
    this.accentWash = StudioAccentColors.accentWash,
    this.infoTone = StudioToneColors.info,
    this.okTone = StudioToneColors.ok,
    this.warnTone = StudioToneColors.warn,
    this.dangerTone = StudioToneColors.danger,
    this.flutterTone = StudioToneColors.flutter,
    this.neutralTone = StudioToneColors.neutral,
  });

  /// The extras with every default.
  static const standard = StudioExtraColors();

  /// The neutral hover of a row or a pill (between `surfaceContainerHighest`
  /// and the next step).
  final Color hover;

  /// Strong secondary text: card titles (between `onSurface` and
  /// `onSurfaceVariant`).
  final Color onSurfaceSoft;

  /// Tertiary text: cards and raised rows only (4.5:1 there).
  final Color onSurfaceFaint;

  /// A border a notch stronger than `outlineVariant`: the hover of a card or
  /// a field, a dashed placeholder.
  final Color lineStrong;

  /// The primary pill while the pointer is over it.
  final Color primaryHover;

  /// The lightest accent wash: a selected row's background.
  final Color accentWash;

  /// The information tone.
  final StudioToneColors infoTone;

  /// The success tone (its `foreground` is the "ok" green).
  final StudioToneColors okTone;

  /// The warning tone.
  final StudioToneColors warnTone;

  /// The error tone (its `foreground` is `colorScheme.error`).
  final StudioToneColors dangerTone;

  /// The "how Flutter does it" tone.
  final StudioToneColors flutterTone;

  /// The neutral gray: a badge or chip with no status.
  final StudioToneColors neutralTone;

  /// The colors of [tone].
  StudioToneColors tone(StudioTone tone) => switch (tone) {
    StudioTone.info => infoTone,
    StudioTone.ok => okTone,
    StudioTone.warn => warnTone,
    StudioTone.danger => dangerTone,
    StudioTone.flutter => flutterTone,
    StudioTone.neutral => neutralTone,
  };

  /// The extras of the nearest theme, or [standard].
  static StudioExtraColors of(BuildContext context) =>
      maybeOf(context) ?? standard;

  /// The extras of the nearest theme, or null when it has none.
  static StudioExtraColors? maybeOf(BuildContext context) =>
      Theme.of(context).extension<StudioExtraColors>();

  /// A copy with the given colors replaced.
  StudioExtraColors copyWith({
    Color? hover,
    Color? onSurfaceSoft,
    Color? onSurfaceFaint,
    Color? lineStrong,
    Color? primaryHover,
    Color? accentWash,
    StudioToneColors? infoTone,
    StudioToneColors? okTone,
    StudioToneColors? warnTone,
    StudioToneColors? dangerTone,
    StudioToneColors? flutterTone,
    StudioToneColors? neutralTone,
  }) => StudioExtraColors(
    hover: hover ?? this.hover,
    onSurfaceSoft: onSurfaceSoft ?? this.onSurfaceSoft,
    onSurfaceFaint: onSurfaceFaint ?? this.onSurfaceFaint,
    lineStrong: lineStrong ?? this.lineStrong,
    primaryHover: primaryHover ?? this.primaryHover,
    accentWash: accentWash ?? this.accentWash,
    infoTone: infoTone ?? this.infoTone,
    okTone: okTone ?? this.okTone,
    warnTone: warnTone ?? this.warnTone,
    dangerTone: dangerTone ?? this.dangerTone,
    flutterTone: flutterTone ?? this.flutterTone,
    neutralTone: neutralTone ?? this.neutralTone,
  );

  @override
  bool operator ==(Object other) =>
      other is StudioExtraColors &&
      other.hover == hover &&
      other.onSurfaceSoft == onSurfaceSoft &&
      other.onSurfaceFaint == onSurfaceFaint &&
      other.lineStrong == lineStrong &&
      other.primaryHover == primaryHover &&
      other.accentWash == accentWash &&
      other.infoTone == infoTone &&
      other.okTone == okTone &&
      other.warnTone == warnTone &&
      other.dangerTone == dangerTone &&
      other.flutterTone == flutterTone &&
      other.neutralTone == neutralTone;

  @override
  int get hashCode => Object.hash(
    hover,
    onSurfaceSoft,
    onSurfaceFaint,
    lineStrong,
    primaryHover,
    accentWash,
    infoTone,
    okTone,
    warnTone,
    dangerTone,
    flutterTone,
    neutralTone,
  );
}

/// The studio's accent (a blue for focus rings, the current item, links and
/// selected text) as roles of Material's `ColorScheme`: the accent is its
/// `tertiary` color, a contrasting hue next to the `primary` pill.
///
/// ```dart
/// final scheme = Theme.of(context).colorScheme;
/// Icon(StudioIcons.info, color: scheme.accent)
/// ```
///
/// A scheme that sets no `tertiary` falls back to `primary` (and its
/// container), so a plain Material scheme still gives a color.
extension StudioAccentRoles on ColorScheme {
  /// Focus, the current item, links (`tertiary`).
  Color get accent => tertiary ?? primary;

  /// Content on [accent] (`onTertiary`).
  Color get onAccent => onTertiary ?? onPrimary;

  /// The accent's tint: the selected rail item, the active tab
  /// (`tertiaryContainer`).
  Color get accentContainer =>
      tertiaryContainer ?? secondaryContainer ?? primaryContainer ?? primary;

  /// Content on [accentContainer] (`onTertiaryContainer`).
  Color get onAccentContainer =>
      onTertiaryContainer ??
      onSecondaryContainer ??
      onPrimaryContainer ??
      onPrimary;
}
