import 'package:thor_engine/thor_engine.dart'
    show DialogController, dialogControllerAttr, keyToken, menuAttr, untracked;
import 'package:thor_style/thor_style.dart';

import '../core/core.dart';
import '../engine/watch.dart'
    show Watch, WatchAttributes, elementEventAttributes, engineAttributes;
import '../foundation/child_rules.dart';
import '../foundation/dialog_scope.dart';
import '../foundation/element.dart';
import '../foundation/errors.dart';
import '../foundation/html_attributes.dart';
import '../foundation/layout_hint.dart';
import '../foundation/material_localizations.dart'
    show MaterialLocalizations, ThorLocalizations;
import '../foundation/native_id.dart';
import '../foundation/parent_data.dart';
import '../foundation/style_registry.dart';
import '../foundation/stylesheet.dart' show WindowSizeClass;
import '../foundation/theme_tokens.dart';
import '../foundation/transparent.dart';
import '../foundation/widget_state.dart';
import 'backdrop.dart';
import 'basic.dart' show Container, boxCss, buttonResetCss;
import 'buttons.dart' show ButtonStyle, ButtonStyleResolved, buttonStyleCss;
import 'component_themes.dart';
import 'dialog_close_corner.dart' show DialogCloseCorner;
import 'dropdown_menu.dart' show MenuStyle, menuStyleCss;
import 'icon.dart' show Icon;
import 'icons.dart' show Icons;
import 'native_control.dart' show childIsNativeControl;
import 'navigation.dart' show Drawer, closeOnNavigateHandler;
import 'selection_controls.dart' show ListTileControlAffinity;
import 'shortcuts.dart' show controllerIdOf;
import 'text.dart' show InlineSpan, Text;
import 'theme.dart' show Theme;

// Material 3 content components on native HTML. Everything here works with
// no JS at all; state (selected, open, pressed) is an
// attribute + a CSS condition of the same class, so the browser only flips
// attributes — never styles.

const _surfaceContainerLow = ThemeTokens.surfaceContainerLow;
const _onSurface = ThemeTokens.onSurface;
const _onSurfaceVariant = ThemeTokens.onSurfaceVariant;
const _outline = ThemeTokens.outline;
const _outlineVariant = ThemeTokens.outlineVariant;
const _primary = ThemeTokens.primary;
const _secondaryContainer = ThemeTokens.secondaryContainer;
const _hover = 'color-mix(in srgb, ${ThemeTokens.onSurface} 8%, transparent)';

/// A plain [Text] as the element's own text: its styles and the text node,
/// no inner span. `null` when it needs its own element.
({CssDeclarations css, Widget node})? _inlineText(Widget? c) {
  if (c is! Text) return null;
  final css = c.boxContentCss;
  return css == null ? null : (css: css, node: Widget.text(c.data!));
}

const _focusRing = ConditionalCss(CssCondition.focused, {
  'outline': '2px solid $_primary',
  'outline-offset': '2px',
});

// web: forced colors drop a surface's background and shadow, so a popover
// would blend into the page: it gets an edge in the system's text color.
const _forcedEdge = ConditionalCss(CssCondition.forcedColors, {
  'border': '1px solid CanvasText',
});

/// Flutter's `Card` (Material 3 elevated card).
class Card extends StatelessWidget
    implements LayoutHint, ThorElementWidget, ThorBuiltIn {
  /// Creates a Material 3 elevated card.
  const Card({
    super.key,
    this.color,
    this.elevation,
    this.margin,
    this.clipBehavior,
    this.shape,
    this.child,
  });

  /// The outline and corners of the card (default: 12 px rounded corners).
  ///
  /// `// web:` a [CircleBorder] is `border-radius: 50%`: on a box that is
  /// not square it is an oval (see [CircleBorder]).
  final OutlinedBorder? shape;

  /// Card background (Flutter's default: the surface-container-low color).
  final Color? color;

  /// Shadow elevation (Flutter's default: 1; `ThemeData.cardTheme` first).
  final double? elevation;

  /// Outer margin (Flutter's default: 4 logical pixels on every side).
  final EdgeInsetsGeometry? margin;

  /// How to clip the card's content (Flutter's default: `Clip.none`).
  final Clip? clipBehavior;

  /// Content of the card.
  final Widget? child;

  // The parameter, else `ThemeData.cardTheme`, else Flutter's default.
  Container _box(CardThemeData? theme) {
    final shape = this.shape ?? theme?.shape;
    final elevation = this.elevation ?? theme?.elevation ?? 1;
    return Container(
      margin: margin ?? theme?.margin ?? const EdgeInsets.all(4),
      clipBehavior: clipBehavior ?? theme?.clipBehavior ?? Clip.none,
      decoration: BoxDecoration(
        color: color ?? theme?.color ?? const Color.css(_surfaceContainerLow),
        borderRadius: switch (shape) {
          null => BorderRadius.circular(12),
          RoundedRectangleBorder(:final borderRadius) ||
          ContinuousRectangleBorder(:final borderRadius) => borderRadius,
          StadiumBorder() => BorderRadius.circular(9999),
          CircleBorder() => null,
        },
        shape: shape is CircleBorder ? BoxShape.circle : BoxShape.rectangle,
        border: shape == null || shape.side == BorderSide.none
            ? null
            : Border.fromBorderSide(shape.side),
        boxShadow: elevation <= 0
            ? null
            : [
                BoxShadow(
                  color: const Color(0x26000000),
                  offset: Offset(0, elevation),
                  blurRadius: elevation * 3,
                ),
                BoxShadow(
                  color: const Color(0x4D000000),
                  offset: Offset(0, elevation / 2),
                  blurRadius: elevation,
                ),
              ],
      ),
      child: child,
    );
  }

  // The theme only changes colors, margin and shape, never the width.
  @override
  bool get fillsWidth => _box(null).fillsWidth;

  // A Container: it merges into a Row/Column child or its text, like any box.
  @override
  Widget build(BuildContext context) => _box(Theme.of(context).cardTheme);
}

/// Flutter's `ListTile`: one row with optional leading, title, subtitle and
/// trailing. With [onTap] (or [href]) the whole row is the
/// native control.
class ListTile extends StatelessWidget
    implements LayoutHint, ThorElementWidget, ThorBuiltIn {
  /// Creates a Material list tile.
  const ListTile({
    super.key,
    this.leading,
    this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.selected = false,
    this.enabled = true,
    this.href,
    this.dense,
    this.contentPadding,
    this.tileColor,
    this.selectedTileColor,
    this.selectedColor,
    this.shape,
    this.minTileHeight,
    this.minVerticalPadding,
    this.hoverColor,
    this.focusColor,
    this.splashColor,
  });

  /// The layer under the pointer (default: on-surface at 8 %), drawn over
  /// [tileColor] like Flutter's ink: `Colors.transparent` removes the layer
  /// and leaves the tile's own fill. Else `ListTileThemeData.hoverColor`.
  // web: the theme field is not in Flutter. The layer is a
  // `background-image` over the tile's `background-color`.
  final Color? hoverColor;

  /// The layer while the tile has keyboard focus (default: none; the focus
  /// ring stays), over [tileColor]. Else `ListTileThemeData.focusColor`.
  final Color? focusColor;

  /// The layer while the tile is pressed (default: none), over [tileColor].
  /// Else `ListTileThemeData.splashColor`.
  // web: a state layer under the press, not an ink ripple.
  final Color? splashColor;

  /// Whether the tile is shorter (48 px, 64 px with a subtitle).
  final bool? dense;

  /// The tile's minimum height, replacing the 48/56 px (64/72 px with a
  /// subtitle) that [dense] picks. Else `ListTileThemeData.minTileHeight`.
  // web: a `min-height`, so a taller content still grows the tile.
  final double? minTileHeight;

  /// The least space above and below the content (Flutter's default: 4,
  /// here the 8 px padding of [contentPadding]). Else
  /// `ListTileThemeData.minVerticalPadding`.
  // web: sets the vertical padding of the tile, which `contentPadding`'s
  // vertical part would otherwise give.
  final double? minVerticalPadding;

  /// Space around the tile's content (Flutter's default: 16 px start,
  /// 24 px end).
  final EdgeInsetsGeometry? contentPadding;

  /// Fill of the tile when not selected.
  final Color? tileColor;

  /// Fill of the tile when [selected].
  final Color? selectedTileColor;

  /// Text and icon color when [selected] (default: the primary color).
  final Color? selectedColor;

  /// Corner shape of the tile (its fill and hover follow it).
  final OutlinedBorder? shape;

  /// Widget before the title, e.g. an icon or avatar.
  final Widget? leading;

  /// Primary content of the tile.
  final Widget? title;

  /// Secondary content shown below the title.
  final Widget? subtitle;

  /// Widget after the title, e.g. an icon or switch.
  final Widget? trailing;

  /// Called when the tile is tapped.
  final VoidCallback? onTap;

  /// Whether the tile is highlighted as selected. With [href] it marks the
  /// current page (`aria-current="page"`), else `aria-current="true"`.
  final bool selected;

  /// Whether the tile responds to input.
  final bool enabled;

  // web: not in Flutter.
  /// Renders as an `a` linking to this URL.
  final String? href;

  @override
  bool get fillsWidth => true;

  // The parameter, else `ThemeData.listTileTheme`, else Flutter's default.
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).listTileTheme;
    final dense = this.dense ?? theme?.dense;
    final contentPadding = this.contentPadding ?? theme?.contentPadding;
    final tileColor = this.tileColor ?? theme?.tileColor;
    final selectedTileColor =
        this.selectedTileColor ?? theme?.selectedTileColor;
    final selectedColor = this.selectedColor ?? theme?.selectedColor;
    final shape = this.shape ?? theme?.shape;
    final minTileHeight = this.minTileHeight ?? theme?.minTileHeight;
    final minVerticalPadding =
        this.minVerticalPadding ?? theme?.minVerticalPadding;
    final hoverColor = this.hoverColor ?? theme?.hoverColor;
    final focusColor = this.focusColor ?? theme?.focusColor;
    final splashColor = this.splashColor ?? theme?.splashColor;
    final interactive = onTap != null || href != null;
    final element = href != null ? 'a' : (onTap != null ? 'button' : 'div');
    final isButton = element == 'button';
    // Also one an app component builds.
    final plain = resolveComponent(title);
    final plainTitle = subtitle == null && plain is Text
        ? plain.boxContentCss
        : null;
    const titleCss = {
      'font-size': ThemeTokens.bodyLargeSize,
      'letter-spacing': ThemeTokens.bodyLargeTracking,
      'line-height': ThemeTokens.bodyLargeLine,
    };
    final texts = plainTitle != null && leading == null && trailing == null
        ? null
        : subtitle == null
        ? [
            if (title != null)
              WrapWith(
                const WrapData(css: {...titleCss, 'flex': '1 1 0'}),
                child: title!,
              ),
          ]
        : [
            thorElement(
              'span',
              css: const {...boxCss, 'flex': '1 1 0', 'gap': '2px'},
              children: [
                if (title != null)
                  WrapWith(const WrapData(css: titleCss), child: title!),
                WrapWith(
                  const WrapData(
                    css: {
                      'font-size': ThemeTokens.bodyMediumSize,
                      'letter-spacing': ThemeTokens.bodyMediumTracking,
                      'line-height': ThemeTokens.bodyMediumLine,
                      'color': _onSurfaceVariant,
                    },
                  ),
                  child: subtitle!,
                ),
              ],
            ),
          ];
    // web: a <button>/<a> cannot hold another control (the parser closes
    // the button at the inner one; a link would also follow on its click):
    // the tile is a <div> and the link/button holds the rest beside the
    // native control (MUI's secondaryAction shape).
    final splitLeading = interactive && childIsNativeControl(leading);
    final splitTrailing = interactive && childIsNativeControl(trailing);
    final split = splitLeading || splitTrailing;
    final tileCss = <String, String>{
      'display': 'flex',
      'align-items': 'center',
      'gap': cssPx(theme?.horizontalTitleGap ?? 16),
      'box-sizing': 'border-box',
      'min-height': minTileHeight != null
          ? cssPx(minTileHeight)
          : dense ?? false
          ? (subtitle == null ? '48px' : '64px')
          : (subtitle == null ? '56px' : '72px'),
      ...(contentPadding?.toCss('padding') ??
          const {'padding': '8px 24px 8px 16px'}),
      if (minVerticalPadding != null)
        'padding-block': cssPx(minVerticalPadding),
      'color': selected
          ? (selectedColor?.css ?? _primary)
          : (theme?.textColor?.css ?? _onSurface),
      'background-color': ?tileColor?.css,
      if (shape case final s?) ...{
        'border-radius': s.radiusCss,
        if (s.side != BorderSide.none) 'border': s.side.css,
      },
      'text-decoration': 'none',
      if (isButton && !split) 'text-align': 'start',
      if (!enabled) 'opacity': '0.38',
      if (interactive && enabled) 'cursor': 'pointer',
      if (plainTitle != null) ...{...titleCss, ...plainTitle},
    };
    final selectedCondition = selectedTileColor == null
        ? null
        : ConditionalCss(
            CssCondition.selector(
              split ? ':has([aria-current])' : '[aria-current]',
            ),
            {'background-color': selectedTileColor.css},
          );
    // The state colors are layers over the tile's fill (Flutter's ink over
    // tileColor / selectedTileColor), not a replacement of it.
    Map<String, String> layer(String c) => {
      'background-image': 'linear-gradient($c, $c)',
    };
    final hover = interactive && enabled
        ? ConditionalCss(CssCondition.hover, layer(hoverColor?.css ?? _hover))
        : null;
    final focusFill = interactive && enabled && focusColor != null
        ? ConditionalCss(CssCondition.focused, layer(focusColor.css))
        : null;
    final pressFill = interactive && enabled && splashColor != null
        ? ConditionalCss(CssCondition.pressed, layer(splashColor.css))
        : null;
    final controlAttributes = {
      if (isButton) 'type': 'button',
      if (isButton && !enabled) 'disabled': '',
      // A disabled tile is no link (Flutter ignores the tap): without the
      // `href` it cannot be followed, and it says so to a screen reader.
      if (enabled)
        'href': ?href
      else if (!isButton && interactive)
        'aria-disabled': 'true',
      // A link to the page being shown is `page`; any other selected
      // tile is the current item of its set.
      if (selected) 'aria-current': element == 'a' ? 'page' : 'true',
      ...engineAttributes({'click': enabled ? onTap : null}),
    };
    if (split) {
      // The focus and press layers fill the whole tile, as hover does (and
      // Flutter's ink): the outer div takes them while its link/button (the
      // body, after a leading control) is focused or pressed, not while the
      // native control beside it is.
      // (`of :not(style)`: a fragment may carry its `<style>` inline.)
      final bodyChild = ':nth-child(${splitLeading ? 2 : 1} of :not(style))';
      final splitFocus = focusFill == null
          ? null
          : ConditionalCss(
              CssCondition.selector(':has(> $bodyChild:focus-visible)'),
              focusFill.css,
            );
      final splitPress = pressFill == null
          ? null
          : ConditionalCss(
              CssCondition.selector(':has(> $bodyChild:active)'),
              pressFill.css,
            );
      final body = thorElement(
        element,
        debugName: 'ListTile',
        baseCss: isButton ? buttonResetCss : const {},
        css: {
          'display': 'flex',
          'align-items': 'center',
          'gap': cssPx(theme?.horizontalTitleGap ?? 16),
          'align-self': 'stretch',
          'flex': '1 1 0',
          'min-width': '0',
          'color': 'inherit',
          'text-decoration': 'none',
          if (isButton) 'text-align': 'start',
          if (enabled) 'cursor': 'pointer',
          if (plainTitle != null) ...{...titleCss, ...plainTitle},
        },
        conditions: [if (enabled) _focusRing],
        attributes: controlAttributes,
        children: [
          if (!splitLeading) ?leading,
          if (texts == null) Widget.text((plain! as Text).data!) else ...texts,
          if (!splitTrailing) ?trailing,
        ],
      );
      return thorElement(
        'div',
        debugName: 'ListTile',
        fillsWidth: true,
        css: tileCss,
        conditions: [?hover, ?splitFocus, ?splitPress, ?selectedCondition],
        children: [
          if (splitLeading) ?leading,
          body,
          if (splitTrailing) ?trailing,
        ],
      );
    }
    return thorElement(
      element,
      debugName: 'ListTile',
      fillsWidth: true,
      baseCss: isButton ? buttonResetCss : const {},
      css: tileCss,
      conditions: [
        if (hover != null) ...[hover, _focusRing],
        ?focusFill,
        ?pressFill,
        ?selectedCondition,
      ],
      attributes: controlAttributes,
      children: [
        ?leading,
        if (texts == null) Widget.text((plain! as Text).data!) else ...texts,
        ?trailing,
      ],
    );
  }
}

