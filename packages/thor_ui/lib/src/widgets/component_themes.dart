import 'package:thor_style/thor_style.dart';

import '../foundation/widget_state.dart';
import 'buttons.dart' show ButtonStyle;
import 'material.dart' show SnackBarBehavior;
import 'navigation_bar.dart' show NavigationDestinationLabelBehavior;

// Flutter's component themes (`ThemeData.cardTheme` and the like): one place
// for the look of a widget kind. A widget reads its theme when it builds, and
// the server writes the result into the widget's own class, so the page
// ships no extra CSS and the browser computes nothing: the same classes a
// widget with those parameters would get. Precedence, as in Flutter: the
// widget's own parameter, then the theme, then the widget's default.
//
// `// web:` colors are resolved on the server. Give them as `ThemeColor`
// variables (`ThemeColor.primary`, `ThemeColor.token('brand')`) so they follow
// the dark switch; a literal `Color` is the same in both themes.

/// Flutter's `CardThemeData`, subset: the default look of `Card`.
// web: no `shadowColor` or `surfaceTintColor` (the shadow is Material 3's
// two-layer one).
class CardThemeData {
  /// A card theme; null fields keep the defaults.
  const CardThemeData({
    this.color,
    this.elevation,
    this.margin,
    this.shape,
    this.clipBehavior,
  });

  /// Background (default: the surface-container-low color).
  final Color? color;

  /// Shadow elevation (default: 1).
  final double? elevation;

  /// Outer margin (default: 4 px on every side).
  final EdgeInsetsGeometry? margin;

  /// Corners and outline (default: 12 px rounded corners).
  final OutlinedBorder? shape;

  /// How to clip the content (default: `Clip.none`).
  final Clip? clipBehavior;

  /// A copy of this theme with the given fields replaced (Flutter's
  /// `CardThemeData.copyWith`).
  CardThemeData copyWith({
    Color? color,
    double? elevation,
    EdgeInsetsGeometry? margin,
    OutlinedBorder? shape,
    Clip? clipBehavior,
  }) => CardThemeData(
    color: color ?? this.color,
    elevation: elevation ?? this.elevation,
    margin: margin ?? this.margin,
    shape: shape ?? this.shape,
    clipBehavior: clipBehavior ?? this.clipBehavior,
  );
}

/// Flutter's `ChipThemeData`, subset: the default look of `Chip`, `InputChip`,
/// `FilterChip`, `ChoiceChip` and `ActionChip`.
class ChipThemeData {
  /// A chip theme; null fields keep the defaults.
  const ChipThemeData({
    this.backgroundColor,
    this.selectedColor,
    this.disabledColor,
    this.shape,
    this.side,
    this.labelStyle,
    this.padding,
    this.showCheckmark,
    this.deleteIconColor,
  });

  /// Fill.
  final Color? backgroundColor;

  /// Fill while selected (default: the secondary container).
  final Color? selectedColor;

  /// The background of a disabled chip (a chip with no callback). `// web:`
  /// the chip's faded look stays on top of it.
  final Color? disabledColor;

  /// Corner shape.
  final OutlinedBorder? shape;

  /// Outline (wins over the shape's side).
  final BorderSide? side;

  /// Font and color of the label.
  final TextStyle? labelStyle;

  /// Space around the label.
  final EdgeInsetsGeometry? padding;

  /// Whether a selected chip shows a check mark.
  final bool? showCheckmark;

  /// Color of the delete icon.
  final Color? deleteIconColor;

  /// A copy of this theme with the given fields replaced (Flutter's
  /// `ChipThemeData.copyWith`).
  ChipThemeData copyWith({
    Color? backgroundColor,
    Color? selectedColor,
    Color? disabledColor,
    OutlinedBorder? shape,
    BorderSide? side,
    TextStyle? labelStyle,
    EdgeInsetsGeometry? padding,
    bool? showCheckmark,
    Color? deleteIconColor,
  }) => ChipThemeData(
    backgroundColor: backgroundColor ?? this.backgroundColor,
    selectedColor: selectedColor ?? this.selectedColor,
    disabledColor: disabledColor ?? this.disabledColor,
    shape: shape ?? this.shape,
    side: side ?? this.side,
    labelStyle: labelStyle ?? this.labelStyle,
    padding: padding ?? this.padding,
    showCheckmark: showCheckmark ?? this.showCheckmark,
    deleteIconColor: deleteIconColor ?? this.deleteIconColor,
  );
}

/// Flutter's `ExpansionTileThemeData`, subset: the default look of
/// `ExpansionTile`.
class ExpansionTileThemeData {
  /// An expansion tile theme; null fields keep the defaults.
  const ExpansionTileThemeData({
    this.backgroundColor,
    this.collapsedBackgroundColor,
    this.iconColor,
    this.collapsedIconColor,
    this.textColor,
    this.collapsedTextColor,
    this.tilePadding,
    this.childrenPadding,
    this.shape,
    this.collapsedShape,
    this.hoverColor,
  });

  /// `// web:` not in Flutter: the header's fill under the pointer
  /// (`ExpansionTile.hoverColor`); transparent removes the tint.
  final Color? hoverColor;

  /// Fill while open.
  final Color? backgroundColor;

  /// Fill while closed.
  final Color? collapsedBackgroundColor;

  /// Chevron color while open (default: the primary color).
  final Color? iconColor;

