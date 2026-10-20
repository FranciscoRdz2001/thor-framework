import 'package:thor_ui/thor_ui.dart';

import '../../tokens/color/studio_tone_colors.dart';
import '../../tokens/motion/studio_curves.dart';
import '../../tokens/motion/studio_durations.dart';
import '../../tokens/motion/studio_motion.dart';
import '../../tokens/shape/studio_radii.dart';
import '../../tokens/spacing/studio_spacing.dart';
import '../studio_extra_colors.dart';

/// The look of chips, like Flutter's `ChipThemeData`: gray pills for
/// filters and the "New" label, filled with the primary color when selected,
/// and tinted ones for tones.
///
/// Every field is optional: the widgets resolve each one as the widget's own
/// parameter, then this theme, then a default derived from
/// `Theme.of(context).colorScheme` and `textTheme`, so a `copyWith(primary:)` on
/// the color scheme reaches the component. Install an override next to the
/// others (`ThemeData(extensions: [StudioChipThemeData(radius: 8)])`) and read the effective
/// values with [StudioChipThemeData.of].
class StudioChipThemeData extends ThemeExtension<StudioChipThemeData> {
  /// Creates a chip theme; a null field keeps the default.
  const StudioChipThemeData({
    this.color,
    this.labelColor,
    this.borderColor,
    this.hoverColor,
    this.selectedColor,
    this.selectedLabelColor,
    this.radius,
    this.height,
    this.padding,
    this.badgeHeight,
    this.badgePadding,
    this.info,
    this.ok,
    this.warn,
    this.danger,
    this.duration,
    this.curve,
    this.pressScale,
    this.flutter,
    this.labelStyle,
    this.badgeLabelStyle,
  });

  /// The chip's background.
  final Color? color;

  /// The label.
  final Color? labelColor;

  /// The hairline around it.
  final Color? borderColor;

  /// The background under the pointer.
  final Color? hoverColor;

  /// The background of a selected chip.
  final Color? selectedColor;

  /// The label of a selected chip.
  final Color? selectedLabelColor;

  /// The corner radius (a pill).
  final double? radius;

  /// The chip's height.
  final double? height;

  /// The space at the sides of the label.
  final EdgeInsets? padding;

  /// The height of a badge (the "New" label).
  final double? badgeHeight;

  /// The space at the sides of a badge's label.
  final EdgeInsets? badgePadding;

  /// The information tone.
  final StudioToneColors? info;

  /// The success tone.
  final StudioToneColors? ok;

  /// The warning tone.
  final StudioToneColors? warn;

  /// The error tone.
  final StudioToneColors? danger;

  /// How long a chip takes to change color.
  final Duration? duration;

  /// The easing of that change.
  final Curve? curve;

  /// The scale while pressed (`:active`).
  final double? pressScale;

  /// The "how Flutter does it" tone.
  final StudioToneColors? flutter;

  /// The label of a chip (the theme's `labelLarge`).
  final TextStyle? labelStyle;

  /// The label of a badge (the theme's `labelMedium`).
  final TextStyle? badgeLabelStyle;

  /// The override installed on the nearest theme, or null.
  static StudioChipThemeData? maybeOf(BuildContext context) =>
      Theme.of(context).extension<StudioChipThemeData>();

  /// The effective values of the nearest theme: [override] (a widget's
  /// `theme:` parameter), then the installed theme, then the defaults of the
  /// theme's color scheme and text theme.
  static StudioChipThemeResolved of(
    BuildContext context, [
    StudioChipThemeData? override,
  ]) => resolve(Theme.of(context), override);

  /// The effective values of [theme] (for code with no `BuildContext`).
  static StudioChipThemeResolved resolve(
    ThemeData theme, [
    StudioChipThemeData? override,
  ]) {
    final installed = theme.extension<StudioChipThemeData>();
    final d = _StudioChipThemeDefaults(theme);
    return StudioChipThemeResolved(
      color: override?.color ?? installed?.color ?? d.color,
      labelColor: override?.labelColor ?? installed?.labelColor ?? d.labelColor,
      borderColor:
          override?.borderColor ?? installed?.borderColor ?? d.borderColor,
      hoverColor: override?.hoverColor ?? installed?.hoverColor ?? d.hoverColor,
      selectedColor:
          override?.selectedColor ??
          installed?.selectedColor ??
          d.selectedColor,
      selectedLabelColor:
          override?.selectedLabelColor ??
          installed?.selectedLabelColor ??
          d.selectedLabelColor,
      radius: override?.radius ?? installed?.radius ?? d.radius,
      height: override?.height ?? installed?.height ?? d.height,
      padding: override?.padding ?? installed?.padding ?? d.padding,
      badgeHeight:
          override?.badgeHeight ?? installed?.badgeHeight ?? d.badgeHeight,
      badgePadding:
          override?.badgePadding ?? installed?.badgePadding ?? d.badgePadding,
      info: override?.info ?? installed?.info ?? d.info,
      ok: override?.ok ?? installed?.ok ?? d.ok,
      warn: override?.warn ?? installed?.warn ?? d.warn,
      danger: override?.danger ?? installed?.danger ?? d.danger,
      duration: override?.duration ?? installed?.duration ?? d.duration,
      curve: override?.curve ?? installed?.curve ?? d.curve,
      pressScale: override?.pressScale ?? installed?.pressScale ?? d.pressScale,
      flutter: override?.flutter ?? installed?.flutter ?? d.flutter,
      labelStyle: override?.labelStyle ?? installed?.labelStyle ?? d.labelStyle,
      badgeLabelStyle:
          override?.badgeLabelStyle ??
          installed?.badgeLabelStyle ??
          d.badgeLabelStyle,
    );
  }

