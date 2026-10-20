import 'package:thor_ui/thor_ui.dart';

import '../../tokens/motion/studio_curves.dart';
import '../../tokens/motion/studio_durations.dart';
import '../../tokens/motion/studio_motion.dart';
import '../../tokens/shape/studio_radii.dart';
import '../../tokens/spacing/studio_spacing.dart';
import '../studio_extra_colors.dart';

/// The look of buttons, like Flutter's `FilledButtonThemeData` plus the
/// tonal and text variants in one: a filled pill (white on dark, ink on
/// light), a gray tonal pill and a plain text one. Every button squeezes to
/// [pressScale] when pressed.
///
/// Every field is optional: the widgets resolve each one as the widget's own
/// parameter, then this theme, then a default derived from
/// `Theme.of(context).colorScheme` and `textTheme`, so a `copyWith(primary:)` on
/// the color scheme reaches the component. Install an override next to the
/// others (`ThemeData(extensions: [StudioButtonThemeData(radius: 8)])`) and read the effective
/// values with [StudioButtonThemeData.of].
class StudioButtonThemeData extends ThemeExtension<StudioButtonThemeData> {
  /// Creates a button theme; a null field keeps the default.
  const StudioButtonThemeData({
    this.filledColor,
    this.filledHoverColor,
    this.onFilledColor,
    this.tonalColor,
    this.tonalHoverColor,
    this.onTonalColor,
    this.outlineColor,
    this.textColor,
    this.radius,
    this.height,
    this.smallHeight,
    this.padding,
    this.smallPadding,
    this.pressScale,
    this.duration,
    this.curve,
    this.textStyle,
    this.iconSize,
  });

  /// The filled (primary) pill.
  final Color? filledColor;

  /// The filled pill under the pointer.
  final Color? filledHoverColor;

  /// The label of the filled pill.
  final Color? onFilledColor;

  /// The tonal (secondary) pill.
  final Color? tonalColor;

  /// The tonal pill under the pointer.
  final Color? tonalHoverColor;

  /// The label of the tonal pill.
  final Color? onTonalColor;

  /// The border of an outlined button.
  final Color? outlineColor;

  /// The label of a text button.
  final Color? textColor;

  /// The corner radius (a pill).
  final double? radius;

  /// The regular height.
  final double? height;

  /// The small height.
  final double? smallHeight;

  /// The space at the sides of the label.
  final EdgeInsets? padding;

  /// The space at the sides of a small button's label.
  final EdgeInsets? smallPadding;

  /// The scale while pressed (`:active`).
  final double? pressScale;

  /// How long press and hover feedback takes.
  final Duration? duration;

  /// The easing of that feedback.
  final Curve? curve;

  /// The label's text style (the theme's `labelLarge`).
  final TextStyle? textStyle;

  /// The side of the icon before a label.
  final double? iconSize;

  /// The override installed on the nearest theme, or null.
  static StudioButtonThemeData? maybeOf(BuildContext context) =>
      Theme.of(context).extension<StudioButtonThemeData>();

  /// The effective values of the nearest theme: [override] (a widget's
  /// `theme:` parameter), then the installed theme, then the defaults of the
  /// theme's color scheme and text theme.
  static StudioButtonThemeResolved of(
    BuildContext context, [
    StudioButtonThemeData? override,
  ]) => resolve(Theme.of(context), override);

  /// The effective values of [theme] (for code with no `BuildContext`).
  static StudioButtonThemeResolved resolve(
    ThemeData theme, [
    StudioButtonThemeData? override,
  ]) {
    final installed = theme.extension<StudioButtonThemeData>();
    final d = _StudioButtonThemeDefaults(theme);
    return StudioButtonThemeResolved(
      filledColor:
          override?.filledColor ?? installed?.filledColor ?? d.filledColor,
      filledHoverColor:
          override?.filledHoverColor ??
          installed?.filledHoverColor ??
          d.filledHoverColor,
      onFilledColor:
          override?.onFilledColor ??
          installed?.onFilledColor ??
          d.onFilledColor,
      tonalColor: override?.tonalColor ?? installed?.tonalColor ?? d.tonalColor,
      tonalHoverColor:
          override?.tonalHoverColor ??
          installed?.tonalHoverColor ??
          d.tonalHoverColor,
      onTonalColor:
          override?.onTonalColor ?? installed?.onTonalColor ?? d.onTonalColor,
      outlineColor:
          override?.outlineColor ?? installed?.outlineColor ?? d.outlineColor,
      textColor: override?.textColor ?? installed?.textColor ?? d.textColor,
      radius: override?.radius ?? installed?.radius ?? d.radius,
      height: override?.height ?? installed?.height ?? d.height,
      smallHeight:
          override?.smallHeight ?? installed?.smallHeight ?? d.smallHeight,
      padding: override?.padding ?? installed?.padding ?? d.padding,
      smallPadding:
          override?.smallPadding ?? installed?.smallPadding ?? d.smallPadding,
      pressScale: override?.pressScale ?? installed?.pressScale ?? d.pressScale,
      duration: override?.duration ?? installed?.duration ?? d.duration,
      curve: override?.curve ?? installed?.curve ?? d.curve,
      textStyle: override?.textStyle ?? installed?.textStyle ?? d.textStyle,
      iconSize: override?.iconSize ?? installed?.iconSize ?? d.iconSize,
    );
  }

