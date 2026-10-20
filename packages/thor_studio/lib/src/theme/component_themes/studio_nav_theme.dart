import 'package:thor_ui/thor_ui.dart';

import '../../tokens/motion/studio_curves.dart';
import '../../tokens/motion/studio_durations.dart';
import '../../tokens/motion/studio_motion.dart';
import '../../tokens/shape/studio_radii.dart';
import '../../tokens/spacing/studio_layout.dart';
import '../../tokens/spacing/studio_spacing.dart';
import '../studio_extra_colors.dart';

/// The look of navigation: the top bar, its links and the sidebar items,
/// like Flutter's `NavigationBarThemeData` and `NavigationRailThemeData`
/// in one. Items are pills; the current one carries `aria-current="page"`
/// and the raised surface.
///
/// Every field is optional: the widgets resolve each one as the widget's own
/// parameter, then this theme, then a default derived from
/// `Theme.of(context).colorScheme` and `textTheme`, so a `copyWith(primary:)` on
/// the color scheme reaches the component. Install an override next to the
/// others (`ThemeData(extensions: [StudioNavThemeData(radius: 8)])`) and read the effective
/// values with [StudioNavThemeData.of].
class StudioNavThemeData extends ThemeExtension<StudioNavThemeData> {
  /// Creates a nav theme; a null field keeps the default.
  const StudioNavThemeData({
    this.barHeight,
    this.barColor,
    this.barBorderColor,
    this.itemRadius,
    this.itemPadding,
    this.itemColor,
    this.itemHoverColor,
    this.selectedItemColor,
    this.selectedItemBackground,
    this.currentMarkColor,
    this.searchColor,
    this.searchHoverColor,
    this.searchHeight,
    this.searchMaxWidth,
    this.hintColor,
    this.hintBackground,
    this.sectionTitleColor,
    this.duration,
    this.curve,
    this.pressScale,
    this.pressDuration,
    this.toggleDuration,
    this.toggleEnterScale,
    this.iconSize,
  });

  /// The top bar's height.
  final double? barHeight;

  /// The top bar's background.
  final Color? barColor;

  /// The hairline under the top bar.
  final Color? barBorderColor;

  /// The corner radius of a link or sidebar item (a pill).
  final double? itemRadius;

  /// The space inside a link or sidebar item.
  final EdgeInsets? itemPadding;

  /// Link and item text.
  final Color? itemColor;

  /// An item's background under the pointer.
  final Color? itemHoverColor;

  /// The current item's text.
  final Color? selectedItemColor;

  /// The current item's background.
  final Color? selectedItemBackground;

  /// The current item's mark: the text of the current top bar area (on
  /// [selectedItemBackground]), the accent like every "you are here".
  final Color? currentMarkColor;

  /// The search pill's surface.
  final Color? searchColor;

  /// The search pill's surface under the pointer.
  final Color? searchHoverColor;

  /// The search pill's height.
  final double? searchHeight;

  /// The widest the search pill grows to in the top bar.
  final double? searchMaxWidth;

  /// The keyboard hint's text (`⌘K`) and the search placeholder.
  final Color? hintColor;

  /// The keyboard hint's background.
  final Color? hintBackground;

  /// The title of a sidebar section, on the page surface.
  final Color? sectionTitleColor;

  /// How long an item takes to change color.
  final Duration? duration;

  /// The easing of that change.
  final Curve? curve;

  /// The scale of a link, a pill or an icon link while pressed.
  final double? pressScale;

  /// How long the press squeeze takes.
  final Duration? pressDuration;

  /// How long the theme toggle's icon takes to turn in.
  final Duration? toggleDuration;

  /// The scale the theme toggle's icon grows from as it turns in.
  final double? toggleEnterScale;

  /// The side of a navigation icon (the theme toggle, a pager arrow).
  final double? iconSize;

  /// The override installed on the nearest theme, or null.
  static StudioNavThemeData? maybeOf(BuildContext context) =>
      Theme.of(context).extension<StudioNavThemeData>();

  /// The effective values of the nearest theme: [override] (a widget's
  /// `theme:` parameter), then the installed theme, then the defaults of the
  /// theme's color scheme and text theme.
  static StudioNavThemeResolved of(
    BuildContext context, [
    StudioNavThemeData? override,
  ]) => resolve(Theme.of(context), override);

