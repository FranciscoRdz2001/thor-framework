import 'package:thor_ui/thor_ui.dart';

import '../../tokens/color/studio_bench_colors.dart';
import '../../tokens/motion/studio_curves.dart';
import '../../tokens/motion/studio_durations.dart';
import '../../tokens/motion/studio_motion.dart';
import '../../tokens/shape/studio_radii.dart';
import '../../tokens/spacing/studio_spacing.dart';
import '../studio_extra_colors.dart';

/// The look of the bench: a big stage for a live example and a side panel
/// with its controls, Switches (a segmented control) and Levels (a bar you
/// drag, name on the left, value on the right, filled up to the value).
///
/// Every field is optional: the widgets resolve each one as the widget's own
/// parameter, then this theme, then a default derived from
/// `Theme.of(context).colorScheme` and `textTheme`, so a `copyWith(primary:)` on
/// the color scheme reaches the component. Install an override next to the
/// others (`ThemeData(extensions: [StudioBenchThemeData(radius: 8)])`) and read the effective
/// values with [StudioBenchThemeData.of].
class StudioBenchThemeData extends ThemeExtension<StudioBenchThemeData> {
  /// Creates a bench theme; a null field keeps the default.
  const StudioBenchThemeData({
    this.stageColor,
    this.stageRadius,
    this.stagePadding,
    this.stageCompactPadding,
    this.stageMinHeight,
    this.stageCompactMinHeight,
    this.panelColor,
    this.panelRadius,
    this.panelPadding,
    this.panelWidth,
    this.panelGap,
    this.sideBySideFrom,
    this.wideBleed,
    this.borderColor,
    this.focusColor,
    this.toolbarInset,
    this.duration,
    this.curve,
    this.enterRise,
    this.enterDuration,
    this.enterCurve,
    this.pressScale,
  });

  /// The demo stage's background.
  final Color? stageColor;

  /// The stage's corner radius.
  final double? stageRadius;

  /// The space around the demo.
  final EdgeInsets? stagePadding;

  /// The stage's padding while the bench is stacked (a phone): tighter, so the stage hugs a small demo.
  final EdgeInsets? stageCompactPadding;

  /// The stage's least height beside the panel (it is as tall as its demo or the panel when those are taller).
  final double? stageMinHeight;

  /// The stage's least height while the bench is stacked (a phone).
  final double? stageCompactMinHeight;

  /// The control panel's background.
  final Color? panelColor;

  /// The control panel's corner radius.
  final double? panelRadius;

  /// The space inside the control panel.
  final EdgeInsets? panelPadding;

  /// The control panel's width beside the stage.
  final double? panelWidth;

  /// The gap between controls, and between stage and panel.
  final double? panelGap;

  /// The bench's own width (a container, not the viewport) from which the panel sits beside the stage; narrower, it stacks under it.
  final double? sideBySideFrom;

  /// How far a `wide` bench goes past the prose measure on each side, from the `xl` breakpoint up.
  final double? wideBleed;

  /// The hairline around the stage and the panel.
  final Color? borderColor;

  /// The focus ring of the bench's native controls.
  final Color? focusColor;

  /// The distance from the stage's edge to its toolbar controls.
  final double? toolbarInset;

  /// How long a control takes to settle.
  final Duration? duration;

  /// The easing of the Switch's thumb.
  final Curve? curve;

  /// How far the Code pane and a replayed stage rise as they appear.
  final double? enterRise;

  /// How long they take to appear.
  final Duration? enterDuration;

  /// The easing of that entrance.
  final Curve? enterCurve;

  /// The scale of a segment, the replay button and a grip while pressed.
  final double? pressScale;

  /// The override installed on the nearest theme, or null.
  static StudioBenchThemeData? maybeOf(BuildContext context) =>
      Theme.of(context).extension<StudioBenchThemeData>();

  /// The effective values of the nearest theme: [override] (a widget's
  /// `theme:` parameter), then the installed theme, then the defaults of the
  /// theme's color scheme and text theme.
  static StudioBenchThemeResolved of(
    BuildContext context, [
    StudioBenchThemeData? override,
  ]) => resolve(Theme.of(context), override);

