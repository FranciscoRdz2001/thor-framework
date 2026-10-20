import 'package:thor_style/thor_style.dart';

import '../core/core.dart';
import '../foundation/child_rules.dart';
import '../foundation/dialog_scope.dart' show ScaffoldScope;
import '../foundation/element.dart';
import '../foundation/layout_hint.dart';
import '../foundation/material_localizations.dart'
    show MaterialLocalizations, ThorLocalizations;
import '../foundation/parent_data.dart';
import '../foundation/style_registry.dart';
import '../foundation/stylesheet.dart' show WindowSizeClass;
import '../foundation/theme_tokens.dart';
import 'buttons.dart' show ButtonStyle;
import 'icon.dart' show Icon, IconButton;
import 'material.dart' show DialogTrigger;
import 'theme.dart' show Theme;

const _surface = ThemeTokens.surface;
const _onSurface = ThemeTokens.onSurface;

/// Flutter's `AppBar` (Material 3 small top app bar) as one `<header>`: a
/// grid with the [leading] widget, the [title] and the [actions] on the
/// toolbar row, and [bottom] (e.g. a `TabBar`) under it.
///
/// Inside `Scaffold(appBar:)` the header is the scaffold's banner landmark
/// (no extra wrapper) and sticks to the top while the page scrolls, like
/// Flutter's app bar over a scrolling body.
///
/// In a `Scaffold` with a `drawer:`, the bar shows a [DrawerButton] before
/// the title by itself (and an [EndDrawerButton] after it for an
/// `endDrawer:`), like Flutter's; [automaticallyImplyLeading] and
/// [automaticallyImplyActions] turn them off.
///
/// ```dart
/// Scaffold(
///   appBar: AppBar(title: const Text('Sales')),   // + the menu button
///   drawer: Drawer(child: Menu()),
///   body: …,
/// )
///
/// AppBar(
///   leading: DialogTrigger(id: 'menu', child: IconButton(icon: menuIcon, tooltip: 'Menu')),
///   title: const Text('Sales'),
///   actions: [IconButton(icon: searchIcon, onPressed: search.open, tooltip: 'Search')],
///   scrolledUnderElevation: 3,
/// )
/// ```
class AppBar extends StatelessWidget
    implements LayoutHint, ThorElementWidget, ThorBuiltIn {
  /// Creates a Material 3 app bar.
  const AppBar({
    super.key,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.automaticallyImplyActions = true,
    this.title,
    this.actions,
    this.flexibleSpace,
    this.bottom,
    this.elevation,
    this.scrolledUnderElevation,
    this.shadowColor,
    this.shape,
    this.backgroundColor,
    this.foregroundColor,
    this.primary = true,
    this.centerTitle,
    this.titleSpacing,
    this.toolbarHeight,
    this.leadingWidth,
    this.titleTextStyle,
  });

  /// Widget before the title, usually an `IconButton` (menu or back).
  final Widget? leading;

  /// Flutter shows a back button (or the drawer's menu button) when
  /// [leading] is null.
  ///
  /// `// web:` only the drawer's menu button ([DrawerButton], when the
  /// `Scaffold` has a `drawer:`): a page has no navigator stack to pop
  /// (the browser's back button is the back button). Pass the [leading]
  /// you want to replace it.
  final bool automaticallyImplyLeading;

  /// Whether the `Scaffold`'s `endDrawer:` gets an [EndDrawerButton] in the
  /// end of the bar when [actions] is null or empty (Flutter's default).
  final bool automaticallyImplyActions;

  /// Primary content, usually a `Text`: one line, cut with an ellipsis
  /// when it doesn't fit (like Flutter's app bar title).
  final Widget? title;

  /// Widgets after the title, usually `IconButton`s. `null` or empty: no
  /// actions element at all.
  final List<Widget>? actions;

  /// Painted behind the toolbar and [bottom], over the whole bar (an image,
  /// a gradient), like Flutter's `AppBar.flexibleSpace`. It is clipped to the
  /// bar's [shape].
  final Widget? flexibleSpace;

  /// Shown under the toolbar row across the whole width (a `TabBar`).
  ///
  /// `// web:` any widget; Flutter asks for a `PreferredSizeWidget` because
  /// it lays the bar out with a fixed height, here the grid row is `auto`.
  final Widget? bottom;

  /// Shadow elevation (Material 3 default: 0, no shadow).
  final double? elevation;

  /// The elevation once the content scrolls under the bar (Flutter's
  /// `AppBar.scrolledUnderElevation`): the shadow grows from [elevation] to
  /// this while the page (or the `CustomScrollView` the bar is in) moves its
  /// first pixels.
  ///
  /// `// web:` null keeps the bar as it is (Flutter's Material 3 default is
  /// 3, which would give every bar a shadow on scroll). The change is a CSS
  /// scroll-driven animation (`animation-timeline: scroll()`), no JS; a
  /// browser without it keeps the [elevation] shadow.
  final double? scrolledUnderElevation;

  /// Color of the elevation shadow (default: black).
  final Color? shadowColor;

  /// The bar's outline: corner radii and border (Flutter's
  /// `AppBar.shape`).
  final OutlinedBorder? shape;

  /// Fill (default: the theme's `surface`).
  final Color? backgroundColor;

  /// Color of the title, icons and actions (default: `onSurface`).
  final Color? foregroundColor;

  /// Whether the bar is at the top of the screen, so its toolbar clears the
  /// device's top inset (the notch).
  ///
  /// `// web:` the inset is `env(safe-area-inset-top)`, which is 0 unless
  /// the page's viewport has `viewport-fit=cover`; `Scaffold(primary:
  /// false)` turns it off for the bar inside.
  final bool primary;

  /// Whether the title is centered on the bar.
  ///
  /// `// web:` `null` means `false` on every platform (Flutter centers on
  /// iOS/macOS); a page doesn't guess the visitor's OS.
  final bool? centerTitle;

  /// Space around the title on the inline axis (Flutter's default: 16).
  final double? titleSpacing;

  /// Height of the toolbar row (Material 3 default: 64).
  final double? toolbarHeight;

  /// Width of the [leading] box (Flutter's default: 56).
  final double? leadingWidth;

  /// Font and color of the title (default: the theme's, else the
  /// title-large role).
  final TextStyle? titleTextStyle;

  @override
  bool get fillsWidth => true;

  @override
  Widget build(BuildContext context) {
    // The parameter, else `ThemeData.appBarTheme`, else Flutter's default.
    final theme = Theme.of(context).appBarTheme;
    final center = centerTitle ?? theme?.centerTitle ?? false;
    final e = elevation ?? theme?.elevation ?? 0;
    final titleStyle = titleTextStyle ?? theme?.titleTextStyle;
    final drawers = ScaffoldScope.maybeOf(context);
    final sliver = _SliverBarScope.maybeOf(context);
    final lead =
        leading ??
        (automaticallyImplyLeading && drawers?.drawerId != null
            ? const DrawerButton()
            : null);
    var trailing = actions ?? const <Widget>[];
    if (trailing.isEmpty &&
        automaticallyImplyActions &&
        drawers?.endDrawerId != null) {
      trailing = const [EndDrawerButton()];
    }
    final toolbar = toolbarHeight ?? theme?.toolbarHeight ?? 64;
    // How far a SliverAppBar's tall bar collapses.
    final collapses = sliver?.collapse(toolbar, bottom != null) ?? 0;
    // The scrolled-under shadow: a scroll-driven animation of `box-shadow`.
    final under = scrolledUnderElevation;
    String? underName;
    if (under != null && under != e) {
      underName =
          't-appbar-under-${_slug(e)}-${_slug(under)}-${_slug(shadowColor?.css)}';
      ThorStyleRegistry.active(context)?.addKeyframes(
        underName,
        'from{box-shadow:${_shadow(e, shadowColor)}}'
        'to{box-shadow:${_shadow(under, shadowColor)}}',
      );
    }
    final timeline = sliver != null
        ? 'scroll(nearest block)'
        : (drawers?.scrollBody ?? false)
        ? _bodyTimeline
        : 'scroll(root block)';
    final topInset = primary && (drawers?.primary ?? true);
    String? collapseName;
    if (collapses > 0) {
      collapseName = 't-sliver-collapse-${_slug(collapses)}';
      ThorStyleRegistry.active(context)?.addKeyframes(
        collapseName,
        'from{translate:0 0}to{translate:0 ${cssPx(collapses)}}',
      );
    }
    // The toolbar's children stay at the top of the screen while the bar
    // collapses: they move down as much as the bar moves up.
    final stay = collapseName == null
        ? null
        : ConditionalCss(_scrollDriven, {
            'animation': '$collapseName linear both',
            'animation-timeline': 'scroll(nearest block)',
            'animation-range': '0px ${cssPx(collapses)}',
          });
    return thorElement(
      'header',
      debugName: 'AppBar',
      fillsWidth: true,
      css: {
        'display': 'grid',
        // Centered: two equal flexible sides keep the title in the middle
        // of the whole bar; the title's own track shrinks to fit (ellipsis).
        'grid-template-columns': center
            ? '1fr minmax(0, max-content) 1fr'
            : 'auto minmax(0, 1fr) auto',
        'grid-template-rows': bottom == null
            ? cssPx(toolbar)
            : '${cssPx(toolbar)} auto',
        'align-items': 'center',
        'box-sizing': 'border-box',
        'background-color':
            (backgroundColor ?? theme?.backgroundColor)?.css ?? _surface,
        'color': (foregroundColor ?? theme?.foregroundColor)?.css ?? _onSurface,
        if (e > 0) 'box-shadow': _shadow(e, shadowColor),
        if (topInset) 'padding-top': 'env(safe-area-inset-top, 0px)',
        if (shape != null) ...{
          'border-radius': shape!.radiusCss,
          if (shape!.side != BorderSide.none) 'border': shape!.side.css,
        },
        if (flexibleSpace != null) ...{
          'position': 'relative',
          'isolation': 'isolate',
          if (shape != null) 'overflow': 'clip',
        },
        ...?sliver?.css(),
      },
      conditions: [
        if (underName != null)
          ConditionalCss(_scrollDriven, {
            'animation': '$underName linear both',
            'animation-timeline': timeline,
            'animation-range': '0px 16px',
          }),
        ...?sliver?.conditions(toolbar, bottom != null),
      ],
      children: [
        if (flexibleSpace != null)
          WrapWith(
            const WrapData(
              css: {
                'position': 'absolute',
                'inset': '0',
                'z-index': '-1',
                'min-width': '0',
                'min-height': '0',
                'overflow': 'hidden',
              },
            ),
            child: flexibleSpace!,
          ),
        if (lead != null)
          WrapWith(
            // 4 + 48 (an IconButton) + 4 = Flutter's 56 px leading box.
            WrapData(
              css: {
                'grid-row': '1',
                'grid-column': '1',
                'justify-self': 'start',
                if (leadingWidth == null)
                  'margin-inline-start': '4px'
                else ...{
                  'width': cssPx(leadingWidth!),
                  'display': 'flex',
                  'justify-content': 'center',
                },
              },
              conditions: [?stay],
            ),
            child: lead,
          ),
        if (title != null)
          WrapWith(
            WrapData(
              // Theme / param text styles are defaults under the title's own
              // style, as Flutter's DefaultTextStyle.
              baseCss: {
                'font-size': 'var(--t-title-large-size, 22px)',
                'line-height': 'var(--t-title-large-line, 28px)',
                'letter-spacing': 'var(--t-title-large-tracking, normal)',
                'font-weight': 'var(--t-title-large-weight, 400)',
                ...?titleStyle?.toCss(),
              },
              css: {
                'grid-row': '1',
                'grid-column': '2',
                'min-width': '0',
                'margin-inline': cssPx(
                  titleSpacing ?? theme?.titleSpacing ?? 16,
                ),
                'overflow': 'hidden',
                'text-overflow': 'ellipsis',
                'white-space': 'nowrap',
                if (center) 'text-align': 'center',
              },
              conditions: [?stay],
            ),
            child: title!,
          ),
        if (trailing.isNotEmpty)
          thorElement(
            'div',
            css: const {
              'grid-row': '1',
              'grid-column': '3',
              'justify-self': 'end',
              'display': 'flex',
              'align-items': 'center',
              'margin-inline-end': '4px',
            },
            conditions: [?stay],
            children: trailing,
          ),
        if (bottom != null)
          WrapWith(
            const WrapData(
              css: {
                'grid-row': '-2 / -1',
                'grid-column': '1 / -1',
                'min-width': '0',
              },
            ),
            child: bottom!,
          ),
      ],
    );
  }
}