/// Flutter's `ExpansionTile` on `<details>`/`<summary>`: opens and closes
/// with no JS, keyboard and screen readers included.
///
/// web: tiles with the same [name] form an exclusive accordion (only one
/// open), like `ExpansionPanelList.radio`.
///
/// [onExpansionChanged] is a method of a `ThorState` that gets `true` when
/// the tile opens and `false` when it closes, from the native `toggle`
/// event of `<details>`: a click, the keyboard or the accordion closing
/// its sibling all report, and a burst of toggles reports the last state
/// once per change. In an accordion (same [name]) the tile that closes is
/// reported before the one that opens, whatever order the browser sent the
/// events in. The tile opens and closes without JS; the state only
/// hears about it once the engine is loaded (the tile's own click loads
/// it). `// web:` Flutter's callback also fires for a controller; here the
/// browser's `open` attribute is the only source. Lite engine only.
class ExpansionTile extends StatelessWidget
    implements LayoutHint, ThorElementWidget, ThorBuiltIn {
  /// Creates a Material expansion tile.
  const ExpansionTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.children = const [],
    this.initiallyExpanded = false,
    this.expandedWatch,
    this.onExpansionChanged,
    this.name,
    this.childrenPadding,
    this.tilePadding,
    this.iconColor,
    this.collapsedIconColor,
    this.backgroundColor,
    this.collapsedBackgroundColor,
    this.shape,
    this.collapsedShape,
    this.permanentFrom,
    this.controlAffinity,
    this.showTrailingIcon = true,
    this.trailing,
    this.dense,
    this.minTileHeight,
    this.iconSize = 24,
    this.iconTurns = 0.5,
    this.collapsedIconTurns = 0,
    this.iconGap = 16,
    this.hoverColor,
  }) : assert(
         expandedWatch == null || !initiallyExpanded,
         'expandedWatch decides whether the tile starts open.',
       );

  /// This tile with every field kept and [group] as its `<details name>`
  /// (for [ExpansionPanelList]); a new field must be added here too.
  ExpansionTile _inGroup(String group) => ExpansionTile(
    key: key,
    title: title,
    subtitle: subtitle,
    leading: leading,
    children: children,
    initiallyExpanded: initiallyExpanded,
    expandedWatch: expandedWatch,
    onExpansionChanged: onExpansionChanged,
    childrenPadding: childrenPadding,
    tilePadding: tilePadding,
    iconColor: iconColor,
    collapsedIconColor: collapsedIconColor,
    backgroundColor: backgroundColor,
    collapsedBackgroundColor: collapsedBackgroundColor,
    shape: shape,
    collapsedShape: collapsedShape,
    permanentFrom: permanentFrom,
    controlAffinity: controlAffinity,
    showTrailingIcon: showTrailingIcon,
    trailing: trailing,
    dense: dense,
    minTileHeight: minTileHeight,
    iconSize: iconSize,
    iconTurns: iconTurns,
    collapsedIconTurns: collapsedIconTurns,
    iconGap: iconGap,
    hoverColor: hoverColor,
    name: group,
  );

  /// A method of a `ThorState` returning whether the tile is open: the
  /// `<details>` follows it in the browser (its `open` attribute), so a tile
  /// inside a `Watch.list` row can be opened from the state instead of
  /// drawing two variants of its whole subtree. Replaces [initiallyExpanded]
  /// (the server draws the tile open or closed as the method says now).
  ///
  /// `// web:` Flutter's `ExpansionTileController` has no equivalent here; the
  /// engine writes `open` when the state starts and each time the signals the
  /// method reads change, so a visitor's own toggle stands only until then:
  /// keep the state in step with [onExpansionChanged].
  final bool Function()? expandedWatch;

  /// Where the chevron sits: [ListTileControlAffinity.leading] puts it
  /// before the header content, [ListTileControlAffinity.trailing] (the
  /// default, also `platform`) after it. A [leading] widget takes the place
  /// of a leading chevron, as in Flutter.
  final ListTileControlAffinity? controlAffinity;

  /// Whether the end of the header shows the chevron or the [trailing]
  /// widget (default: true). False shows neither, as in Flutter.
  final bool showTrailingIcon;

  /// A widget at the end of the header, instead of the chevron (shown only
  /// with [showTrailingIcon]).
  ///
  /// `// web:` it does not turn. To turn a chevron of your own with the tile
  /// (also one inside the [title], with `showTrailingIcon: false`), style it
  /// with the open state of the tile it is in:
  /// `Styled(style: StyleProps(turns: 0).when(open: StyleProps(turns: 0.5)), child: icon)`.
  final Widget? trailing;

  /// Whether the header is shorter (48 px instead of 56).
  final bool? dense;

  /// The header's minimum height (replaces the 56 or 48 of [dense]).
  final double? minTileHeight;

  // web: not in Flutter (it turns whatever icon the app gives); the chevron
  // here is a CSS mask, so its size and turns are parameters.
  /// The chevron's size in logical pixels (default 24).
  final double iconSize;

  // web: not in Flutter, see [iconSize].
  /// Turns of the chevron while the tile is open (default 0.5: it points
  /// up; 0 keeps it pointing down).
  final double iconTurns;

  // web: not in Flutter, see [iconSize].
  /// Turns of the chevron while the tile is closed (default 0, pointing
  /// down; -0.25 points right).
  final double collapsedIconTurns;

  // web: not in Flutter, see [iconSize].
  /// Space between a leading chevron ([controlAffinity] `leading`) and the
  /// header content (default 16).
  final double iconGap;

  /// The header's fill under the pointer (Flutter's `ListTile.hoverColor`,
  /// which its `ExpansionTile` header is); a transparent color removes the
  /// tint. Default: the theme's `ExpansionTileThemeData.hoverColor`, else a
  /// faint on-surface tint.
  // web: not in Flutter (neither is `ExpansionTileThemeData.hoverColor`).
  final Color? hoverColor;

  // web: not in Flutter.
  /// From this breakpoint up the tile is always expanded and its
  /// header is plain text, not a control: a footer that is an accordion on
  /// a phone and a column of lists on a desktop, written once.
  ///
  /// One `<details>` in the DOM, CSS only, no JS: below the breakpoint it
  /// opens and closes as always; from it up the content shows whether the
  /// tile is open or not (`::details-content` is made visible), the header
  /// stops reacting to the pointer and loses its chevron. Browsers without
  /// `::details-content` (before Chrome 131, Safari 18.4, Firefox 143) keep
  /// the accordion at every width.
  ///
  /// `// web:` the header stays a Tab stop and a screen reader still calls it
  /// a button: only CSS can't remove it from the tab order. [onExpansionChanged]
  /// keeps hearing the tile's own `open` attribute, which a desktop never
  /// changes with the pointer.
  final WindowSizeClass? permanentFrom;

  /// Padding of the header (Flutter's default: 16 px on the sides). The
  /// chevron sits inside its end side.
  // web: null keeps 8 px above and below the header row.
  final EdgeInsets? tilePadding;

  /// Chevron color while open (default: the primary color).
  final Color? iconColor;

  /// Chevron color while closed (default: on-surface-variant).
  final Color? collapsedIconColor;

  /// Fill of the tile while open.
  final Color? backgroundColor;

  /// Fill of the tile while closed.
  final Color? collapsedBackgroundColor;

  /// Shape (corners and outline) of the tile while open.
  final OutlinedBorder? shape;

  /// Shape (corners and outline) of the tile while closed.
  final OutlinedBorder? collapsedShape;

  /// Header content, always visible.
  final Widget title;

  /// Secondary header content shown below `title`.
  final Widget? subtitle;

  /// Widget before the header content.
  final Widget? leading;

  /// Widgets shown when expanded.
  final List<Widget> children;

  /// Whether the tile starts open (Flutter's default: false).
  final bool initiallyExpanded;

  /// Called with whether the tile is now open, on every change.
  final void Function(bool expanded)? onExpansionChanged;

  /// web: accordion group name; tiles sharing it allow only one open.
  final String? name;

  /// Padding around `children` (Flutter's default: 16px sides, 16px bottom).
  final EdgeInsetsGeometry? childrenPadding;

  @override
  bool get fillsWidth => true;

  static String _chevron(double size) =>
      'url("data:image/svg+xml,${Uri.encodeComponent('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="m6 9 6 6 6-6" fill="none" stroke="#000" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>')}") center / ${cssPx(size)} no-repeat';

  static String _turns(double turns) => '${cssNum(turns * 360)}deg';

  /// [widget] in the tile's icon colors when it is an [Icon] with no color
  /// of its own: [iconColor] while open, [collapsed] while closed (Flutter's
  /// `ListTileTheme.merge(iconColor:)` around the header colors the leading
  /// and trailing icons). Anything else is left as given.
  // web: thor has no `IconTheme`; an `Icon` draws in `currentColor`, so the
  // color lands on the icon's own element, and the open color follows the
  // `<details>` (`CssCondition.detailsOpen`), not a rebuild.
  static Widget? _tintIcon(Widget? widget, Color? iconColor, Color? collapsed) {
    if (widget == null) return null;
    final resolved = resolveComponent(widget);
    if (resolved is! Icon || resolved.color != null) return widget;
    return WrapWith(
      WrapData(
        css: {'color': collapsed?.css ?? _onSurfaceVariant},
        conditions: [
          ConditionalCss(CssCondition.detailsOpen, {
            'color': iconColor?.css ?? _primary,
          }),
        ],
      ),
      child: widget,
    );
  }

  static CssDeclarations _shapeCss(OutlinedBorder s) => {
    'border-radius': s.radiusCss,
    'border': s.side == BorderSide.none ? '0' : s.side.css,
  };

  @override
  Widget build(BuildContext context) {
    // Each parameter, else `ThemeData.expansionTileTheme`, else the default.
    final t = Theme.of(context).expansionTileTheme;
    final pad = switch (tilePadding ?? t?.tilePadding) {
      final p? => numericInsets(p, 'ExpansionTile.tilePadding'),
      null => null,
    };
    final iconColor = this.iconColor ?? t?.iconColor;
    final collapsedIconColor = this.collapsedIconColor ?? t?.collapsedIconColor;
    final backgroundColor = this.backgroundColor ?? t?.backgroundColor;
    final collapsedBackgroundColor =
        this.collapsedBackgroundColor ?? t?.collapsedBackgroundColor;
    final shape = this.shape ?? t?.shape;
    final collapsedShape = this.collapsedShape ?? t?.collapsedShape;
    final textColor = t?.textColor;
    final collapsedTextColor = t?.collapsedTextColor;
    final childrenPadding =
        this.childrenPadding ??
        t?.childrenPadding ??
        const EdgeInsets.fromLTRB(16, 0, 16, 16);
    final end = pad?.right ?? 16;
    const gap = 16.0;
    final minHeight = minTileHeight ?? (dense ?? false ? 48.0 : 56.0);
    // The chevron: before the header when it leads (a `leading` widget takes
    // its place), after it when it trails (a `trailing` widget does).
    final leadingChevron =
        controlAffinity == ListTileControlAffinity.leading && leading == null;
    final trailingChevron =
        controlAffinity != ListTileControlAffinity.leading &&
        trailing == null &&
        showTrailingIcon;
    final hasChevron = leadingChevron || trailingChevron;
    final start = pad?.left ?? 16;
    final padStart = leadingChevron ? start + iconSize + iconGap : start;
    final hoverColor = this.hoverColor ?? t?.hoverColor;
    final trailingWidget = showTrailingIcon ? trailing : null;
    final padEnd = trailingChevron
        ? (pad == null ? iconSize + 24 : end + iconSize + 16)
        : end;
    if (permanentFrom != null) {
      ThorStyleRegistry.of(context)?.usePermanentScript();
    }
    // A lone Text title is the header's own text, no element of its own.
    final fusedTitle =
        subtitle == null && leading == null && trailingWidget == null
        ? _inlineText(title)
        : null;
    final tile = thorElement(
      'details',
      debugName: 'ExpansionTile',
      fillsWidth: true,
      css: {
        'display': 'block',
        'box-sizing': 'border-box',
        // `interpolate-size` lets the content's height animate to and from
        // `auto` (see the `::details-content` rules below).
        'interpolate-size': 'allow-keywords',
        'background-color': ?collapsedBackgroundColor?.css,
        if (collapsedShape case final s?) ..._shapeCss(s),
        if (shape != null || collapsedShape != null) 'overflow': 'hidden',
      },
      conditions: [
        // web: a height transition on `::details-content`; a browser without
        // that pseudo-element drops these rules alone and the tile just
        // flips open, as a `<details>` always did. Under reduced motion it
        // flips too. Flutter grows the content in 200 ms with
        // `Curves.easeIn`, which ends at full speed: on a 60 Hz screen the
        // last frame jumps 14 % of the height and stops dead. Here the
        // height, the content's fade and the chevron share
        // [_expansionMotion] (250 ms, `Curves.fastOutSlowIn`, Material's
        // standard curve): it lands softly and the three move as one.
        ConditionalCss(const CssCondition.selector('::details-content'), {
          'block-size': '0',
          'opacity': '0',
          'overflow': 'clip',
          'transition':
              'block-size $_expansionMotion, opacity $_expansionMotion, '
              'content-visibility ${cssDuration(_expansionDuration)} '
              'allow-discrete',
        }),
        const ConditionalCss(CssCondition.selector('[open]::details-content'), {
          'block-size': 'auto',
          'opacity': '1',
        }),
        ConditionalCss(
          CssCondition.both(
            CssCondition.reducedMotion,
            const CssCondition.selector('::details-content'),
          ),
          const {'transition': 'none'},
        ),
        // The chevron turns and takes the open color (Flutter rotates it
        // half a turn).
        if (hasChevron)
          ConditionalCss(
            const CssCondition.selector('[open] > summary::after'),
            {
              'rotate': _turns(iconTurns),
              'background-color': iconColor?.css ?? _primary,
            },
          ),
        if (textColor != null)
          ConditionalCss(const CssCondition.selector('[open] > summary'), {
            'color': textColor.css,
          }),
        if (permanentFrom case final bp?) ..._expansionPermanent(bp),
        if (backgroundColor != null || shape != null)
          ConditionalCss(const CssCondition.selector('[open]'), {
            'background-color': ?backgroundColor?.css,
            if (shape case final s?) ..._shapeCss(s),
          }),
      ],
      attributes: {
        if (initiallyExpanded) 'open': '',
        'name': ?name,
        // The width the header stops being a Tab stop at (see
        // `permanentScript`).
        if (permanentFrom case final bp?)
          'data-thor-pf': _pixels(Theme.of(context).breakpoints[bp]),
        ...elementEventAttributes({'toggle': onExpansionChanged}),
      },
      children: [
        thorElement(
          'summary',
          css: {
            if (fusedTitle != null) ...fusedTitle.css,
            'display': 'flex',
            'align-items': 'center',
            'gap': cssPx(gap),
            'min-height': cssPx(minHeight),
            'padding': EdgeInsets.fromLTRB(
              padStart,
              pad?.top ?? 8,
              padEnd,
              pad?.bottom ?? 8,
            ).css,
            'box-sizing': 'border-box',
            'cursor': 'pointer',
            'list-style': 'none',
            'font-size': ThemeTokens.bodyLargeSize,
            'letter-spacing': ThemeTokens.bodyLargeTracking,
            'line-height': ThemeTokens.bodyLargeLine,
            'color': collapsedTextColor?.css ?? _onSurface,
            'position': 'relative',
            // Again last: the title's own style wins over the theme's above,
            // as Flutter merges the Text's style over the tile's (a key
            // keeps its first place, so the rule reads as before).
            if (fusedTitle != null) ...fusedTitle.css,
          },
          conditions: [
            const ConditionalCss(
              CssCondition.selector('::-webkit-details-marker'),
              {'display': 'none'},
            ),
            // web: the chevron is a masked pseudo-element (its color follows
            // the theme), not a node.
            if (hasChevron)
              ConditionalCss(const CssCondition.selector('::after'), {
                'content': '""',
                'position': 'absolute',
                if (leadingChevron)
                  'left': cssPx(start)
                else
                  'right': cssPx(end),
                'top': '50%',
                'width': cssPx(iconSize),
                'height': cssPx(iconSize),
                'margin-top': cssPx(-iconSize / 2),
                if (collapsedIconTurns != 0)
                  'rotate': _turns(collapsedIconTurns),
                'background-color':
                    collapsedIconColor?.css ?? _onSurfaceVariant,
                'mask': _chevron(iconSize),
                '-webkit-mask': _chevron(iconSize),
                // Flutter turns the icon and changes its color with the
                // same controller as the content.
                'transition':
                    'rotate $_expansionMotion, '
                    'background-color $_expansionMotion',
              }),
            if (hasChevron)
              ConditionalCss(
                CssCondition.both(
                  CssCondition.reducedMotion,
                  const CssCondition.selector('::after'),
                ),
                const {'transition-duration': '1ms'},
              ),
            ConditionalCss(CssCondition.hover, {
              'background-color': hoverColor?.css ?? _hover,
            }),
            _focusRing,
          ],
          childRules: ChildRules.row,
          children: [
            ?_tintIcon(leading, iconColor, collapsedIconColor),
            if (fusedTitle != null)
              fusedTitle.node
            else if (subtitle == null)
              WrapWith(const WrapData(css: {'flex': '1 1 0'}), child: title)
            else
              thorElement(
                'span',
                css: const {...boxCss, 'flex': '1 1 0'},
                children: [
                  title,
                  WrapWith(
                    const WrapData(
                      css: {
                        'font-size': ThemeTokens.bodyMediumSize,
                        'letter-spacing': ThemeTokens.bodyMediumTracking,
                        'color': _onSurfaceVariant,
                      },
                    ),
                    child: subtitle!,
                  ),
                ],
              ),
            ?_tintIcon(trailingWidget, iconColor, collapsedIconColor),
          ],
        ),
        if (children.length == 1 && _inlineText(children.single) != null)
          thorElement(
            'div',
            css: {
              ...boxCss,
              ...childrenPadding.toCss('padding'),
              ..._inlineText(children.single)!.css,
            },
            children: [_inlineText(children.single)!.node],
          )
        else
          thorElement(
            'div',
            css: {...boxCss, ...childrenPadding.toCss('padding')},
            childRules: ChildRules.column,
            children: children,
          ),
      ],
    );
    final watch = expandedWatch;
    return watch == null
        ? tile
        : WatchAttributes({AttributeName.open: watch}, child: tile);
  }
}

/// How long an [ExpansionTile] takes to open or close.
const _expansionDuration = Duration(milliseconds: 250);

/// The timing every part of an [ExpansionTile] moves with (see its rules).
final _expansionMotion =
    '${cssDuration(_expansionDuration)} ${Curves.fastOutSlowIn.css}';

String _pixels(double px) => '${px == px.roundToDouble() ? px.round() : px}';

