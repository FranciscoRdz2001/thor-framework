import 'package:thor_ui/thor_ui.dart';

import '../../tokens/color/studio_bench_colors.dart';
import '../../tokens/motion/studio_curves.dart';
import '../../tokens/motion/studio_durations.dart';
import '../../tokens/motion/studio_motion.dart';
import '../../tokens/shape/studio_radii.dart';
import '../studio_extra_colors.dart';

/// The look of a `StudioLevelSlider`: a bar with the name on the left, the
/// value on the right and a fill up to the grip (Flutter's `SliderThemeData`).
///
/// Every field is optional: the widget resolves each one as its own parameter,
/// then this theme, then a default derived from
/// `Theme.of(context).colorScheme` and `textTheme`. Install an override next
/// to the others
/// (`ThemeData(extensions: [StudioSliderThemeData(radius: 8)])`) and read the
/// effective values with [StudioSliderThemeData.of].
class StudioSliderThemeData extends ThemeExtension<StudioSliderThemeData> {
  /// Creates the theme; a null field keeps the default.
  const StudioSliderThemeData({
    this.trackColor,
    this.fillColor,
    this.radius,
    this.height,
    this.nameColor,
    this.valueColor,
    this.handleColor,
    this.handleWidth,
    this.handleHeight,
    this.padding,
    this.nameGap,
    this.valueWidth,
    this.nameWidth,
    this.disabledOpacity,
    this.focusColor,
    this.curve,
    this.gripScale,
    this.gripHoverScale,
    this.gripDuration,
  });

  /// The empty part of the bar.
  final Color? trackColor;

  /// The filled part, up to the value.
  final Color? fillColor;

  /// The bar's corner radius.
  final double? radius;

  /// The bar's height.
  final double? height;

  /// The name on the left.
  final Color? nameColor;

  /// The value on the right.
  final Color? valueColor;

  /// The grip at the end of the fill.
  final Color? handleColor;

  /// The grip's width.
  final double? handleWidth;

  /// The grip's height.
  final double? handleHeight;

  /// The space at the sides of the name and the value.
  final EdgeInsets? padding;

  /// The space between the name and the bar.
  final double? nameGap;

  /// The room kept for the value on the right: the grip stops before it, so it never covers the number.
  final double? valueWidth;

  /// The least room of the name on the left: the bar starts after it, so the grip never covers it, even at the lowest value. A longer name takes what it needs.
  final double? nameWidth;

  /// How opaque a disabled bar is (Material's 38 %).
  final double? disabledOpacity;

  /// The focus ring.
  final Color? focusColor;

  /// The easing of the grip.
  final Curve? curve;

  /// The scale of the grip while held or focused.
  final double? gripScale;

  /// The scale of the grip on hover.
  final double? gripHoverScale;

  /// How long the grip takes to grow.
  final Duration? gripDuration;

  /// The override installed on the nearest theme, or null.
  static StudioSliderThemeData? maybeOf(BuildContext context) =>
      Theme.of(context).extension<StudioSliderThemeData>();

  /// The effective values of the nearest theme: [override] (a widget's
  /// `theme:` parameter), then the installed theme, then the defaults of the
  /// theme's color scheme and text theme.
  static StudioSliderThemeResolved of(
    BuildContext context, [
    StudioSliderThemeData? override,
  ]) => resolve(Theme.of(context), override);