/// The name of the timeline a `Scaffold` whose body is a `CustomScrollView`
/// publishes for the app bar to follow.
const _bodyTimeline = '--t-body-scroll';

/// Only where the browser has scroll-driven animations.
final _scrollDriven = CssCondition.supports(
  '(animation-timeline: scroll())',
  const CssCondition.selector(''),
);

String _slug(Object? n) =>
    '$n'.replaceAll(RegExp(r'[^A-Za-z0-9]'), '_').replaceAll('__', '_');

/// The Material 3 elevation shadow of [e] (two layers), in [color].
String _shadow(double e, Color? color) {
  if (e <= 0) return 'none';
  final key = color?.css ?? 'rgba(0, 0, 0, 0.2)';
  final ambient = color?.css ?? 'rgba(0, 0, 0, 0.14)';
  return '0 ${cssPx(e / 2)} ${cssPx(e * 1.5)} $key, '
      '0 ${cssPx(e / 4)} ${cssPx(e / 2)} $ambient';
}

/// What a [SliverAppBar] tells the [AppBar] it builds.
class _SliverBarScope extends InheritedWidget implements InheritedMemoKey {
  const _SliverBarScope({
    required this.pinned,
    required this.expandedHeight,
    required super.child,
  });

  final bool pinned;
  final double? expandedHeight;