  /// Chevron color while closed.
  final Color? collapsedIconColor;

  /// Header text color while open.
  final Color? textColor;

  /// Header text color while closed.
  final Color? collapsedTextColor;

  /// Padding of the header.
  final EdgeInsets? tilePadding;

  /// Padding around the children.
  final EdgeInsetsGeometry? childrenPadding;

  /// Shape while open.
  final OutlinedBorder? shape;

  /// Shape while closed.
  final OutlinedBorder? collapsedShape;

  /// A copy of this theme with the given fields replaced (Flutter's
  /// `ExpansionTileThemeData.copyWith`).
  ExpansionTileThemeData copyWith({
    Color? backgroundColor,
    Color? collapsedBackgroundColor,
    Color? iconColor,
    Color? collapsedIconColor,
    Color? textColor,
    Color? collapsedTextColor,
    EdgeInsets? tilePadding,
    EdgeInsetsGeometry? childrenPadding,
    OutlinedBorder? shape,
    OutlinedBorder? collapsedShape,
    Color? hoverColor,
  }) => ExpansionTileThemeData(
    backgroundColor: backgroundColor ?? this.backgroundColor,
    collapsedBackgroundColor:
        collapsedBackgroundColor ?? this.collapsedBackgroundColor,
    iconColor: iconColor ?? this.iconColor,
    collapsedIconColor: collapsedIconColor ?? this.collapsedIconColor,
    textColor: textColor ?? this.textColor,
    collapsedTextColor: collapsedTextColor ?? this.collapsedTextColor,
    tilePadding: tilePadding ?? this.tilePadding,
    childrenPadding: childrenPadding ?? this.childrenPadding,
    shape: shape ?? this.shape,
    collapsedShape: collapsedShape ?? this.collapsedShape,
    hoverColor: hoverColor ?? this.hoverColor,
  );
}

/// Flutter's `FilledButtonThemeData`: the default [ButtonStyle] of
/// `FilledButton` (the button's own `style` wins, field by field).
class FilledButtonThemeData {
  /// A theme for `FilledButton`.
  const FilledButtonThemeData({this.style});

  /// The default style.
  final ButtonStyle? style;

  /// A copy of this theme with the given fields replaced (Flutter's
  /// `FilledButtonThemeData.copyWith`).
  FilledButtonThemeData copyWith({ButtonStyle? style}) =>
      FilledButtonThemeData(style: style ?? this.style);
}

/// Flutter's `ElevatedButtonThemeData`: the default [ButtonStyle] of
/// `ElevatedButton`.
class ElevatedButtonThemeData {
  /// A theme for `ElevatedButton`.
  const ElevatedButtonThemeData({this.style});

  /// The default style.
  final ButtonStyle? style;

  /// A copy of this theme with the given fields replaced (Flutter's
  /// `ElevatedButtonThemeData.copyWith`).
  ElevatedButtonThemeData copyWith({ButtonStyle? style}) =>
      ElevatedButtonThemeData(style: style ?? this.style);
}

/// Flutter's `OutlinedButtonThemeData`: the default [ButtonStyle] of
/// `OutlinedButton`.
class OutlinedButtonThemeData {
  /// A theme for `OutlinedButton`.
  const OutlinedButtonThemeData({this.style});

  /// The default style.
  final ButtonStyle? style;

  /// A copy of this theme with the given fields replaced (Flutter's
  /// `OutlinedButtonThemeData.copyWith`).
  OutlinedButtonThemeData copyWith({ButtonStyle? style}) =>
      OutlinedButtonThemeData(style: style ?? this.style);
}

/// Flutter's `TextButtonThemeData`: the default [ButtonStyle] of
/// `TextButton`.
class TextButtonThemeData {
  /// A theme for `TextButton`.
  const TextButtonThemeData({this.style});

  /// The default style.
  final ButtonStyle? style;

  /// A copy of this theme with the given fields replaced (Flutter's
  /// `TextButtonThemeData.copyWith`).
  TextButtonThemeData copyWith({ButtonStyle? style}) =>
      TextButtonThemeData(style: style ?? this.style);
}

/// Flutter's `IconButtonThemeData`: the default [ButtonStyle] of every
/// `IconButton` (plain, `.filled`, `.filledTonal` and `.outlined`).
class IconButtonThemeData {
  /// A theme for `IconButton`.
  const IconButtonThemeData({this.style});

  /// The default style.
  final ButtonStyle? style;

  /// A copy of this theme with the given fields replaced (Flutter's
  /// `IconButtonThemeData.copyWith`).
  IconButtonThemeData copyWith({ButtonStyle? style}) =>
      IconButtonThemeData(style: style ?? this.style);
}

/// Flutter's `DividerThemeData`: the default look of `Divider` and
/// `VerticalDivider`.
class DividerThemeData {
  /// A divider theme; null fields keep the defaults.
  const DividerThemeData({
    this.color,
    this.space,
    this.thickness,
    this.indent,
    this.endIndent,
  });

  /// Line color (default: the outline-variant color).
  final Color? color;

  /// The room the divider takes across its axis, line included (default:
  /// 16).
  final double? space;

  /// Line thickness (default: 1).
  final double? thickness;

  /// Empty space before the line's start (default: 0).
  final double? indent;

  /// Empty space after the line's end (default: 0).
  final double? endIndent;