  /// The effective values of [theme] (for code with no `BuildContext`).
  static StudioSliderThemeResolved resolve(
    ThemeData theme, [
    StudioSliderThemeData? override,
  ]) {
    final installed = theme.extension<StudioSliderThemeData>();
    final d = _StudioSliderThemeDefaults(theme);
    return StudioSliderThemeResolved(
      trackColor: override?.trackColor ?? installed?.trackColor ?? d.trackColor,
      fillColor: override?.fillColor ?? installed?.fillColor ?? d.fillColor,
      radius: override?.radius ?? installed?.radius ?? d.radius,
      height: override?.height ?? installed?.height ?? d.height,
      nameColor: override?.nameColor ?? installed?.nameColor ?? d.nameColor,
      valueColor: override?.valueColor ?? installed?.valueColor ?? d.valueColor,
      handleColor:
          override?.handleColor ?? installed?.handleColor ?? d.handleColor,
      handleWidth:
          override?.handleWidth ?? installed?.handleWidth ?? d.handleWidth,
      handleHeight:
          override?.handleHeight ?? installed?.handleHeight ?? d.handleHeight,
      padding: override?.padding ?? installed?.padding ?? d.padding,
      nameGap: override?.nameGap ?? installed?.nameGap ?? d.nameGap,
      valueWidth: override?.valueWidth ?? installed?.valueWidth ?? d.valueWidth,
      nameWidth: override?.nameWidth ?? installed?.nameWidth ?? d.nameWidth,
      disabledOpacity:
          override?.disabledOpacity ??
          installed?.disabledOpacity ??
          d.disabledOpacity,
      focusColor: override?.focusColor ?? installed?.focusColor ?? d.focusColor,
      curve: override?.curve ?? installed?.curve ?? d.curve,
      gripScale: override?.gripScale ?? installed?.gripScale ?? d.gripScale,
      gripHoverScale:
          override?.gripHoverScale ??
          installed?.gripHoverScale ??
          d.gripHoverScale,
      gripDuration:
          override?.gripDuration ?? installed?.gripDuration ?? d.gripDuration,
    );
  }

  /// A copy with the given fields replaced.
  StudioSliderThemeData copyWith({
    Color? trackColor,
    Color? fillColor,
    double? radius,
    double? height,
    Color? nameColor,
    Color? valueColor,
    Color? handleColor,
    double? handleWidth,
    double? handleHeight,
    EdgeInsets? padding,
    double? nameGap,
    double? valueWidth,
    double? nameWidth,
    double? disabledOpacity,
    Color? focusColor,
    Curve? curve,
    double? gripScale,
    double? gripHoverScale,
    Duration? gripDuration,
  }) => StudioSliderThemeData(
    trackColor: trackColor ?? this.trackColor,
    fillColor: fillColor ?? this.fillColor,
    radius: radius ?? this.radius,
    height: height ?? this.height,
    nameColor: nameColor ?? this.nameColor,
    valueColor: valueColor ?? this.valueColor,
    handleColor: handleColor ?? this.handleColor,
    handleWidth: handleWidth ?? this.handleWidth,
    handleHeight: handleHeight ?? this.handleHeight,
    padding: padding ?? this.padding,
    nameGap: nameGap ?? this.nameGap,
    valueWidth: valueWidth ?? this.valueWidth,
    nameWidth: nameWidth ?? this.nameWidth,
    disabledOpacity: disabledOpacity ?? this.disabledOpacity,
    focusColor: focusColor ?? this.focusColor,
    curve: curve ?? this.curve,
    gripScale: gripScale ?? this.gripScale,
    gripHoverScale: gripHoverScale ?? this.gripHoverScale,
    gripDuration: gripDuration ?? this.gripDuration,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StudioSliderThemeData &&
          other.trackColor == trackColor &&
          other.fillColor == fillColor &&
          other.radius == radius &&
          other.height == height &&
          other.nameColor == nameColor &&
          other.valueColor == valueColor &&
          other.handleColor == handleColor &&
          other.handleWidth == handleWidth &&
          other.handleHeight == handleHeight &&
          other.padding == padding &&
          other.nameGap == nameGap &&
          other.valueWidth == valueWidth &&
          other.nameWidth == nameWidth &&
          other.disabledOpacity == disabledOpacity &&
          other.focusColor == focusColor &&
          other.curve == curve &&
          other.gripScale == gripScale &&
          other.gripHoverScale == gripHoverScale &&
          other.gripDuration == gripDuration);

  @override
  int get hashCode => Object.hashAll([
    trackColor,
    fillColor,
    radius,
    height,
    nameColor,
    valueColor,
    handleColor,
    handleWidth,
    handleHeight,
    padding,
    nameGap,
    valueWidth,
    nameWidth,
    disabledOpacity,
    focusColor,
    curve,
    gripScale,
    gripHoverScale,
    gripDuration,
  ]);
}