  static _SliverBarScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SliverBarScope>();

  // Flutter's `kTextTabBarHeight`: what `bottom` is taken to measure.
  static const _bottomHeight = 48.0;

  /// How far the expanded bar can collapse (0: it does not).
  double collapse(double toolbar, bool hasBottom) {
    final expanded = expandedHeight;
    if (expanded == null) return 0;
    final rest = toolbar + (hasBottom ? _bottomHeight : 0);
    return expanded > rest ? expanded - rest : 0;
  }

  /// The bar's own declarations: where it sticks.
  CssDeclarations css() => {
    if (pinned) ...{'position': 'sticky', 'top': '0', 'z-index': '5'},
  };

  /// What only a browser with scroll-driven animations gets: the tall bar
  /// that collapses to its toolbar as the view scrolls.
  List<ConditionalCss> conditions(double toolbar, bool hasBottom) {
    final by = collapse(toolbar, hasBottom);
    if (by <= 0) return const [];
    return [
      ConditionalCss(_scrollDriven, {
        'min-height': cssPx(expandedHeight!),
        'grid-template-rows':
            '${cssPx(toolbar)} 1fr${hasBottom ? ' auto' : ''}',
        if (pinned) 'top': cssPx(-by),
      }),
    ];
  }

  @override
  bool updateShouldNotify(covariant _SliverBarScope oldWidget) =>
      pinned != oldWidget.pinned || expandedHeight != oldWidget.expandedHeight;