  /// A copy of this theme with the given fields replaced (Flutter's
  /// `DividerThemeData.copyWith`).
  DividerThemeData copyWith({
    Color? color,
    double? space,
    double? thickness,
    double? indent,
    double? endIndent,
  }) => DividerThemeData(
    color: color ?? this.color,
    space: space ?? this.space,
    thickness: thickness ?? this.thickness,
    indent: indent ?? this.indent,
    endIndent: endIndent ?? this.endIndent,
  );
}

/// Flutter's `DialogThemeData`, subset: the default look of `AlertDialog`
/// and `Dialog`.
// web: no `shadowColor`, `surfaceTintColor`, `alignment`, `iconColor` nor
// `clipBehavior` (the dialog is a native `<dialog>` in the top layer).
class DialogThemeData {
  /// A dialog theme; null fields keep the defaults.
  const DialogThemeData({
    this.backgroundColor,
    this.elevation,
    this.shape,
    this.titleTextStyle,
    this.contentTextStyle,
    this.actionsPadding,
    this.barrierColor,
    this.barrierFilter,
    this.insetPadding,
    this.constraints,
  });

  /// Surface color (default: the surface-container-high color).
  final Color? backgroundColor;

  /// Shadow elevation. `// web:` Material 3's dialog shadow for the default,
  /// a one-layer shadow of this depth otherwise; 0 draws none.
  final double? elevation;

  /// Corners and outline (default: 28 px rounded corners).
  final OutlinedBorder? shape;

  /// Font and color of an `AlertDialog` title.
  final TextStyle? titleTextStyle;

  /// Font and color of an `AlertDialog` content.
  final TextStyle? contentTextStyle;

  /// Space around an `AlertDialog`'s actions.
  final EdgeInsetsGeometry? actionsPadding;

  /// The color behind the dialog (default: 32 % black).
  final Color? barrierColor;

  /// A filter over what is behind the dialog, e.g. `ImageFilter.blur(sigmaX:
  /// 3, sigmaY: 3)` (default: none). `// web:` Flutter's `showDialog(filter:)`
  /// lives on the route; here it is the `backdrop-filter` of the dialog's
  /// `::backdrop`.
  final ImageFilter? barrierFilter;

  /// The space a `Dialog` keeps to the edges of the window.
  final EdgeInsets? insetPadding;

  /// Size limits of a `Dialog`.
  final BoxConstraints? constraints;

  /// A copy of this theme with the given fields replaced (Flutter's
  /// `DialogThemeData.copyWith`).
  DialogThemeData copyWith({
    Color? backgroundColor,
    double? elevation,
    OutlinedBorder? shape,
    TextStyle? titleTextStyle,
    TextStyle? contentTextStyle,
    EdgeInsetsGeometry? actionsPadding,
    Color? barrierColor,
    ImageFilter? barrierFilter,
    EdgeInsets? insetPadding,
    BoxConstraints? constraints,
  }) => DialogThemeData(
    backgroundColor: backgroundColor ?? this.backgroundColor,
    elevation: elevation ?? this.elevation,
    shape: shape ?? this.shape,
    titleTextStyle: titleTextStyle ?? this.titleTextStyle,
    contentTextStyle: contentTextStyle ?? this.contentTextStyle,
    actionsPadding: actionsPadding ?? this.actionsPadding,
    barrierColor: barrierColor ?? this.barrierColor,
    barrierFilter: barrierFilter ?? this.barrierFilter,
    insetPadding: insetPadding ?? this.insetPadding,
    constraints: constraints ?? this.constraints,
  );
}

/// Flutter's `AppBarThemeData`, subset: the default look of `AppBar`.
// web: no `scrolledUnderElevation`, `shadowColor`, `surfaceTintColor`,
// `iconTheme` nor `actionsIconTheme` (the bar's `foregroundColor` colors its
// icons).
class AppBarThemeData {
  /// An app bar theme; null fields keep the defaults.
  const AppBarThemeData({
    this.backgroundColor,
    this.foregroundColor,
    this.elevation,
    this.centerTitle,
    this.titleSpacing,
    this.toolbarHeight,
    this.titleTextStyle,
  });

  /// Fill (default: the surface color).
  final Color? backgroundColor;

  /// Color of the title, icons and actions (default: on-surface).
  final Color? foregroundColor;

  /// Shadow elevation (default: 0).
  final double? elevation;

  /// Whether the title is centered.
  final bool? centerTitle;

  /// Space around the title on the inline axis (default: 16).
  final double? titleSpacing;

  /// Height of the toolbar row (default: 64).
  final double? toolbarHeight;

  /// Font and color of the title (default: the title-large role).
  final TextStyle? titleTextStyle;

  /// A copy of this theme with the given fields replaced (Flutter's
  /// `AppBarThemeData.copyWith`).
  AppBarThemeData copyWith({
    Color? backgroundColor,
    Color? foregroundColor,
    double? elevation,
    bool? centerTitle,
    double? titleSpacing,
    double? toolbarHeight,
    TextStyle? titleTextStyle,
  }) => AppBarThemeData(
    backgroundColor: backgroundColor ?? this.backgroundColor,
    foregroundColor: foregroundColor ?? this.foregroundColor,
    elevation: elevation ?? this.elevation,
    centerTitle: centerTitle ?? this.centerTitle,
    titleSpacing: titleSpacing ?? this.titleSpacing,
    toolbarHeight: toolbarHeight ?? this.toolbarHeight,
    titleTextStyle: titleTextStyle ?? this.titleTextStyle,
  );
}

