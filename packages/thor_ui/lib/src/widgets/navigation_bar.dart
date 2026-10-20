import 'package:thor_style/thor_style.dart';

import '../core/core.dart';
import '../engine/watch.dart' show engineAttributes;
import '../foundation/child_rules.dart';
import '../foundation/element.dart';
import '../foundation/layout_hint.dart';
import '../foundation/parent_data.dart';
import '../foundation/style_registry.dart';
import '../foundation/theme_tokens.dart';
import '../foundation/transparent.dart';
import 'basic.dart' show buttonResetCss;
import 'component_themes.dart' show NavigationBarThemeData;
import 'theme.dart' show Theme;

const _primary = ThemeTokens.primary;
const _onSurface = ThemeTokens.onSurface;
const _onSurfaceVariant = ThemeTokens.onSurfaceVariant;
const _hover = 'color-mix(in srgb, ${ThemeTokens.onSurface} 8%, transparent)';

/// The destination that is the current one: `aria-current` on its link or
/// button (a condition on the same classes, never a class of its own).
const _current = '[aria-current]';

/// Visually hidden, still read by screen readers (the accessible name).
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

/// Flutter's `NavigationDestinationLabelBehavior`: when a
/// [NavigationDestination]'s label is shown. Hidden labels stay the
/// destination's accessible name.
enum NavigationDestinationLabelBehavior {
  /// Every label is shown (Flutter's default).
  alwaysShow,

  /// No label is shown.
  alwaysHide,

  /// Only the selected destination's label is shown.
  onlyShowSelected,
}

/// One entry of a [NavigationBar]: an icon (a pill indicator behind it
/// when selected) over a label.
///
/// `// web:` [href] makes it a link (`<a href>`): the destination works
/// with no JS, opens in a new tab with a middle click and can be crawled.
/// Without it, it is a `<button>` that calls the bar's
/// `onDestinationSelected` (a `ThorState` method).
class NavigationDestination extends StatelessWidget implements ThorBuiltIn {
  /// Creates a navigation bar destination.
  const NavigationDestination({
    super.key,
    required this.icon,
    this.selectedIcon,
    required this.label,
    this.tooltip,
    this.enabled = true,
    this.href,
  });

  /// Icon of the destination.
  final Widget icon;

  /// Icon when selected (default: [icon]).
  final Widget? selectedIcon;

  /// Text under the icon; also the accessible name when hidden.
  final String label;

  /// Native tooltip (`title`).
  final String? tooltip;

  /// Whether it responds to input (Flutter's default: true).
  final bool enabled;

  /// `// web:` the route it links to. A link destination works with no JS;
  /// the bar marks the selected one `aria-current="page"`.
  final String? href;

  @override
  Widget build(BuildContext context) => throw StateError(
    'NavigationDestination must be one of NavigationBar.destinations',
  );
}