  @override
  Object? get memoKey => (pinned, expandedHeight);
}

/// Flutter's `SliverAppBar`: an [AppBar] inside a `CustomScrollView`. It
/// scrolls away with the content, or, with [pinned], sticks to the top of the
/// view (`position: sticky`).
///
/// ```dart
/// CustomScrollView(
///   slivers: [
///     SliverAppBar(pinned: true, expandedHeight: 160, title: Text('Sales'),
///         flexibleSpace: Image.network('/hero.jpg')),
///     SliverList.builder(itemCount: 50, itemBuilder: (c, i) => ListTile(title: Text('$i'))),
///   ],
/// )
/// ```
///
/// With [expandedHeight] the bar starts that tall and collapses to the
/// toolbar (plus [bottom]) as the view scrolls: the toolbar stays on top while
/// the [flexibleSpace] goes up, all in CSS (`animation-timeline: scroll()`).
///
/// `// web:` [floating] and [snap] (the bar coming back as soon as the view
/// scrolls up) need to know the scroll direction, which CSS cannot read:
/// they are accepted and the bar behaves as without them. [bottom] is taken
/// to be 48 px tall (a `TabBar`) when the bar collapses. A browser without
/// scroll-driven animations shows the bar at its collapsed size.
class SliverAppBar extends StatelessWidget
    implements ThorElementWidget, ThorBuiltIn {
  /// Creates a sliver app bar.
  const SliverAppBar({
    super.key,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.title,
    this.actions,
    this.flexibleSpace,
    this.bottom,
    this.elevation,
    this.scrolledUnderElevation,
    this.shadowColor,
    this.backgroundColor,
    this.foregroundColor,
    this.primary = true,
    this.centerTitle,
    this.titleSpacing,
    this.toolbarHeight,
    this.leadingWidth,
    this.titleTextStyle,
    this.shape,
    this.expandedHeight,
    this.floating = false,
    this.pinned = false,
    this.snap = false,
  }) : assert(!snap || floating, 'snap needs floating');

  /// See [AppBar.leading].
  final Widget? leading;

  /// See [AppBar.automaticallyImplyLeading].
  final bool automaticallyImplyLeading;

  /// See [AppBar.title].
  final Widget? title;

  /// See [AppBar.actions].
  final List<Widget>? actions;

  /// See [AppBar.flexibleSpace].
  final Widget? flexibleSpace;

  /// See [AppBar.bottom].
  final Widget? bottom;

  /// See [AppBar.elevation].
  final double? elevation;

  /// See [AppBar.scrolledUnderElevation].
  final double? scrolledUnderElevation;

  /// See [AppBar.shadowColor].
  final Color? shadowColor;

  /// See [AppBar.backgroundColor].
  final Color? backgroundColor;

  /// See [AppBar.foregroundColor].
  final Color? foregroundColor;

  /// See [AppBar.primary].
  final bool primary;

  /// See [AppBar.centerTitle].
  final bool? centerTitle;

  /// See [AppBar.titleSpacing].
  final double? titleSpacing;

  /// See [AppBar.toolbarHeight].
  final double? toolbarHeight;

  /// See [AppBar.leadingWidth].
  final double? leadingWidth;

  /// See [AppBar.titleTextStyle].
  final TextStyle? titleTextStyle;

  /// See [AppBar.shape].
  final OutlinedBorder? shape;

  /// The height of the bar before it collapses (default: the toolbar's).
  final double? expandedHeight;

  /// Whether the bar returns as soon as the view scrolls up. `// web:` not
  /// done, see the class.
  final bool floating;

  /// Whether the bar stays at the top once collapsed.
  final bool pinned;

  /// Whether a floating bar finishes appearing or hiding. `// web:` not done,
  /// see the class.
  final bool snap;

  @override
  Widget build(BuildContext context) => _SliverBarScope(
    pinned: pinned,
    expandedHeight: expandedHeight,
    child: AppBar(
      leading: leading,
      automaticallyImplyLeading: automaticallyImplyLeading,
      title: title,
      actions: actions,
      flexibleSpace: flexibleSpace,
      bottom: bottom,
      elevation: elevation,
      scrolledUnderElevation: scrolledUnderElevation,
      shadowColor: shadowColor,
      shape: shape,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      primary: primary,
      centerTitle: centerTitle,
      titleSpacing: titleSpacing,
      toolbarHeight: toolbarHeight,
      leadingWidth: leadingWidth,
      titleTextStyle: titleTextStyle,
    ),
  );
}