/// Flutter's `ListTileThemeData`, subset: the default look of `ListTile`.
// web: no `iconColor` yet (not implemented); `dense` is read from the theme
// when the tile's own `dense` is null; the tile colors its text and icons
// with one `color`.
class ListTileThemeData {
  /// A list tile theme; null fields keep the defaults.
  const ListTileThemeData({
    this.dense,
    this.shape,
    this.selectedColor,
    this.textColor,
    this.tileColor,
    this.selectedTileColor,
    this.contentPadding,
    this.horizontalTitleGap,
    this.minTileHeight,
    this.minVerticalPadding,
    this.hoverColor,
    this.focusColor,
    this.splashColor,
  });

  /// The fill under the pointer (default: on-surface at 8 %).
  // web: not in Flutter's `ListTileThemeData`.
  final Color? hoverColor;

  /// The fill while focused (default: none).
  // web: not in Flutter's `ListTileThemeData`.
  final Color? focusColor;

  /// The fill while pressed (default: none).
  // web: not in Flutter's `ListTileThemeData`.
  final Color? splashColor;

  /// The tiles' minimum height (replaces the one `dense` picks).
  final double? minTileHeight;

  /// The least space above and below the content.
  final double? minVerticalPadding;

  /// Whether the tiles are shorter.
  final bool? dense;

  /// Corners and outline of the tile.
  final OutlinedBorder? shape;

  /// Text and icon color while selected (default: the primary color).
  final Color? selectedColor;

  /// Text color while not selected (default: on-surface).
  final Color? textColor;

  /// Fill while not selected.
  final Color? tileColor;

  /// Fill while selected.
  final Color? selectedTileColor;

  /// Space around the content (default: 16 px start, 24 px end).
  final EdgeInsetsGeometry? contentPadding;

  /// Space between the leading, the text and the trailing (default: 16).
  final double? horizontalTitleGap;

  /// A copy of this theme with the given fields replaced (Flutter's
  /// `ListTileThemeData.copyWith`).
  ListTileThemeData copyWith({
    bool? dense,
    OutlinedBorder? shape,
    Color? selectedColor,
    Color? textColor,
    Color? tileColor,
    Color? selectedTileColor,
    EdgeInsetsGeometry? contentPadding,
    double? horizontalTitleGap,
    double? minTileHeight,
    double? minVerticalPadding,
    Color? hoverColor,
    Color? focusColor,
    Color? splashColor,
  }) => ListTileThemeData(
    dense: dense ?? this.dense,
    shape: shape ?? this.shape,
    selectedColor: selectedColor ?? this.selectedColor,
    textColor: textColor ?? this.textColor,
    tileColor: tileColor ?? this.tileColor,
    selectedTileColor: selectedTileColor ?? this.selectedTileColor,
    contentPadding: contentPadding ?? this.contentPadding,
    horizontalTitleGap: horizontalTitleGap ?? this.horizontalTitleGap,
    minTileHeight: minTileHeight ?? this.minTileHeight,
    minVerticalPadding: minVerticalPadding ?? this.minVerticalPadding,
    hoverColor: hoverColor ?? this.hoverColor,
    focusColor: focusColor ?? this.focusColor,
    splashColor: splashColor ?? this.splashColor,
  );
}

/// Flutter's `TooltipThemeData`: the default look and timing of `Tooltip`.
class TooltipThemeData {
  /// A tooltip theme; null fields keep the defaults.
  const TooltipThemeData({
    this.height,
    this.padding,
    this.margin,
    this.verticalOffset,
    this.preferBelow,
    this.excludeFromSemantics,
    this.decoration,
    this.textStyle,
    this.textAlign,
    this.waitDuration,
  });

  /// The bubble's minimum height (default: 24).
  final double? height;

  /// Space inside the bubble (default: 8 by 4).
  final EdgeInsetsGeometry? padding;

  /// Empty space around the bubble (default: none).
  final EdgeInsetsGeometry? margin;

  /// From the child's center to the bubble (default: 24).
  final double? verticalOffset;

  /// Below the child (default) or above it.
  final bool? preferBelow;

  /// Whether the child leaves out the description.
  final bool? excludeFromSemantics;

  /// The bubble's background, border and radius.
  final BoxDecoration? decoration;

  /// The bubble's text style.
  final TextStyle? textStyle;

  /// How the bubble's lines align.
  final TextAlign? textAlign;

  /// How long the pointer rests before the bubble shows (default: none).
  final Duration? waitDuration;

  /// A copy of this theme with the given fields replaced (Flutter's
  /// `TooltipThemeData.copyWith`).
  TooltipThemeData copyWith({
    double? height,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    double? verticalOffset,
    bool? preferBelow,
    bool? excludeFromSemantics,
    BoxDecoration? decoration,
    TextStyle? textStyle,
    TextAlign? textAlign,
    Duration? waitDuration,
  }) => TooltipThemeData(
    height: height ?? this.height,
    padding: padding ?? this.padding,
    margin: margin ?? this.margin,
    verticalOffset: verticalOffset ?? this.verticalOffset,
    preferBelow: preferBelow ?? this.preferBelow,
    excludeFromSemantics: excludeFromSemantics ?? this.excludeFromSemantics,
    decoration: decoration ?? this.decoration,
    textStyle: textStyle ?? this.textStyle,
    textAlign: textAlign ?? this.textAlign,
    waitDuration: waitDuration ?? this.waitDuration,
  );
}

