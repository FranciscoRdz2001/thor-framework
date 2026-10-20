import 'package:thor_ui/thor_ui.dart';

import '../../tokens/elevation/studio_shadows.dart';
import '../../tokens/motion/studio_curves.dart';
import '../../tokens/motion/studio_durations.dart';
import '../../tokens/motion/studio_motion.dart';
import '../../tokens/shape/studio_radii.dart';
import '../../tokens/spacing/studio_spacing.dart';
import '../studio_extra_colors.dart';

/// The look of a studio card, like Flutter's `CardThemeData`: a big (28)
/// surface with a hairline border and no shadow.
///
/// Every field is optional: the widgets resolve each one as the widget's own
/// parameter, then this theme, then a default derived from
/// `Theme.of(context).colorScheme` and `textTheme`, so a `copyWith(primary:)` on
/// the color scheme reaches the component. Install an override next to the
/// others (`ThemeData(extensions: [StudioCardThemeData(radius: 8)])`) and read the effective
/// values with [StudioCardThemeData.of].
class StudioCardThemeData extends ThemeExtension<StudioCardThemeData> {
  /// Creates a card theme; a null field keeps the default.
  const StudioCardThemeData({
    this.color,
    this.borderColor,
    this.hoverBorderColor,
    this.radius,
    this.padding,
    this.shadows,
    this.gridGap,
    this.pressScale,
    this.hoverLift,
    this.arrowNudge,
    this.duration,
    this.hoverDuration,
    this.curve,
  });

  /// The card's surface.
  final Color? color;

  /// The hairline around it.
  final Color? borderColor;

  /// The border while the pointer is over an interactive card.
  final Color? hoverBorderColor;

  /// The corner radius.
  final double? radius;

  /// The space between the border and the content.
  final EdgeInsets? padding;

  /// The card's shadows (none: borders carry the structure).
  final List<BoxShadow>? shadows;

  /// The space between the cards of a `StudioCardGrid`.
  final double? gridGap;

  /// The scale of an interactive card while pressed: a wide surface moves its edges too far at the button's .97.
  final double? pressScale;

  /// How far an interactive card lifts on hover.
  final double? hoverLift;

  /// How far a card's arrow nudges toward where it points on hover.
  final double? arrowNudge;

  /// How long a card's hover and press take.
  final Duration? duration;

  /// How long the border and arrow colors take to change.
  final Duration? hoverDuration;

  /// The easing of card motion.
  final Curve? curve;

  /// The override installed on the nearest theme, or null.
  static StudioCardThemeData? maybeOf(BuildContext context) =>
      Theme.of(context).extension<StudioCardThemeData>();

  /// The effective values of the nearest theme: [override] (a widget's
  /// `theme:` parameter), then the installed theme, then the defaults of the
  /// theme's color scheme and text theme.
  static StudioCardThemeResolved of(
    BuildContext context, [
    StudioCardThemeData? override,
  ]) => resolve(Theme.of(context), override);

  /// The effective values of [theme] (for code with no `BuildContext`).
  static StudioCardThemeResolved resolve(
    ThemeData theme, [
    StudioCardThemeData? override,
  ]) {
    final installed = theme.extension<StudioCardThemeData>();
    final d = _StudioCardThemeDefaults(theme);
    return StudioCardThemeResolved(
      color: override?.color ?? installed?.color ?? d.color,
      borderColor:
          override?.borderColor ?? installed?.borderColor ?? d.borderColor,
      hoverBorderColor:
          override?.hoverBorderColor ??
          installed?.hoverBorderColor ??
          d.hoverBorderColor,
      radius: override?.radius ?? installed?.radius ?? d.radius,
      padding: override?.padding ?? installed?.padding ?? d.padding,
      shadows: override?.shadows ?? installed?.shadows ?? d.shadows,
      gridGap: override?.gridGap ?? installed?.gridGap ?? d.gridGap,
      pressScale: override?.pressScale ?? installed?.pressScale ?? d.pressScale,
      hoverLift: override?.hoverLift ?? installed?.hoverLift ?? d.hoverLift,
      arrowNudge: override?.arrowNudge ?? installed?.arrowNudge ?? d.arrowNudge,
      duration: override?.duration ?? installed?.duration ?? d.duration,
      hoverDuration:
          override?.hoverDuration ??
          installed?.hoverDuration ??
          d.hoverDuration,
      curve: override?.curve ?? installed?.curve ?? d.curve,
    );
  }