  /// The effective values of [theme] (for code with no `BuildContext`).
  static StudioBenchThemeResolved resolve(
    ThemeData theme, [
    StudioBenchThemeData? override,
  ]) {
    final installed = theme.extension<StudioBenchThemeData>();
    final d = _StudioBenchThemeDefaults(theme);
    return StudioBenchThemeResolved(
      stageColor: override?.stageColor ?? installed?.stageColor ?? d.stageColor,
      stageRadius:
          override?.stageRadius ?? installed?.stageRadius ?? d.stageRadius,
      stagePadding:
          override?.stagePadding ?? installed?.stagePadding ?? d.stagePadding,
      stageCompactPadding:
          override?.stageCompactPadding ??
          installed?.stageCompactPadding ??
          d.stageCompactPadding,
      stageMinHeight:
          override?.stageMinHeight ??
          installed?.stageMinHeight ??
          d.stageMinHeight,
      stageCompactMinHeight:
          override?.stageCompactMinHeight ??
          installed?.stageCompactMinHeight ??
          d.stageCompactMinHeight,
      panelColor: override?.panelColor ?? installed?.panelColor ?? d.panelColor,
      panelRadius:
          override?.panelRadius ?? installed?.panelRadius ?? d.panelRadius,
      panelPadding:
          override?.panelPadding ?? installed?.panelPadding ?? d.panelPadding,
      panelWidth: override?.panelWidth ?? installed?.panelWidth ?? d.panelWidth,
      panelGap: override?.panelGap ?? installed?.panelGap ?? d.panelGap,
      sideBySideFrom:
          override?.sideBySideFrom ??
          installed?.sideBySideFrom ??
          d.sideBySideFrom,
      wideBleed: override?.wideBleed ?? installed?.wideBleed ?? d.wideBleed,
      borderColor:
          override?.borderColor ?? installed?.borderColor ?? d.borderColor,
      focusColor: override?.focusColor ?? installed?.focusColor ?? d.focusColor,
      toolbarInset:
          override?.toolbarInset ?? installed?.toolbarInset ?? d.toolbarInset,
      duration: override?.duration ?? installed?.duration ?? d.duration,
      curve: override?.curve ?? installed?.curve ?? d.curve,
      enterRise: override?.enterRise ?? installed?.enterRise ?? d.enterRise,
      enterDuration:
          override?.enterDuration ??
          installed?.enterDuration ??
          d.enterDuration,
      enterCurve: override?.enterCurve ?? installed?.enterCurve ?? d.enterCurve,
      pressScale: override?.pressScale ?? installed?.pressScale ?? d.pressScale,
    );
  }

