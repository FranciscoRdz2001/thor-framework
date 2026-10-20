import 'package:thor_ui/thor_ui.dart';

import '../../tokens/elevation/studio_shadows.dart';
import '../../tokens/shape/studio_radii.dart';
import '../../tokens/spacing/studio_layout.dart';
import '../../tokens/spacing/studio_spacing.dart';
import '../studio_extra_colors.dart';

/// The look of the floating side panels (navigation, "on this page"): a
/// card that sticks under the top bar and scrolls inside itself.
///
/// Every field is optional: the widgets resolve each one as the widget's own
/// parameter, then this theme, then a default derived from
/// `Theme.of(context).colorScheme` and `textTheme`, so a `copyWith(primary:)` on
/// the color scheme reaches the component. Install an override next to the
/// others (`ThemeData(extensions: [StudioPanelThemeData(radius: 8)])`) and read the effective
/// values with [StudioPanelThemeData.of].
class StudioPanelThemeData extends ThemeExtension<StudioPanelThemeData> {
  /// Creates a panel theme; a null field keeps the default.
  const StudioPanelThemeData({
    this.color,
    this.borderColor,
    this.titleColor,
    this.radius,
    this.padding,
    this.width,
    this.gap,
    this.shadows,
  });

  /// The panel's surface.
  final Color? color;

  /// The hairline around it.
  final Color? borderColor;

  /// The color of a panel's title.
  final Color? titleColor;

  /// The corner radius.
  final double? radius;

  /// The space between the border and the content.
  final EdgeInsets? padding;

  /// The panel's width in a workspace.
  final double? width;

  /// The gap between panels and the page edge.
  final double? gap;

  /// The panel's shadows.
  final List<BoxShadow>? shadows;

  /// The override installed on the nearest theme, or null.
  static StudioPanelThemeData? maybeOf(BuildContext context) =>
      Theme.of(context).extension<StudioPanelThemeData>();

  /// The effective values of the nearest theme: [override] (a widget's
  /// `theme:` parameter), then the installed theme, then the defaults of the
  /// theme's color scheme and text theme.
  static StudioPanelThemeResolved of(
    BuildContext context, [
    StudioPanelThemeData? override,
  ]) => resolve(Theme.of(context), override);

  /// The effective values of [theme] (for code with no `BuildContext`).
  static StudioPanelThemeResolved resolve(
    ThemeData theme, [
    StudioPanelThemeData? override,
  ]) {
    final installed = theme.extension<StudioPanelThemeData>();
    final d = _StudioPanelThemeDefaults(theme);
    return StudioPanelThemeResolved(
      color: override?.color ?? installed?.color ?? d.color,
      borderColor:
          override?.borderColor ?? installed?.borderColor ?? d.borderColor,
      titleColor: override?.titleColor ?? installed?.titleColor ?? d.titleColor,
      radius: override?.radius ?? installed?.radius ?? d.radius,
      padding: override?.padding ?? installed?.padding ?? d.padding,
      width: override?.width ?? installed?.width ?? d.width,
      gap: override?.gap ?? installed?.gap ?? d.gap,
      shadows: override?.shadows ?? installed?.shadows ?? d.shadows,
    );
  }

  /// A copy with the given fields replaced.
  StudioPanelThemeData copyWith({
    Color? color,
    Color? borderColor,
    Color? titleColor,
    double? radius,
    EdgeInsets? padding,
    double? width,
    double? gap,
    List<BoxShadow>? shadows,
  }) => StudioPanelThemeData(
    color: color ?? this.color,
    borderColor: borderColor ?? this.borderColor,
    titleColor: titleColor ?? this.titleColor,
    radius: radius ?? this.radius,
    padding: padding ?? this.padding,
    width: width ?? this.width,
    gap: gap ?? this.gap,
    shadows: shadows ?? this.shadows,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StudioPanelThemeData &&
          other.color == color &&
          other.borderColor == borderColor &&
          other.titleColor == titleColor &&
          other.radius == radius &&
          other.padding == padding &&
          other.width == width &&
          other.gap == gap &&
          other.shadows == shadows);

  @override
  int get hashCode => Object.hashAll([
    color,
    borderColor,
    titleColor,
    radius,
    padding,
    width,
    gap,
    shadows,
  ]);
}

/// The effective look of a panel: [StudioPanelThemeData.of] with every field set. It is a
/// [StudioPanelThemeData] too, so it can be handed to a widget's `theme:` parameter.
class StudioPanelThemeResolved extends StudioPanelThemeData {
  /// Creates the resolved values.
  const StudioPanelThemeResolved({
    required Color color,
    required Color borderColor,
    required Color titleColor,
    required double radius,
    required EdgeInsets padding,
    required double width,
    required double gap,
    required List<BoxShadow> shadows,
  }) : _color = color,
       _borderColor = borderColor,
       _titleColor = titleColor,
       _radius = radius,
       _padding = padding,
       _width = width,
       _gap = gap,
       _shadows = shadows,
       super(
         color: color,
         borderColor: borderColor,
         titleColor: titleColor,
         radius: radius,
         padding: padding,
         width: width,
         gap: gap,
         shadows: shadows,
       );

  final Color _color;

  @override
  Color get color => _color;

  final Color _borderColor;

  @override
  Color get borderColor => _borderColor;

  final Color _titleColor;

  @override
  Color get titleColor => _titleColor;

  final double _radius;

  @override
  double get radius => _radius;

  final EdgeInsets _padding;

  @override
  EdgeInsets get padding => _padding;

  final double _width;

  @override
  double get width => _width;

  final double _gap;

  @override
  double get gap => _gap;

  final List<BoxShadow> _shadows;

  @override
  List<BoxShadow> get shadows => _shadows;
}

/// The defaults of the panel theme: every value from the theme's color
/// scheme, text theme and the studio's tokens (Flutter's `_Defaults(context)`).
class _StudioPanelThemeDefaults {
  _StudioPanelThemeDefaults(ThemeData theme)
    : s = theme.colorScheme,
      x = theme.extension<StudioExtraColors>() ?? StudioExtraColors.standard;

  final ColorScheme s;
  final StudioExtraColors x;

  Color get color => s.surfaceContainer;
  Color get borderColor => s.outlineVariant;
  Color get titleColor => x.onSurfaceSoft;
  double get radius => StudioRadii.card;
  EdgeInsets get padding => const EdgeInsets.all(StudioSpacing.md);
  double get width => StudioLayout.panelWidth;
  double get gap => StudioLayout.gap;
  List<BoxShadow> get shadows => StudioShadows.none;
}