  /// A copy with the given fields replaced.
  StudioChipThemeData copyWith({
    Color? color,
    Color? labelColor,
    Color? borderColor,
    Color? hoverColor,
    Color? selectedColor,
    Color? selectedLabelColor,
    double? radius,
    double? height,
    EdgeInsets? padding,
    double? badgeHeight,
    EdgeInsets? badgePadding,
    StudioToneColors? info,
    StudioToneColors? ok,
    StudioToneColors? warn,
    StudioToneColors? danger,
    Duration? duration,
    Curve? curve,
    double? pressScale,
    StudioToneColors? flutter,
    TextStyle? labelStyle,
    TextStyle? badgeLabelStyle,
  }) => StudioChipThemeData(
    color: color ?? this.color,
    labelColor: labelColor ?? this.labelColor,
    borderColor: borderColor ?? this.borderColor,
    hoverColor: hoverColor ?? this.hoverColor,
    selectedColor: selectedColor ?? this.selectedColor,
    selectedLabelColor: selectedLabelColor ?? this.selectedLabelColor,
    radius: radius ?? this.radius,
    height: height ?? this.height,
    padding: padding ?? this.padding,
    badgeHeight: badgeHeight ?? this.badgeHeight,
    badgePadding: badgePadding ?? this.badgePadding,
    info: info ?? this.info,
    ok: ok ?? this.ok,
    warn: warn ?? this.warn,
    danger: danger ?? this.danger,
    duration: duration ?? this.duration,
    curve: curve ?? this.curve,
    pressScale: pressScale ?? this.pressScale,
    flutter: flutter ?? this.flutter,
    labelStyle: labelStyle ?? this.labelStyle,
    badgeLabelStyle: badgeLabelStyle ?? this.badgeLabelStyle,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StudioChipThemeData &&
          other.color == color &&
          other.labelColor == labelColor &&
          other.borderColor == borderColor &&
          other.hoverColor == hoverColor &&
          other.selectedColor == selectedColor &&
          other.selectedLabelColor == selectedLabelColor &&
          other.radius == radius &&
          other.height == height &&
          other.padding == padding &&
          other.badgeHeight == badgeHeight &&
          other.badgePadding == badgePadding &&
          other.info == info &&
          other.ok == ok &&
          other.warn == warn &&
          other.danger == danger &&
          other.duration == duration &&
          other.curve == curve &&
          other.pressScale == pressScale &&
          other.flutter == flutter &&
          other.labelStyle == labelStyle &&
          other.badgeLabelStyle == badgeLabelStyle);

  @override
  int get hashCode => Object.hashAll([
    color,
    labelColor,
    borderColor,
    hoverColor,
    selectedColor,
    selectedLabelColor,
    radius,
    height,
    padding,
    badgeHeight,
    badgePadding,
    info,
    ok,
    warn,
    danger,
    duration,
    curve,
    pressScale,
    flutter,
    labelStyle,
    badgeLabelStyle,
  ]);
}

