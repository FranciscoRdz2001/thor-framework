import 'package:thor_ui/thor_ui.dart';

import '../../tokens/color/studio_bench_colors.dart';
import '../../tokens/elevation/studio_shadows.dart';
import '../../tokens/motion/studio_curves.dart';
import '../../tokens/motion/studio_durations.dart';
import '../../tokens/motion/studio_motion.dart';
import '../../tokens/shape/studio_radii.dart';
import '../studio_extra_colors.dart';

/// The look of a `StudioSegmentedControl`: a groove with the chosen segment
/// raised in it (Flutter's `SegmentedButtonThemeData`).
///
/// Every field is optional: the widget resolves each one as its own parameter,
/// then this theme, then a default derived from
/// `Theme.of(context).colorScheme` and `textTheme`. Install an override
/// next to the others
/// (`ThemeData(extensions: [StudioSegmentedButtonThemeData(radius: 8)])`) and
/// read the effective values with [StudioSegmentedButtonThemeData.of].
class StudioSegmentedButtonThemeData
    extends ThemeExtension<StudioSegmentedButtonThemeData> {
  /// Creates the theme; a null field keeps the default.
  const StudioSegmentedButtonThemeData({
    this.trackColor,
    this.selectedColor,
    this.radius,
    this.height,
    this.shadows,
    this.labelColor,
    this.selectedLabelColor,
    this.padding,
    this.segmentPadding,
    this.iconGap,
    this.disabledOpacity,
    this.focusColor,
    this.duration,
    this.curve,
    this.pressScale,
    this.thumbDuration,
  });

  /// The groove.
  final Color? trackColor;

  /// The chosen segment.
  final Color? selectedColor;

  /// The corner radius (a pill).
  final double? radius;

  /// The control's height.
  final double? height;

  /// The chosen segment's shadows.
  final List<BoxShadow>? shadows;

  /// The label of a segment that is not chosen.
  final Color? labelColor;

  /// The label of the chosen segment.
  final Color? selectedLabelColor;

  /// The space between the groove and its segments.
  final EdgeInsets? padding;

  /// The space at the sides of a segment's content.
  final EdgeInsets? segmentPadding;

  /// The space between a segment's icon and its label.
  final double? iconGap;

  /// How opaque a disabled control is (Material's 38 %).
  final double? disabledOpacity;

  /// The focus ring.
  final Color? focusColor;

  /// How long a segment's label takes to change color.
  final Duration? duration;

  /// The easing of the thumb.
  final Curve? curve;

  /// The scale of a segment while pressed.
  final double? pressScale;

  /// How long the thumb takes to slide.
  final Duration? thumbDuration;

  /// The override installed on the nearest theme, or null.
  static StudioSegmentedButtonThemeData? maybeOf(BuildContext context) =>
      Theme.of(context).extension<StudioSegmentedButtonThemeData>();

  /// The effective values of the nearest theme: [override] (a widget's
  /// `theme:` parameter), then the installed theme, then the defaults of the
  /// theme's color scheme and text theme.
  static StudioSegmentedButtonThemeResolved of(
    BuildContext context, [
    StudioSegmentedButtonThemeData? override,
  ]) => resolve(Theme.of(context), override);

  /// The effective values of [theme] (for code with no `BuildContext`).
  static StudioSegmentedButtonThemeResolved resolve(
    ThemeData theme, [
    StudioSegmentedButtonThemeData? override,
  ]) {
    final installed = theme.extension<StudioSegmentedButtonThemeData>();
    final d = _StudioSegmentedButtonThemeDefaults(theme);
    return StudioSegmentedButtonThemeResolved(
      trackColor: override?.trackColor ?? installed?.trackColor ?? d.trackColor,
      selectedColor:
          override?.selectedColor ??
          installed?.selectedColor ??
          d.selectedColor,
      radius: override?.radius ?? installed?.radius ?? d.radius,
      height: override?.height ?? installed?.height ?? d.height,
      shadows: override?.shadows ?? installed?.shadows ?? d.shadows,
      labelColor: override?.labelColor ?? installed?.labelColor ?? d.labelColor,
      selectedLabelColor:
          override?.selectedLabelColor ??
          installed?.selectedLabelColor ??
          d.selectedLabelColor,
      padding: override?.padding ?? installed?.padding ?? d.padding,
      segmentPadding:
          override?.segmentPadding ??
          installed?.segmentPadding ??
          d.segmentPadding,
      iconGap: override?.iconGap ?? installed?.iconGap ?? d.iconGap,
      disabledOpacity:
          override?.disabledOpacity ??
          installed?.disabledOpacity ??
          d.disabledOpacity,
      focusColor: override?.focusColor ?? installed?.focusColor ?? d.focusColor,
      duration: override?.duration ?? installed?.duration ?? d.duration,
      curve: override?.curve ?? installed?.curve ?? d.curve,
      pressScale: override?.pressScale ?? installed?.pressScale ?? d.pressScale,
      thumbDuration:
          override?.thumbDuration ??
          installed?.thumbDuration ??
          d.thumbDuration,
    );
  }

  /// A copy with the given fields replaced.
  StudioSegmentedButtonThemeData copyWith({
    Color? trackColor,
    Color? selectedColor,
    double? radius,
    double? height,
    List<BoxShadow>? shadows,
    Color? labelColor,
    Color? selectedLabelColor,
    EdgeInsets? padding,
    EdgeInsets? segmentPadding,
    double? iconGap,
    double? disabledOpacity,
    Color? focusColor,
    Duration? duration,
    Curve? curve,
    double? pressScale,
    Duration? thumbDuration,
  }) => StudioSegmentedButtonThemeData(
    trackColor: trackColor ?? this.trackColor,
    selectedColor: selectedColor ?? this.selectedColor,
    radius: radius ?? this.radius,
    height: height ?? this.height,
    shadows: shadows ?? this.shadows,
    labelColor: labelColor ?? this.labelColor,
    selectedLabelColor: selectedLabelColor ?? this.selectedLabelColor,
    padding: padding ?? this.padding,
    segmentPadding: segmentPadding ?? this.segmentPadding,
    iconGap: iconGap ?? this.iconGap,
    disabledOpacity: disabledOpacity ?? this.disabledOpacity,
    focusColor: focusColor ?? this.focusColor,
    duration: duration ?? this.duration,
    curve: curve ?? this.curve,
    pressScale: pressScale ?? this.pressScale,
    thumbDuration: thumbDuration ?? this.thumbDuration,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StudioSegmentedButtonThemeData &&
          other.trackColor == trackColor &&
          other.selectedColor == selectedColor &&
          other.radius == radius &&
          other.height == height &&
          other.shadows == shadows &&
          other.labelColor == labelColor &&
          other.selectedLabelColor == selectedLabelColor &&
          other.padding == padding &&
          other.segmentPadding == segmentPadding &&
          other.iconGap == iconGap &&
          other.disabledOpacity == disabledOpacity &&
          other.focusColor == focusColor &&
          other.duration == duration &&
          other.curve == curve &&
          other.pressScale == pressScale &&
          other.thumbDuration == thumbDuration);

  @override
  int get hashCode => Object.hashAll([
    trackColor,
    selectedColor,
    radius,
    height,
    shadows,
    labelColor,
    selectedLabelColor,
    padding,
    segmentPadding,
    iconGap,
    disabledOpacity,
    focusColor,
    duration,
    curve,
    pressScale,
    thumbDuration,
  ]);
}

