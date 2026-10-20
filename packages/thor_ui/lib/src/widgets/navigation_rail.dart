import 'package:thor_style/thor_style.dart';

import '../core/core.dart';
import '../engine/watch.dart' show engineAttributes;
import '../foundation/child_rules.dart';
import '../foundation/element.dart';
import '../foundation/layout_hint.dart';
import '../foundation/style_registry.dart';
import '../foundation/theme_tokens.dart';
import 'basic.dart' show buttonResetCss;
import 'theme.dart' show Theme;

const _primary = ThemeTokens.primary;
const _onSurface = ThemeTokens.onSurface;
const _onSurfaceVariant = ThemeTokens.onSurfaceVariant;
const _hover = 'color-mix(in srgb, ${ThemeTokens.onSurface} 8%, transparent)';
const _current = '[aria-current]';

const _srOnly = {
  'position': 'absolute',
  'width': '1px',
  'height': '1px',
  'overflow': 'hidden',
  'clip-path': 'inset(50%)',
  'white-space': 'nowrap',
};

const _srOnlyUndo = {
  'position': 'static',
  'width': 'auto',
  'height': 'auto',
  'overflow': 'hidden',
  'clip-path': 'none',
};

/// Flutter's `NavigationRailLabelType`: when a [NavigationRailDestination]'s
/// label is shown under its icon. Hidden labels stay the destination's
/// accessible name.
enum NavigationRailLabelType {
  /// Only the icons are shown (Flutter's default).
  none,

  /// Only the selected destination's label is shown.
  selected,

  /// Every label is shown.
  all,
}

/// Flutter's `NavigationRailThemeData` (the parts that are not text or icon
/// themes: style those on the destination's widgets): the defaults of the
/// rails below. A `NavigationRail` parameter wins; a null field keeps the
/// Material 3 default. Put it in `ThemeData(navigationRailTheme:)` or around
/// a subtree with [NavigationRailTheme].
class NavigationRailThemeData {
  /// A rail theme; null fields keep the defaults.
  const NavigationRailThemeData({
    this.backgroundColor,
    this.elevation,
    this.groupAlignment,
    this.labelType,
    this.useIndicator,
    this.indicatorColor,
    this.minWidth,
    this.minExtendedWidth,
  });

  /// Default of [NavigationRail.backgroundColor].
  final Color? backgroundColor;

  /// Default of [NavigationRail.elevation].
  final double? elevation;

  /// Default of [NavigationRail.groupAlignment].
  final double? groupAlignment;

  /// Default of [NavigationRail.labelType].
  final NavigationRailLabelType? labelType;

  /// Default of [NavigationRail.useIndicator].
  final bool? useIndicator;

  /// Default of [NavigationRail.indicatorColor].
  final Color? indicatorColor;

  /// Default of [NavigationRail.minWidth].
  final double? minWidth;

  /// Default of [NavigationRail.minExtendedWidth].
  final double? minExtendedWidth;
}

/// Flutter's `NavigationRailTheme`: a [NavigationRailThemeData] for the
/// rails in [child].
class NavigationRailTheme extends InheritedWidget implements InheritedMemoKey {
  /// Applies [data] to the rails in [child].
  const NavigationRailTheme({
    super.key,
    required this.data,
    required super.child,
  });

  /// The theme.
  final NavigationRailThemeData data;

  /// The nearest [NavigationRailTheme]'s data, else the app theme's
  /// `navigationRailTheme`, else the defaults.
  static NavigationRailThemeData of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<NavigationRailTheme>()?.data ??
      Theme.of(context).navigationRailTheme ??
      const NavigationRailThemeData();

  @override
  bool updateShouldNotify(covariant NavigationRailTheme oldWidget) =>
      !identical(oldWidget.data, data);

  /// Readers see only this value.
  @override
  Object? get memoKey => data;
}

/// One entry of a [NavigationRail]: an icon (a pill indicator behind it when
/// selected) and a label.
///
/// `// web:` [href] makes it a link (`<a href>`): the destination works with
/// no JS and can be crawled. Without it, it is a `<button>` that calls the
/// rail's `onDestinationSelected` (a `ThorState` method).
class NavigationRailDestination {
  /// Creates a destination for [NavigationRail.destinations].
  const NavigationRailDestination({
    required this.icon,
    Widget? selectedIcon,
    this.indicatorColor,
    required this.label,
    this.padding,
    this.disabled = false,
    this.href,
  }) : selectedIcon = selectedIcon ?? icon;

  /// The icon of the destination.
  final Widget icon;

  /// The icon when selected (default: [icon]).
  final Widget selectedIcon;

  /// The pill behind the selected icon (default: the rail's
  /// [NavigationRail.indicatorColor]).
  final Color? indicatorColor;

  /// The label; also the accessible name when it is not shown.
  final Widget label;

  /// Space around the destination (default: none).
  final EdgeInsetsGeometry? padding;