  /// A copy with the given fields replaced.
  StudioButtonThemeData copyWith({
    Color? filledColor,
    Color? filledHoverColor,
    Color? onFilledColor,
    Color? tonalColor,
    Color? tonalHoverColor,
    Color? onTonalColor,
    Color? outlineColor,
    Color? textColor,
    double? radius,
    double? height,
    double? smallHeight,
    EdgeInsets? padding,
    EdgeInsets? smallPadding,
    double? pressScale,
    Duration? duration,
    Curve? curve,
    TextStyle? textStyle,
    double? iconSize,
  }) => StudioButtonThemeData(
    filledColor: filledColor ?? this.filledColor,
    filledHoverColor: filledHoverColor ?? this.filledHoverColor,
    onFilledColor: onFilledColor ?? this.onFilledColor,
    tonalColor: tonalColor ?? this.tonalColor,
    tonalHoverColor: tonalHoverColor ?? this.tonalHoverColor,
    onTonalColor: onTonalColor ?? this.onTonalColor,
    outlineColor: outlineColor ?? this.outlineColor,
    textColor: textColor ?? this.textColor,
    radius: radius ?? this.radius,
    height: height ?? this.height,
    smallHeight: smallHeight ?? this.smallHeight,
    padding: padding ?? this.padding,
    smallPadding: smallPadding ?? this.smallPadding,
    pressScale: pressScale ?? this.pressScale,
    duration: duration ?? this.duration,
    curve: curve ?? this.curve,
    textStyle: textStyle ?? this.textStyle,
    iconSize: iconSize ?? this.iconSize,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StudioButtonThemeData &&
          other.filledColor == filledColor &&
          other.filledHoverColor == filledHoverColor &&
          other.onFilledColor == onFilledColor &&
          other.tonalColor == tonalColor &&
          other.tonalHoverColor == tonalHoverColor &&
          other.onTonalColor == onTonalColor &&
          other.outlineColor == outlineColor &&
          other.textColor == textColor &&
          other.radius == radius &&
          other.height == height &&
          other.smallHeight == smallHeight &&
          other.padding == padding &&
          other.smallPadding == smallPadding &&
          other.pressScale == pressScale &&
          other.duration == duration &&
          other.curve == curve &&
          other.textStyle == textStyle &&
          other.iconSize == iconSize);

  @override
  int get hashCode => Object.hashAll([
    filledColor,
    filledHoverColor,
    onFilledColor,
    tonalColor,
    tonalHoverColor,
    onTonalColor,
    outlineColor,
    textColor,
    radius,
    height,
    smallHeight,
    padding,
    smallPadding,
    pressScale,
    duration,
    curve,
    textStyle,
    iconSize,
  ]);
}