/// The effective look of the segmented control: [StudioSegmentedButtonThemeData.of] with every field set.
/// It is a [StudioSegmentedButtonThemeData] too, so it can be handed to a widget's `theme:` parameter.
class StudioSegmentedButtonThemeResolved
    extends StudioSegmentedButtonThemeData {
  /// Creates the resolved values.
  const StudioSegmentedButtonThemeResolved({
    required Color trackColor,
    required Color selectedColor,
    required double radius,
    required double height,
    required List<BoxShadow> shadows,
    required Color labelColor,
    required Color selectedLabelColor,
    required EdgeInsets padding,
    required EdgeInsets segmentPadding,
    required double iconGap,
    required double disabledOpacity,
    required Color focusColor,
    required Duration duration,
    required Curve curve,
    required double pressScale,
    required Duration thumbDuration,
  }) : _trackColor = trackColor,
       _selectedColor = selectedColor,
       _radius = radius,
       _height = height,
       _shadows = shadows,
       _labelColor = labelColor,
       _selectedLabelColor = selectedLabelColor,
       _padding = padding,
       _segmentPadding = segmentPadding,
       _iconGap = iconGap,
       _disabledOpacity = disabledOpacity,
       _focusColor = focusColor,
       _duration = duration,
       _curve = curve,
       _pressScale = pressScale,
       _thumbDuration = thumbDuration,
       super(
         trackColor: trackColor,
         selectedColor: selectedColor,
         radius: radius,
         height: height,
         shadows: shadows,
         labelColor: labelColor,
         selectedLabelColor: selectedLabelColor,
         padding: padding,
         segmentPadding: segmentPadding,
         iconGap: iconGap,
         disabledOpacity: disabledOpacity,
         focusColor: focusColor,
         duration: duration,
         curve: curve,
         pressScale: pressScale,
         thumbDuration: thumbDuration,
       );

  final Color _trackColor;

  @override
  Color get trackColor => _trackColor;

  final Color _selectedColor;

  @override
  Color get selectedColor => _selectedColor;

  final double _radius;

  @override
  double get radius => _radius;

  final double _height;

  @override
  double get height => _height;

  final List<BoxShadow> _shadows;

  @override
  List<BoxShadow> get shadows => _shadows;

  final Color _labelColor;

  @override
  Color get labelColor => _labelColor;

  final Color _selectedLabelColor;

  @override
  Color get selectedLabelColor => _selectedLabelColor;

  final EdgeInsets _padding;

  @override
  EdgeInsets get padding => _padding;

  final EdgeInsets _segmentPadding;

  @override
  EdgeInsets get segmentPadding => _segmentPadding;

  final double _iconGap;

  @override
  double get iconGap => _iconGap;

  final double _disabledOpacity;

  @override
  double get disabledOpacity => _disabledOpacity;

  final Color _focusColor;

  @override
  Color get focusColor => _focusColor;

  final Duration _duration;

  @override
  Duration get duration => _duration;

  final Curve _curve;

  @override
  Curve get curve => _curve;

  final double _pressScale;

  @override
  double get pressScale => _pressScale;

  final Duration _thumbDuration;

  @override
  Duration get thumbDuration => _thumbDuration;
}