const _menuIcon = IconData.svg(
  't-menu',
  '<path d="M3 6h18M3 12h18M3 18h18"/>',
  strokeWidth: 2,
);

String _openMenuLabel(BuildContext context, {required bool end}) =>
    // `// web:` Flutter names both `openAppDrawerTooltip`; two buttons with
    // the same name are ambiguous for a screen reader.
    end
    ? ThorLocalizations.of(context).openSecondaryMenuTooltip
    : MaterialLocalizations.of(context).openAppDrawerTooltip;

Widget _drawerButton(
  BuildContext context,
  String widget,
  String? id,
  VoidCallback? onPressed,
  ButtonStyle? style,
  WindowSizeClass? permanentFrom,
) {
  if (id == null) {
    throw StateError(
      '$widget needs a Scaffold with '
      '${widget == 'DrawerButton' ? 'drawer:' : 'endDrawer:'} above it '
      '(Scaffold(${widget == 'DrawerButton' ? 'drawer:' : 'endDrawer:'} '
      'Drawer(...), ...)): there is none. To open a Drawer from anywhere '
      'else, use DialogTrigger(id: ...).',
    );
  }
  final label = _openMenuLabel(context, end: widget == 'EndDrawerButton');
  return DialogTrigger(
    id: id,
    // A permanent drawer is a panel in the page from there: nothing to open.
    hiddenFrom: permanentFrom,
    child: IconButton(
      icon: const Icon(_menuIcon),
      tooltip: label,
      style: style,
      // Opening is native (`command="show-modal"`); this runs besides it.
      onPressed: onPressed ?? _noop,
    ),
  );
}