  /// Whether the destination ignores input (Flutter's default: false).
  final bool disabled;

  /// `// web:` the route it links to (works with no JS). The selected
  /// link is marked `aria-current="page"`.
  final String? href;
}

/// Flutter's `NavigationRail` (Material 3 side navigation) as a `<nav>`
/// landmark: each [NavigationRailDestination] is a link (with `href`) or a
/// button; the selected one carries `aria-current` (`page` for a link,
/// `true` for a button).
///
/// ```dart
/// Row(children: [
///   NavigationRail(
///     selectedIndex: 0,
///     labelType: NavigationRailLabelType.all,
///     destinations: const [
///       NavigationRailDestination(icon: homeIcon, label: Text('Home'), href: '/'),
///       NavigationRailDestination(icon: cartIcon, label: Text('Cart'), href: '/cart'),
///     ],
///   ),
///   Expanded(child: body),
/// ])
/// ```
///
/// `// web:` [groupAlignment] snaps to the start, the middle or the end of
/// the free height (CSS has no fractional free-space split); the label
/// styles and icon themes of Flutter's rail are not parameters: the label
/// is a widget, style it there.
class NavigationRail extends StatelessWidget
    implements HeightHint, ThorElementWidget, ThorBuiltIn {
  /// Creates a Material 3 navigation rail.
  ///
  /// Not `const`, like Flutter's asserts that read the destinations' count.
  NavigationRail({
    super.key,
    this.backgroundColor,
    this.extended = false,
    this.leading,
    this.trailing,
    required this.destinations,
    required this.selectedIndex,
    this.onDestinationSelected,
    this.elevation,
    this.groupAlignment,
    this.labelType,
    this.minWidth,
    this.minExtendedWidth,
    this.useIndicator,
    this.indicatorColor,
  }) : assert(
         selectedIndex == null ||
             (0 <= selectedIndex && selectedIndex < destinations.length),
       ),
       assert(elevation == null || elevation > 0),
       assert(minWidth == null || minWidth > 0),
       assert(minExtendedWidth == null || minExtendedWidth > 0),
       assert(
         (minWidth == null || minExtendedWidth == null) ||
             minExtendedWidth >= minWidth,
       ),
       assert(
         !extended ||
             (labelType == null || labelType == NavigationRailLabelType.none),
       ),
       assert(
         useIndicator != false || indicatorColor == null,
         '[NavigationRail.indicatorColor] does not have an effect when '
         '[NavigationRail.useIndicator] is false',
       );

  /// Fill (default: the theme's `surface`).
  final Color? backgroundColor;

  /// Whether the rail is wide, each destination showing its label beside
  /// its icon. Needs [labelType] `none` (Flutter's assert).
  final bool extended;

  /// A widget above the destinations (a menu button, a FAB).
  final Widget? leading;

  /// A widget after the destinations.
  final Widget? trailing;

  /// The entries (zero or more).
  final List<NavigationRailDestination> destinations;

  /// Index of the selected destination; `null` selects none.
  final int? selectedIndex;

  /// Called with the index of the tapped destination (a `ThorState`
  /// method).
  final ValueChanged<int>? onDestinationSelected;

  /// Shadow elevation (default: none).
  final double? elevation;

  /// Where the destinations sit in the free height: -1 start (default), 0
  /// middle, 1 end. `// web:` anything in between snaps to the nearest of
  /// the three.
  final double? groupAlignment;

  /// When labels are shown (default: [NavigationRailLabelType.none]).
  final NavigationRailLabelType? labelType;

  /// Width of the rail (Material 3 default: 80).
  final double? minWidth;

  /// Width of the extended rail (Material 3 default: 256).
  final double? minExtendedWidth;

  /// Whether the selected destination gets a pill (default: true).
  final bool? useIndicator;

  /// Color of the selected destination's pill (default:
  /// `secondaryContainer`).
  final Color? indicatorColor;

  @override
  bool get fillsHeight => true;

  @override
  Widget build(BuildContext context) {
    final theme = NavigationRailTheme.of(context);
    final align = groupAlignment ?? theme.groupAlignment ?? -1;
    final justify = align <= -0.5
        ? null
        : align < 0.5
        ? 'center'
        : 'flex-end';
    final e = elevation ?? theme.elevation ?? 0;
    final bg = backgroundColor ?? theme.backgroundColor;
    final width = extended
        ? (minExtendedWidth ?? theme.minExtendedWidth ?? 256)
        : (minWidth ?? theme.minWidth ?? 80);
    final type = labelType ?? theme.labelType ?? NavigationRailLabelType.none;
    final indicator = useIndicator ?? theme.useIndicator ?? true;
    final pill = indicatorColor ?? theme.indicatorColor;
    return thorElement(
      'nav',
      debugName: 'NavigationRail',
      fillsHeight: true,
      css: {
        'display': 'flex',
        'flex-direction': 'column',
        'flex': 'none',
        'align-items': extended ? 'stretch' : 'center',
        'box-sizing': 'border-box',
        'min-width': cssPx(width),
        'padding': extended ? '8px 12px' : '8px 0',
        'gap': '12px',
        'justify-content': ?justify,
        'background-color': bg?.css ?? ThemeTokens.surface,
        'color': _onSurfaceVariant,
        if (e > 0)
          'box-shadow':
              '0 ${cssPx(e / 2)} ${cssPx(e * 1.5)} rgba(0, 0, 0, 0.15)',
      },
      children: [
        ?leading,
        for (final (i, d) in destinations.indexed)
          _destination(d, i, type, indicator, pill),
        ?trailing,
      ],
    );
  }

  Widget _destination(
    NavigationRailDestination d,
    int index,
    NavigationRailLabelType type,
    bool indicator,
    Color? indicatorColor,
  ) {
    final selected = index == selectedIndex;
    final link = d.href != null;
    final labelShown = extended || type != NavigationRailLabelType.none;
    final pillColor = d.indicatorColor ?? indicatorColor;
    final pill = <String, String>{
      'background-color': pillColor?.css ?? ThemeTokens.secondaryContainer,
      'color': ThemeTokens.onSecondaryContainer,
    };
    return thorElement(
      link ? 'a' : 'button',
      debugName: 'NavigationRailDestination',
      baseCss: link ? const {} : buttonResetCss,
      css: {
        'position': 'relative',
        'display': 'flex',
        'flex-direction': extended ? 'row' : 'column',
        'align-items': 'center',
        'justify-content': extended ? 'flex-start' : 'center',
        'gap': extended ? '12px' : '4px',
        'box-sizing': 'border-box',
        'color': _onSurfaceVariant,
        'text-decoration': 'none',
        'cursor': 'pointer',
        '-webkit-tap-highlight-color': 'transparent',
        if (extended) ...{
          'height': '56px',
          'padding': '0 16px',
          'border-radius': '28px',
          'transition-property': 'background-color',
          'transition-duration': '150ms',
        },
        if (d.padding case final p?) ...p.toCss('padding'),
      },
      conditions: [
        ConditionalCss(const CssCondition.selector(_current), {
          'color': _onSurface,
          if (extended && indicator) ...pill,
        }),
        if (extended)
          const ConditionalCss(CssCondition.hover, {
            'background-image': 'linear-gradient($_hover, $_hover)',
          }),
        const ConditionalCss(CssCondition.focused, {
          'outline': '2px solid $_primary',
          'outline-offset': '-2px',
        }),
        const ConditionalCss(
          CssCondition.selector(':is(:disabled, [aria-disabled="true"])'),
          {'opacity': '0.38', 'cursor': 'default'},
        ),
      ],
      attributes: {
        if (!link) 'type': 'button',
        if (link && !d.disabled) 'href': d.href!,
        if (selected) 'aria-current': link ? 'page' : 'true',
        if (d.disabled) ...{
          if (link) 'aria-disabled': 'true' else 'disabled': '',
        },
        ...engineAttributes({
          'click': d.disabled ? null : onDestinationSelected,
        }, arg: index),
      },
      children: [
        // The icon, over a pill that shows on the selected one. In the
        // extended rail the whole destination is the pill.
        if (extended)
          selected ? d.selectedIcon : d.icon
        else
          thorElement(
            'span',
            css: {
              'display': 'inline-flex',
              'align-items': 'center',
              'justify-content': 'center',
              'flex': 'none',
              'width': '56px',
              'height': labelShown ? '32px' : '56px',
              'border-radius': labelShown ? '16px' : '28px',
              'transition-property': 'background-color',
              'transition-duration': '150ms',
            },
            conditions: [
              if (!extended)
                const ConditionalCss(
                  CssCondition.within(':is(a, button):hover'),
                  {'background-image': 'linear-gradient($_hover, $_hover)'},
                ),
              if (indicator)
                ConditionalCss(const CssCondition.within(_current), pill),
              const ConditionalCss(CssCondition.reducedMotion, {
                'transition-duration': '1ms',
              }),
            ],
            children: [selected ? d.selectedIcon : d.icon],
          ),
        thorElement(
          'span',
          css: {
            'max-width': '100%',
            'overflow': 'hidden',
            'text-overflow': 'ellipsis',
            'white-space': 'nowrap',
            'font-size': ThemeTokens.labelMediumSize,
            'line-height': ThemeTokens.labelMediumLine,
            'letter-spacing': ThemeTokens.labelMediumTracking,
            'font-weight': ThemeTokens.labelMediumWeight,
            if (!labelShown || type == NavigationRailLabelType.selected)
              ..._srOnly,
          },
          conditions: [
            if (type == NavigationRailLabelType.selected && !extended)
              const ConditionalCss(CssCondition.within(_current), _srOnlyUndo),
          ],
          children: [d.label],
        ),
      ],
    );
  }
}