  /// A copy with the given fields replaced.
  StudioBenchThemeData copyWith({
    Color? stageColor,
    double? stageRadius,
    EdgeInsets? stagePadding,
    EdgeInsets? stageCompactPadding,
    double? stageMinHeight,
    double? stageCompactMinHeight,
    Color? panelColor,
    double? panelRadius,
    EdgeInsets? panelPadding,
    double? panelWidth,
    double? panelGap,
    double? sideBySideFrom,
    double? wideBleed,
    Color? borderColor,
    Color? focusColor,
    double? toolbarInset,
    Duration? duration,
    Curve? curve,
    double? enterRise,
    Duration? enterDuration,
    Curve? enterCurve,
    double? pressScale,
  }) => StudioBenchThemeData(
    stageColor: stageColor ?? this.stageColor,
    stageRadius: stageRadius ?? this.stageRadius,
    stagePadding: stagePadding ?? this.stagePadding,
    stageCompactPadding: stageCompactPadding ?? this.stageCompactPadding,
    stageMinHeight: stageMinHeight ?? this.stageMinHeight,
    stageCompactMinHeight: stageCompactMinHeight ?? this.stageCompactMinHeight,
    panelColor: panelColor ?? this.panelColor,
    panelRadius: panelRadius ?? this.panelRadius,
    panelPadding: panelPadding ?? this.panelPadding,
    panelWidth: panelWidth ?? this.panelWidth,
    panelGap: panelGap ?? this.panelGap,
    sideBySideFrom: sideBySideFrom ?? this.sideBySideFrom,
    wideBleed: wideBleed ?? this.wideBleed,
    borderColor: borderColor ?? this.borderColor,
    focusColor: focusColor ?? this.focusColor,
    toolbarInset: toolbarInset ?? this.toolbarInset,
    duration: duration ?? this.duration,
    curve: curve ?? this.curve,
    enterRise: enterRise ?? this.enterRise,
    enterDuration: enterDuration ?? this.enterDuration,
    enterCurve: enterCurve ?? this.enterCurve,
    pressScale: pressScale ?? this.pressScale,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StudioBenchThemeData &&
          other.stageColor == stageColor &&
          other.stageRadius == stageRadius &&
          other.stagePadding == stagePadding &&
          other.stageCompactPadding == stageCompactPadding &&
          other.stageMinHeight == stageMinHeight &&
          other.stageCompactMinHeight == stageCompactMinHeight &&
          other.panelColor == panelColor &&
          other.panelRadius == panelRadius &&
          other.panelPadding == panelPadding &&
          other.panelWidth == panelWidth &&
          other.panelGap == panelGap &&
          other.sideBySideFrom == sideBySideFrom &&
          other.wideBleed == wideBleed &&
          other.borderColor == borderColor &&
          other.focusColor == focusColor &&
          other.toolbarInset == toolbarInset &&
          other.duration == duration &&
          other.curve == curve &&
          other.enterRise == enterRise &&
          other.enterDuration == enterDuration &&
          other.enterCurve == enterCurve &&
          other.pressScale == pressScale);

  @override
  int get hashCode => Object.hashAll([
    stageColor,
    stageRadius,
    stagePadding,
    stageCompactPadding,
    stageMinHeight,
    stageCompactMinHeight,
    panelColor,
    panelRadius,
    panelPadding,
    panelWidth,
    panelGap,
    sideBySideFrom,
    wideBleed,
    borderColor,
    focusColor,
    toolbarInset,
    duration,
    curve,
    enterRise,
    enterDuration,
    enterCurve,
    pressScale,
  ]);
}

/// The effective look of a bench: [StudioBenchThemeData.of] with every field set. It is a
/// [StudioBenchThemeData] too, so it can be handed to a widget's `theme:` parameter.
class StudioBenchThemeResolved extends StudioBenchThemeData {
  /// Creates the resolved values.
  const StudioBenchThemeResolved({
    required Color stageColor,
    required double stageRadius,
    required EdgeInsets stagePadding,
    required EdgeInsets stageCompactPadding,
    required double stageMinHeight,
    required double stageCompactMinHeight,
    required Color panelColor,
    required double panelRadius,
    required EdgeInsets panelPadding,
    required double panelWidth,
    required double panelGap,
    required double sideBySideFrom,
    required double wideBleed,
    required Color borderColor,
    required Color focusColor,
    required double toolbarInset,
    required Duration duration,
    required Curve curve,
    required double enterRise,
    required Duration enterDuration,
    required Curve enterCurve,
    required double pressScale,
  }) : _stageColor = stageColor,
       _stageRadius = stageRadius,
       _stagePadding = stagePadding,
       _stageCompactPadding = stageCompactPadding,
       _stageMinHeight = stageMinHeight,
       _stageCompactMinHeight = stageCompactMinHeight,
       _panelColor = panelColor,
       _panelRadius = panelRadius,
       _panelPadding = panelPadding,
       _panelWidth = panelWidth,
       _panelGap = panelGap,
       _sideBySideFrom = sideBySideFrom,
       _wideBleed = wideBleed,
       _borderColor = borderColor,
       _focusColor = focusColor,
       _toolbarInset = toolbarInset,
       _duration = duration,
       _curve = curve,
       _enterRise = enterRise,
       _enterDuration = enterDuration,
       _enterCurve = enterCurve,
       _pressScale = pressScale,
       super(
         stageColor: stageColor,
         stageRadius: stageRadius,
         stagePadding: stagePadding,
         stageCompactPadding: stageCompactPadding,
         stageMinHeight: stageMinHeight,
         stageCompactMinHeight: stageCompactMinHeight,
         panelColor: panelColor,
         panelRadius: panelRadius,
         panelPadding: panelPadding,
         panelWidth: panelWidth,
         panelGap: panelGap,
         sideBySideFrom: sideBySideFrom,
         wideBleed: wideBleed,
         borderColor: borderColor,
         focusColor: focusColor,
         toolbarInset: toolbarInset,
         duration: duration,
         curve: curve,
         enterRise: enterRise,
         enterDuration: enterDuration,
         enterCurve: enterCurve,
         pressScale: pressScale,
       );