void _noop() {}

/// Flutter's `DrawerButton`: the menu button that opens the `Scaffold`'s
/// `drawer:`. An [AppBar] adds one by itself; use it directly to put the
/// button somewhere else in the scaffold.
///
/// `// web:` Flutter's calls `Scaffold.of(context).openDrawer()`; here it is
/// a native button (`command="show-modal"` on the drawer's `<dialog>`,
/// works without JS). [onPressed] runs in addition to opening the drawer.
class DrawerButton extends StatelessWidget
    implements ThorElementWidget, ThorBuiltIn {
  /// A button that opens the nearest `Scaffold`'s drawer.
  const DrawerButton({super.key, this.onPressed, this.style});

  /// Called besides opening the drawer (a `ThorState` method).
  final void Function()? onPressed;

  /// The button's look (Flutter's `IconButton.style`).
  final ButtonStyle? style;

  @override
  Widget build(BuildContext context) => _drawerButton(
    context,
    'DrawerButton',
    ScaffoldScope.maybeOf(context)?.drawerId,
    onPressed,
    style,
    ScaffoldScope.maybeOf(context)?.drawerPermanentFrom,
  );
}

/// Flutter's `EndDrawerButton`: opens the `Scaffold`'s `endDrawer:`.
///
/// `// web:` its label is "Open secondary menu" (Flutter gives both buttons
/// the same tooltip, which a screen reader can't tell apart).
class EndDrawerButton extends StatelessWidget
    implements ThorElementWidget, ThorBuiltIn {
  /// A button that opens the nearest `Scaffold`'s end drawer.
  const EndDrawerButton({super.key, this.onPressed, this.style});

  /// Called besides opening the drawer (a `ThorState` method).
  final void Function()? onPressed;

  /// The button's look (Flutter's `IconButton.style`).
  final ButtonStyle? style;

  @override
  Widget build(BuildContext context) => _drawerButton(
    context,
    'EndDrawerButton',
    ScaffoldScope.maybeOf(context)?.endDrawerId,
    onPressed,
    style,
    ScaffoldScope.maybeOf(context)?.endDrawerPermanentFrom,
  );
}