/// Flutter's `SnackBarThemeData`, subset: the default look of `SnackBar`.
// web: no `actionTextColor` nor `disabledActionTextColor` (the action is any
// widget), `dismissDirection`, `actionOverflowThreshold` nor `actionBackgroundColor`.
class SnackBarThemeData {
  /// A snack bar theme; null fields keep the defaults.
  const SnackBarThemeData({
    this.backgroundColor,
    this.contentTextStyle,
    this.elevation,
    this.shape,
    this.behavior,
    this.showCloseIcon,
    this.closeIconColor,
    this.width,
    this.insetPadding,
  });

  /// Whether the bar has a close button (default: false).
  // web: a real `<button>` named by the localized `closeButtonTooltip`; it
  // ends the bar the way its timer would (the next one waiting shows).
  final bool? showCloseIcon;

  /// Color of the close icon (default: the bar's text color).
  final Color? closeIconColor;

  /// Width of a floating bar (default: as wide as its message, up to the
  /// window less 32 px). A fixed bar spans the window.
  final double? width;

  /// Space between a floating bar and the window's edges (default: 16 px at
  /// the bottom, centered). The bottom inset also keeps clear of the notch
  /// (`safe-area-inset-bottom`): give it the height of a toolbar to sit
  /// above it.
  // web: only physical or directional insets of plain numbers (`EdgeInsets`,
  // `EdgeInsetsDirectional`, resolved left to right); the top inset is not
  // used (the bar sits at the bottom).
  final EdgeInsetsGeometry? insetPadding;

  /// Fill (default: the inverse-surface color).
  final Color? backgroundColor;

  /// Font and color of the message.
  final TextStyle? contentTextStyle;

  /// Shadow elevation (default: 3).
  final double? elevation;

  /// Corners and outline.
  final OutlinedBorder? shape;

  /// Fixed to the bottom edge or floating (default: fixed).
  final SnackBarBehavior? behavior;

  /// A copy of this theme with the given fields replaced (Flutter's
  /// `SnackBarThemeData.copyWith`).
  SnackBarThemeData copyWith({
    Color? backgroundColor,
    TextStyle? contentTextStyle,
    double? elevation,
    OutlinedBorder? shape,
    SnackBarBehavior? behavior,
    bool? showCloseIcon,
    Color? closeIconColor,
    double? width,
    EdgeInsetsGeometry? insetPadding,
  }) => SnackBarThemeData(
    backgroundColor: backgroundColor ?? this.backgroundColor,
    contentTextStyle: contentTextStyle ?? this.contentTextStyle,
    elevation: elevation ?? this.elevation,
    shape: shape ?? this.shape,
    behavior: behavior ?? this.behavior,
    showCloseIcon: showCloseIcon ?? this.showCloseIcon,
    closeIconColor: closeIconColor ?? this.closeIconColor,
    width: width ?? this.width,
    insetPadding: insetPadding ?? this.insetPadding,
  );
}

/// Flutter's `ProgressIndicatorThemeData`, subset: the default look of
/// `LinearProgressIndicator` and `CircularProgressIndicator`.
// web: no track colors (a `<progress>`'s track is the browser's, and the
// circular indicator has none), `borderRadius`, `circularTrackPadding` nor
// `year2023`.
class ProgressIndicatorThemeData {
  /// A progress indicator theme; null fields keep the defaults.
  const ProgressIndicatorThemeData({
    this.color,
    this.linearMinHeight,
    this.circularStrokeWidth,
  });

  /// Color of the filled part (default: the primary color).
  final Color? color;

  /// Height of the linear bar (default: 4).
  final double? linearMinHeight;

  /// Stroke of the circular indicator (default: 4).
  final double? circularStrokeWidth;

  /// A copy of this theme with the given fields replaced (Flutter's
  /// `ProgressIndicatorThemeData.copyWith`).
  ProgressIndicatorThemeData copyWith({
    Color? color,
    double? linearMinHeight,
    double? circularStrokeWidth,
  }) => ProgressIndicatorThemeData(
    color: color ?? this.color,
    linearMinHeight: linearMinHeight ?? this.linearMinHeight,
    circularStrokeWidth: circularStrokeWidth ?? this.circularStrokeWidth,
  );
}

/// Flutter's `BottomSheetThemeData`, subset: the default look of
/// `ModalBottomSheet`.
// web: no `shadowColor`, `surfaceTintColor`, `showDragHandle` nor
// `dragHandleColor`/`dragHandleSize` (the handle is a parameter of the
// sheet), `clipBehavior`.
class BottomSheetThemeData {
  /// A bottom sheet theme; null fields keep the defaults.
  const BottomSheetThemeData({
    this.backgroundColor,
    this.modalBackgroundColor,
    this.elevation,
    this.modalElevation,
    this.shape,
    this.modalBarrierColor,
    this.constraints,
  });

  /// Fill (default: the surface-container-low color).
  final Color? backgroundColor;

  /// Fill of a modal sheet; wins over [backgroundColor] for a
  /// `ModalBottomSheet`, which is always modal.
  final Color? modalBackgroundColor;