/// The rules that make a closed [ExpansionTile] a plain open block from [bp]
/// up (see `ExpansionTile.permanentFrom`).
List<ConditionalCss> _expansionPermanent(WindowSizeClass bp) => [
  ConditionalCss(
    CssCondition.both(
      CssCondition.breakpoint(bp),
      const CssCondition.selector('::details-content'),
    ),
    const {
      'content-visibility': 'visible',
      'display': 'block',
      'block-size': 'auto',
      'opacity': '1',
    },
  ),
  // The header stops being a control only where the content shows without
  // it: a browser without `::details-content` keeps the accordion working.
  ConditionalCss(
    CssCondition.both(
      CssCondition.breakpoint(bp),
      CssCondition.supports(
        'selector(::details-content)',
        const CssCondition.selector(' > summary'),
      ),
    ),
    const {'pointer-events': 'none', 'cursor': 'default'},
  ),
  ConditionalCss(
    CssCondition.both(
      CssCondition.breakpoint(bp),
      CssCondition.supports(
        'selector(::details-content)',
        const CssCondition.selector(' > summary::after'),
      ),
    ),
    const {'display': 'none'},
  ),
];

/// Flutter's `ExpansionPanelList.radio`-like group: only one tile open.
class ExpansionPanelList extends StatelessWidget
    implements LayoutHint, ThorElementWidget, ThorBuiltIn {
  /// Creates an exclusive-open group of `ExpansionTile`s.
  const ExpansionPanelList({
    super.key,
    required this.name,
    required this.children,
  });

  /// Accordion group name (`<details name>`).
  final String name;

  /// Tiles in the group; rebuilt with the shared `name`.
  final List<ExpansionTile> children;

  @override
  bool get fillsWidth => true;

  @override
  Widget build(BuildContext context) => thorElement(
    'div',
    debugName: 'ExpansionPanelList',
    fillsWidth: true,
    css: const {
      ...boxCss,
      'border': '1px solid $_outlineVariant',
      'border-radius': '12px',
      'overflow': 'hidden',
    },
    childRules: ChildRules.column,
    children: [for (final t in children) t._inGroup(name)],
  );
}

const _chipBase = <String, String>{
  'display': 'inline-flex',
  'align-items': 'center',
  'gap': '8px',
  'box-sizing': 'border-box',
  'min-height': '32px',
  // web: a label longer than its container wraps inside the chip (as
  // Flutter's does) instead of overflowing it.
  'max-width': '100%',
  'padding': '0 16px',
  'border': '1px solid $_outline',
  'border-radius': '8px',
  'font-size': ThemeTokens.labelLargeSize,
  'letter-spacing': ThemeTokens.labelLargeTracking,
  'font-weight': ThemeTokens.labelLargeWeight,
  'line-height': ThemeTokens.labelLargeLine,
  'color': _onSurfaceVariant,
  'background-color': 'transparent',
  'overflow-wrap': 'anywhere',
};

/// The look of a chip (Flutter's chip style parameters). Not exported.
class _ChipStyle {
  const _ChipStyle({
    this.selectedColor,
    this.disabledColor,
    this.backgroundColor,
    this.shape,
    this.side,
    this.labelStyle,
    this.padding,
    this.showCheckmark,
  });

  final Color? selectedColor;
  final Color? disabledColor;
  final Color? backgroundColor;
  final OutlinedBorder? shape;
  final BorderSide? side;
  final TextStyle? labelStyle;
  final EdgeInsetsGeometry? padding;
  final bool? showCheckmark;

  /// This style with the chip theme's values where its own are null.
  _ChipStyle over(ChipThemeData? t) => t == null
      ? this
      : _ChipStyle(
          selectedColor: selectedColor ?? t.selectedColor,
          disabledColor: disabledColor ?? t.disabledColor,
          backgroundColor: backgroundColor ?? t.backgroundColor,
          shape: shape ?? t.shape,
          side: side ?? t.side,
          labelStyle: labelStyle ?? t.labelStyle,
          padding: padding ?? t.padding,
          showCheckmark: showCheckmark ?? t.showCheckmark,
        );

  CssDeclarations get css {
    final border = side ?? shape?.side;
    return {
      'background-color': ?backgroundColor?.css,
      'border-radius': ?shape?.radiusCss,
      if (border != null)
        'border': border == BorderSide.none ? '0' : border.css,
      ...?padding?.toCss('padding'),
      ...?labelStyle?.toCss(),
    };
  }

  CssDeclarations get selectedCss => {
    'background-color': selectedColor?.css ?? _secondaryContainer,
    if (side == null && shape?.side == null) 'border-color': 'transparent',
    'color': labelStyle?.color?.css ?? ThemeTokens.onSecondaryContainer,
  };
}

/// The delete control of a chip: Flutter's `onDeleted`, `deleteIcon`,
/// `deleteIconColor` and `deleteButtonTooltipMessage`, and the web extra
/// `deleteHref`. Not exported.
class _ChipDelete {
  const _ChipDelete({
    required this.engine,
    required this.href,
    required this.icon,
    required this.color,
    required this.tooltip,
  });

  /// `null` when the chip has neither `onDeleted` nor `deleteHref`.
  static _ChipDelete? of({
    required Function? onDeleted,
    required String? href,
    required Widget? icon,
    required Color? color,
    required String? tooltip,
  }) => onDeleted == null && href == null
      ? null
      : _ChipDelete(
          engine: engineAttributes({'click': onDeleted}),
          href: href,
          icon: icon,
          color: color,
          tooltip: tooltip,
        );

  /// The same control with the chip theme's icon color when it has none.
  _ChipDelete themed(Color? themeColor) => color != null || themeColor == null
      ? this
      : _ChipDelete(
          engine: engine,
          href: href,
          icon: icon,
          color: themeColor,
          tooltip: tooltip,
        );

  /// The click handler's attributes.
  final Map<String, String> engine;

  /// Where the control goes (a link) instead of calling a handler.
  final String? href;
  final Widget? icon;
  final Color? color;
  final String? tooltip;
}

/// A chip with an icon and a label (and, when they navigate, as a link).
const _linkBase = <String, String>{
  'text-decoration': 'none',
  'color': 'inherit',
};

/// One chip, for [Chip], [InputChip], [FilterChip], [ChoiceChip] and
/// [ActionChip]. Not exported.
///
/// The body is a `<button>` (it does something), an `<a>` (it has an
/// `href`) or a `<span>` (it is only a label). Its selected state is
/// `aria-pressed` on a button and `aria-current` on a link: a condition of
/// the same class. With a [delete] control the chip is a wrapper `<span>`
/// around two sibling controls (the body and the delete one), because a
/// control cannot hold another; a label-only body is then the wrapper's own
/// text.
Widget _chip({
  required BuildContext context,
  required String debugName,
  required Widget label,
  Widget? avatar,
  bool? selected,
  bool interactive = false,
  bool disabled = false,
  String? href,
  String? tooltip,
  Map<String, String> engine = const {},
  _ChipStyle style = const _ChipStyle(),
  _ChipDelete? delete,
}) {
  // The parameter, else `ThemeData.chipTheme`, else the chip's default.
  final theme = Theme.of(context).chipTheme;
  style = style.over(theme);
  delete = delete?.themed(theme?.deleteIconColor);
  final link = href != null && !disabled;
  final control = interactive || link;
  final inline = avatar == null ? _inlineText(label) : null;
  final mark = link ? '[aria-current="true"]' : '[aria-pressed="true"]';
  final checkmark = control && (style.showCheckmark ?? false)
      // web: the checkmark is a glyph before the label, not an avatar
      // that animates in.
      ? ConditionalCss(CssCondition.selector('$mark::before'), {
          'content': '"\\2713"',
          'font-size': '18px',
          'line-height': '1',
        })
      : null;
  final content = [?avatar, inline?.node ?? label];
  final attributes = {
    if (link) 'href': href,
    if (control && !link) 'type': 'button',
    if (link && selected == true)
      'aria-current': 'true'
    else if (control && !link && selected != null)
      'aria-pressed': '$selected',
    if (disabled)
      if (control && !link) 'disabled': '' else 'aria-disabled': 'true',
    'title': ?tooltip,
    ...engine,
  };
  final disabledCss = {
    'cursor': 'default',
    'opacity': '0.38',
    'background-color': ?style.disabledColor?.css,
  };

  if (delete == null) {
    return thorElement(
      link ? 'a' : (control ? 'button' : 'span'),
      debugName: debugName,
      baseCss: link ? _linkBase : (control ? buttonResetCss : const {}),
      css: {
        ..._chipBase,
        if (control) ...const {
          'cursor': 'pointer',
          'transition-property': 'background-color, border-color',
          'transition-duration': '150ms',
        },
        ...?inline?.css,
        ...style.css,
        // Only a label: nothing switches it, so it is written as it is.
        if (!control && selected == true) ...style.selectedCss,
      },
      conditions: [
        if (control) ...[
          ConditionalCss(CssCondition.selector(mark), style.selectedCss),
          ?checkmark,
          const ConditionalCss(CssCondition.hoverEnabled, {
            'box-shadow': 'inset 0 0 0 100px $_hover',
          }),
          _focusRing,
          ConditionalCss(CssCondition.disabled, disabledCss),
          const ConditionalCss(CssCondition.reducedMotion, {
            'transition-duration': '1ms',
          }),
        ] else if (disabled)
          ConditionalCss(
            const CssCondition.selector('[aria-disabled="true"]'),
            disabledCss,
          ),
      ],
      attributes: attributes,
      childRules: ChildRules.row,
      children: content,
    );
  }

  final name = label is Text ? label.data : null;
  final tip =
      delete.tooltip ?? MaterialLocalizations.of(context).deleteButtonTooltip;
  final deleteLink = delete.href != null && !disabled;
  final body = control
      ? thorElement(
          link ? 'a' : 'button',
          baseCss: link ? _linkBase : buttonResetCss,
          css: const {
            'display': 'inline-flex',
            'align-items': 'center',
            'gap': '8px',
            'align-self': 'stretch',
            'flex': '0 1 auto',
            'min-width': '0',
            'padding-inline': '16px 4px',
            'border-radius': 'inherit',
          },
          conditions: [
            ?checkmark,
            _focusRing,
            const ConditionalCss(CssCondition.disabled, {'cursor': 'default'}),
          ],
          attributes: attributes,
          childRules: ChildRules.row,
          children: content,
        )
      : null;
  return thorElement(
    'span',
    debugName: debugName,
    css: {
      ..._chipBase,
      // The controls carry the padding, so each is a target to its edge.
      'padding': '0',
      if (!control) 'padding-inline-start': '16px',
      'gap': control ? '0' : '8px',
      ...?inline?.css,
      ...style.css,
      if (!control && selected == true) ...style.selectedCss,
    },
    conditions: [
      if (control) ...[
        ConditionalCss(
          CssCondition.selector(':has(> $mark)'),
          style.selectedCss,
        ),
        const ConditionalCss(CssCondition.hoverEnabled, {
          'box-shadow': 'inset 0 0 0 100px $_hover',
        }),
      ],
      if (disabled)
        ConditionalCss(
          const CssCondition.selector('[aria-disabled="true"]'),
          disabledCss,
        ),
    ],
    attributes: {if (disabled) 'aria-disabled': 'true'},
    childRules: ChildRules.row,
    children: [
      if (body != null) body else ...content,
      thorElement(
        deleteLink ? 'a' : 'button',
        baseCss: deleteLink ? _linkBase : buttonResetCss,
        css: {
          'display': 'inline-flex',
          'align-items': 'center',
          'justify-content': 'center',
          'flex': 'none',
          'width': '24px',
          'height': '24px',
          'margin-inline-end': '6px',
          'border-radius': '50%',
          'color': ?delete.color?.css,
        },
        conditions: const [
          ConditionalCss(CssCondition.hoverEnabled, {
            'background-color': _hover,
          }),
          _focusRing,
          ConditionalCss(CssCondition.disabled, {'cursor': 'default'}),
        ],
        attributes: {
          if (deleteLink) 'href': delete.href!,
          if (!deleteLink) 'type': 'button',
          if (disabled && !deleteLink) 'disabled': '',
          'aria-label': name == null ? tip : '$tip $name',
          'title': tip,
          if (!disabled) ...delete.engine,
        },
        childRules: ChildRules.row,
        children: [delete.icon ?? const Icon(Icons.cancel, size: 18)],
      ),
    ],
  );
}

/// Flutter's `Chip`: a label, with an optional avatar and delete control.
///
/// ```dart
/// Chip(label: Text('Red'), href: '/c/red')                       // a link
/// Chip(label: Text('Red'), onDeleted: filters.remove)           // with an X
/// ```
class Chip extends StatelessWidget implements ThorElementWidget, ThorBuiltIn {
  /// Creates a Material chip.
  const Chip({
    super.key,
    required this.label,
    this.avatar,
    this.labelStyle,
    this.padding,
    this.backgroundColor,
    this.side,
    this.shape,
    this.deleteIcon,
    this.onDeleted,
    this.deleteIconColor,
    this.deleteButtonTooltipMessage,
    this.href,
    this.deleteHref,
  });

  /// Content of the chip.
  final Widget label;

  /// Optional leading icon or avatar.
  final Widget? avatar;

  /// Font and color of the label.
  final TextStyle? labelStyle;

  /// Space around the label.
  final EdgeInsetsGeometry? padding;

  /// Fill.
  final Color? backgroundColor;

  /// Outline (wins over the shape's side).
  final BorderSide? side;

  /// Corner shape.
  final OutlinedBorder? shape;

  /// The delete control's icon (Flutter's default: a circled X).
  final Widget? deleteIcon;

  /// Called when the delete control is pressed; without it (and without
  /// [deleteHref]) the chip has none.
  final VoidCallback? onDeleted;

  /// Color of the delete icon.
  final Color? deleteIconColor;

  /// The delete control's name (its tooltip and, with the label, its
  /// accessible name: "Delete Red"); Flutter's default is "Delete".
  final String? deleteButtonTooltipMessage;

  // web: not in Flutter.
  /// Makes the chip a link (`<a href>`), e.g. a facet or a tag.
  final String? href;

  // web: not in Flutter.
  /// The delete control is a link (`<a href>`) to where the chip
  /// is gone, which works without JavaScript.
  final String? deleteHref;

  @override
  Widget build(BuildContext context) => _chip(
    context: context,
    debugName: 'Chip',
    label: label,
    avatar: avatar,
    href: href,
    style: _ChipStyle(
      backgroundColor: backgroundColor,
      shape: shape,
      side: side,
      labelStyle: labelStyle,
      padding: padding,
    ),
    delete: _ChipDelete.of(
      onDeleted: onDeleted,
      href: deleteHref,
      icon: deleteIcon,
      color: deleteIconColor,
      tooltip: deleteButtonTooltipMessage,
    ),
  );
}

/// Flutter's `InputChip`: a piece of user input (a tag, a filter) that can
/// be pressed or selected and removed with its delete control.
///
/// Without [onPressed] or [onSelected] it is not a control (like [Chip]).
/// With [href] it is a link. `onSelected` and `onPressed` can't both be set
/// (Flutter's rule).
///
/// ```dart
/// InputChip(label: Text('Red'), onDeleted: filters.remove)
/// InputChip(label: Text('Red'), href: '/c/red', deleteHref: '/c')
/// ```
class InputChip extends StatelessWidget
    implements ThorElementWidget, ThorBuiltIn {
  /// Creates a Material input chip.
  const InputChip({
    super.key,
    this.avatar,
    required this.label,
    this.labelStyle,
    this.padding,
    this.selected = false,
    this.isEnabled = true,
    this.onSelected,
    this.deleteIcon,
    this.onDeleted,
    this.deleteIconColor,
    this.deleteButtonTooltipMessage,
    this.onPressed,
    this.selectedColor,
    this.tooltip,
    this.side,
    this.shape,
    this.backgroundColor,
    this.showCheckmark,
    this.href,
    this.deleteHref,
  }) : assert(
         onSelected == null || onPressed == null,
         'InputChip: onSelected and onPressed cannot both be set',
       );

  /// Optional leading icon or avatar.
  final Widget? avatar;

  /// Content of the chip.
  final Widget label;

  /// Font and color of the label (its color also when selected).
  final TextStyle? labelStyle;

  /// Space around the label.
  final EdgeInsetsGeometry? padding;

  /// Whether the chip is selected (shown when it can be, with
  /// [onSelected]).
  final bool selected;

  /// Whether the chip responds to input (Flutter's default: true).
  final bool isEnabled;

  /// Called with the new `selected` value when the body is tapped.
  final ValueChanged<bool>? onSelected;

  /// The delete control's icon (Flutter's default: a circled X).
  final Widget? deleteIcon;

  /// Called when the delete control is pressed; without it (and without
  /// [deleteHref]) the chip has none.
  final VoidCallback? onDeleted;

  /// Color of the delete icon.
  final Color? deleteIconColor;

  /// The delete control's name (its tooltip and, with the label, its
  /// accessible name: "Delete Red"); Flutter's default is "Delete".
  final String? deleteButtonTooltipMessage;

  /// Called when the body is tapped.
  final VoidCallback? onPressed;

  /// Fill when selected.
  final Color? selectedColor;

  /// Text shown on hover and focus (`title`).
  final String? tooltip;

  /// Outline (wins over the shape's side).
  final BorderSide? side;

  /// Corner shape.
  final OutlinedBorder? shape;

  /// Fill when not selected.
  final Color? backgroundColor;

  /// Whether a checkmark shows before the label when selected.
  // web: null draws none (Flutter's Material 3 default draws it).
  final bool? showCheckmark;

  // web: not in Flutter.
  /// Makes the body a link (`<a href>`). A selected link is
  /// `aria-current="true"`, not a toggle.
  final String? href;

  // web: not in Flutter.
  /// The delete control is a link (`<a href>`) to where the chip
  /// is gone, which works without JavaScript.
  final String? deleteHref;

  @override
  Widget build(BuildContext context) => _chip(
    context: context,
    debugName: 'InputChip',
    label: label,
    avatar: avatar,
    selected: onSelected != null || href != null || selected ? selected : null,
    interactive: onSelected != null || onPressed != null,
    disabled: !isEnabled,
    href: href,
    tooltip: tooltip,
    engine: onSelected != null
        ? engineAttributes({'click': onSelected}, arg: !selected)
        : engineAttributes({'click': onPressed}),
    style: _ChipStyle(
      selectedColor: selectedColor,
      backgroundColor: backgroundColor,
      shape: shape,
      side: side,
      labelStyle: labelStyle,
      padding: padding,
      showCheckmark: showCheckmark,
    ),
    delete: _ChipDelete.of(
      onDeleted: onDeleted,
      href: deleteHref,
      icon: deleteIcon,
      color: deleteIconColor,
      tooltip: deleteButtonTooltipMessage,
    ),
  );
}