  /// The effective values of [theme] (for code with no `BuildContext`).
  static StudioNavThemeResolved resolve(
    ThemeData theme, [
    StudioNavThemeData? override,
  ]) {
    final installed = theme.extension<StudioNavThemeData>();
    final d = _StudioNavThemeDefaults(theme);
    return StudioNavThemeResolved(
      barHeight: override?.barHeight ?? installed?.barHeight ?? d.barHeight,
      barColor: override?.barColor ?? installed?.barColor ?? d.barColor,
      barBorderColor:
          override?.barBorderColor ??
          installed?.barBorderColor ??
          d.barBorderColor,
      itemRadius: override?.itemRadius ?? installed?.itemRadius ?? d.itemRadius,
      itemPadding:
          override?.itemPadding ?? installed?.itemPadding ?? d.itemPadding,
      itemColor: override?.itemColor ?? installed?.itemColor ?? d.itemColor,
      itemHoverColor:
          override?.itemHoverColor ??
          installed?.itemHoverColor ??
          d.itemHoverColor,
      selectedItemColor:
          override?.selectedItemColor ??
          installed?.selectedItemColor ??
          d.selectedItemColor,
      selectedItemBackground:
          override?.selectedItemBackground ??
          installed?.selectedItemBackground ??
          d.selectedItemBackground,
      currentMarkColor:
          override?.currentMarkColor ??
          installed?.currentMarkColor ??
          d.currentMarkColor,
      searchColor:
          override?.searchColor ?? installed?.searchColor ?? d.searchColor,
      searchHoverColor:
          override?.searchHoverColor ??
          installed?.searchHoverColor ??
          d.searchHoverColor,
      searchHeight:
          override?.searchHeight ?? installed?.searchHeight ?? d.searchHeight,
      searchMaxWidth:
          override?.searchMaxWidth ??
          installed?.searchMaxWidth ??
          d.searchMaxWidth,
      hintColor: override?.hintColor ?? installed?.hintColor ?? d.hintColor,
      hintBackground:
          override?.hintBackground ??
          installed?.hintBackground ??
          d.hintBackground,
      sectionTitleColor:
          override?.sectionTitleColor ??
          installed?.sectionTitleColor ??
          d.sectionTitleColor,
      duration: override?.duration ?? installed?.duration ?? d.duration,
      curve: override?.curve ?? installed?.curve ?? d.curve,
      pressScale: override?.pressScale ?? installed?.pressScale ?? d.pressScale,
      pressDuration:
          override?.pressDuration ??
          installed?.pressDuration ??
          d.pressDuration,
      toggleDuration:
          override?.toggleDuration ??
          installed?.toggleDuration ??
          d.toggleDuration,
      toggleEnterScale:
          override?.toggleEnterScale ??
          installed?.toggleEnterScale ??
          d.toggleEnterScale,
      iconSize: override?.iconSize ?? installed?.iconSize ?? d.iconSize,
    );
  }

  /// A copy with the given fields replaced.
  StudioNavThemeData copyWith({
    double? barHeight,
    Color? barColor,
    Color? barBorderColor,
    double? itemRadius,
    EdgeInsets? itemPadding,
    Color? itemColor,
    Color? itemHoverColor,
    Color? selectedItemColor,
    Color? selectedItemBackground,
    Color? currentMarkColor,
    Color? searchColor,
    Color? searchHoverColor,
    double? searchHeight,
    double? searchMaxWidth,
    Color? hintColor,
    Color? hintBackground,
    Color? sectionTitleColor,
    Duration? duration,
    Curve? curve,
    double? pressScale,
    Duration? pressDuration,
    Duration? toggleDuration,
    double? toggleEnterScale,
    double? iconSize,
  }) => StudioNavThemeData(
    barHeight: barHeight ?? this.barHeight,
    barColor: barColor ?? this.barColor,
    barBorderColor: barBorderColor ?? this.barBorderColor,
    itemRadius: itemRadius ?? this.itemRadius,
    itemPadding: itemPadding ?? this.itemPadding,
    itemColor: itemColor ?? this.itemColor,
    itemHoverColor: itemHoverColor ?? this.itemHoverColor,
    selectedItemColor: selectedItemColor ?? this.selectedItemColor,
    selectedItemBackground:
        selectedItemBackground ?? this.selectedItemBackground,
    currentMarkColor: currentMarkColor ?? this.currentMarkColor,
    searchColor: searchColor ?? this.searchColor,
    searchHoverColor: searchHoverColor ?? this.searchHoverColor,
    searchHeight: searchHeight ?? this.searchHeight,
    searchMaxWidth: searchMaxWidth ?? this.searchMaxWidth,
    hintColor: hintColor ?? this.hintColor,
    hintBackground: hintBackground ?? this.hintBackground,
    sectionTitleColor: sectionTitleColor ?? this.sectionTitleColor,
    duration: duration ?? this.duration,
    curve: curve ?? this.curve,
    pressScale: pressScale ?? this.pressScale,
    pressDuration: pressDuration ?? this.pressDuration,
    toggleDuration: toggleDuration ?? this.toggleDuration,
    toggleEnterScale: toggleEnterScale ?? this.toggleEnterScale,
    iconSize: iconSize ?? this.iconSize,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StudioNavThemeData &&
          other.barHeight == barHeight &&
          other.barColor == barColor &&
          other.barBorderColor == barBorderColor &&
          other.itemRadius == itemRadius &&
          other.itemPadding == itemPadding &&
          other.itemColor == itemColor &&
          other.itemHoverColor == itemHoverColor &&
          other.selectedItemColor == selectedItemColor &&
          other.selectedItemBackground == selectedItemBackground &&
          other.currentMarkColor == currentMarkColor &&
          other.searchColor == searchColor &&
          other.searchHoverColor == searchHoverColor &&
          other.searchHeight == searchHeight &&
          other.searchMaxWidth == searchMaxWidth &&
          other.hintColor == hintColor &&
          other.hintBackground == hintBackground &&
          other.sectionTitleColor == sectionTitleColor &&
          other.duration == duration &&
          other.curve == curve &&
          other.pressScale == pressScale &&
          other.pressDuration == pressDuration &&
          other.toggleDuration == toggleDuration &&
          other.toggleEnterScale == toggleEnterScale &&
          other.iconSize == iconSize);