/// The effective look of a chip: [StudioChipThemeData.of] with every field set. It is a
/// [StudioChipThemeData] too, so it can be handed to a widget's `theme:` parameter.
class StudioChipThemeResolved extends StudioChipThemeData {
  /// Creates the resolved values.
  const StudioChipThemeResolved({
    required Color color,
    required Color labelColor,
    required Color borderColor,
    required Color hoverColor,
    required Color selectedColor,
    required Color selectedLabelColor,
    required double radius,
    required double height,
    required EdgeInsets padding,
    required double badgeHeight,
    required EdgeInsets badgePadding,
    required StudioToneColors info,
    required StudioToneColors ok,
    required StudioToneColors warn,
    required StudioToneColors danger,
    required Duration duration,
    required Curve curve,
    required double pressScale,
    required StudioToneColors flutter,
    required TextStyle labelStyle,
    required TextStyle badgeLabelStyle,
  }) : _color = color,
       _labelColor = labelColor,
       _borderColor = borderColor,
       _hoverColor = hoverColor,
       _selectedColor = selectedColor,
       _selectedLabelColor = selectedLabelColor,
       _radius = radius,
       _height = height,
       _padding = padding,
       _badgeHeight = badgeHeight,
       _badgePadding = badgePadding,
       _info = info,
       _ok = ok,
       _warn = warn,
       _danger = danger,
       _duration = duration,
       _curve = curve,
       _pressScale = pressScale,
       _flutter = flutter,
       _labelStyle = labelStyle,
       _badgeLabelStyle = badgeLabelStyle,
       super(
         color: color,
         labelColor: labelColor,
         borderColor: borderColor,
         hoverColor: hoverColor,
         selectedColor: selectedColor,
         selectedLabelColor: selectedLabelColor,
         radius: radius,
         height: height,
         padding: padding,
         badgeHeight: badgeHeight,
         badgePadding: badgePadding,
         info: info,
         ok: ok,
         warn: warn,
         danger: danger,
         duration: duration,
         curve: curve,
         pressScale: pressScale,
         flutter: flutter,
         labelStyle: labelStyle,
         badgeLabelStyle: badgeLabelStyle,
       );

  final Color _color;

  @override
  Color get color => _color;

  final Color _labelColor;

  @override
  Color get labelColor => _labelColor;

  final Color _borderColor;

  @override
  Color get borderColor => _borderColor;

  final Color _hoverColor;

  @override
  Color get hoverColor => _hoverColor;

  final Color _selectedColor;

  @override
  Color get selectedColor => _selectedColor;

  final Color _selectedLabelColor;

  @override
  Color get selectedLabelColor => _selectedLabelColor;

  final double _radius;

  @override
  double get radius => _radius;

  final double _height;

  @override
  double get height => _height;

  final EdgeInsets _padding;

  @override
  EdgeInsets get padding => _padding;

  final double _badgeHeight;

  @override
  double get badgeHeight => _badgeHeight;

  final EdgeInsets _badgePadding;

  @override
  EdgeInsets get badgePadding => _badgePadding;

  final StudioToneColors _info;

  @override
  StudioToneColors get info => _info;

  final StudioToneColors _ok;

  @override
  StudioToneColors get ok => _ok;

  final StudioToneColors _warn;

  @override
  StudioToneColors get warn => _warn;

  final StudioToneColors _danger;

  @override
  StudioToneColors get danger => _danger;

  final Duration _duration;

  @override
  Duration get duration => _duration;

  final Curve _curve;

  @override
  Curve get curve => _curve;

  final double _pressScale;

  @override
  double get pressScale => _pressScale;

  final StudioToneColors _flutter;

  @override
  StudioToneColors get flutter => _flutter;

  final TextStyle _labelStyle;

  @override
  TextStyle get labelStyle => _labelStyle;

  final TextStyle _badgeLabelStyle;

  @override
  TextStyle get badgeLabelStyle => _badgeLabelStyle;
}

/// The defaults of the chip theme: every value from the theme's color
/// scheme, text theme and the studio's tokens (Flutter's `_Defaults(context)`).
class _StudioChipThemeDefaults {
  _StudioChipThemeDefaults(ThemeData theme)
    : s = theme.colorScheme,
      t = theme.textTheme,
      x = theme.extension<StudioExtraColors>() ?? StudioExtraColors.standard;

  final ColorScheme s;
  final TextTheme t;
  final StudioExtraColors x;

  Color get color => s.surfaceContainerHighest ?? s.surfaceContainer;
  Color get labelColor => x.onSurfaceSoft;
  Color get borderColor => s.outlineVariant;
  Color get hoverColor => x.hover;
  Color get selectedColor => s.primary;
  Color get selectedLabelColor => s.onPrimary;
  double get radius => StudioRadii.control;
  double get height => 32;
  EdgeInsets get padding =>
      const EdgeInsets.symmetric(horizontal: StudioSpacing.sm);
  double get badgeHeight => 20;
  EdgeInsets get badgePadding =>
      const EdgeInsets.symmetric(horizontal: StudioSpacing.xs);
  StudioToneColors get info => x.infoTone;
  StudioToneColors get ok => x.okTone;
  StudioToneColors get warn => x.warnTone;
  StudioToneColors get danger => x.dangerTone;
  Duration get duration => StudioDurations.fast;
  Curve get curve => StudioCurves.enter;
  double get pressScale => StudioMotion.pressScale;
  StudioToneColors get flutter => x.flutterTone;
  TextStyle get labelStyle => t.labelLarge;
  TextStyle get badgeLabelStyle => t.labelMedium;
}