/// Flutter's `FilterChip`: toggles; `onSelected(!selected)`.
///
/// With [href] it is a link to the filtered page (`aria-current` when
/// selected).
class FilterChip extends StatelessWidget
    implements ThorElementWidget, ThorBuiltIn {
  /// Creates a toggleable Material filter chip.
  const FilterChip({
    super.key,
    this.avatar,
    required this.label,
    this.labelStyle,
    this.padding,
    required this.selected,
    required this.onSelected,
    this.tooltip,
    this.backgroundColor,
    this.selectedColor,
    this.side,
    this.shape,
    this.showCheckmark,
    this.href,
  });

  /// Optional leading icon or avatar.
  final Widget? avatar;

  /// Content of the chip.
  final Widget label;

  /// Font and color of the label (its color also when selected).
  final TextStyle? labelStyle;

  /// Space around the label.
  final EdgeInsetsGeometry? padding;

  /// Whether the chip is currently selected.
  final bool selected;

  /// Called with the new `selected` value when tapped.
  final ValueChanged<bool>? onSelected;

  /// Text shown on hover and focus (`title`).
  final String? tooltip;

  /// Fill when not selected.
  final Color? backgroundColor;

  /// Fill when selected.
  final Color? selectedColor;

  /// Outline (wins over the shape's side).
  final BorderSide? side;

  /// Corner shape.
  final OutlinedBorder? shape;

  /// Whether a checkmark shows before the label when selected.
  // web: null draws none (Flutter's Material 3 default draws it).
  final bool? showCheckmark;

  // web: not in Flutter.
  /// Makes the chip a link (`<a href>`) to the page with the
  /// filter on or off; it works without JavaScript. A selected link is
  /// `aria-current="true"`, not a toggle.
  final String? href;

  @override
  Widget build(BuildContext context) => _chip(
    context: context,
    debugName: 'FilterChip',
    label: label,
    avatar: avatar,
    selected: selected,
    interactive: true,
    disabled: onSelected == null && href == null,
    href: href,
    tooltip: tooltip,
    engine: engineAttributes({'click': onSelected}, arg: !selected),
    style: _ChipStyle(
      selectedColor: selectedColor,
      backgroundColor: backgroundColor,
      shape: shape,
      side: side,
      labelStyle: labelStyle,
      padding: padding,
      showCheckmark: showCheckmark,
    ),
  );
}

/// Flutter's `ChoiceChip`: one of a group; `onSelected(true)`.
///
/// With [href] it is a link to the page of that choice (`aria-current` when
/// selected).
class ChoiceChip extends StatelessWidget
    implements ThorElementWidget, ThorBuiltIn {
  /// Creates a Material choice chip, one of a group.
  const ChoiceChip({
    super.key,
    this.avatar,
    required this.label,
    this.labelStyle,
    this.padding,
    required this.selected,
    required this.onSelected,
    this.tooltip,
    this.backgroundColor,
    this.selectedColor,
    this.side,
    this.shape,
    this.showCheckmark,
    this.href,
  });

  /// Optional leading icon or avatar.
  final Widget? avatar;

  /// Content of the chip.
  final Widget label;

  /// Font and color of the label (its color also when selected).
  final TextStyle? labelStyle;

  /// Space around the label.
  final EdgeInsetsGeometry? padding;

  /// Whether this chip is the chosen one.
  final bool selected;

  /// Called with `true` when the chip is tapped.
  final ValueChanged<bool>? onSelected;

  /// Text shown on hover and focus (`title`).
  final String? tooltip;

  /// Fill when not selected.
  final Color? backgroundColor;

  /// Fill when selected.
  final Color? selectedColor;

  /// Outline (wins over the shape's side).
  final BorderSide? side;

  /// Corner shape.
  final OutlinedBorder? shape;

  /// Whether a checkmark shows before the label when selected.
  // web: null draws none (Flutter's Material 3 default draws it).
  final bool? showCheckmark;

  // web: not in Flutter.
  /// Makes the chip a link (`<a href>`) to the page of this
  /// choice; it works without JavaScript. A selected link is
  /// `aria-current="true"`, not a toggle.
  final String? href;

  @override
  Widget build(BuildContext context) => _chip(
    context: context,
    debugName: 'ChoiceChip',
    label: label,
    avatar: avatar,
    selected: selected,
    interactive: true,
    disabled: onSelected == null && href == null,
    href: href,
    tooltip: tooltip,
    engine: engineAttributes({'click': onSelected}, arg: true),
    style: _ChipStyle(
      selectedColor: selectedColor,
      backgroundColor: backgroundColor,
      shape: shape,
      side: side,
      labelStyle: labelStyle,
      padding: padding,
      showCheckmark: showCheckmark,
    ),
  );
}

/// Flutter's `ActionChip`. With [href] it is a link.
class ActionChip extends StatelessWidget
    implements ThorElementWidget, ThorBuiltIn {
  /// Creates a Material action chip that triggers `onPressed`.
  const ActionChip({
    super.key,
    this.avatar,
    required this.label,
    required this.onPressed,
    this.tooltip,
    this.href,
  });

  /// Optional leading icon or avatar.
  final Widget? avatar;

  /// Content of the chip.
  final Widget label;

  /// Called when the chip is tapped.
  final VoidCallback? onPressed;

  /// Text shown on hover and focus (`title`).
  final String? tooltip;

  // web: not in Flutter.
  /// Makes the chip a link (`<a href>`); it works without
  /// JavaScript.
  final String? href;

  @override
  Widget build(BuildContext context) => _chip(
    context: context,
    debugName: 'ActionChip',
    label: label,
    avatar: avatar,
    interactive: true,
    disabled: onPressed == null && href == null,
    href: href,
    tooltip: tooltip,
    engine: engineAttributes({'click': onPressed}),
  );
}

/// Flutter's `Badge`: a small label on the top-right corner of [child].
///
/// ```dart
/// Badge.count(count: cart.length, child: Icon(cartIcon))
/// ```
class Badge extends StatelessWidget implements ThorElementWidget, ThorBuiltIn {
  /// Creates a Material badge on top of `child`.
  const Badge({
    super.key,
    this.backgroundColor,
    this.textColor,
    this.smallSize,
    this.largeSize,
    this.textStyle,
    this.padding,
    this.alignment,
    this.offset,
    this.label,
    this.isLabelVisible = true,
    this.child,
  });

  /// Creates a badge with the number [count] (`999+` past [maxCount]).
  Badge.count({
    super.key,
    this.backgroundColor,
    this.textColor,
    this.smallSize,
    this.largeSize,
    this.textStyle,
    this.padding,
    this.alignment,
    this.offset,
    required int count,
    int maxCount = 999,
    this.isLabelVisible = true,
    this.child,
  }) : assert(count >= 0, 'count must be non-negative'),
       assert(maxCount > 0, 'maxCount must be positive'),
       label = Text(count > maxCount ? '$maxCount+' : '$count');

  /// Fill (Flutter's default: the error color).
  final Color? backgroundColor;

  /// Color of the label (Flutter's default: on-error).
  final Color? textColor;

  /// Size of the dot, when there is no [label] (Flutter's default: 6).
  final double? smallSize;

  /// Smallest size of the badge with a [label] (Flutter's default: 16).
  final double? largeSize;

  /// Font of the label (Flutter's default: label small).
  final TextStyle? textStyle;

  /// Space around the label (Flutter's default: 4 on each side).
  final EdgeInsetsGeometry? padding;

  /// Where on [child] the badge sits (Flutter's default:
  /// `AlignmentDirectional.topEnd`).
  // web: only the physical [Alignment] exists; without one the badge sits
  // at the end corner of the inline direction (it flips in RTL).
  final Alignment? alignment;

  /// Displacement from [alignment] (Flutter's default: 4 to the end and 4
  /// up, a label centered on a line 4 below the top).
  // web: the default 4 flips in RTL; a given offset is physical.
  final Offset? offset;

  /// `null` → the small dot.
  final Widget? label;

  /// Whether the badge is shown (Flutter's default: true).
  final bool isLabelVisible;

  /// Widget the badge is anchored to.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    if (!isLabelVisible) return child ?? const Widget.fragment([]);
    final hasLabel = label != null;
    final inline = _inlineText(label);
    final size = hasLabel ? (largeSize ?? 16) : (smallSize ?? 6);
    final look = <String, String>{
      'box-sizing': 'border-box',
      'border-radius': '9999px',
      'background-color': backgroundColor?.css ?? ThemeTokens.error,
      if (hasLabel) ...{
        'min-width': cssPx(size),
        'min-height': cssPx(size),
        ...(padding?.toCss('padding') ?? const {'padding': '0 4px'}),
        'color': textColor?.css ?? ThemeTokens.onError,
        'font-size': 'var(--t-label-small-size, 11px)',
        'letter-spacing': 'var(--t-label-small-tracking, normal)',
        'line-height': 'var(--t-label-small-line, 16px)',
        'text-align': 'center',
        ...?inline?.css,
        ...?textStyle?.toCss(),
        if (textColor != null) 'color': textColor!.css,
      } else ...{
        'width': cssPx(size),
        'height': cssPx(size),
      },
    };
    if (child == null) {
      return thorElement(
        'span',
        debugName: 'Badge',
        css: {'display': 'inline-block', 'flex': 'none', ...look},
        childRules: ChildRules.row,
        children: [if (hasLabel) inline?.node ?? label!],
      );
    }
    // Flutter's `_RenderBadge`: the badge's start edge is at
    // `(1 + x) / 2 * (width - size) + dx` and, with a label, its center is
    // `(1 + y) / 2 * height + dy + 8` from the top (the 8 is Flutter's fix
    // for the old offset); a dot takes no offset.
    final a = alignment;
    final fx = a == null ? 1.0 : (1 + a.x) / 2;
    final fy = a == null ? 0.0 : (1 + a.y) / 2;
    final dx = hasLabel ? (offset?.dx ?? 4) : 0.0;
    final dy = hasLabel ? (offset?.dy ?? -4) + 8 : 0.0;
    String pos(double f, String full, double shift) {
      final base = switch (f) {
        0 => null,
        1 => full,
        _ => '($full) * ${cssNum(f)}',
      };
      if (base == null) return shift == 0 ? '0' : cssPx(shift);
      if (shift == 0) return 'calc($base)';
      return 'calc($base ${shift < 0 ? '-' : '+'} ${cssPx(shift.abs())})';
    }

    final x = pos(fx, '100% - ${cssPx(size)}', 0);
    final badge = thorElement(
      'span',
      css: {
        'position': 'absolute',
        if (a == null) 'inset-inline-start': x else 'left': x,
        'top': pos(fy, '100%', dy),
        if (hasLabel) 'translate': '${cssPx(dx)} -50%',
        ...look,
      },
      conditions: [
        if (hasLabel && offset == null)
          // web: Flutter's default offset mirrors in RTL; the browser knows
          // the direction.
          ConditionalCss(const CssCondition.selector(':dir(rtl)'), {
            'translate': '${cssPx(-dx)} -50%',
          }),
      ],
      children: [if (hasLabel) inline?.node ?? label!],
    );
    return thorElement(
      'span',
      debugName: 'Badge',
      css: const {
        'display': 'inline-grid',
        'position': 'relative',
        'flex': 'none',
      },
      childRules: ChildRules.stack,
      children: [child!, badge],
    );
  }
}

/// Flutter's `LinearProgressIndicator` on `<progress>`: determinate with a
/// [value], the browser's own indeterminate animation without one.
class LinearProgressIndicator extends StatelessWidget
    implements LayoutHint, ThorElementWidget, ThorBuiltIn {
  /// Creates a horizontal Material progress indicator.
  const LinearProgressIndicator({
    super.key,
    this.value,
    this.color,
    this.minHeight,
    this.semanticsLabel,
  }) : upload = false,
       _source = null;

  /// A bar whose progress is the number [source] returns (0 to 1; a
  /// `ThorState` method or a field's `call`; null is indeterminate), kept
  /// current in the browser: the page is not rebuilt.
  ///
  /// ```dart
  /// LinearProgressIndicator.watch(timer.fraction)
  /// ```
  ///
  /// `// web:` no Flutter counterpart: Flutter rebuilds with a new `value`.
  /// It replaces `WatchAttributes({AttributeName.value: …}, child: LinearProgressIndicator(…))`.
  LinearProgressIndicator.watch(
    double? Function() source, {
    super.key,
    this.color,
    this.minHeight,
    this.semanticsLabel,
  }) : value = untracked(source),
       upload = false,
       _source = source;

  /// `// web:` the bar of a `Form` that sends files: it is hidden, and the
  /// page that has it ships a small script of its own that sends the
  /// files with an `XMLHttpRequest` (`fetch` has no upload progress), shows
  /// the bar and fills it as the bytes leave; the result is then the
  /// browser's own navigation. Put it inside a
  /// `Form(encoding: FormEncoding.multipart)` with a `FileField`. Without
  /// JavaScript the form is the plain post and the bar stays hidden.
  ///
  /// ```dart
  /// Form(
  ///   action: '/videos',
  ///   encoding: FormEncoding.multipart,
  ///   child: Column(children: [
  ///     FileField(name: 'video'),
  ///     LinearProgressIndicator.upload(),
  ///     FilledButton(buttonType: ButtonType.submit, child: Text('Upload')),
  ///   ]),
  /// )
  /// ```
  const LinearProgressIndicator.upload({
    super.key,
    this.color,
    this.minHeight,
    this.semanticsLabel,
  }) : value = null,
       upload = true,
       _source = null;

  /// Progress from 0 to 1; `null` for an indeterminate indicator.
  final double? value;

  /// Color of the filled track (default: the theme's `color`, else Flutter's:
  /// the primary color).
  final Color? color;

  /// Height of the bar, in logical pixels (default: the theme's
  /// `linearMinHeight`, else Flutter's 4).
  final double? minHeight;

  /// Accessible label for the indicator.
  final String? semanticsLabel;

  /// Whether it is the upload bar of a form ([LinearProgressIndicator.upload]).
  final bool upload;

  final double? Function()? _source;

  @override
  bool get fillsWidth => true;

  @override
  Widget build(BuildContext context) {
    // Only a page with the bar ships the upload script.
    if (upload) ThorStyleRegistry.active(context)?.useUploadScript();
    final source = _source;
    return source == null
        ? _bar(context)
        : WatchAttributes({AttributeName.value: source}, child: _bar(context));
  }

  Widget _bar(BuildContext context) {
    final theme = Theme.of(context).progressIndicatorTheme;
    return _barElement(context, theme);
  }

  Widget _barElement(BuildContext context, ProgressIndicatorThemeData? theme) =>
      thorElement(
        'progress',
        debugName: 'LinearProgressIndicator',
        fillsWidth: true,
        // A class' `display: block` would beat the `hidden` attribute.
        conditions: upload
            ? const [
                ConditionalCss(CssCondition.selector('[hidden]'), {
                  'display': 'none',
                }),
              ]
            : const [],
        css: {
          'display': 'block',
          'box-sizing': 'border-box',
          'width': '100%',
          'height': cssPx(minHeight ?? theme?.linearMinHeight ?? 4),
          'accent-color': (color ?? theme?.color)?.css ?? _primary,
        },
        attributes: {
          if (value != null) ...{'max': '1', 'value': cssNum(value!)},
          if (value == null && _source != null) 'max': '1',
          if (upload) ...{'data-t-upload': '', 'hidden': '', 'max': '1'},
          'aria-label':
              ?(semanticsLabel ??
              (upload
                  ? ThorLocalizations.of(context).uploadProgressLabel
                  : null)),
        },
      );
}

