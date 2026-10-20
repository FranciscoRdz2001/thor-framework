import 'package:thor_ui/thor_ui.dart';

import '../../tokens/color/studio_status_colors.dart';
import '../../tokens/motion/studio_curves.dart';
import '../../tokens/motion/studio_durations.dart';
import '../../tokens/motion/studio_motion.dart';
import '../../tokens/shape/studio_radii.dart';
import '../../tokens/spacing/studio_spacing.dart';
import '../studio_extra_colors.dart';
import '../studio_extra_text_styles.dart';

/// The look of a code block: a raised surface, a hairline, mono type, a
/// header strip for the file name and the marks of its lines. Syntax colors
/// are `StudioSyntaxColors`.
///
/// Every field is optional: the widgets resolve each one as the widget's own
/// parameter, then this theme, then a default derived from
/// `Theme.of(context).colorScheme` and `textTheme`, so a `copyWith(primary:)` on
/// the color scheme reaches the component. Install an override next to the
/// others (`ThemeData(extensions: [StudioCodeThemeData(radius: 8)])`) and read the effective
/// values with [StudioCodeThemeData.of].
class StudioCodeThemeData extends ThemeExtension<StudioCodeThemeData> {
  /// Creates a code theme; a null field keeps the default.
  const StudioCodeThemeData({
    this.color,
    this.borderColor,
    this.headerTextColor,
    this.highlightColor,
    this.highlightBarColor,
    this.changedColor,
    this.changedBarColor,
    this.radius,
    this.padding,
    this.textStyle,
    this.pressScale,
    this.duration,
    this.curve,
  });

  /// The block's surface.
  final Color? color;

  /// The hairline around it.
  final Color? borderColor;

  /// The file name in the header strip.
  final Color? headerTextColor;

  /// The background of a highlighted line (`StudioCodeBlock(highlight:)`).
  final Color? highlightColor;

  /// The bar at the start of a highlighted line.
  final Color? highlightBarColor;

  /// The background of a changed line (`StudioCodeBlock(changed:)`, the lines a diff adds).
  final Color? changedColor;

  /// The bar at the start of a changed line.
  final Color? changedBarColor;

  /// The corner radius.
  final double? radius;

  /// The space between the border and the code.
  final EdgeInsets? padding;

  /// The code's text style (mono).
  final TextStyle? textStyle;

  /// The scale of the copy button while pressed.
  final double? pressScale;

  /// How long the copy button's press takes.
  final Duration? duration;

  /// The easing of the copy button's press.
  final Curve? curve;

  /// The override installed on the nearest theme, or null.
  static StudioCodeThemeData? maybeOf(BuildContext context) =>
      Theme.of(context).extension<StudioCodeThemeData>();

  /// The effective values of the nearest theme: [override] (a widget's
  /// `theme:` parameter), then the installed theme, then the defaults of the
  /// theme's color scheme and text theme.
  static StudioCodeThemeResolved of(
    BuildContext context, [
    StudioCodeThemeData? override,
  ]) => resolve(Theme.of(context), override);

  /// The effective values of [theme] (for code with no `BuildContext`).
  static StudioCodeThemeResolved resolve(
    ThemeData theme, [
    StudioCodeThemeData? override,
  ]) {
    final installed = theme.extension<StudioCodeThemeData>();
    final d = _StudioCodeThemeDefaults(theme);
    return StudioCodeThemeResolved(
      color: override?.color ?? installed?.color ?? d.color,
      borderColor:
          override?.borderColor ?? installed?.borderColor ?? d.borderColor,
      headerTextColor:
          override?.headerTextColor ??
          installed?.headerTextColor ??
          d.headerTextColor,
      highlightColor:
          override?.highlightColor ??
          installed?.highlightColor ??
          d.highlightColor,
      highlightBarColor:
          override?.highlightBarColor ??
          installed?.highlightBarColor ??
          d.highlightBarColor,
      changedColor:
          override?.changedColor ?? installed?.changedColor ?? d.changedColor,
      changedBarColor:
          override?.changedBarColor ??
          installed?.changedBarColor ??
          d.changedBarColor,
      radius: override?.radius ?? installed?.radius ?? d.radius,
      padding: override?.padding ?? installed?.padding ?? d.padding,
      textStyle: override?.textStyle ?? installed?.textStyle ?? d.textStyle,
      pressScale: override?.pressScale ?? installed?.pressScale ?? d.pressScale,
      duration: override?.duration ?? installed?.duration ?? d.duration,
      curve: override?.curve ?? installed?.curve ?? d.curve,
    );
  }