/// Flutter's `NavigationBar` (Material 3 bottom navigation) as a `<nav>`
/// landmark: each [NavigationDestination] is a link (with `href`) or a
/// button; the selected one carries `aria-current` (`page` for a link,
/// `true` for a button).
///
/// Inside `Scaffold(bottomNavigationBar:)` the `<nav>` replaces the
/// scaffold's footer (no extra wrapper) and sticks to the bottom of the
/// viewport, like Flutter's bar under a scrolling body.
///
/// ```dart
/// NavigationBar(
///   selectedIndex: 0,
///   destinations: const [
///     NavigationDestination(icon: homeIcon, label: 'Home', href: '/'),
///     NavigationDestination(icon: cartIcon, label: 'Cart', href: '/cart'),
///   ],
/// )
/// ```
class NavigationBar extends StatelessWidget
    implements LayoutHint, ThorElementWidget, ThorBuiltIn {
  /// Creates a Material 3 navigation bar.
  ///
  /// Not `const`, like Flutter's: the asserts read the destinations' count.
  NavigationBar({
    super.key,
    required this.destinations,
    this.selectedIndex = 0,
    this.onDestinationSelected,
    this.backgroundColor,
    this.elevation,
    this.height,
    this.indicatorColor,
    this.labelBehavior,
  }) : assert(destinations.length >= 2),
       assert(
         selectedIndex == null ||
             (0 <= selectedIndex && selectedIndex < destinations.length),
       );

  /// The entries, usually [NavigationDestination]s (at least two, like
  /// Flutter). Any other widget takes an equal share of the bar.
  final List<Widget> destinations;

  /// Index of the selected destination; `null` selects none (a page that
  /// isn't one of the destinations).
  final int? selectedIndex;

  /// Called with the index of the tapped destination (a `ThorState`
  /// method, e.g. `app.goTo`).
  final ValueChanged<int>? onDestinationSelected;

  /// Fill (default: the theme's `surfaceContainer`).
  final Color? backgroundColor;

  /// Shadow elevation (Material 3 default: no shadow).
  final double? elevation;

  /// Height of the bar without the safe area (Material 3 default: 80).
  final double? height;

  /// Color of the selected destination's pill (default:
  /// `secondaryContainer`).
  final Color? indicatorColor;

  /// When labels are shown (default: always).
  final NavigationDestinationLabelBehavior? labelBehavior;

  @override
  bool get fillsWidth => true;

  @override
  Widget build(BuildContext context) {
    // The parameter, else `ThemeData.navigationBarTheme`, else the default.
    final theme = Theme.of(context).navigationBarTheme;
    final e = elevation ?? theme?.elevation ?? 0;
    return thorElement(
      'nav',
      debugName: 'NavigationBar',
      fillsWidth: true,
      css: {
        'display': 'flex',
        'align-items': 'stretch',
        'box-sizing': 'border-box',
        'min-height': cssPx(height ?? theme?.height ?? 80),
        'padding-bottom': 'env(safe-area-inset-bottom)',
        'background-color':
            (backgroundColor ?? theme?.backgroundColor)?.css ??
            ThemeTokens.surfaceContainer,
        'color': _onSurfaceVariant,
        if (e > 0)
          'box-shadow':
              '0 -${cssPx(e / 2)} ${cssPx(e * 1.5)} rgba(0, 0, 0, 0.15)',
      },
      children: [
        for (final (i, d) in destinations.indexed)
          // Also one an app component builds.
          if (resolveComponent(d) case final NavigationDestination d)
            _destination(d, i, theme)
          else
            WrapWith(
              const WrapData(css: {'flex': '1 1 0', 'min-width': '0'}),
              child: d,
            ),
      ],
    );
  }

  Widget _destination(
    NavigationDestination d,
    int index,
    NavigationBarThemeData? theme,
  ) {
    final selected = index == selectedIndex;
    final link = d.href != null;
    final behavior =
        labelBehavior ??
        theme?.labelBehavior ??
        NavigationDestinationLabelBehavior.alwaysShow;
    final indicatorColor = this.indicatorColor ?? theme?.indicatorColor;
    return thorElement(
      link ? 'a' : 'button',
      debugName: 'NavigationDestination',
      baseCss: link ? const {} : buttonResetCss,
      css: const {
        'position': 'relative',
        'display': 'flex',
        'flex-direction': 'column',
        'align-items': 'center',
        'justify-content': 'center',
        'gap': '4px',
        'flex': '1 1 0',
        'min-width': '0',
        'box-sizing': 'border-box',
        'padding': '12px 0 16px',
        'color': _onSurfaceVariant,
        'text-decoration': 'none',
        'cursor': 'pointer',
        '-webkit-tap-highlight-color': 'transparent',
      },
      conditions: const [
        ConditionalCss(CssCondition.selector(_current), {'color': _onSurface}),
        ConditionalCss(CssCondition.focused, {
          'outline': '2px solid $_primary',
          'outline-offset': '-2px',
        }),
        ConditionalCss(
          CssCondition.selector(':is(:disabled, [aria-disabled="true"])'),
          {'opacity': '0.38', 'cursor': 'default'},
        ),
      ],
      attributes: {
        if (!link) 'type': 'button',
        if (link && d.enabled) 'href': d.href!,
        if (selected) 'aria-current': link ? 'page' : 'true',
        if (!d.enabled) ...{
          if (link) 'aria-disabled': 'true' else 'disabled': '',
        },
        'title': ?d.tooltip,
        ...engineAttributes({
          'click': d.enabled ? onDestinationSelected : null,
        }, arg: index),
      },
      children: [
        thorElement(
          'span',
          css: const {
            'display': 'inline-flex',
            'align-items': 'center',
            'justify-content': 'center',
            'flex': 'none',
            'width': '64px',
            'height': '32px',
            'border-radius': '16px',
            'transition-property': 'background-color',
            'transition-duration': '150ms',
          },
          conditions: [
            const ConditionalCss(CssCondition.within(':is(a, button):hover'), {
              'background-image': 'linear-gradient($_hover, $_hover)',
            }),
            ConditionalCss(const CssCondition.within(_current), {
              'background-color':
                  indicatorColor?.css ?? ThemeTokens.secondaryContainer,
              'color': ThemeTokens.onSecondaryContainer,
            }),
            const ConditionalCss(CssCondition.reducedMotion, {
              'transition-duration': '1ms',
            }),
          ],
          children: [selected ? (d.selectedIcon ?? d.icon) : d.icon],
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
            if (behavior != NavigationDestinationLabelBehavior.alwaysShow)
              ..._srOnly,
          },
          conditions: [
            if (behavior == NavigationDestinationLabelBehavior.onlyShowSelected)
              const ConditionalCss(CssCondition.within(_current), _srOnlyUndo),
          ],
          children: [Widget.text(d.label)],
        ),
      ],
    );
  }
}