  /// Shadow elevation.
  final double? elevation;

  /// Shadow elevation of a modal sheet (wins over [elevation]).
  final double? modalElevation;

  /// Corners and outline (default: 28 px on the top corners).
  final OutlinedBorder? shape;

  /// The color behind a modal sheet.
  final Color? modalBarrierColor;

  /// Size limits (default: at most 640 px wide).
  final BoxConstraints? constraints;

  /// A copy of this theme with the given fields replaced (Flutter's
  /// `BottomSheetThemeData.copyWith`).
  BottomSheetThemeData copyWith({
    Color? backgroundColor,
    Color? modalBackgroundColor,
    double? elevation,
    double? modalElevation,
    OutlinedBorder? shape,
    Color? modalBarrierColor,
    BoxConstraints? constraints,
  }) => BottomSheetThemeData(
    backgroundColor: backgroundColor ?? this.backgroundColor,
    modalBackgroundColor: modalBackgroundColor ?? this.modalBackgroundColor,
    elevation: elevation ?? this.elevation,
    modalElevation: modalElevation ?? this.modalElevation,
    shape: shape ?? this.shape,
    modalBarrierColor: modalBarrierColor ?? this.modalBarrierColor,
    constraints: constraints ?? this.constraints,
  );
}

/// Flutter's `DrawerThemeData`, subset: the default look of `Drawer`.
// web: no `shadowColor`, `surfaceTintColor`, `endShape` nor `clipBehavior`.
class DrawerThemeData {
  /// A drawer theme; null fields keep the defaults.
  const DrawerThemeData({
    this.backgroundColor,
    this.scrimColor,
    this.elevation,
    this.shape,
    this.width,
  });

  /// Fill (default: the surface-container-low color).
  final Color? backgroundColor;

  /// The color behind a modal drawer.
  final Color? scrimColor;

  /// Shadow elevation.
  final double? elevation;

  /// Corners and outline (default: 16 px on the inner corners).
  final OutlinedBorder? shape;

  /// Width (default: 304).
  final double? width;

  /// A copy of this theme with the given fields replaced (Flutter's
  /// `DrawerThemeData.copyWith`).
  DrawerThemeData copyWith({
    Color? backgroundColor,
    Color? scrimColor,
    double? elevation,
    OutlinedBorder? shape,
    double? width,
  }) => DrawerThemeData(
    backgroundColor: backgroundColor ?? this.backgroundColor,
    scrimColor: scrimColor ?? this.scrimColor,
    elevation: elevation ?? this.elevation,
    shape: shape ?? this.shape,
    width: width ?? this.width,
  );
}

/// Flutter's `CheckboxThemeData`, subset: the default look of `Checkbox`
/// (and the checkbox of `CheckboxListTile`).
// web: the properties follow `selected` (checked or indeterminate); the
// `disabled` state is not resolved yet; no `mouseCursor`, `overlayColor`, `splashRadius`,
// `materialTapTargetSize` nor `visualDensity`.
class CheckboxThemeData {
  /// A checkbox theme; null fields keep the defaults.
  const CheckboxThemeData({
    this.fillColor,
    this.checkColor,
    this.side,
    this.shape,
  });

  /// The box's fill and outline while `selected` (default: the primary
  /// color); without it, the outline in its default color and no fill.
  final WidgetStateProperty<Color?>? fillColor;

  /// The color of the check mark (default: white).
  final WidgetStateProperty<Color?>? checkColor;

  /// The outline while not selected (default: 2 px on-surface-variant).
  final BorderSide? side;

  /// The corners of the box (default: 2 px).
  final OutlinedBorder? shape;

  /// A copy of this theme with the given fields replaced (Flutter's
  /// `CheckboxThemeData.copyWith`).
  CheckboxThemeData copyWith({
    WidgetStateProperty<Color?>? fillColor,
    WidgetStateProperty<Color?>? checkColor,
    BorderSide? side,
    OutlinedBorder? shape,
  }) => CheckboxThemeData(
    fillColor: fillColor ?? this.fillColor,
    checkColor: checkColor ?? this.checkColor,
    side: side ?? this.side,
    shape: shape ?? this.shape,
  );
}

/// Flutter's `SwitchThemeData`, subset: the default look of `Switch`.
// web: the properties follow `selected` (on); the `disabled` state is not
// resolved yet; no `thumbIcon`, `trackOutlineColor`, `overlayColor` nor
// `mouseCursor`. [trackSize] and [thumbSize] are not in Flutter (its switch
// is always 52x32): they let an app draw a compact one without scaling it.
class SwitchThemeData {
  /// A switch theme; null fields keep the defaults.
  const SwitchThemeData({
    this.thumbColor,
    this.trackColor,
    this.trackOutlineWidth,
    this.padding,
    this.materialTapTargetSize,
    this.trackSize,
    this.thumbSize,
    this.thumbShadow,
  });

  /// The thumb's color (default: on-primary while on, outline off).
  final WidgetStateProperty<Color?>? thumbColor;

  /// The track's fill and outline while on (default: the primary color).
  final WidgetStateProperty<Color?>? trackColor;

  /// The track's outline width (default: 2).
  final WidgetStateProperty<double?>? trackOutlineWidth;