  /// A copy with the given fields replaced.
  StudioCodeThemeData copyWith({
    Color? color,
    Color? borderColor,
    Color? headerTextColor,
    Color? highlightColor,
    Color? highlightBarColor,
    Color? changedColor,
    Color? changedBarColor,
    double? radius,
    EdgeInsets? padding,
    TextStyle? textStyle,
    double? pressScale,
    Duration? duration,
    Curve? curve,
  }) => StudioCodeThemeData(
    color: color ?? this.color,
    borderColor: borderColor ?? this.borderColor,
    headerTextColor: headerTextColor ?? this.headerTextColor,
    highlightColor: highlightColor ?? this.highlightColor,
    highlightBarColor: highlightBarColor ?? this.highlightBarColor,
    changedColor: changedColor ?? this.changedColor,
    changedBarColor: changedBarColor ?? this.changedBarColor,
    radius: radius ?? this.radius,
    padding: padding ?? this.padding,
    textStyle: textStyle ?? this.textStyle,
    pressScale: pressScale ?? this.pressScale,
    duration: duration ?? this.duration,
    curve: curve ?? this.curve,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StudioCodeThemeData &&
          other.color == color &&
          other.borderColor == borderColor &&
          other.headerTextColor == headerTextColor &&
          other.highlightColor == highlightColor &&
          other.highlightBarColor == highlightBarColor &&
          other.changedColor == changedColor &&
          other.changedBarColor == changedBarColor &&
          other.radius == radius &&
          other.padding == padding &&
          other.textStyle == textStyle &&
          other.pressScale == pressScale &&
          other.duration == duration &&
          other.curve == curve);

  @override
  int get hashCode => Object.hashAll([
    color,
    borderColor,
    headerTextColor,
    highlightColor,
    highlightBarColor,
    changedColor,
    changedBarColor,
    radius,
    padding,
    textStyle,
    pressScale,
    duration,
    curve,
  ]);
}

/// The effective look of a code: [StudioCodeThemeData.of] with every field set. It is a
/// [StudioCodeThemeData] too, so it can be handed to a widget's `theme:` parameter.
class StudioCodeThemeResolved extends StudioCodeThemeData {
  /// Creates the resolved values.
  const StudioCodeThemeResolved({
    required Color color,
    required Color borderColor,
    required Color headerTextColor,
    required Color highlightColor,
    required Color highlightBarColor,
    required Color changedColor,
    required Color changedBarColor,
    required double radius,
    required EdgeInsets padding,
    required TextStyle textStyle,
    required double pressScale,
    required Duration duration,
    required Curve curve,
  }) : _color = color,
       _borderColor = borderColor,
       _headerTextColor = headerTextColor,
       _highlightColor = highlightColor,
       _highlightBarColor = highlightBarColor,
       _changedColor = changedColor,
       _changedBarColor = changedBarColor,
       _radius = radius,
       _padding = padding,
       _textStyle = textStyle,
       _pressScale = pressScale,
       _duration = duration,
       _curve = curve,
       super(
         color: color,
         borderColor: borderColor,
         headerTextColor: headerTextColor,
         highlightColor: highlightColor,
         highlightBarColor: highlightBarColor,
         changedColor: changedColor,
         changedBarColor: changedBarColor,
         radius: radius,
         padding: padding,
         textStyle: textStyle,
         pressScale: pressScale,
         duration: duration,
         curve: curve,
       );

  final Color _color;

  @override
  Color get color => _color;

  final Color _borderColor;

  @override
  Color get borderColor => _borderColor;

  final Color _headerTextColor;

  @override
  Color get headerTextColor => _headerTextColor;

  final Color _highlightColor;

  @override
  Color get highlightColor => _highlightColor;

  final Color _highlightBarColor;

  @override
  Color get highlightBarColor => _highlightBarColor;

  final Color _changedColor;

  @override
  Color get changedColor => _changedColor;

  final Color _changedBarColor;

  @override
  Color get changedBarColor => _changedBarColor;

  final double _radius;

  @override
  double get radius => _radius;

  final EdgeInsets _padding;

  @override
  EdgeInsets get padding => _padding;

  final TextStyle _textStyle;

  @override
  TextStyle get textStyle => _textStyle;

  final double _pressScale;

  @override
  double get pressScale => _pressScale;

  final Duration _duration;

  @override
  Duration get duration => _duration;

  final Curve _curve;

  @override
  Curve get curve => _curve;
}

/// The defaults of the code theme: every value from the theme's color
/// scheme, text theme and the studio's tokens (Flutter's `_Defaults(context)`).
class _StudioCodeThemeDefaults {
  _StudioCodeThemeDefaults(ThemeData theme)
    : s = theme.colorScheme,
      x = theme.extension<StudioExtraColors>() ?? StudioExtraColors.standard,
      c =
          theme.extension<StudioExtraTextStyles>() ??
          StudioExtraTextStyles.standard;

  final ColorScheme s;
  final StudioExtraColors x;
  final StudioExtraTextStyles c;

  Color get color => s.surfaceContainerLowest ?? s.surfaceContainer;
  Color get borderColor => s.outlineVariant;
  Color get headerTextColor => s.onSurfaceVariant ?? s.onSurface;
  Color get highlightColor => x.accentWash;
  Color get highlightBarColor => s.accent;
  Color get changedColor => StudioStatusColors.okBg;
  Color get changedBarColor => x.okTone.foreground;
  double get radius => StudioRadii.inner;
  EdgeInsets get padding => const EdgeInsets.symmetric(
    horizontal: StudioSpacing.md,
    vertical: StudioSpacing.sm,
  );
  TextStyle get textStyle => c.codeMedium;
  double get pressScale => StudioMotion.pressScale;
  Duration get duration => StudioDurations.base;
  Curve get curve => StudioCurves.enter;
}