/// Flutter's `CircularProgressIndicator` as SVG. Indeterminate spins with
/// a CSS rotation on the compositor: no JS.
class CircularProgressIndicator extends StatelessWidget
    implements ThorElementWidget, ThorBuiltIn {
  /// Creates a circular Material progress indicator.
  const CircularProgressIndicator({
    super.key,
    this.value,
    this.color,
    this.strokeWidth,
    this.size = 40,
    this.semanticsLabel,
  });

  /// Progress from 0 to 1; `null` for an indeterminate indicator.
  final double? value;

  /// Color of the stroke (default: the theme's `color`, else Flutter's: the
  /// primary color).
  final Color? color;

  /// Width of the stroke, in logical pixels (default: the theme's
  /// `circularStrokeWidth`, else Flutter's 4).
  final double? strokeWidth;

  /// web: Flutter sizes it through its parent (default 36 + padding).
  final double size;

  /// Accessible label for the indicator.
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).progressIndicatorTheme;
    final strokeWidth = this.strokeWidth ?? theme?.circularStrokeWidth ?? 4;
    final r = (size - strokeWidth) / 2;
    final circumference = 2 * 3.141592653589793 * r;
    final c = cssNum(size / 2);
    final shown = value == null ? 0.25 : value!.clamp(0.0, 1.0);
    final spin = value == null;
    // Indeterminate: a CSS rotation of the whole SVG, which runs on the
    // compositor (SMIL would re-lay out the page on every frame).
    final registry = ThorStyleRegistry.active(context);
    if (spin) registry?.addKeyframes(_spinName, _spinFrames);
    final svg = thorElement(
      'svg',
      debugName: 'CircularProgressIndicator',
      css: {
        'display': 'block',
        'flex': 'none',
        'width': cssPx(size),
        'height': cssPx(size),
        'color': (color ?? theme?.color)?.css ?? _primary,
        if (spin) 'animation': '$_spinName 1.4s linear infinite',
      },
      conditions: [
        if (spin)
          const ConditionalCss(CssCondition.reducedMotion, {
            'animation-duration': '4s',
          }),
      ],
      attributes: {
        'viewBox': '0 0 ${cssNum(size)} ${cssNum(size)}',
        'role': 'progressbar',
        if (value != null) ...{
          'aria-valuemin': '0',
          'aria-valuemax': '100',
          'aria-valuenow': cssNum((shown * 100).roundToDouble()),
        },
        'aria-label': ?semanticsLabel,
      },
      children: [
        Widget.element(
          tag: 'circle',
          attributes: {
            'cx': c,
            'cy': c,
            'r': cssNum(r),
            'fill': 'none',
            'stroke': 'currentColor',
            'stroke-width': cssNum(strokeWidth),
            'stroke-linecap': 'round',
            'stroke-dasharray':
                '${cssNum(circumference * shown)} ${cssNum(circumference)}',
            'transform': 'rotate(-90 $c $c)',
          },
        ),
      ],
    );
    if (!spin || registry != null) return svg;
    // No ThorApp: ship the keyframes next to it.
    return Widget.fragment([
      const Widget.element(
        tag: 'style',
        children: [RawText('@keyframes $_spinName{$_spinFrames}')],
      ),
      svg,
    ]);
  }

  static const _spinName = 'thor-spin';
  static const _spinFrames = 'to{rotate:1turn}';
}

/// Flutter's `CircleAvatar`: initials ([child]) or an image.
class CircleAvatar extends StatelessWidget
    implements ThorElementWidget, ThorBuiltIn {
  /// Creates a circular avatar.
  const CircleAvatar({
    super.key,
    this.radius = 20,
    this.backgroundColor,
    this.foregroundColor,
    this.backgroundImage,
    this.child,
  });

  /// Radius of the circle, in logical pixels (Flutter's default: 20).
  final double radius;

  /// Background color behind `child` (Flutter's default: the
  /// primary-container color).
  final Color? backgroundColor;

  /// Color of `child`'s content, e.g. initials text (Flutter's default: the
  /// on-primary-container color).
  final Color? foregroundColor;

  /// URL of the image (web: `ImageProvider` → a URL).
  final String? backgroundImage;

  /// Content shown when there's no `backgroundImage`, e.g. initials.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final d = cssPx(radius * 2);
    final content = resolveComponent(child);
    final text = content is Text ? content.boxContentCss : null;
    if (backgroundImage != null) {
      return thorElement(
        'img',
        debugName: 'CircleAvatar',
        css: {
          'display': 'block',
          'flex': 'none',
          'width': d,
          'height': d,
          'border-radius': '50%',
          'object-fit': 'cover',
        },
        attributes: {
          'src': backgroundImage!,
          'alt': '',
          // Intrinsic size: no layout shift while it loads.
          'width': cssNum(radius * 2),
          'height': cssNum(radius * 2),
          'loading': 'lazy',
          'decoding': 'async',
        },
      );
    }
    return thorElement(
      'span',
      debugName: 'CircleAvatar',
      css: {
        'display': 'inline-flex',
        'align-items': 'center',
        'justify-content': 'center',
        'flex': 'none',
        'width': d,
        'height': d,
        'border-radius': '50%',
        'background-color':
            backgroundColor?.css ?? ThemeTokens.primaryContainer,
        'color': foregroundColor?.css ?? ThemeTokens.onPrimaryContainer,
        'font-size': cssPx(radius * 0.8),
        'font-weight': '500',
        'overflow': 'hidden',
        ...?text,
      },
      children: [
        if (text != null) Widget.text((content! as Text).data!) else ?child,
      ],
    );
  }
}

// A dialog's shadow: Material 3's for the default, a one-layer one of the
// theme's `elevation` otherwise (0: none).
String _dialogShadow(double? elevation) => elevation == null
    ? '0 8px 24px rgba(0, 0, 0, 0.2)'
    : elevation <= 0
    ? 'none'
    : '0 ${cssPx(elevation)} ${cssPx(elevation * 3)} rgba(0, 0, 0, 0.2)';

/// Flutter's `AlertDialog`, rendered in place as a closed native `<dialog>`
/// (top layer, focus trap, Esc and backdrop for free).
///
/// Open it with [DialogTrigger] (`commandfor` + `command="show-modal"`,
/// no JS on supporting browsers; thor_engine polyfills the rest) and close it
/// with [DialogClose], or from a state method with a [controller]. Flutter's
/// imperative `showDialog` has no equivalent on a static page: the dialog is
/// part of the markup, like a `Scaffold` slot.
class AlertDialog extends StatelessWidget
    implements ThorElementWidget, ThorBuiltIn {
  /// Creates a Material alert dialog.
  const AlertDialog({
    super.key,
    this.id,
    this.title,
    this.content,
    this.actions = const [],
    this.semanticLabel,
    this.barrierDismissible = true,
    this.controller,
    this.modal = true,
    this.showClose = false,
    this.closeLabel,
  }) : assert(
         modal || controller == null,
         'A non-modal dialog has no controller',
       );

  /// Whether the dialog brings its own close button in the top corner
  /// (`DialogClose` with a close icon, named by the localized "Close").
  ///
  /// `// web:` Flutter's dialogs have no built-in close button.
  final bool showClose;

  /// The name of the [showClose] button, for assistive technology and the
  /// tooltip. Null is the localized "Close" of `MaterialLocalizations`; give
  /// it when the page's text is not in the app's locale.
  final String? closeLabel;

  /// Whether the dialog blocks the page (default) or floats over it.
  ///
  /// With `false` it is a `<dialog open>` drawn without `showModal`: it is
  /// shown from the first paint, nothing behind it turns inert, there is no
  /// backdrop, no scroll lock and Esc or a click outside do not close it
  /// ([DialogClose] does). It sits in the page flow like any positioned box,
  /// so a `Positioned` (or `Styled`) around it puts it where the app wants.
  /// It takes no [controller] and no [DialogTrigger] (there is nothing to open).
  // web: Flutter has only modal dialogs (`showDialog`); a floating card
  // there is an `Overlay` entry.
  final bool modal;

  /// DOM id (the triggers point at it). Optional: without one the dialog
  /// is named by its [controller], by its `ValueKey` or by its place in the
  /// page (the same on every render); a `DialogTrigger` finds it by that
  /// controller, and `DialogClose()` needs no id at all.
  ///
  /// `// web:` Flutter has no ids: `showDialog` pushes a route.
  final String? id;

  /// Opens and closes it from a `ThorState` method (a field of the state).
  ///
  /// `// web:` Flutter's `showDialog` / `Navigator.pop` (see
  /// `DialogController`).
  final DialogController? controller;

  /// Heading content.
  final Widget? title;

  /// Body content.
  final Widget? content;

  /// Buttons shown at the bottom, right-aligned.
  final List<Widget> actions;

  /// The dialog's accessible name (`aria-label`); without it the [title]
  /// names the dialog.
  final String? semanticLabel;

  /// Backdrop click / Esc close it (`closedby="any"`).
  final bool barrierDismissible;

  @override
  Widget build(BuildContext context) {
    final id = nativeId(
      context,
      prefix: 'dlg',
      id: this.id,
      key: key,
      controller: controller,
      owner: this,
    );
    if (modal) lockScrollWhileModal(context);
    return DialogScope(
      id: id,
      child: _element(id, Theme.of(context).dialogTheme),
    );
  }

  // The parameter, else `ThemeData.dialogTheme`, else Flutter's default.
  Widget _element(String id, DialogThemeData? theme) => thorElement(
    'dialog',
    id: id,
    debugName: 'AlertDialog',
    css: {
      'box-sizing': 'border-box',
      'min-width': '280px',
      'max-width': 'min(560px, calc(100vw - 48px))',
      'padding': '24px',
      'border':
          theme?.shape?.side == null || theme!.shape!.side == BorderSide.none
          ? '0'
          : theme.shape!.side.css,
      'border-radius': theme?.shape?.radiusCss ?? '28px',
      'background-color':
          theme?.backgroundColor?.css ?? ThemeTokens.surfaceContainerHigh,
      'color': _onSurface,
      'box-shadow': _dialogShadow(theme?.elevation),
      if (modal) ...modalOverscroll,
    },
    conditions: [
      if (modal)
        ConditionalCss(const CssCondition.selector('::backdrop'), {
          'background-color': theme?.barrierColor?.css ?? 'rgba(0, 0, 0, 0.32)',
          'backdrop-filter': ?theme?.barrierFilter?.css,
        }),
      const ConditionalCss(CssCondition.selector('[open]'), {
        'display': 'flex',
        'flex-direction': 'column',
        'gap': '16px',
      }),
    ],
    attributes: {
      // Only a title that exists can name the dialog (a dangling IDREF names
      // nothing).
      if (semanticLabel != null)
        'aria-label': semanticLabel!
      else if (title != null)
        'aria-labelledby': '$id-title',
      if (modal)
        'closedby': barrierDismissible ? 'any' : 'closerequest'
      else
        'open': '',
      dialogControllerAttr: ?controllerIdOf(controller),
    },
    childRules: ChildRules.column,
    children: [
      if (showClose) DialogCloseCorner(label: closeLabel),
      if (title != null)
        WrapWith(
          WrapData(
            // web: Flutter's dialog title is a header (a route name); here
            // it is the dialog's `<h2>` that `aria-labelledby` points at, so
            // the app doesn't wrap it in `Semantics(headingLevel: 2)`. A
            // `Semantics(headingLevel:)` of its own still sets the level.
            tag: 'h2',
            baseCss: {
              'font-weight': 'inherit',
              'font-size': 'var(--t-headline-small-size, 24px)',
              'letter-spacing': 'var(--t-headline-small-tracking, normal)',
              'line-height': 'var(--t-headline-small-line, 32px)',
              // web: a theme text style is a default under the title's own.
              ...?theme?.titleTextStyle?.toCss(),
            },
            attributes: {'id': '$id-title'},
            css: const {'margin': '0'},
          ),
          child: title!,
        ),
      if (content != null)
        WrapWith(
          WrapData(
            baseCss: {
              'font-size': ThemeTokens.bodyMediumSize,
              'letter-spacing': ThemeTokens.bodyMediumTracking,
              'line-height': ThemeTokens.bodyMediumLine,
              'color': _onSurfaceVariant,
              ...?theme?.contentTextStyle?.toCss(),
            },
          ),
          child: content!,
        ),
      if (actions.isNotEmpty)
        thorElement(
          'div',
          css: {
            'display': 'flex',
            'justify-content': 'flex-end',
            'gap': '8px',
            'margin-top': '8px',
            ...?theme?.actionsPadding?.toCss('padding'),
          },
          childRules: ChildRules.row,
          children: actions,
        ),
    ],
  );
}

/// Flutter's `Dialog`: a modal surface for any content, as a native
/// `<dialog>` like [AlertDialog], with the look given by the caller.
/// Open it with [DialogTrigger] or a [controller]; close it with
/// [DialogClose].
class Dialog extends StatelessWidget implements ThorElementWidget, ThorBuiltIn {
  /// A dialog with [child] as its content.
  const Dialog({
    super.key,
    this.id,
    required this.child,
    this.backgroundColor,
    this.elevation,
    this.shape,
    this.insetPadding,
    this.constraints,
    this.shadows,
    this.barrierColor,
    this.barrierFilter,
    this.barrierDismissible = true,
    this.label,
    this.controller,
    this.modal = true,
    this.showClose = false,
    this.closeLabel,
  }) : assert(
         modal || controller == null,
         'A non-modal dialog has no controller',
       );

  /// Whether the dialog blocks the page (default) or floats over it; see
  /// `AlertDialog.modal`.
  final bool modal;

  /// Whether the dialog brings its own close button in the top corner
  /// (`DialogClose` with a close icon, named by the localized "Close").
  ///
  /// `// web:` Flutter's dialogs have no built-in close button.
  final bool showClose;

  /// The name of the [showClose] button, for assistive technology and the
  /// tooltip. Null is the localized "Close" of `MaterialLocalizations`; give
  /// it when the page's text is not in the app's locale.
  final String? closeLabel;

  /// DOM id (the triggers point at it); optional, see `AlertDialog.id`.
  final String? id;

  /// The content.
  final Widget child;

  /// Surface color (Material's surface container by default).
  final Color? backgroundColor;

  /// The dialog's shadow depth (default: Material 3's; the theme's
  /// `elevation` first; 0 draws none). [shadows] wins over it.
  final double? elevation;

  /// Its outline and corners (28px corners by default, like Material 3).
  final OutlinedBorder? shape;

  /// The space kept between the dialog and the edges of the window
  /// (default: 40 by 24).
  final EdgeInsets? insetPadding;

  /// Size limits (a 280px minimum width by default, like Flutter).
  final BoxConstraints? constraints;

  /// `// web:` the dialog's shadows (Flutter derives them from
  /// `elevation`).
  final List<BoxShadow>? shadows;

  /// The color behind the dialog (default: 32 % black).
  final Color? barrierColor;

  /// A filter over what is behind the dialog (the theme's `barrierFilter`
  /// by default; none otherwise).
  final ImageFilter? barrierFilter;

  /// Backdrop click / Esc close it.
  final bool barrierDismissible;

  /// Accessible name, when the content has no heading that names it.
  final String? label;

  /// Opens and closes it from a `ThorState` method (see [AlertDialog]).
  final DialogController? controller;

  @override
  Widget build(BuildContext context) {
    final id = nativeId(
      context,
      prefix: 'dlg',
      id: this.id,
      key: key,
      controller: controller,
      owner: this,
    );
    if (modal) lockScrollWhileModal(context);
    return DialogScope(
      id: id,
      child: _element(id, Theme.of(context).dialogTheme),
    );
  }

  // The parameter, else `ThemeData.dialogTheme`, else Flutter's default.
  Widget _element(String id, DialogThemeData? theme) {
    final s = shape ?? theme?.shape;
    final depth = elevation ?? theme?.elevation;
    final inset =
        insetPadding ??
        theme?.insetPadding ??
        const EdgeInsets.symmetric(horizontal: 40, vertical: 24);
    final box = BoxDecoration(
      color: backgroundColor ?? theme?.backgroundColor,
      boxShadow:
          shadows ??
          (depth == null
              ? const [
                  BoxShadow(
                    color: Color(0x33000000),
                    offset: Offset(0, 8),
                    blurRadius: 24,
                  ),
                ]
              : depth <= 0
              ? null
              : [
                  BoxShadow(
                    color: const Color(0x33000000),
                    offset: Offset(0, depth),
                    blurRadius: depth * 3,
                  ),
                ]),
      border: s == null || s.side == BorderSide.none
          ? null
          : Border.fromBorderSide(s.side),
    ).toCss();
    return thorElement(
      'dialog',
      id: id,
      debugName: 'Dialog',
      css: {
        'box-sizing': 'border-box',
        'padding': '0',
        'border': '0',
        'border-radius': s?.radiusCss ?? '28px',
        'background-color': ThemeTokens.surfaceContainerHigh,
        'color': _onSurface,
        'max-width': 'calc(100vw - ${cssPx(inset.left + inset.right)})',
        'max-height': 'calc(100dvh - ${cssPx(inset.top + inset.bottom)})',
        'min-width': '280px',
        'overflow': 'auto',
        if (modal) ...modalOverscroll,
        ...box,
        ...?(constraints ?? theme?.constraints)?.toCss(),
      },
      conditions: [
        if (modal)
          ConditionalCss(const CssCondition.selector('::backdrop'), {
            'background-color':
                (barrierColor ?? theme?.barrierColor)?.css ??
                const Color(0x52000000).css,
            'backdrop-filter': ?(barrierFilter ?? theme?.barrierFilter)?.css,
          }),
      ],
      attributes: {
        'aria-label': ?label,
        if (modal)
          'closedby': barrierDismissible ? 'any' : 'closerequest'
        else
          'open': '',
        dialogControllerAttr: ?controllerIdOf(controller),
      },
      childRules: ChildRules.column,
      children: [
        if (showClose) DialogCloseCorner(label: closeLabel),
        child,
      ],
    );
  }
}

/// Makes its `<button>` child open a dialog (Invoker Commands). Three ways
/// to say which one, the first needing no name at all:
///
/// * [dialog]: the dialog travels with its button, like Flutter's
///   `onPressed: () => showDialog(builder: …)` reads. The trigger renders
///   the button and, right after it, the closed `<dialog>`; the page names
///   it.
/// * [controller]: the dialog that holds the same `DialogController` (a
///   field of a `ThorState`).
/// * [id]: the dialog with that DOM id.
///
/// `// web:` the button needs no `onPressed` (Flutter code writes one only
/// to enable the button): the browser opens the dialog and the button
/// stays enabled.
///
/// The child may also be a tappable box (an `InkWell` or `GestureDetector`
/// around a card): the browser only runs the command on a `<button>`, so
/// that element is a focusable `role="button"` and the engine opens the
/// dialog on a click, Enter or Space. [DialogClose] works the same.
///
/// ```dart
/// DialogTrigger(
///   dialog: AlertDialog(
///     title: const Text('Delete?'),
///     actions: [DialogClose(child: TextButton(child: const Text('Cancel')))],
///   ),
///   child: FilledButton(child: const Text('Delete')),
/// )
/// ```
class DialogTrigger extends ParentDataWrapper {
  /// Wraps a `button` child so it opens a dialog: the one it carries
  /// ([dialog]), the one with the given [id] or the one of the given
  /// [controller] (exactly one of the three).
  const DialogTrigger({
    super.key,
    this.dialog,
    this.id,
    this.controller,
    this.enabled = true,
    this.hiddenFrom,
    required super.child,
  }) : assert(
         (dialog != null ? 1 : 0) +
                 (id != null ? 1 : 0) +
                 (controller != null ? 1 : 0) ==
             1,
         'DialogTrigger needs exactly one of dialog, id or controller',
       );