/// The effective look of the level slider: [StudioSliderThemeData.of] with every field set.
/// It is a [StudioSliderThemeData] too, so it can be handed to a widget's `theme:` parameter.
class StudioSliderThemeResolved extends StudioSliderThemeData {
  /// Creates the resolved values.
  const StudioSliderThemeResolved({
    required Color trackColor,
    required Color fillColor,
    required double radius,
    required double height,
    required Color nameColor,
    required Color valueColor,
    required Color handleColor,
    required double handleWidth,
    required double handleHeight,
    required EdgeInsets padding,
    required double nameGap,
    required double valueWidth,
    required double nameWidth,
    required double disabledOpacity,
    required Color focusColor,
    required Curve curve,
    required double gripScale,
    required double gripHoverScale,
    required Duration gripDuration,
  }) : _trackColor = trackColor,
       _fillColor = fillColor,
       _radius = radius,
       _height = height,
       _nameColor = nameColor,
       _valueColor = valueColor,
       _handleColor = handleColor,
       _handleWidth = handleWidth,
       _handleHeight = handleHeight,
       _padding = padding,
       _nameGap = nameGap,
       _valueWidth = valueWidth,
       _nameWidth = nameWidth,
       _disabledOpacity = disabledOpacity,
       _focusColor = focusColor,
       _curve = curve,
       _gripScale = gripScale,
       _gripHoverScale = gripHoverScale,
       _gripDuration = gripDuration,
       super(
         trackColor: trackColor,
         fillColor: fillColor,
         radius: radius,
         height: height,
         nameColor: nameColor,
         valueColor: valueColor,
         handleColor: handleColor,
         handleWidth: handleWidth,
         handleHeight: handleHeight,
         padding: padding,
         nameGap: nameGap,
         valueWidth: valueWidth,
         nameWidth: nameWidth,
         disabledOpacity: disabledOpacity,
         focusColor: focusColor,
         curve: curve,
         gripScale: gripScale,
         gripHoverScale: gripHoverScale,
         gripDuration: gripDuration,
       );

  final Color _trackColor;

  @override
  Color get trackColor => _trackColor;

  final Color _fillColor;

  @override
  Color get fillColor => _fillColor;

  final double _radius;

  @override
  double get radius => _radius;

  final double _height;

  @override
  double get height => _height;

  final Color _nameColor;

  @override
  Color get nameColor => _nameColor;

  final Color _valueColor;

  @override
  Color get valueColor => _valueColor;

  final Color _handleColor;

  @override
  Color get handleColor => _handleColor;

  final double _handleWidth;

  @override
  double get handleWidth => _handleWidth;

  final double _handleHeight;

  @override
  double get handleHeight => _handleHeight;

  final EdgeInsets _padding;

  @override
  EdgeInsets get padding => _padding;

  final double _nameGap;

  @override
  double get nameGap => _nameGap;

  final double _valueWidth;

  @override
  double get valueWidth => _valueWidth;

  final double _nameWidth;

  @override
  double get nameWidth => _nameWidth;

  final double _disabledOpacity;

  @override
  double get disabledOpacity => _disabledOpacity;

  final Color _focusColor;

  @override
  Color get focusColor => _focusColor;

  final Curve _curve;

  @override
  Curve get curve => _curve;

  final double _gripScale;

  @override
  double get gripScale => _gripScale;

  final double _gripHoverScale;

  @override
  double get gripHoverScale => _gripHoverScale;

  final Duration _gripDuration;

  @override
  Duration get gripDuration => _gripDuration;
}

/// The defaults of the level slider theme: every value from the theme's color
/// scheme, text theme and the studio's tokens (Flutter's `_Defaults(context)`).
class _StudioSliderThemeDefaults {
  _StudioSliderThemeDefaults(ThemeData theme)
    : s = theme.colorScheme,
      x = theme.extension<StudioExtraColors>() ?? StudioExtraColors.standard;

  final ColorScheme s;
  final StudioExtraColors x;

  Color get trackColor => StudioBenchColors.levelTrack;
  Color get fillColor => StudioBenchColors.levelFill;
  double get radius => StudioRadii.inner;
  double get height => 44;
  Color get nameColor => s.onSurface;
  Color get valueColor => x.onSurfaceSoft;
  Color get handleColor => s.onSurfaceVariant ?? s.onSurface;
  double get handleWidth => 4;
  double get handleHeight => 20;
  EdgeInsets get padding => const EdgeInsets.symmetric(horizontal: 16);
  double get nameGap => 12;
  double get valueWidth => 64;
  double get nameWidth => 88;
  double get disabledOpacity => 0.38;
  Color get focusColor => s.accent;
  Curve get curve => StudioCurves.move;
  double get gripScale => StudioMotion.gripScale;
  double get gripHoverScale => StudioMotion.gripHoverScale;
  Duration get gripDuration => StudioDurations.base;
}