  @override
  int get hashCode => Object.hashAll([
    barHeight,
    barColor,
    barBorderColor,
    itemRadius,
    itemPadding,
    itemColor,
    itemHoverColor,
    selectedItemColor,
    selectedItemBackground,
    currentMarkColor,
    searchColor,
    searchHoverColor,
    searchHeight,
    searchMaxWidth,
    hintColor,
    hintBackground,
    sectionTitleColor,
    duration,
    curve,
    pressScale,
    pressDuration,
    toggleDuration,
    toggleEnterScale,
    iconSize,
  ]);
}

/// The effective look of a nav: [StudioNavThemeData.of] with every field set. It is a
/// [StudioNavThemeData] too, so it can be handed to a widget's `theme:` parameter.
class StudioNavThemeResolved extends StudioNavThemeData {
  /// Creates the resolved values.
  const StudioNavThemeResolved({
    required double barHeight,
    required Color barColor,
    required Color barBorderColor,
    required double itemRadius,
    required EdgeInsets itemPadding,
    required Color itemColor,
    required Color itemHoverColor,
    required Color selectedItemColor,
    required Color selectedItemBackground,
    required Color currentMarkColor,
    required Color searchColor,
    required Color searchHoverColor,
    required double searchHeight,
    required double searchMaxWidth,
    required Color hintColor,
    required Color hintBackground,
    required Color sectionTitleColor,
    required Duration duration,
    required Curve curve,
    required double pressScale,
    required Duration pressDuration,
    required Duration toggleDuration,
    required double toggleEnterScale,
    required double iconSize,
  }) : _barHeight = barHeight,
       _barColor = barColor,
       _barBorderColor = barBorderColor,
       _itemRadius = itemRadius,
       _itemPadding = itemPadding,
       _itemColor = itemColor,
       _itemHoverColor = itemHoverColor,
       _selectedItemColor = selectedItemColor,
       _selectedItemBackground = selectedItemBackground,
       _currentMarkColor = currentMarkColor,
       _searchColor = searchColor,
       _searchHoverColor = searchHoverColor,
       _searchHeight = searchHeight,
       _searchMaxWidth = searchMaxWidth,
       _hintColor = hintColor,
       _hintBackground = hintBackground,
       _sectionTitleColor = sectionTitleColor,
       _duration = duration,
       _curve = curve,
       _pressScale = pressScale,
       _pressDuration = pressDuration,
       _toggleDuration = toggleDuration,
       _toggleEnterScale = toggleEnterScale,
       _iconSize = iconSize,
       super(
         barHeight: barHeight,
         barColor: barColor,
         barBorderColor: barBorderColor,
         itemRadius: itemRadius,
         itemPadding: itemPadding,
         itemColor: itemColor,
         itemHoverColor: itemHoverColor,
         selectedItemColor: selectedItemColor,
         selectedItemBackground: selectedItemBackground,
         currentMarkColor: currentMarkColor,
         searchColor: searchColor,
         searchHoverColor: searchHoverColor,
         searchHeight: searchHeight,
         searchMaxWidth: searchMaxWidth,
         hintColor: hintColor,
         hintBackground: hintBackground,
         sectionTitleColor: sectionTitleColor,
         duration: duration,
         curve: curve,
         pressScale: pressScale,
         pressDuration: pressDuration,
         toggleDuration: toggleDuration,
         toggleEnterScale: toggleEnterScale,
         iconSize: iconSize,
       );