  /// The dialog this button opens, rendered right after the button: an
  /// [AlertDialog], a [Dialog], a [ModalBottomSheet] or a [Drawer] (its own `id` or
  /// `controller` still name it, if the app wants to point at it elsewhere).
  ///
  /// `// web:` Flutter's `showDialog` pushes a route when pressed; the
  /// dialog here is part of the markup, next to the button.
  final Widget? dialog;

  /// Id of the dialog to open (the `id` of its `<dialog>`).
  final String? id;

  /// `false` disables the button on purpose.
  ///
  /// `// web:` the button the trigger wraps is enabled without `onPressed`
  /// (the browser is its action), so a `null` `onPressed` no longer means
  /// disabled; say it here.
  final bool enabled;

  /// Hides the button from this breakpoint up: the one that opens a
  /// `Drawer(permanentFrom:)` has nothing to open once the panel is inline.
  /// CSS only (`display: none`), so it is right on the first paint.
  final WindowSizeClass? hiddenFrom;

  /// The controller (a field of a `ThorState`) of the dialog to open: the
  /// dialog built with the same one has the id both derive from it, so
  /// nothing is named twice.
  ///
  /// `// web:` no Flutter counterpart (see `DialogController`).
  final DialogController? controller;

  WrapData _data(String? commandfor) => WrapData(
    attributes: {
      'commandfor': ?commandfor,
      'command': 'show-modal',
      if (!enabled) 'disabled': '',
    },
    conditions: [
      if (hiddenFrom case final bp?)
        ConditionalCss(CssCondition.breakpoint(bp), const {'display': 'none'}),
    ],
  );

  @override
  WrapData get wrapData {
    // The dialog form gets its `commandfor` when built (the page names
    // the dialog); everything else is the same.
    if (dialog != null) return _data(null);
    final id = this.id ?? derivedNativeId('dlg', controller);
    if (id == null) {
      // A controller no state holds only exists on the server: no id to
      // point at, and the dialog could not have been derived either.
      throw StateError(
        'DialogTrigger(controller:) needs a controller that is a field of '
        'a ThorState (final confirm = DialogController();), or an id.',
      );
    }
    return _data(id);
  }

  @override
  @internal
  bool get addsSiblings => dialog != null;

  @override
  WrapData wrapDataIn(BuildContext context, List<Widget> after) {
    final d = dialog;
    if (d == null) return wrapData;
    // An app component that builds the dialog is the dialog: the
    // preview shows which one it is, and the first of its kind built below
    // takes the id.
    final r = resolveComponent(d)!;
    final (prefix, id, key, controller) = switch (r) {
      AlertDialog() => ('dlg', r.id, r.key, r.controller),
      Dialog() => ('dlg', r.id, r.key, r.controller),
      ModalBottomSheet() => ('sheet', r.id, r.key, r.controller),
      Drawer() => ('drawer', r.id, r.key, r.controller),
      _ => throw StateError(
        'DialogTrigger(dialog:) takes an AlertDialog, a Dialog, a '
        'ModalBottomSheet or a Drawer, or a component that builds one, '
        'not a ${r.runtimeType}.',
      ),
    };
    final panelId = nativeId(
      context,
      prefix: prefix,
      id: id,
      key: key,
      controller: controller,
    );
    after.add(
      PresetDialogId(
        id: panelId,
        dialog: r,
        byType: !identical(r, d),
        scope: DialogScope.maybeOf(context),
        child: d,
      ),
    );
    return _data(panelId);
  }
}

/// Makes its `<button>` child close a dialog: the nearest one above it, or
/// the one with the id [id].
///
/// `// web:` Flutter's `Navigator.pop(context)` pops the route the button
/// is in; `DialogClose()` closes the dialog it is in (`command="close"`,
/// no JS). Outside any dialog it needs an [id], and a build error says
/// so instead of leaving a button that does nothing.
class DialogClose extends ParentDataWrapper {
  /// Wraps a `button` child so it closes the dialog with the given id (or,
  /// without one, the dialog it is inside).
  const DialogClose({
    super.key,
    this.id,
    this.enabled = true,
    required super.child,
  });

  /// Id of the dialog to close (default: the nearest one above).
  final String? id;

  /// `false` disables the button on purpose (see [DialogTrigger.enabled]).
  final bool enabled;

  @override
  WrapData get wrapData => id == null
      ? WrapData(
          closesDialog: true,
          attributes: {'command': 'close', if (!enabled) 'disabled': ''},
        )
      : WrapData(
          attributes: {
            'commandfor': id!,
            'command': 'close',
            if (!enabled) 'disabled': '',
          },
        );
}

/// The anchor a tooltip's bubble finds its child by: one name, scoped to
/// each [Tooltip] (`anchor-scope`), so every tooltip shares the same
/// classes.
const _tipAnchor = '--t-tip';
var _fallbackTipIds = 0;

// The named fallbacks of a bubble on the other side, its edge lined up with
// the child's (`position-try-fallbacks: --t-tip-bottom-r flip-block`): the
// tactic flips both the area and the margins, so the gap stays between the
// bubble and the child. A plain `top span-right` would keep the gap on the
// far side. Constant: the same rules for every tooltip.
const _tipTries = {
  '--t-tip-bottom-r': 'position-area: bottom span-right',
  '--t-tip-bottom-l': 'position-area: bottom span-left',
  '--t-tip-top-r': 'position-area: top span-right',
  '--t-tip-top-l': 'position-area: top span-left',
};

/// Flutter's `Tooltip`: a bubble with [message] (or [richMessage]) that
/// shows while the pointer is over [child] or it has keyboard focus, with
/// no JS.
///
/// web: the bubble is the element right after the child's, shown by CSS
/// (`:hover`/`:focus-visible` of the child, after [waitDuration]) and
/// placed by anchor positioning below the child ([preferBelow]), flipping
/// to the other side when it doesn't fit. Both sit in a box that takes no
/// part in the layout (`display: contents`) and scopes the anchor. The
/// child points at the bubble with `aria-describedby`. Unlike Flutter: no
/// long press on touch (a tap that focuses a control shows it), no Esc to
/// dismiss it, and a browser without anchor positioning shows the bubble
/// where it would sit in the page, next to the child.
///
/// As the state of a `Watch` the box is the state's element (it carries the
/// state mark and the other states are its siblings, like any widget that
/// renders more than one element).
class Tooltip extends StatelessWidget
    implements ThorElementWidget, ThorBuiltIn, MultipleRoots {
  /// Shows [message] (or [richMessage] or [messageWatch], exactly one) over
  /// [child].
  const Tooltip({
    super.key,
    this.message,
    this.richMessage,
    this.messageWatch,
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
    required this.child,
  }) : assert(
         (message == null ? 0 : 1) +
                 (richMessage == null ? 0 : 1) +
                 (messageWatch == null ? 0 : 1) ==
             1,
         'Exactly one of message, richMessage or messageWatch must be specified',
       );

  /// The text of the bubble.
  final String? message;

  // web: not in Flutter.
  /// The text of the bubble, bound to a `ThorState` method that returns it
  /// (`Tooltip(messageWatch: editor.undoTip, …)`): the server draws the
  /// first value and the browser keeps the bubble current as the state
  /// changes, with no reload. Instead of [message].
  final String Function()? messageWatch;

  /// The bubble's rich text (a `TextSpan`), instead of [message].
  final InlineSpan? richMessage;

  /// The bubble's minimum height (Material 3 on desktop: 24).
  final double? height;

  /// Space inside the bubble (default: 8 by 4).
  final EdgeInsetsGeometry? padding;

  /// Empty space around the bubble (default: none): its top (below the
  /// child) or bottom (above it) adds to [verticalOffset].
  final EdgeInsetsGeometry? margin;

  /// From the child's center to the bubble (Flutter's default: 24), so a
  /// 48 px button has the bubble right at its edge.
  final double? verticalOffset;

  /// Below the child (the default) or above it; either flips when there
  /// is no room.
  final bool? preferBelow;

  /// Whether the child leaves out the description (`aria-describedby`).
  final bool? excludeFromSemantics;

  /// The bubble's background, border and radius (default: the theme's
  /// inverse surface, radius 4).
  final BoxDecoration? decoration;

  /// The bubble's text style (default: body small on the inverse surface).
  final TextStyle? textStyle;

  /// How the bubble's lines align.
  final TextAlign? textAlign;

  /// How long the pointer rests on the child before the bubble shows
  /// (default: none).
  final Duration? waitDuration;

  /// The widget the tooltip describes.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // The parameter, else `ThemeData.tooltipTheme`, else Flutter's default.
    final theme = Theme.of(context).tooltipTheme;
    final registry = ThorStyleRegistry.active(context);
    final id = registry?.uniqueId('t-tip') ?? 't-tip-${++_fallbackTipIds}';
    for (final MapEntry(:key, :value) in _tipTries.entries) {
      registry?.addPositionTry(key, value);
    }
    final scope = ChildRulesScope.maybeOf(context);
    final pending = scope?.pending;
    final silent = excludeFromSemantics ?? theme?.excludeFromSemantics ?? false;
    final below = preferBelow ?? theme?.preferBelow ?? true;
    final offset = verticalOffset ?? theme?.verticalOffset ?? 24;
    final wait =
        '${(waitDuration ?? theme?.waitDuration ?? Duration.zero).inMilliseconds}ms';
    final padding = this.padding ?? theme?.padding;
    final margin = this.margin ?? theme?.margin;
    // The gap to the child: the vertical offset past the child's edge, plus
    // the margin on that side.
    var gap = 'max(0px, calc(${cssPx(offset)} - anchor-size(height) / 2))';
    final side = margin == null
        ? null
        : below
        ? margin.cssTop
        : margin.cssBottom;
    if (side != null && side != '0' && side != '0px') {
      gap = 'calc($gap + $side)';
    }
    // Everything the wrappers around the Tooltip gave it (a margin,
    // `Expanded`) belongs to the child's element, where the layout is.
    final anchor = WrapData(
      css: const {'anchor-name': _tipAnchor},
      attributes: silent ? const {} : {'aria-describedby': id},
    );
    const shown = {'display': 'flex', 'opacity': '1'};
    final bubble = thorElement(
      'span',
      id: id,
      debugName: 'Tooltip',
      attributes: silent
          ? const {'role': 'tooltip', 'aria-hidden': 'true'}
          : const {'role': 'tooltip'},
      css: {
        'display': 'none',
        // web: fixed, placed by its anchor: a containing block made by an
        // ancestor (`container-type`) only moves the box the anchor is read
        // against, and the anchor is in it too, so it stays beside its child.
        'position': 'fixed',
        'position-anchor': _tipAnchor,
        'position-area': below ? 'bottom' : 'top',
        // web: Flutter clamps the bubble inside the screen. `bottom` is
        // `bottom span-all` with `justify-self: anchor-center`: centered on
        // the child, but a child near the viewport's left or right edge
        // pushes it past that edge (nothing shifts an anchor-centered box
        // back in a fixed containing block). Then its margin box overflows
        // the area, so the browser tries the next fallback that fits: the
        // other side, then the bubble's edge lined up with the child's left
        // (`span-right`: center and right columns, aligned towards the
        // anchor) or right edge (`span-left`), on the preferred side first.
        // A centered bubble that fits never leaves the first position. On
        // the other side, a named try flipped by `flip-block` (see
        // [_tipTries]) moves the gap with it.
        'position-try-fallbacks': below
            ? 'flip-block, bottom span-right, bottom span-left, '
                  '--t-tip-bottom-r flip-block, --t-tip-bottom-l flip-block'
            : 'flip-block, top span-right, top span-left, '
                  '--t-tip-top-r flip-block, --t-tip-top-l flip-block',
        'inset': 'auto',
        'z-index': '1000',
        // `flip-block` (alone or after a named try) swaps the top and bottom
        // margins with the side.
        ...?margin?.toCss('margin'),
        if (margin == null) 'margin': '0',
        below ? 'margin-top' : 'margin-bottom': gap,
        'box-sizing': 'border-box',
        'align-items': 'center',
        'min-height': cssPx(height ?? theme?.height ?? 24),
        'max-width': 'calc(100vw - 16px)',
        ...(padding ?? const EdgeInsets.symmetric(horizontal: 8, vertical: 4))
            .toCss('padding'),
        'border-radius': '4px',
        'background-color': ThemeTokens.inverseSurface,
        'color': ThemeTokens.inverseOnSurface,
        'font-size': 'var(--t-body-small-size, 12px)',
        'line-height': 'var(--t-body-small-line, 16px)',
        'letter-spacing': 'var(--t-body-small-tracking, normal)',
        'text-align': ?(textAlign ?? theme?.textAlign)?.css,
        ...?(decoration ?? theme?.decoration)?.toCss(),
        ...?(textStyle ?? theme?.textStyle)?.toCss(),
        'opacity': '0',
        // Shows after the wait; fades out, then leaves the layout.
        'transition':
            'opacity 150ms, display 150ms allow-discrete, '
            'overlay 150ms allow-discrete',
      },
      conditions: [
        ConditionalCss(const CssCondition.after(':hover'), {
          ...shown,
          'transition-delay': wait,
        }),
        ConditionalCss(
          const CssCondition.after(':is(:focus-visible, :has(:focus-visible))'),
          {...shown, 'transition-delay': wait},
        ),
        // The pointer may move onto the bubble (WCAG 1.4.13).
        const ConditionalCss(CssCondition.hover, shown),
        // From `display: none` nothing transitions: this is where the fade
        // (and the wait before it) starts.
        const ConditionalCss(CssCondition.startingStyle(), {'opacity': '0'}),
        const ConditionalCss(CssCondition.reducedMotion, {
          'transition-duration': '0s',
        }),
      ],
      children: [
        if (richMessage case final rich?)
          rich.toComponent()
        else if (messageWatch case final watch?)
          Watch(watch)
        else
          Widget.text(message!),
      ],
    );
    final box = thorElement(
      'span',
      debugName: 'Tooltip',
      css: const {'display': 'contents', 'anchor-scope': _tipAnchor},
      // The box isn't there for the layout: the child gets its parent's
      // rules.
      childRules: scope?.rules ?? ChildRules.none,
      children: [
        // No ThorApp: ship the named fallbacks before the child (the bubble
        // stays the child's next sibling).
        if (registry == null)
          Widget.element(
            tag: 'style',
            children: [
              RawText(
                _tipTries.entries
                    .map((e) => '@position-try ${e.key}{${e.value}}')
                    .join(),
              ),
            ],
          ),
        WrapWith(
          pending == null ? anchor : pending.merge(anchor),
          child: child,
        ),
        bubble,
      ],
    );
    // The box consumes none of the wrappers' data (one node between: an
    // element reads the scope above its parent).
    return ChildRulesScope(rules: scope?.rules, child: Widget.fragment([box]));
  }
}

const _sheetMotion = {
  'transition-property': 'translate, display, overlay',
  'transition-duration': '250ms',
  'transition-timing-function': 'cubic-bezier(0.2, 0, 0, 1)',
  'transition-behavior': 'allow-discrete',
};