  /// The space around the track (Flutter's `padding`, default
  /// `EdgeInsets.symmetric(horizontal: 4)`; `// web:` a margin, as the
  /// clickable area is the track).
  final EdgeInsetsGeometry? padding;

  /// The size of the touch target (`// web:` both values lay out the same
  /// box, see [MaterialTapTargetSize]).
  final MaterialTapTargetSize? materialTapTargetSize;

  // web: not in Flutter (its track is always 52x32).
  /// The track's width and height (default: 52x32). The thumb stays centered
  /// on the cross axis and as far from the ends as from the sides.
  final Size? trackSize;

  // web: not in Flutter.
  /// The thumb's diameter (default: 16 off, 24 on).
  final WidgetStateProperty<double?>? thumbSize;

  // web: not in Flutter (its M3 thumb has no shadow). The thumb is a
  // background image, so the shadow is drawn inside that image: only the
  // offset, blur radius, spread and color of each [BoxShadow] apply (no
  // `inset`), and it is the same one on and off.
  /// The shadows under the thumb (default: none), e.g. Tailwind's `shadow-sm`:
  /// `[BoxShadow(color: Color(0x1A000000), offset: Offset(0, 1), blurRadius: 3)]`.
  final List<BoxShadow>? thumbShadow;

  /// A copy of this theme with the given fields replaced (Flutter's
  /// `SwitchThemeData.copyWith`).
  SwitchThemeData copyWith({
    WidgetStateProperty<Color?>? thumbColor,
    WidgetStateProperty<Color?>? trackColor,
    WidgetStateProperty<double?>? trackOutlineWidth,
    EdgeInsetsGeometry? padding,
    MaterialTapTargetSize? materialTapTargetSize,
    Size? trackSize,
    WidgetStateProperty<double?>? thumbSize,
    List<BoxShadow>? thumbShadow,
  }) => SwitchThemeData(
    thumbColor: thumbColor ?? this.thumbColor,
    trackColor: trackColor ?? this.trackColor,
    trackOutlineWidth: trackOutlineWidth ?? this.trackOutlineWidth,
    padding: padding ?? this.padding,
    materialTapTargetSize: materialTapTargetSize ?? this.materialTapTargetSize,
    trackSize: trackSize ?? this.trackSize,
    thumbSize: thumbSize ?? this.thumbSize,
    thumbShadow: thumbShadow ?? this.thumbShadow,
  );
}

/// Flutter's `RadioThemeData`, subset: the default look of `Radio`.
// web: the property follows `selected`; no `mouseCursor`, `overlayColor`,
// `splashRadius`, `materialTapTargetSize` nor `visualDensity`.
class RadioThemeData {
  /// A radio theme; null fields keep the defaults.
  const RadioThemeData({this.fillColor});

  /// The ring and dot's color while `selected` (default: the primary
  /// color).
  final WidgetStateProperty<Color?>? fillColor;

  /// A copy of this theme with the given fields replaced (Flutter's
  /// `RadioThemeData.copyWith`).
  RadioThemeData copyWith({WidgetStateProperty<Color?>? fillColor}) =>
      RadioThemeData(fillColor: fillColor ?? this.fillColor);
}

/// Flutter's `ShowValueIndicator`: when a `Slider` shows the bubble with its
/// value above the thumb.
// web: Flutter's deprecated `always` is [onDrag].
enum ShowValueIndicator {
  /// Only while dragging, for a slider with `divisions` (Flutter's default).
  onlyForDiscrete,

  /// Only while dragging, for a slider without `divisions`.
  onlyForContinuous,

  /// While dragging (or focused with the keyboard).
  onDrag,

  /// Always, as long as the slider can change.
  alwaysVisible,

  /// Never.
  never,
}

/// Flutter's `SliderThemeData`, subset: the default look of `Slider`.
// web: the track and thumb are the native `<input type=range>`'s, painted by
// one `accent-color`: [activeTrackColor] wins, else [thumbColor]. No
// inactive track, shapes, tick marks nor overlay colors. The value indicator
// is a bubble of CSS that follows the thumb, a rounded rectangle (no
// `valueIndicatorShape`).
class SliderThemeData {
  /// A slider theme; null fields keep the defaults.
  const SliderThemeData({
    this.activeTrackColor,
    this.thumbColor,
    this.showValueIndicator,
    this.valueIndicatorColor,
    this.valueIndicatorTextStyle,
  });

  /// The filled part of the track (default: the primary color).
  final Color? activeTrackColor;

  /// The thumb (default: the primary color).
  final Color? thumbColor;

  /// When the bubble with the value shows above the thumb. Null: no bubble
  /// (the `Slider.label` is only the tooltip).
  ///
  /// `// web:` the bubble's text is the slider's `label` (a `{}` in it
  /// stands for the live value), else the value itself.
  final ShowValueIndicator? showValueIndicator;

  /// The bubble's fill (default: the primary color).
  final Color? valueIndicatorColor;

  /// The bubble's font and color (default: the label-medium role, on the
  /// primary color).
  final TextStyle? valueIndicatorTextStyle;

