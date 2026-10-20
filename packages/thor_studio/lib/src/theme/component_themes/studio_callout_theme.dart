import 'package:thor_ui/thor_ui.dart';

import '../../tokens/color/studio_tone_colors.dart';
import '../../tokens/shape/studio_radii.dart';
import '../../tokens/spacing/studio_spacing.dart';
import '../studio_extra_colors.dart';

/// The look of a callout (a note, a tip, a warning): a tinted inner block
/// with a tone's icon, border and background.
///
/// Every field is optional: the widgets resolve each one as the widget's own
/// parameter, then this theme, then a default derived from
/// `Theme.of(context).colorScheme` and `textTheme`, so a `copyWith(primary:)` on
/// the color scheme reaches the component. Install an override next to the
/// others (`ThemeData(extensions: [StudioCalloutThemeData(radius: 8)])`) and read the effective
/// values with [StudioCalloutThemeData.of].
class StudioCalloutThemeData extends ThemeExtension<StudioCalloutThemeData> {
  /// Creates a callout theme; a null field keeps the default.
  const StudioCalloutThemeData({
    this.info,
    this.ok,
    this.warn,
    this.danger,
    this.flutter,
    this.radius,
    this.padding,
    this.iconSize,
    this.gap,
  });

  /// The information tone.
  final StudioToneColors? info;

  /// The success tone.
  final StudioToneColors? ok;

  /// The warning tone.
  final StudioToneColors? warn;

  /// The error tone.
  final StudioToneColors? danger;

  /// The "how Flutter does it" tone.
  final StudioToneColors? flutter;

  /// The corner radius.
  final double? radius;

  /// The space between the border and the content.
  final EdgeInsets? padding;

  /// The tone icon's size.
  final double? iconSize;

  /// The space between the icon and the text.
  final double? gap;

  /// The override installed on the nearest theme, or null.
  static StudioCalloutThemeData? maybeOf(BuildContext context) =>
      Theme.of(context).extension<StudioCalloutThemeData>();

  /// The effective values of the nearest theme: [override] (a widget's
  /// `theme:` parameter), then the installed theme, then the defaults of the
  /// theme's color scheme and text theme.
  static StudioCalloutThemeResolved of(
    BuildContext context, [
    StudioCalloutThemeData? override,
  ]) => resolve(Theme.of(context), override);

  /// The effective values of [theme] (for code with no `BuildContext`).
  static StudioCalloutThemeResolved resolve(
    ThemeData theme, [
    StudioCalloutThemeData? override,
  ]) {
    final installed = theme.extension<StudioCalloutThemeData>();
    final d = _StudioCalloutThemeDefaults(theme);
    return StudioCalloutThemeResolved(
      info: override?.info ?? installed?.info ?? d.info,
      ok: override?.ok ?? installed?.ok ?? d.ok,
      warn: override?.warn ?? installed?.warn ?? d.warn,
      danger: override?.danger ?? installed?.danger ?? d.danger,
      flutter: override?.flutter ?? installed?.flutter ?? d.flutter,
      radius: override?.radius ?? installed?.radius ?? d.radius,
      padding: override?.padding ?? installed?.padding ?? d.padding,
      iconSize: override?.iconSize ?? installed?.iconSize ?? d.iconSize,
      gap: override?.gap ?? installed?.gap ?? d.gap,
    );
  }

  /// A copy with the given fields replaced.
  StudioCalloutThemeData copyWith({
    StudioToneColors? info,
    StudioToneColors? ok,
    StudioToneColors? warn,
    StudioToneColors? danger,
    StudioToneColors? flutter,
    double? radius,
    EdgeInsets? padding,
    double? iconSize,
    double? gap,
  }) => StudioCalloutThemeData(
    info: info ?? this.info,
    ok: ok ?? this.ok,
    warn: warn ?? this.warn,
    danger: danger ?? this.danger,
    flutter: flutter ?? this.flutter,
    radius: radius ?? this.radius,
    padding: padding ?? this.padding,
    iconSize: iconSize ?? this.iconSize,
    gap: gap ?? this.gap,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StudioCalloutThemeData &&
          other.info == info &&
          other.ok == ok &&
          other.warn == warn &&
          other.danger == danger &&
          other.flutter == flutter &&
          other.radius == radius &&
          other.padding == padding &&
          other.iconSize == iconSize &&
          other.gap == gap);

  @override
  int get hashCode => Object.hashAll([
    info,
    ok,
    warn,
    danger,
    flutter,
    radius,
    padding,
    iconSize,
    gap,
  ]);
}

/// The effective look of a callout: [StudioCalloutThemeData.of] with every field set. It is a
/// [StudioCalloutThemeData] too, so it can be handed to a widget's `theme:` parameter.
class StudioCalloutThemeResolved extends StudioCalloutThemeData {
  /// Creates the resolved values.
  const StudioCalloutThemeResolved({
    required StudioToneColors info,
    required StudioToneColors ok,
    required StudioToneColors warn,
    required StudioToneColors danger,
    required StudioToneColors flutter,
    required double radius,
    required EdgeInsets padding,
    required double iconSize,
    required double gap,
  }) : _info = info,
       _ok = ok,
       _warn = warn,
       _danger = danger,
       _flutter = flutter,
       _radius = radius,
       _padding = padding,
       _iconSize = iconSize,
       _gap = gap,
       super(
         info: info,
         ok: ok,
         warn: warn,
         danger: danger,
         flutter: flutter,
         radius: radius,
         padding: padding,
         iconSize: iconSize,
         gap: gap,
       );

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

  final StudioToneColors _flutter;

  @override
  StudioToneColors get flutter => _flutter;

  final double _radius;

  @override
  double get radius => _radius;

  final EdgeInsets _padding;

  @override
  EdgeInsets get padding => _padding;

  final double _iconSize;

  @override
  double get iconSize => _iconSize;

  final double _gap;

  @override
  double get gap => _gap;
}

/// The defaults of the callout theme: every value from the theme's color
/// scheme, text theme and the studio's tokens (Flutter's `_Defaults(context)`).
class _StudioCalloutThemeDefaults {
  _StudioCalloutThemeDefaults(ThemeData theme)
    : x = theme.extension<StudioExtraColors>() ?? StudioExtraColors.standard;

  final StudioExtraColors x;

  StudioToneColors get info => x.infoTone;
  StudioToneColors get ok => x.okTone;
  StudioToneColors get warn => x.warnTone;
  StudioToneColors get danger => x.dangerTone;
  StudioToneColors get flutter => x.flutterTone;
  double get radius => StudioRadii.inner;
  EdgeInsets get padding =>
      const EdgeInsets.symmetric(horizontal: StudioSpacing.md, vertical: 14);
  double get iconSize => 16;
  double get gap => StudioSpacing.sm;
}