/// The defaults of the segmented control theme: every value from the theme's color
/// scheme, text theme and the studio's tokens (Flutter's `_Defaults(context)`).
class _StudioSegmentedButtonThemeDefaults {
  _StudioSegmentedButtonThemeDefaults(ThemeData theme)
    : s = theme.colorScheme,
      x = theme.extension<StudioExtraColors>() ?? StudioExtraColors.standard;

  final ColorScheme s;
  final StudioExtraColors x;

  Color get trackColor => StudioBenchColors.segmentedTrack;
  Color get selectedColor => s.accent;
  double get radius => StudioRadii.control;
  double get height => 36;
  List<BoxShadow> get shadows => StudioShadows.soft;
  Color get labelColor => s.onSurfaceVariant ?? s.onSurface;
  Color get selectedLabelColor => s.onAccent;
  EdgeInsets get padding => const EdgeInsets.all(2);
  EdgeInsets get segmentPadding => const EdgeInsets.symmetric(horizontal: 14);
  double get iconGap => 6;
  double get disabledOpacity => 0.38;
  Color get focusColor => s.accent;
  Duration get duration => StudioDurations.base;
  Curve get curve => StudioCurves.move;
  double get pressScale => StudioMotion.pressScale;
  Duration get thumbDuration => StudioDurations.slow;
}