/// The effective look of a button: [StudioButtonThemeData.of] with every field set. It is a
/// [StudioButtonThemeData] too, so it can be handed to a widget's `theme:` parameter.
class StudioButtonThemeResolved extends StudioButtonThemeData {
  /// Creates the resolved values.
  const StudioButtonThemeResolved({
    required Color filledColor,
    required Color filledHoverColor,
    required Color onFilledColor,
    required Color tonalColor,
    required Color tonalHoverColor,
    required Color onTonalColor,
    required Color outlineColor,
    required Color textColor,
    required double radius,
    required double height,
    required double smallHeight,
    required EdgeInsets padding,
    required EdgeInsets smallPadding,
    required double pressScale,
    required Duration duration,
    required Curve curve,
    required TextStyle textStyle,
    required double iconSize,
  }) : _filledColor = filledColor,
       _filledHoverColor = filledHoverColor,
       _onFilledColor = onFilledColor,
       _tonalColor = tonalColor,
       _tonalHoverColor = tonalHoverColor,
       _onTonalColor = onTonalColor,
       _outlineColor = outlineColor,
       _textColor = textColor,
       _radius = radius,
       _height = height,
       _smallHeight = smallHeight,
       _padding = padding,
       _smallPadding = smallPadding,
       _pressScale = pressScale,
       _duration = duration,
       _curve = curve,
       _textStyle = textStyle,
       _iconSize = iconSize,
       super(
         filledColor: filledColor,
         filledHoverColor: filledHoverColor,
         onFilledColor: onFilledColor,
         tonalColor: tonalColor,
         tonalHoverColor: tonalHoverColor,
         onTonalColor: onTonalColor,
         outlineColor: outlineColor,
         textColor: textColor,
         radius: radius,
         height: height,
         smallHeight: smallHeight,
         padding: padding,
         smallPadding: smallPadding,
         pressScale: pressScale,
         duration: duration,
         curve: curve,
         textStyle: textStyle,
         iconSize: iconSize,
       );

  final Color _filledColor;

  @override
  Color get filledColor => _filledColor;

  final Color _filledHoverColor;

  @override
  Color get filledHoverColor => _filledHoverColor;

  final Color _onFilledColor;

  @override
  Color get onFilledColor => _onFilledColor;

  final Color _tonalColor;

  @override
  Color get tonalColor => _tonalColor;

  final Color _tonalHoverColor;

  @override
  Color get tonalHoverColor => _tonalHoverColor;

  final Color _onTonalColor;

  @override
  Color get onTonalColor => _onTonalColor;

  final Color _outlineColor;

  @override
  Color get outlineColor => _outlineColor;

  final Color _textColor;

  @override
  Color get textColor => _textColor;

  final double _radius;

  @override
  double get radius => _radius;

  final double _height;

  @override
  double get height => _height;

  final double _smallHeight;

  @override
  double get smallHeight => _smallHeight;

  final EdgeInsets _padding;

  @override
  EdgeInsets get padding => _padding;

  final EdgeInsets _smallPadding;

  @override
  EdgeInsets get smallPadding => _smallPadding;

  final double _pressScale;

  @override
  double get pressScale => _pressScale;

  final Duration _duration;

  @override
  Duration get duration => _duration;

  final Curve _curve;

  @override
  Curve get curve => _curve;

  final TextStyle _textStyle;

  @override
  TextStyle get textStyle => _textStyle;

  final double _iconSize;

  @override
  double get iconSize => _iconSize;

  /// The compact pill as a style for Flutter's own buttons, which `StudioTheme` already makes pills:
  /// `FilledButton(style: StudioButtonThemeData.of(context).smallStyle, …)`.
  ButtonStyle get smallStyle => ButtonStyle(
    minimumSize: WidgetStatePropertyAll(Size(0, smallHeight)),
    padding: WidgetStatePropertyAll(smallPadding),
  );
}

/// The defaults of the button theme: every value from the theme's color
/// scheme, text theme and the studio's tokens (Flutter's `_Defaults(context)`).
class _StudioButtonThemeDefaults {
  _StudioButtonThemeDefaults(ThemeData theme)
    : s = theme.colorScheme,
      t = theme.textTheme,
      x = theme.extension<StudioExtraColors>() ?? StudioExtraColors.standard;

  final ColorScheme s;
  final TextTheme t;
  final StudioExtraColors x;

  Color get filledColor => s.primary;
  Color get filledHoverColor => x.primaryHover;
  Color get onFilledColor => s.onPrimary;
  Color get tonalColor => s.surfaceContainerHighest ?? s.surfaceContainer;
  Color get tonalHoverColor => x.hover;
  Color get onTonalColor => s.onSurface;
  Color get outlineColor => x.lineStrong;
  Color get textColor => s.onSurface;
  double get radius => StudioRadii.control;
  double get height => 40;
  double get smallHeight => 32;
  EdgeInsets get padding =>
      const EdgeInsets.symmetric(horizontal: StudioSpacing.lg);
  EdgeInsets get smallPadding =>
      const EdgeInsets.symmetric(horizontal: StudioSpacing.md);
  double get pressScale => StudioMotion.pressScale;
  Duration get duration => StudioDurations.base;
  Curve get curve => StudioCurves.enter;
  TextStyle get textStyle => t.labelLarge;
  double get iconSize => 16;
}