/// Flutter's `showModalBottomSheet`: a native modal `<dialog>` anchored to
/// the bottom, sliding up on open (`@starting-style`, no JS). Open it with
/// [DialogTrigger] and close it with [DialogClose], Esc or the backdrop, or
/// both from a state method with a [controller].
class ModalBottomSheet extends StatelessWidget
    implements ThorElementWidget, ThorBuiltIn {
  /// Creates a Material modal bottom sheet.
  const ModalBottomSheet({
    super.key,
    this.id,
    required this.child,
    this.showDragHandle = true,
    this.label,
    this.controller,
    this.backgroundColor,
    this.elevation,
    this.shape,
    this.constraints,
    this.barrierColor,
    this.showClose = false,
    this.closeLabel,
  });

  /// DOM id (the triggers point at it); optional, see `AlertDialog.id`.
  final String? id;

  /// Opens and closes it from a `ThorState` method (a field of the state).
  ///
  /// `// web:` Flutter's `showModalBottomSheet` / `Navigator.pop` (see
  /// `DialogController`).
  final DialogController? controller;

  /// Content of the sheet.
  final Widget child;

  /// Whether the sheet brings its own close button in the top corner
  /// (`DialogClose` with a close icon, named by the localized "Close").
  ///
  /// `// web:` Flutter's sheets have no built-in close button.
  final bool showClose;

  /// The name of the [showClose] button, for assistive technology and the
  /// tooltip. Null is the localized "Close" of `MaterialLocalizations`; give
  /// it when the page's text is not in the app's locale.
  final String? closeLabel;

  /// Whether to show the drag handle at the top (Flutter's default: true).
  final bool showDragHandle;

  /// Fill (default: the theme's `modalBackgroundColor` or
  /// `backgroundColor`, else the surface-container-low color).
  final Color? backgroundColor;

  /// Shadow elevation (default: the theme's; none otherwise).
  final double? elevation;

  /// Corners and outline (default: the theme's, else 28 px on the top
  /// corners).
  final OutlinedBorder? shape;

  /// Size limits (default: the theme's, else at most 640 px wide).
  final BoxConstraints? constraints;

  /// The color behind the sheet (default: the theme's
  /// `modalBarrierColor`, else 32 % black).
  final Color? barrierColor;

  /// Accessible name of the sheet.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final id = nativeId(
      context,
      prefix: 'sheet',
      id: this.id,
      key: key,
      controller: controller,
      owner: this,
    );
    lockScrollWhileModal(context);
    return DialogScope(
      id: id,
      child: _element(id, Theme.of(context).bottomSheetTheme),
    );
  }

  // The parameter, else `ThemeData.bottomSheetTheme`, else Flutter's default.
  Widget _element(String id, BottomSheetThemeData? theme) {
    final shape = this.shape ?? theme?.shape;
    final depth = elevation ?? theme?.modalElevation ?? theme?.elevation;
    final barrier = barrierColor ?? theme?.modalBarrierColor;
    return _sheet(id, theme, shape, depth, barrier);
  }

  Widget _sheet(
    String id,
    BottomSheetThemeData? theme,
    OutlinedBorder? shape,
    double? depth,
    Color? barrier,
  ) => thorElement(
    'dialog',
    id: id,
    debugName: 'ModalBottomSheet',
    css: {
      'box-sizing': 'border-box',
      'margin': 'auto auto 0',
      'width': 'min(640px, 100%)',
      'max-width': '100%',
      'max-height': '90dvh',
      'padding': '0 24px 24px',
      'border': switch (shape?.side) {
        final side? when side != BorderSide.none => side.css,
        _ => '0',
      },
      'border-radius': shape?.radiusCss ?? '28px 28px 0 0',
      'background-color':
          (backgroundColor ??
                  theme?.modalBackgroundColor ??
                  theme?.backgroundColor)
              ?.css ??
          _surfaceContainerLow,
      'color': _onSurface,
      'translate': '0 100%',
      'overflow-y': 'auto',
      if (depth != null && depth > 0)
        'box-shadow':
            '0 ${cssPx(depth / 2)} ${cssPx(depth * 1.5)} rgba(0, 0, 0, 0.2)',
      ...modalOverscroll,
      ..._sheetMotion,
      ...?(constraints ?? theme?.constraints)?.toCss(),
    },
    conditions: [
      const ConditionalCss(CssCondition.selector('[open]'), {
        'display': 'flex',
        'flex-direction': 'column',
        'translate': '0 0',
      }),
      const ConditionalCss(CssCondition.startingStyle('[open]'), {
        'translate': '0 100%',
      }),
      ...fadingBackdrop('250ms', color: barrier),
      const ConditionalCss(CssCondition.reducedMotion, {
        'transition-duration': '1ms',
      }),
    ],
    attributes: {
      'closedby': 'any',
      'aria-label': ?label,
      dialogControllerAttr: ?controllerIdOf(controller),
    },
    childRules: ChildRules.column,
    children: [
      if (showDragHandle)
        thorElement(
          'div',
          css: const {
            'align-self': 'center',
            'width': '32px',
            'height': '4px',
            'margin': '22px 0 16px',
            'border-radius': '2px',
            'background-color': _onSurfaceVariant,
            'opacity': '0.4',
            'flex': 'none',
          },
          attributes: const {'aria-hidden': 'true'},
        ),
      if (showClose) DialogCloseCorner(label: closeLabel),
      child,
    ],
  );
}

/// One entry of a [PopupMenuButton]. Choosing it calls `onSelected` with
/// its [value]; choosing an item closes the menu
/// natively (`popovertargetaction="hide"`).
class PopupMenuItem<T> {
  /// Creates a popup menu entry.
  const PopupMenuItem({
    required this.value,
    required this.child,
    this.enabled = true,
    this.height = 48,
    this.padding,
    this.textStyle,
  });

  /// Argument passed to `onSelected` when this item is chosen.
  final T value;

  /// Content of the entry.
  final Widget child;

  /// Whether the entry responds to input (Flutter's default: true).
  final bool enabled;

  /// The entry's smallest height (Flutter's default: 48).
  final double height;

  /// Inner spacing (default: 12 on each side).
  final EdgeInsetsGeometry? padding;

  /// The font of the entry.
  final TextStyle? textStyle;
}

/// Flutter's `PopupMenuButton` / `MenuAnchor` on the Popover API: the
/// trigger opens it with `popovertarget` (no JS), light dismiss and Esc are
/// native, and CSS anchor positioning places it under the trigger (centered
/// by the browser where anchoring is unsupported).
class PopupMenuButton<T> extends StatelessWidget
    implements ThorElementWidget, ThorBuiltIn, MultipleRoots {
  /// Creates a Material popup menu button.
  const PopupMenuButton({
    super.key,
    this.id,
    required this.items,
    required this.child,
    this.onSelected,
    this.tooltip,
    this.initialValue,
    this.style,
    this.color,
    this.shape,
    this.elevation,
    this.constraints,
    this.menuPadding,
  });

  /// The value of the item marked as the current one when the menu opens
  /// (`aria-checked`), like Flutter highlights it.
  final T? initialValue;

  /// The trigger's look (Flutter's `PopupMenuButton.style`). With one, the
  /// trigger is a button of that style instead of the round icon target.
  final ButtonStyle? style;

  /// The menu's fill.
  final Color? color;

  /// The menu's corners and outline.
  final OutlinedBorder? shape;

  /// The menu's shadow (Flutter's default: 8).
  final double? elevation;

  /// The menu's size bounds (e.g. a `minWidth` as wide as the trigger).
  final BoxConstraints? constraints;

  /// Space around the items (default: 8 above and below).
  final EdgeInsetsGeometry? menuPadding;

  /// DOM id of the popover menu; optional: without one it is named by its
  /// `ValueKey` or its place in the page (the same on every render).
  final String? id;

  /// Entries shown in the menu.
  final List<PopupMenuItem<T>> items;

  /// The trigger's content (an icon or a text).
  final Widget child;

  /// Called with the chosen item's value (a `ThorState` method, e.g.
  /// `menu.pick`). [T] is any value the engine
  /// encodes: a `String`, `int`, `double`, `bool`, an enum or a registered
  /// JSON model (`registerJsonModel`).
  final void Function(T value)? onSelected;

  /// Text and accessible label for the trigger button.
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final id = nativeId(context, prefix: 'menu', id: this.id, key: key);
    // The parameter, else `ThemeData.popupMenuTheme`, else the default.
    final theme = Theme.of(context).popupMenuTheme;
    final color = this.color ?? theme?.color;
    final shape = this.shape ?? theme?.shape;
    final elevation = this.elevation ?? theme?.elevation;
    final menuPadding = this.menuPadding ?? theme?.menuPadding;
    final anchor = '--$id';
    final tip = tooltip ?? MaterialLocalizations.of(context).showMenuTooltip;
    return Widget.fragment([
      thorElement(
        'button',
        debugName: 'PopupMenuButton',
        baseCss: buttonResetCss,
        css: {
          'display': 'inline-flex',
          'align-items': 'center',
          'justify-content': 'center',
          if (style == null) ...{
            'min-width': '40px',
            'min-height': '40px',
            'border-radius': '20px',
          },
          'anchor-name': anchor,
          'flex': 'none',
          if (style case final s?) ...buttonStyleCss(s),
        },
        conditions: [
          ConditionalCss(CssCondition.hover, {
            'background-color':
                style?.overlayAt(WidgetState.hovered)?.css ?? _hover,
          }),
          _focusRing,
        ],
        attributes: {
          'type': 'button',
          'popovertarget': id,
          'aria-haspopup': 'true',
          'title': tip,
          // web: a button with a visible text keeps it as its name; the
          // default tooltip names an icon-only one (Flutter's
          // `showMenuTooltip`).
          if (tooltip != null || child is! Text) 'aria-label': tip,
        },
        children: [child],
      ),
      thorElement(
        'div',
        id: id,
        debugName: 'PopupMenu',
        css: {
          'position-anchor': anchor,
          // The UA gives popovers `inset: 0` (centered); anchoring needs auto.
          'inset': 'auto',
          // Below the trigger, growing toward the inline end; flipped above
          // or to the other side when it doesn't fit.
          'position-area': 'block-end span-inline-end',
          'position-try-fallbacks':
              'flip-block, flip-inline, flip-block flip-inline',
          'margin': '4px 0',
          ...(menuPadding?.toCss('padding') ?? const {'padding': '8px 0'}),
          'min-width': '112px',
          ...?constraints?.toCss(),
          'border': switch (shape?.side) {
            final side? when side != BorderSide.none => side.css,
            _ => '0',
          },
          'border-radius': shape?.radiusCss ?? '4px',
          'background-color': color?.css ?? ThemeTokens.surfaceContainer,
          'color': _onSurface,
          'box-shadow': switch (elevation) {
            null =>
              '0 3px 6px rgba(0, 0, 0, 0.16), 0 2px 4px rgba(0, 0, 0, 0.12)',
            <= 0 => 'none',
            final e =>
              '0 ${cssPx(e / 2)} ${cssPx(e * 1.5)} rgba(15, 23, 42, 0.08), '
                  '0 ${cssPx(e / 4)} ${cssPx(e / 2)} rgba(15, 23, 42, 0.06)',
          },
        },
        conditions: const [
          ConditionalCss(CssCondition.selector(':popover-open'), {
            'display': 'flex',
            'flex-direction': 'column',
          }),
          _forcedEdge,
        ],
        attributes: const {'popover': 'auto', menuAttr: ''},
        childRules: ChildRules.column,
        children: [
          for (final item in items)
            thorElement(
              'button',
              baseCss: buttonResetCss,
              css: {
                'display': 'flex',
                'align-items': 'center',
                'min-height': cssPx(item.height),
                ...(item.padding?.toCss('padding') ??
                    const {'padding': '0 12px'}),
                'font-size': ThemeTokens.labelLargeSize,
                'letter-spacing': ThemeTokens.labelLargeTracking,
                'text-align': 'start',
                ...?(item.textStyle ?? theme?.textStyle)?.toCss(),
                ...?_inlineText(item.child)?.css,
              },
              conditions: [
                const ConditionalCss(CssCondition.hoverEnabled, {
                  'background-color': _hover,
                }),
                _focusRing,
                const ConditionalCss(CssCondition.disabled, {
                  'opacity': '0.38',
                  'cursor': 'default',
                }),
                // The current item (initialValue), as Flutter highlights it.
                if (initialValue != null)
                  const ConditionalCss(
                    CssCondition.selector('[aria-checked="true"]'),
                    {'background-color': _hover, 'font-weight': '500'},
                  ),
              ],
              attributes: {
                'type': 'button',
                if (initialValue != null) ...{
                  'role': 'menuitemradio',
                  'aria-checked': '${item.value == initialValue}',
                },
                'popovertarget': id,
                'popovertargetaction': 'hide',
                ...engineAttributes({'click': onSelected}, arg: item.value),
                if (!item.enabled) 'disabled': '',
              },
              children: [_inlineText(item.child)?.node ?? item.child],
            ),
        ],
      ),
    ]);
  }
}

/// Flutter's `MenuController` (what a [MenuAnchor]'s `builder` receives).
///
/// `// web:` the anchor opens its menu natively (`popovertarget`), so the
/// builder's button needs no handler. The controller is accepted so Flutter
/// code compiles; its methods change nothing, and [isOpen] is `false`.
class MenuController {
  /// Creates a controller.
  MenuController();

  /// Always `false` on the server (the browser tracks it).
  bool get isOpen => false;

  /// Accepted; the anchor opens the menu itself.
  void open({Offset? position}) {}

  /// Accepted; light dismiss and Esc close the menu natively.
  void close() {}

  /// Accepted; no effect.
  void closeChildren() {}
}

final _menuController = MenuController();

/// The id of the root menu panel an item is in: what a [MenuItemButton]
/// closes. Not exported.
class _MenuScope extends InheritedWidget implements InheritedMemoKey {
  const _MenuScope({required this.id, required super.child});

  final String id;

  static String? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_MenuScope>()?.id;

  @override
  bool updateShouldNotify(covariant _MenuScope oldComponent) =>
      oldComponent.id != id;

  @override
  Object? get memoKey => id;
}

/// Makes the builder's widget the opener of a menu: its element gets the
/// popover wiring and the CSS anchor name. Not exported.
class _MenuTrigger extends ParentDataWrapper {
  const _MenuTrigger({required this.id, required super.child});

  final String id;

  @override
  WrapData get wrapData => WrapData(
    css: _anchorName(id),
    attributes: {'popovertarget': id, 'aria-haspopup': 'true'},
  );
}

// web: in a `Watch.list` row template the id carries the `{{key}}` token
// the browser fills, and CSS values can't (the token would be escaped), so
// those panels anchor to their invoker (`popovertarget`), the popover's
// implicit anchor, instead of by name.
bool _inRowTemplate(String id) => id.contains(keyToken);

Map<String, String> _anchorName(String id) =>
    _inRowTemplate(id) ? const {} : {'anchor-name': '--$id'};

Map<String, String>? _positionAnchor(String id) =>
    _inRowTemplate(id) ? null : {'position-anchor': '--$id'};

/// The popover of a menu or a submenu. Not exported.
Widget _menuPanel({
  required String id,
  required bool submenu,
  required MenuStyle? style,
  required Offset offset,
  required List<Widget> children,
  required bool closeOnNavigate,
}) => thorElement(
  'div',
  id: id,
  debugName: submenu ? 'Submenu' : 'Menu',
  css: {
    ...?_positionAnchor(id),
    // The UA gives popovers `inset: 0` (centered); anchoring needs auto.
    'inset': 'auto',
    if (submenu) ...{
      'position-area': 'inline-end span-block-end',
      'position-try-fallbacks':
          'flip-inline, flip-block, flip-block flip-inline',
      'margin': '0',
    } else ...{
      // Below the anchor, growing toward the inline end; flipped above or
      // to the other side when it doesn't fit.
      'position-area': 'block-end span-inline-end',
      'position-try-fallbacks':
          'flip-block, flip-inline, flip-block flip-inline',
      'margin': '4px 0',
    },
    if (offset != Offset.zero)
      'translate': '${cssPx(offset.dx)} ${cssPx(offset.dy)}',
    'padding': '8px 0',
    'min-width': '112px',
    'border': '0',
    'border-radius': '4px',
    'background-color': ThemeTokens.surfaceContainer,
    'color': _onSurface,
    'box-shadow':
        '0 3px 6px rgba(0, 0, 0, 0.16), 0 2px 4px rgba(0, 0, 0, 0.12)',
    ...?style == null ? null : menuStyleCss(style),
  },
  conditions: const [
    ConditionalCss(CssCondition.selector(':popover-open'), {
      'display': 'flex',
      'flex-direction': 'column',
    }),
    _forcedEdge,
  ],
  attributes: {
    'popover': 'auto',
    menuAttr: '',
    if (closeOnNavigate)
      'onclick': closeOnNavigateHandler('this.hidePopover()'),
  },
  childRules: ChildRules.column,
  children: children,
);

/// Flutter's `MenuAnchor`: a button that opens a menu of [MenuItemButton]s
/// and [SubmenuButton]s, on the Popover API (the same as `PopupMenuButton`):
/// no JS, light dismiss and Esc are native, CSS anchor positioning places
/// the menu under the anchor (flipping where it doesn't fit). Choosing a
/// button item closes it natively; following a link item closes it on the
/// tap ([closeOnNavigate]).
///
/// The anchor is the `builder`'s widget (or [child]), and it must be a
/// button (`IconButton`, `TextButton`…): it is the popover's invoker. The
/// builder's `controller` and any handler that uses it are accepted but do
/// nothing, since the browser opens the menu.
///
/// ```dart
/// MenuAnchor(
///   builder: (context, controller, child) => TextButton(
///     onPressed: () => controller.isOpen ? controller.close() : controller.open(),
///     child: const Text('Account'),
///   ),
///   menuChildren: [
///     MenuItemButton(onPressed: account.signOut, child: const Text('Sign out')),
///     const MenuItemButton(href: '/orders', child: Text('Orders')),
///   ],
/// )
/// ```
///
/// `// web:` not supported yet: `onOpen`/`onClose`, `childFocusNode`,
/// `consumeOutsideTap`, `clipBehavior` and shortcuts. Without JS the menu is
/// a disclosure (Tab moves between the items); on a page with the engine
/// the `menu` part makes it an ARIA `menu` (`menuitem`s) with the arrows,
/// Home/End, type-ahead and submenu keys of the menu button pattern.
class MenuAnchor extends StatelessWidget
    implements ThorElementWidget, ThorBuiltIn, MultipleRoots {
  /// Creates a menu anchored to a button.
  const MenuAnchor({
    super.key,
    this.id,
    this.controller,
    this.style,
    this.alignmentOffset = Offset.zero,
    this.closeOnNavigate = true,
    required this.menuChildren,
    this.builder,
    this.child,
  });

  /// DOM id of the menu; optional: without one it is named by its
  /// `ValueKey` or its place in the page (the same on every render).
  final String? id;

  /// Accepted so Flutter code compiles; the browser opens the menu.
  final MenuController? controller;

  /// The menu's look: fill, corners, outline, shadow, size.
  final MenuStyle? style;

  /// Displacement of the menu from where it is placed.
  final Offset alignmentOffset;

  /// Whether following a link in the menu in the same tab closes it on the
  /// tap (an inline `onclick`: turn it off under a strict CSP).
  // web: no Flutter counterpart.
  final bool closeOnNavigate;

  /// The items: [MenuItemButton], [SubmenuButton] and any widget.
  final List<Widget> menuChildren;

  /// Builds the anchor (a button) from the [child].
  final Widget Function(
    BuildContext context,
    MenuController controller,
    Widget? child,
  )?
  builder;

  /// The anchor itself without a [builder], or what the builder receives.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final id = nativeId(context, prefix: 'menu', id: this.id, key: key);
    final anchor = builder != null
        ? builder!(context, controller ?? _menuController, child)
        : child;
    return Widget.fragment([
      if (anchor != null) _MenuTrigger(id: id, child: anchor),
      _menuPanel(
        id: id,
        submenu: false,
        style: style,
        offset: alignmentOffset,
        closeOnNavigate: closeOnNavigate,
        children: [
          for (final item in menuChildren) _MenuScope(id: id, child: item),
        ],
      ),
    ]);
  }
}