  /// A copy with the given fields replaced.
  StudioCardThemeData copyWith({
    Color? color,
    Color? borderColor,
    Color? hoverBorderColor,
    double? radius,
    EdgeInsets? padding,
    List<BoxShadow>? shadows,
    double? gridGap,
    double? pressScale,
    double? hoverLift,
    double? arrowNudge,
    Duration? duration,
    Duration? hoverDuration,
    Curve? curve,
  }) => StudioCardThemeData(
    color: color ?? this.color,
    borderColor: borderColor ?? this.borderColor,
    hoverBorderColor: hoverBorderColor ?? this.hoverBorderColor,
    radius: radius ?? this.radius,
    padding: padding ?? this.padding,
    shadows: shadows ?? this.shadows,
    gridGap: gridGap ?? this.gridGap,
    pressScale: pressScale ?? this.pressScale,
    hoverLift: hoverLift ?? this.hoverLift,
    arrowNudge: arrowNudge ?? this.arrowNudge,
    duration: duration ?? this.duration,
    hoverDuration: hoverDuration ?? this.hoverDuration,
    curve: curve ?? this.curve,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StudioCardThemeData &&
          other.color == color &&
          other.borderColor == borderColor &&
          other.hoverBorderColor == hoverBorderColor &&
          other.radius == radius &&
          other.padding == padding &&
          other.shadows == shadows &&
          other.gridGap == gridGap &&
          other.pressScale == pressScale &&
          other.hoverLift == hoverLift &&
          other.arrowNudge == arrowNudge &&
          other.duration == duration &&
          other.hoverDuration == hoverDuration &&
          other.curve == curve);

  @override
  int get hashCode => Object.hashAll([
    color,
    borderColor,
    hoverBorderColor,
    radius,
    padding,
    shadows,
    gridGap,
    pressScale,
    hoverLift,
    arrowNudge,
    duration,
    hoverDuration,
    curve,
  ]);
}

/// The effective look of a card: [StudioCardThemeData.of] with every field set. It is a
/// [StudioCardThemeData] too, so it can be handed to a widget's `theme:` parameter.
class StudioCardThemeResolved extends StudioCardThemeData {
  /// Creates the resolved values.
  const StudioCardThemeResolved({
    required Color color,
    required Color borderColor,
    required Color hoverBorderColor,
    required double radius,
    required EdgeInsets padding,
    required List<BoxShadow> shadows,
    required double gridGap,
    required double pressScale,
    required double hoverLift,
    required double arrowNudge,
    required Duration duration,
    required Duration hoverDuration,
    required Curve curve,
  }) : _color = color,
       _borderColor = borderColor,
       _hoverBorderColor = hoverBorderColor,
       _radius = radius,
       _padding = padding,
       _shadows = shadows,
       _gridGap = gridGap,
       _pressScale = pressScale,
       _hoverLift = hoverLift,
       _arrowNudge = arrowNudge,
       _duration = duration,
       _hoverDuration = hoverDuration,
       _curve = curve,
       super(
         color: color,
         borderColor: borderColor,
         hoverBorderColor: hoverBorderColor,
         radius: radius,
         padding: padding,
         shadows: shadows,
         gridGap: gridGap,
         pressScale: pressScale,
         hoverLift: hoverLift,
         arrowNudge: arrowNudge,
         duration: duration,
         hoverDuration: hoverDuration,
         curve: curve,
       );

  final Color _color;

  @override
  Color get color => _color;

  final Color _borderColor;

  @override
  Color get borderColor => _borderColor;

  final Color _hoverBorderColor;

  @override
  Color get hoverBorderColor => _hoverBorderColor;

  final double _radius;

  @override
  double get radius => _radius;

  final EdgeInsets _padding;

  @override
  EdgeInsets get padding => _padding;

  final List<BoxShadow> _shadows;

  @override
  List<BoxShadow> get shadows => _shadows;

  final double _gridGap;

  @override
  double get gridGap => _gridGap;

  final double _pressScale;

  @override
  double get pressScale => _pressScale;

  final double _hoverLift;

  @override
  double get hoverLift => _hoverLift;

  final double _arrowNudge;

  @override
  double get arrowNudge => _arrowNudge;

  final Duration _duration;

  @override
  Duration get duration => _duration;

  final Duration _hoverDuration;

  @override
  Duration get hoverDuration => _hoverDuration;

  final Curve _curve;

  @override
  Curve get curve => _curve;
}

/// The defaults of the card theme: every value from the theme's color
/// scheme, text theme and the studio's tokens (Flutter's `_Defaults(context)`).
class _StudioCardThemeDefaults {
  _StudioCardThemeDefaults(ThemeData theme)
    : s = theme.colorScheme,
      x = theme.extension<StudioExtraColors>() ?? StudioExtraColors.standard;

  final ColorScheme s;
  final StudioExtraColors x;

  Color get color => s.surfaceContainer;
  Color get borderColor => s.outlineVariant;
  Color get hoverBorderColor => x.lineStrong;
  double get radius => StudioRadii.card;
  EdgeInsets get padding => const EdgeInsets.all(20);
  List<BoxShadow> get shadows => StudioShadows.none;
  double get gridGap => StudioSpacing.sm;
  double get pressScale => StudioMotion.pressScaleLarge;
  double get hoverLift => StudioMotion.hoverLift;
  double get arrowNudge => StudioMotion.arrowNudge;
  Duration get duration => StudioDurations.base;
  Duration get hoverDuration => StudioDurations.fast;
  Curve get curve => StudioCurves.enter;
}