  final double _barHeight;

  @override
  double get barHeight => _barHeight;

  final Color _barColor;

  @override
  Color get barColor => _barColor;

  final Color _barBorderColor;

  @override
  Color get barBorderColor => _barBorderColor;

  final double _itemRadius;

  @override
  double get itemRadius => _itemRadius;

  final EdgeInsets _itemPadding;

  @override
  EdgeInsets get itemPadding => _itemPadding;

  final Color _itemColor;

  @override
  Color get itemColor => _itemColor;

  final Color _itemHoverColor;

  @override
  Color get itemHoverColor => _itemHoverColor;

  final Color _selectedItemColor;

  @override
  Color get selectedItemColor => _selectedItemColor;

  final Color _selectedItemBackground;

  @override
  Color get selectedItemBackground => _selectedItemBackground;

  final Color _currentMarkColor;

  @override
  Color get currentMarkColor => _currentMarkColor;

  final Color _searchColor;

  @override
  Color get searchColor => _searchColor;

  final Color _searchHoverColor;

  @override
  Color get searchHoverColor => _searchHoverColor;

  final double _searchHeight;

  @override
  double get searchHeight => _searchHeight;

  final double _searchMaxWidth;

  @override
  double get searchMaxWidth => _searchMaxWidth;

  final Color _hintColor;

  @override
  Color get hintColor => _hintColor;

  final Color _hintBackground;

  @override
  Color get hintBackground => _hintBackground;

  final Color _sectionTitleColor;

  @override
  Color get sectionTitleColor => _sectionTitleColor;

  final Duration _duration;

  @override
  Duration get duration => _duration;

  final Curve _curve;

  @override
  Curve get curve => _curve;

  final double _pressScale;

  @override
  double get pressScale => _pressScale;

  final Duration _pressDuration;

  @override
  Duration get pressDuration => _pressDuration;

  final Duration _toggleDuration;

  @override
  Duration get toggleDuration => _toggleDuration;

  final double _toggleEnterScale;

  @override
  double get toggleEnterScale => _toggleEnterScale;

  final double _iconSize;

  @override
  double get iconSize => _iconSize;
}

/// The defaults of the nav theme: every value from the theme's color
/// scheme, text theme and the studio's tokens (Flutter's `_Defaults(context)`).
class _StudioNavThemeDefaults {
  _StudioNavThemeDefaults(ThemeData theme)
    : s = theme.colorScheme,
      x = theme.extension<StudioExtraColors>() ?? StudioExtraColors.standard;

  final ColorScheme s;
  final StudioExtraColors x;

  double get barHeight => StudioLayout.topbarHeight;
  Color get barColor => s.surface;
  Color get barBorderColor => s.outlineVariant;
  double get itemRadius => StudioRadii.control;
  EdgeInsets get itemPadding =>
      const EdgeInsets.symmetric(horizontal: StudioSpacing.sm, vertical: 6);
  Color get itemColor => s.onSurfaceVariant ?? s.onSurface;
  Color get itemHoverColor => x.hover;
  Color get selectedItemColor => s.onSurface;
  Color get selectedItemBackground => s.accentContainer;
  Color get currentMarkColor => s.accent;
  Color get searchColor => s.surfaceContainerHighest ?? s.surfaceContainer;
  Color get searchHoverColor => x.hover;
  double get searchHeight => 36;
  double get searchMaxWidth => 240;
  Color get hintColor => s.onSurfaceVariant ?? s.onSurface;
  Color get hintBackground => s.surfaceContainer;
  Color get sectionTitleColor => s.onSurfaceVariant ?? s.onSurface;
  Duration get duration => StudioDurations.fast;
  Curve get curve => StudioCurves.enter;
  double get pressScale => StudioMotion.pressScale;
  Duration get pressDuration => StudioDurations.base;
  Duration get toggleDuration => StudioDurations.slow;
  double get toggleEnterScale => 0.6;
  double get iconSize => 18;
}