  /// A copy of this theme with the given fields replaced (Flutter's
  /// `SliderThemeData.copyWith`).
  SliderThemeData copyWith({
    Color? activeTrackColor,
    Color? thumbColor,
    ShowValueIndicator? showValueIndicator,
    Color? valueIndicatorColor,
    TextStyle? valueIndicatorTextStyle,
  }) => SliderThemeData(
    activeTrackColor: activeTrackColor ?? this.activeTrackColor,
    thumbColor: thumbColor ?? this.thumbColor,
    showValueIndicator: showValueIndicator ?? this.showValueIndicator,
    valueIndicatorColor: valueIndicatorColor ?? this.valueIndicatorColor,
    valueIndicatorTextStyle:
        valueIndicatorTextStyle ?? this.valueIndicatorTextStyle,
  );
}

/// Flutter's `TabBarThemeData`, subset: the default look of `TabBar`.
// web: no `indicator`, `indicatorSize`, `overlayColor`, `splashFactory` nor
// `tabAlignment` (the indicator is the selected tab's underline).
class TabBarThemeData {
  /// A tab bar theme; null fields keep the defaults.
  const TabBarThemeData({
    this.indicatorColor,
    this.labelColor,
    this.unselectedLabelColor,
    this.dividerColor,
    this.labelStyle,
    this.labelPadding,
  });

  /// Color of the selected tab's underline (default: the primary color).
  final Color? indicatorColor;

  /// Color of the selected tab's label (default: the primary color).
  final Color? labelColor;

  /// Color of the other labels (default: on-surface-variant).
  final Color? unselectedLabelColor;

  /// Color of the line under the bar (default: outline-variant).
  final Color? dividerColor;

  /// Font of the labels (default: the title-small role).
  final TextStyle? labelStyle;

  /// Space inside each tab on the inline axis (default: 16).
  final EdgeInsetsGeometry? labelPadding;

  /// A copy of this theme with the given fields replaced (Flutter's
  /// `TabBarThemeData.copyWith`).
  TabBarThemeData copyWith({
    Color? indicatorColor,
    Color? labelColor,
    Color? unselectedLabelColor,
    Color? dividerColor,
    TextStyle? labelStyle,
    EdgeInsetsGeometry? labelPadding,
  }) => TabBarThemeData(
    indicatorColor: indicatorColor ?? this.indicatorColor,
    labelColor: labelColor ?? this.labelColor,
    unselectedLabelColor: unselectedLabelColor ?? this.unselectedLabelColor,
    dividerColor: dividerColor ?? this.dividerColor,
    labelStyle: labelStyle ?? this.labelStyle,
    labelPadding: labelPadding ?? this.labelPadding,
  );
}

/// Flutter's `PopupMenuThemeData`, subset: the default look of
/// `PopupMenuButton`'s menu.
// web: no `shadowColor`, `surfaceTintColor`, `position`, `iconColor` nor
// `labelTextStyle`.
class PopupMenuThemeData {
  /// A popup menu theme; null fields keep the defaults.
  const PopupMenuThemeData({
    this.color,
    this.shape,
    this.elevation,
    this.textStyle,
    this.menuPadding,
  });

  /// The menu's fill (default: the surface-container color).
  final Color? color;

  /// The menu's corners and outline.
  final OutlinedBorder? shape;

  /// The menu's shadow (default: 8).
  final double? elevation;

  /// The font of the items.
  final TextStyle? textStyle;

  /// Space around the items (default: 8 above and below).
  final EdgeInsetsGeometry? menuPadding;

  /// A copy of this theme with the given fields replaced (Flutter's
  /// `PopupMenuThemeData.copyWith`).
  PopupMenuThemeData copyWith({
    Color? color,
    OutlinedBorder? shape,
    double? elevation,
    TextStyle? textStyle,
    EdgeInsetsGeometry? menuPadding,
  }) => PopupMenuThemeData(
    color: color ?? this.color,
    shape: shape ?? this.shape,
    elevation: elevation ?? this.elevation,
    textStyle: textStyle ?? this.textStyle,
    menuPadding: menuPadding ?? this.menuPadding,
  );
}

/// Flutter's `NavigationBarThemeData`, subset: the default look of
/// `NavigationBar`.
// web: no `shadowColor`, `surfaceTintColor`, `indicatorShape`,
// `iconTheme`, `labelTextStyle` nor `overlayColor`.
class NavigationBarThemeData {
  /// A navigation bar theme; null fields keep the defaults.
  const NavigationBarThemeData({
    this.height,
    this.backgroundColor,
    this.elevation,
    this.indicatorColor,
    this.labelBehavior,
  });

  /// Height of the bar (default: 80).
  final double? height;

  /// Fill (default: the surface-container color).
  final Color? backgroundColor;

  /// Shadow elevation (default: none).
  final double? elevation;

  /// Color of the selected destination's pill (default: the
  /// secondary-container color).
  final Color? indicatorColor;

  /// When labels are shown (default: always).
  final NavigationDestinationLabelBehavior? labelBehavior;

  /// A copy of this theme with the given fields replaced (Flutter's
  /// `NavigationBarThemeData.copyWith`).
  NavigationBarThemeData copyWith({
    double? height,
    Color? backgroundColor,
    double? elevation,
    Color? indicatorColor,
    NavigationDestinationLabelBehavior? labelBehavior,
  }) => NavigationBarThemeData(
    height: height ?? this.height,
    backgroundColor: backgroundColor ?? this.backgroundColor,
    elevation: elevation ?? this.elevation,
    indicatorColor: indicatorColor ?? this.indicatorColor,
    labelBehavior: labelBehavior ?? this.labelBehavior,
  );
}