  final Color _stageColor;

  @override
  Color get stageColor => _stageColor;

  final double _stageRadius;

  @override
  double get stageRadius => _stageRadius;

  final EdgeInsets _stagePadding;

  @override
  EdgeInsets get stagePadding => _stagePadding;

  final EdgeInsets _stageCompactPadding;

  @override
  EdgeInsets get stageCompactPadding => _stageCompactPadding;

  final double _stageMinHeight;

  @override
  double get stageMinHeight => _stageMinHeight;

  final double _stageCompactMinHeight;

  @override
  double get stageCompactMinHeight => _stageCompactMinHeight;

  final Color _panelColor;

  @override
  Color get panelColor => _panelColor;

  final double _panelRadius;

  @override
  double get panelRadius => _panelRadius;

  final EdgeInsets _panelPadding;

  @override
  EdgeInsets get panelPadding => _panelPadding;

  final double _panelWidth;

  @override
  double get panelWidth => _panelWidth;

  final double _panelGap;

  @override
  double get panelGap => _panelGap;

  final double _sideBySideFrom;

  @override
  double get sideBySideFrom => _sideBySideFrom;

  final double _wideBleed;

  @override
  double get wideBleed => _wideBleed;

  final Color _borderColor;

  @override
  Color get borderColor => _borderColor;

  final Color _focusColor;

  @override
  Color get focusColor => _focusColor;

  final double _toolbarInset;

  @override
  double get toolbarInset => _toolbarInset;

  final Duration _duration;

  @override
  Duration get duration => _duration;

  final Curve _curve;

  @override
  Curve get curve => _curve;

  final double _enterRise;

  @override
  double get enterRise => _enterRise;

  final Duration _enterDuration;

  @override
  Duration get enterDuration => _enterDuration;

  final Curve _enterCurve;

  @override
  Curve get enterCurve => _enterCurve;

  final double _pressScale;

  @override
  double get pressScale => _pressScale;
}

/// The defaults of the bench theme: every value from the theme's color
/// scheme, text theme and the studio's tokens (Flutter's `_Defaults(context)`).
class _StudioBenchThemeDefaults {
  _StudioBenchThemeDefaults(ThemeData theme)
    : s = theme.colorScheme,
      x = theme.extension<StudioExtraColors>() ?? StudioExtraColors.standard;

  final ColorScheme s;
  final StudioExtraColors x;

  Color get stageColor => StudioBenchColors.stage;
  double get stageRadius => StudioRadii.card;
  EdgeInsets get stagePadding => const EdgeInsets.all(StudioSpacing.xl);
  EdgeInsets get stageCompactPadding => const EdgeInsets.all(StudioSpacing.md);
  double get stageMinHeight => 240;
  double get stageCompactMinHeight => 148;
  Color get panelColor => s.surfaceContainer;
  double get panelRadius => StudioRadii.card;
  EdgeInsets get panelPadding => const EdgeInsets.all(StudioSpacing.lg);
  double get panelWidth => 288;
  double get panelGap => StudioSpacing.md;
  double get sideBySideFrom => 640;
  double get wideBleed => 96;
  Color get borderColor => s.outlineVariant;
  Color get focusColor => s.accent;
  double get toolbarInset => StudioSpacing.sm;
  Duration get duration => StudioDurations.base;
  Curve get curve => StudioCurves.move;
  double get enterRise => StudioMotion.enterRise;
  Duration get enterDuration => StudioDurations.slow;
  Curve get enterCurve => StudioCurves.enter;
  double get pressScale => StudioMotion.pressScale;
}