/// The row of a [MenuItemButton] and of a [SubmenuButton]'s button. Not
/// exported.
Widget _menuRow({
  required String tag,
  required String debugName,
  required Widget? child,
  required Widget? leadingIcon,
  required Widget? trailingIcon,
  required ButtonStyle? style,
  required Map<String, String> attributes,
  Map<String, String> extraCss = const {},
}) {
  final icons = leadingIcon != null || trailingIcon != null;
  final inline = _inlineText(child);
  return thorElement(
    tag,
    debugName: debugName,
    baseCss: tag == 'a' ? _linkBase : buttonResetCss,
    css: {
      'display': 'flex',
      'align-items': 'center',
      'gap': '12px',
      'box-sizing': 'border-box',
      'min-height': '48px',
      'padding': '0 12px',
      'font-size': ThemeTokens.labelLargeSize,
      'letter-spacing': ThemeTokens.labelLargeTracking,
      'text-align': 'start',
      if (!icons) ...?inline?.css,
      ...extraCss,
      if (style != null) ...buttonStyleCss(style),
    },
    conditions: const [
      ConditionalCss(CssCondition.hoverEnabled, {'background-color': _hover}),
      _focusRing,
      ConditionalCss(CssCondition.disabled, {
        'opacity': '0.38',
        'cursor': 'default',
      }),
    ],
    attributes: attributes,
    childRules: ChildRules.row,
    children: [
      ?leadingIcon,
      if (icons)
        thorElement(
          'span',
          css: {'flex': '1 1 auto', 'min-width': '0', ...?inline?.css},
          children: [?inline?.node ?? child],
        )
      else if (inline != null)
        inline.node
      else
        ?child,
      ?trailingIcon,
    ],
  );
}

/// Flutter's `MenuItemButton`: an entry of a [MenuAnchor]. A `<button>`
/// that closes the menu natively (`closeOnActivate`) and calls
/// [onPressed] (a `ThorState` method); with [href] an `<a>` that goes
/// there. Without either it is disabled, as in Flutter.
///
/// ```dart
/// MenuItemButton(onPressed: account.signOut, child: const Text('Sign out'))
/// MenuItemButton(href: '/orders', leadingIcon: Icon(Icons.list), child: Text('Orders'))
/// ```
class MenuItemButton extends StatelessWidget
    implements ThorElementWidget, ThorBuiltIn {
  /// Creates a menu entry.
  const MenuItemButton({
    super.key,
    this.onPressed,
    this.leadingIcon,
    this.trailingIcon,
    this.style,
    this.closeOnActivate = true,
    this.href,
    this.child,
  });

  /// Called when the entry is pressed; `null` (and no [href]) disables it.
  final VoidCallback? onPressed;

  /// Shown before the label.
  final Widget? leadingIcon;

  /// Shown at the end of the row.
  final Widget? trailingIcon;

  /// The row's look: padding, size, text, colors, `overlayColor`.
  final ButtonStyle? style;

  /// Whether pressing the entry closes the menu (Flutter's default: true).
  final bool closeOnActivate;

  // web: not in Flutter.
  /// Makes the entry a link (`<a href>`), which works without
  /// JavaScript and closes the menu on the tap.
  final String? href;

  /// The label.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final menu = _MenuScope.maybeOf(context);
    final link = href != null;
    return _menuRow(
      tag: link ? 'a' : 'button',
      debugName: 'MenuItemButton',
      child: child,
      leadingIcon: leadingIcon,
      trailingIcon: trailingIcon,
      style: style,
      attributes: {
        if (link)
          'href': href!
        else ...{
          'type': 'button',
          if (onPressed == null) 'disabled': '',
          // The menu closes natively; a link closes it by the panel's
          // click handler.
          if (menu != null && closeOnActivate) ...{
            'popovertarget': menu,
            'popovertargetaction': 'hide',
          },
        },
        ...engineAttributes({'click': onPressed}),
      },
    );
  }
}

/// Flutter's `SubmenuButton`: an entry of a [MenuAnchor] that opens
/// [menuChildren] in a second popover beside it. Choosing an item of the
/// submenu closes the whole menu.
class SubmenuButton extends StatelessWidget
    implements ThorElementWidget, ThorBuiltIn, MultipleRoots {
  /// Creates an entry with a submenu.
  const SubmenuButton({
    super.key,
    this.id,
    this.leadingIcon,
    this.trailingIcon,
    this.style,
    this.menuStyle,
    required this.menuChildren,
    this.child,
  });

  /// DOM id of the submenu; optional (see [MenuAnchor.id]).
  final String? id;

  /// Shown before the label.
  final Widget? leadingIcon;

  /// Shown at the end of the row (default: a chevron).
  final Widget? trailingIcon;

  /// The row's look.
  final ButtonStyle? style;

  /// The submenu's look.
  final MenuStyle? menuStyle;

  /// The items of the submenu.
  final List<Widget> menuChildren;

  /// The label.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final id = nativeId(context, prefix: 'submenu', id: this.id, key: key);
    return Widget.fragment([
      _menuRow(
        tag: 'button',
        debugName: 'SubmenuButton',
        child: child,
        leadingIcon: leadingIcon,
        trailingIcon: trailingIcon ?? const Icon(Icons.chevron_right),
        style: style,
        extraCss: _anchorName(id),
        attributes: {
          'type': 'button',
          'popovertarget': id,
          'aria-haspopup': 'true',
        },
      ),
      // Its items keep the root menu's scope, so they close all of it.
      _menuPanel(
        id: id,
        submenu: true,
        style: menuStyle,
        offset: Offset.zero,
        closeOnNavigate: false,
        children: menuChildren,
      ),
    ]);
  }
}

/// Flutter's `SnackBarBehavior`: where a [SnackBar] sits.
enum SnackBarBehavior {
  /// A full-width bar pinned to the bottom of the window (Material 3's
  /// default).
  fixed,

  /// A rounded bar floating above the bottom edge, centered.
  floating,
}

// The insets of a floating bar as numbers, resolved left to right; null when
// there are none or they are not plain numbers.
({double left, double right, double bottom})? _resolveInset(
  EdgeInsetsGeometry? insets,
) {
  if (insets == null) return null;
  final r = insets.resolve(TextDirection.ltr);
  return r is EdgeInsets
      ? (left: r.left, right: r.right, bottom: r.bottom)
      : null;
}

// The close button of a snack bar: a `<button>` (focusable, Enter and Space)
// named for a screen reader, 40 px around a 24 px icon. The snack script and
// toast.js listen for `data-snack-close`.
Widget _closeButton(String label, String? color) => thorElement(
  'button',
  debugName: 'SnackBarClose',
  baseCss: const {'appearance': 'none', 'border': '0', 'margin': '0'},
  css: {
    'display': 'inline-grid',
    'place-items': 'center',
    'flex': 'none',
    'box-sizing': 'border-box',
    'width': '40px',
    'height': '40px',
    'padding': '8px',
    // Pulls the 40 px box into the bar's 14 px padding: the bar stays 48 px.
    'margin-block': '-8px',
    'margin-inline-end': '-8px',
    'border-radius': '50%',
    'background': 'transparent',
    'color': color ?? 'inherit',
    'cursor': 'pointer',
    'transition-property': 'background-color',
    'transition-duration': '150ms',
  },
  conditions: const [
    ConditionalCss(CssCondition.hoverEnabled, {
      'background-color': 'color-mix(in srgb, currentColor 12%, transparent)',
    }),
    ConditionalCss(CssCondition.focused, {
      'outline': '2px solid currentColor',
      'outline-offset': '-2px',
    }),
    ConditionalCss(CssCondition.reducedMotion, {'transition-duration': '1ms'}),
  ],
  attributes: {'type': 'button', 'aria-label': label, 'data-snack-close': ''},
  children: const [Icon(Icons.close)],
);

/// Flutter's `SnackBar`: a short message at the bottom (`role=status`, read
/// by screen readers). Show and hide it by switching [visible] with a
/// thor_engine variant; the transition is CSS. It hides itself after
/// [duration] with a CSS animation (no JS), paused while the pointer or
/// the focus is on it.
///
/// A `Scaffold` that has a `NavigationBar` or a `floatingActionButton` sets
/// `--t-snack-offset` for what is inside it, and the bar sits above them. The
/// page's own bar (`toast()`, `Redirect.flash`) is outside every scaffold and
/// does not know about them.
class SnackBar extends StatelessWidget
    implements ThorElementWidget, ThorBuiltIn {
  /// Creates a Material snack bar.
  const SnackBar({
    super.key,
    required this.content,
    this.visible = true,
    this.action,
    this.duration = const Duration(milliseconds: 4000),
    this.behavior,
    this.backgroundColor,
    this.elevation,
    this.shape,
    this.showCloseIcon,
    this.closeIconColor,
    this.width,
    this.margin,
  });

  /// Whether the bar has a close button after its message (default: the
  /// theme's, else false).
  // web: a real `<button>` named by the localized `closeButtonTooltip`
  // ("Close"); the snack script ends the bar when it is pressed (the page's
  // own bar, `toast()`, shows the next one waiting). With no JS it does
  // nothing: the CSS animation still hides the bar after [duration].
  final bool? showCloseIcon;

  /// Color of the close icon (default: the theme's, else the text color).
  final Color? closeIconColor;

  /// Width of a floating bar (default: the theme's, else as wide as its
  /// message). A fixed bar spans the window.
  final double? width;

  /// Space between a floating bar and the window's edges (default: the
  /// theme's `insetPadding`, else 16 px at the bottom).
  // web: see `SnackBarThemeData.insetPadding`.
  final EdgeInsetsGeometry? margin;

  /// Fill (default: the theme's, else the inverse-surface color).
  final Color? backgroundColor;

  /// Shadow elevation (default: the theme's, else 3).
  final double? elevation;

  /// Corners and outline (default: the theme's, else 4 px when floating).
  final OutlinedBorder? shape;

  /// Where the bar sits. Null is [SnackBarBehavior.fixed] (Flutter's M3
  /// default).
  final SnackBarBehavior? behavior;

  /// Message content.
  final Widget content;

  /// How long it stays before hiding itself (Flutter's default: 4 s).
  // web: a CSS animation starts when it shows; it pauses while hovered or
  // focused (WCAG 2.2.1). The state still says [visible]: showing it again
  // is switching it off and on.
  final Duration duration;

  /// Whether the snack bar is shown.
  // web: Flutter shows a snack bar with
  // `ScaffoldMessenger.of(context).showSnackBar(...)`, a call that has no
  // place in a server render: here the bar is a widget in the page and
  // [visible] is the state the page keeps (a `Watch`, or `toast()` from a
  // `ThorState` for the page's own bar).
  final bool visible;

  /// A trailing button (e.g. "Deshacer").
  final Widget? action;

  static const _floatName = 'thor-snack-out';
  static const _fixedName = 'thor-snack-out-fixed';
  // web: `from` is the shown state and the fill is `both`, on purpose: with
  // only a `to` keyframe and `forwards`, Firefox leaves the bar at
  // `opacity: 0; visibility: hidden` once the entry transition (the same
  // properties) ends, so it never showed. Holding the shown state through the
  // delay as the animation's own `from` is the same in Chromium, Firefox and
  // WebKit.
  static const _floatFrames =
      'from{opacity:1;visibility:visible;translate:-50% 0}'
      'to{opacity:0;visibility:hidden;translate:-50% 16px}';
  static const _fixedFrames =
      'from{opacity:1;visibility:visible;translate:0 0}'
      'to{opacity:0;visibility:hidden;translate:0 16px}';

  @override
  Widget build(BuildContext context) {
    // The parameter, else `ThemeData.snackBarTheme`, else Flutter's default.
    final theme = Theme.of(context).snackBarTheme;
    final inline = action == null ? _inlineText(content) : null;
    final registry = ThorStyleRegistry.active(context);
    final floating = (behavior ?? theme?.behavior) == SnackBarBehavior.floating;
    final shape = this.shape ?? theme?.shape;
    final depth = elevation ?? theme?.elevation;
    final closable = showCloseIcon ?? theme?.showCloseIcon ?? false;
    final barWidth = floating ? width ?? theme?.width : null;
    final inset = floating
        ? _resolveInset(margin ?? theme?.insetPadding)
        : null;
    final outName = floating ? _floatName : _fixedName;
    final outFrames = floating ? _floatFrames : _fixedFrames;
    final hiddenAt = floating ? '-50% 16px' : '0 16px';
    if (visible) registry?.addKeyframes(outName, outFrames);
    // web: a `position: fixed` bar is measured against the nearest ancestor
    // with `container-type`, `transform`, `filter` or `contain` (a
    // `LayoutScope`), not the window, so it would land at the end of that
    // box. A `popover="manual"` in the top layer ignores its ancestors: the
    // snack script opens it while `data-snack` is `on`. The page's own bar
    // is one already (toast.js), and with no ThorApp (no script) or no JS the
    // bar stays the plain fixed one.
    final own = registry != null && !PageSnackScope.of(context);
    if (own) registry.useSnack();
    final bar = thorElement(
      'div',
      debugName: 'SnackBar',
      css: {
        'position': 'fixed',
        'left': !floating
            ? '0'
            : inset == null || inset.left == inset.right
            ? '50%'
            : 'calc(50% + ${cssPx((inset.left - inset.right) / 2)})',
        // Above the scaffold's navigation bar and button, when it has them.
        'bottom': floating
            ? 'calc(max(${cssPx(inset?.bottom ?? 16)}, '
                  'env(safe-area-inset-bottom)) + ${ThemeTokens.snackOffset})'
            : ThemeTokens.snackOffset,
        // The page's bar is a `popover` (the top layer, over modals): this
        // undoes the browser's box for one (centered, bordered, scrolling).
        'top': 'auto',
        'right': floating ? 'auto' : '0',
        // web: the browser's popover box is `width: fit-content`, which wins
        // over `left: 0; right: 0`; a fixed bar spans the window.
        if (!floating) ...{'width': 'auto', 'max-width': 'none'},
        'margin': '0',
        'border': 'none',
        'overflow': 'visible',
        'z-index': '20',
        'display': 'flex',
        'align-items': 'center',
        'gap': '12px',
        'box-sizing': 'border-box',
        'min-height': '48px',
        if (floating) ...{
          'max-width':
              'calc(100vw - ${cssPx(inset == null ? 32 : inset.left + inset.right)})',
          if (barWidth != null) 'width': cssPx(barWidth),
          'padding': '14px 16px',
          'border-radius': shape?.radiusCss ?? '4px',
        } else ...{
          'border-radius': shape?.radiusCss ?? '0',
          'padding': '14px 16px calc(14px + env(safe-area-inset-bottom)) 16px',
        },
        if (shape?.side case final side? when side != BorderSide.none)
          'border': side.css,
        'background-color':
            (backgroundColor ?? theme?.backgroundColor)?.css ??
            ThemeTokens.inverseSurface,
        'color': ThemeTokens.inverseOnSurface,
        'font-size': ThemeTokens.bodyMediumSize,
        'letter-spacing': ThemeTokens.bodyMediumTracking,
        'line-height': ThemeTokens.bodyMediumLine,
        'box-shadow': depth == null
            ? '0 3px 6px rgba(0, 0, 0, 0.2)'
            : depth <= 0
            ? 'none'
            : '0 ${cssPx(depth)} ${cssPx(depth * 2)} rgba(0, 0, 0, 0.2)',
        'transition-property': 'translate, opacity, visibility',
        'transition-duration': '200ms',
        'translate': visible ? (floating ? '-50% 0' : '0 0') : hiddenAt,
        'opacity': visible ? '1' : '0',
        'visibility': visible ? 'visible' : 'hidden',
        if (visible)
          'animation':
              '$outName 200ms ease-in ${duration.inMilliseconds}ms both',
        ...?theme?.contentTextStyle?.toCss(),
        ...?inline?.css,
      },
      conditions: [
        ConditionalCss(CssCondition.reducedMotion, {
          'transition-duration': '1ms',
          // Still hides after [duration], without the slide.
          if (visible) 'animation-duration': '1ms',
        }),
        // web: the close button hides the bar by this attribute (the snack
        // script sets it): the author's `display` keeps a closed popover on
        // screen, so it is the same hidden state the animation ends in.
        if (closable)
          const ConditionalCss(CssCondition.selector('[data-snack-closed]'), {
            'opacity': '0',
            'visibility': 'hidden',
          }),
        if (visible) ...const [
          ConditionalCss(CssCondition.hover, {
            'animation-play-state': 'paused',
          }),
          ConditionalCss(CssCondition.focusWithin, {
            'animation-play-state': 'paused',
          }),
        ],
      ],
      attributes: {
        'role': 'status',
        'aria-live': 'polite',
        if (own) ...{'popover': 'manual', 'data-snack': visible ? 'on' : 'off'},
      },
      childRules: ChildRules.row,
      children: [
        // The message has its own node when there is a button after it: the
        // page's bar writes its text there (toast.js), not over the button.
        if (closable)
          thorElement(
            'span',
            debugName: 'SnackBarText',
            css: const {'flex': '1 1 auto', 'min-width': '0'},
            attributes: const {'data-snack-text': ''},
            children: [inline?.node ?? content],
          )
        else
          inline?.node ?? content,
        ?action,
        if (closable)
          _closeButton(
            MaterialLocalizations.of(context).closeButtonTooltip,
            (closeIconColor ?? theme?.closeIconColor)?.css,
          ),
      ],
    );
    if (!visible || registry != null) return bar;
    // No ThorApp: ship the keyframes next to it.
    return Widget.fragment([
      Widget.element(
        tag: 'style',
        children: [RawText('@keyframes $outName{$outFrames}')],
      ),
      bar,
    ]);
  }
}
