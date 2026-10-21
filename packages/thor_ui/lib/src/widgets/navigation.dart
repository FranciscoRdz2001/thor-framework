import 'package:thor_engine/thor_engine.dart'
    show DialogController, dialogControllerAttr;
import 'package:thor_server/thor_server.dart' show RouteUrl;
import 'package:thor_style/thor_style.dart';

import '../core/core.dart';
import '../foundation/child_rules.dart';
import '../foundation/dialog_scope.dart';
import '../foundation/element.dart';
import '../foundation/native_id.dart';
import '../foundation/page_navigation.dart' show noPrefetchAttribute;
import '../foundation/parent_data.dart';
import '../foundation/style_registry.dart';
import '../foundation/stylesheet.dart' show WindowSizeClass;
import '../foundation/theme_tokens.dart';
import '../foundation/widget_state.dart';
import 'backdrop.dart';
import 'buttons.dart' show ButtonStyle, ButtonStyleResolved, buttonStyleCss;
import 'component_themes.dart' show DrawerThemeData;
import 'dialog_close_corner.dart' show DialogCloseCorner;
import 'flex.dart' show Expanded;
import 'shortcuts.dart' show controllerIdOf;
import 'theme.dart' show Theme;

/// A link: makes its child's element an `<a href>` (no extra node), like
/// Flutter's `Link` from `url_launcher`. With [newTab] it opens in a new
/// tab (`target="_blank"`, `rel="noopener noreferrer"`).
///
/// ```dart
/// Link(href: RouteUrl('#pricing'), child: Text('Pricing'))
/// ```
///
/// In a routed app the page is fetched ahead on hover (see
/// `PageNavigation`); [prefetch] `false` keeps this link out.
class Link extends ParentDataWrapper {
  /// Links `child` to [href].
  const Link({
    super.key,
    this.href = const RouteUrl('#'),
    this.newTab = false,
    this.label,
    this.prefetch = true,
    this.current = false,
    this.fetch,
    required super.child,
  });

  /// Shows a region of the page [href] names, here, instead of going there
  /// (see [FragmentFetch]). Without JavaScript, or with a modified click,
  /// the link goes to [href] as always.
  final FragmentFetch? fetch;

  /// Whether [href] is the page being shown (`aria-current="page"`), e.g.
  /// the active entry of a sidebar.
  ///
  /// `// web:` no Flutter counterpart (Flutter has no current page to
  /// announce); `ListTile(href:, selected: true)` sets it too.
  final bool current;

  // web: Flutter's `Link` takes a `Uri`; a page here is an `href` the
  // browser follows (with or without JS).
  /// Destination (a URL, a path or `#section`). Omit it only where the
  /// destination comes from elsewhere, a list row's
  /// `row.link(links.urlOf, child: …)`: the row's
  /// own value replaces this `#` (the row template has no `href`, the browser
  /// writes one on every clone). Anywhere else a `Link` without [href] goes to
  /// the top of the page.
  final RouteUrl href;

  /// Whether it opens in a new tab.
  final bool newTab;

  /// Accessible name, when the child has no text (an icon).
  final String? label;

  /// Whether the page's speculation rules may fetch [href] before the
  /// click (`false` adds `data-no-prefetch`). Turn it off for a `GET` with
  /// side effects or an expensive page.
  ///
  /// `// web:` no Flutter counterpart.
  final bool prefetch;

  @override
  WrapData get wrapData => WrapData(
    tag: 'a',
    baseCss: const {'text-decoration': 'none', 'color': 'inherit'},
    attributes: {
      'href': href,
      if (newTab) ...{'target': '_blank', 'rel': 'noopener noreferrer'},
      'aria-label': ?label,
      if (current) 'aria-current': 'page',
      if (!prefetch) noPrefetchAttribute: '',
      if (fetch case final f?) ...f._attributes(href),
    },
  );
}

/// What a [Link] fetches instead of navigating: the [Region] [piece] of the
/// page the link points to, put into the [Region] [into] of the page that
/// has the link, and the dialog or popover [open] opened once it is there.
///
/// One `Dialog` can show any item this way: it has an empty region, each
/// item's link asks for the `detail` region of the item's own page, and the
/// dialog holds one item's content instead of the whole catalog's.
///
/// ```dart
/// Dialog(id: 'product', child: Region(id: 'product-body', child: SizedBox())),
/// Link(
///   href: RouteUrl('/shop/mug'),
///   fetch: const FragmentFetch(
///     piece: 'detail',
///     into: 'product-body',
///     open: 'product',
///   ),
///   child: ProductCard(mug),
/// ),
/// // /shop/mug draws: Region(id: 'detail', child: ProductDetail(mug))
/// ```
///
/// Clicking again on the same link only reopens the dialog. If the request
/// fails the browser goes to the link's page.
///
/// `// web:` Flutter's `showDialog(builder:)` builds the content in the
/// device; here the server draws it, and only when it is asked for.
class FragmentFetch {
  /// Fetches [piece] of the link's page into [into].
  const FragmentFetch({required this.piece, required this.into, this.open});

  /// The id of the `Region` of the page the link points to.
  final String piece;

  /// The id of the `Region` of this page that receives it.
  final String into;

  /// The id of the `Dialog`, `Drawer` or popover to open once the region has
  /// its content, or null.
  final String? open;

  Map<String, String> _attributes(RouteUrl href) {
    final url = '$href';
    final hash = url.indexOf('#');
    final page = hash < 0 ? url : url.substring(0, hash);
    return {
      'data-thor-lazy':
          '$page${page.contains('?') ? '&' : '?'}thor-piece='
          '${Uri.encodeQueryComponent(piece)}',
      'data-thor-lazy-on': 'click',
      'data-thor-lazy-as': 'into',
      'data-thor-lazy-into': into,
      'data-thor-lazy-open': ?open,
    };
  }
}

/// The `onclick` of a panel that closes with [close] when a link inside
/// is followed in the same tab (not a new tab, a download or a click with a
/// modifier key), so it closes on the tap instead of when the next page
/// arrives. An attribute, not a script: pages still load no JS file, and
/// without JS the panel closes with the navigation, as before.
///
/// `// web:` a strict Content-Security-Policy blocks inline handlers (turn
/// it off with `closeOnNavigate: false`, or allow it with
/// `'unsafe-hashes'` and its hash).
String closeOnNavigateHandler(String close) =>
    'if(!event.defaultPrevented&&!event.metaKey&&!event.ctrlKey'
    '&&!event.shiftKey&&!event.altKey&&event.target.closest('
    "'a[href]:not([target]):not([download])'))$close";

/// Which edge a [Drawer] slides from.
enum DrawerSide {
  /// The start edge (left in left-to-right text).
  start,

  /// The end edge.
  end,
}

/// Flutter's `Drawer`: a side panel over the page, on a native modal
/// `<dialog>` (focus trap, Esc and a click on the backdrop close it; no
/// JS). It slides in on open (`@starting-style`). Open it with a
/// `DialogTrigger(id: id, …)` button and close it with `DialogClose`,
/// or from a state method with a [controller] (`details.open()`).
///
/// With [permanentFrom] it is also Material 3's *standard* drawer: the same
/// subtree is that modal panel below the breakpoint and an inline panel from
/// it up, so a filter list is written once.
///
/// ```dart
/// Row(
///   children: [
///     Drawer(id: 'filters', permanentFrom: WindowSizeClass.medium, child: Filters()),
///     Expanded(
///       child: Column(children: [
///         DialogTrigger(id: 'filters', hiddenFrom: WindowSizeClass.medium,
///             child: TextButton(child: Text('Filters'))),
///         Results(),
///       ]),
///     ),
///   ],
/// )
/// ```
///
/// `// web:` Flutter opens it with `Scaffold.of(context).openDrawer()`;
/// here any button can open it by id, and a state method through its
/// `DialogController`.
class Drawer extends StatelessWidget implements ThorElementWidget, ThorBuiltIn {
  /// Creates a drawer.
  const Drawer({
    super.key,
    this.id,
    required this.child,
    this.side,
    this.width,
    this.backgroundColor,
    this.label,
    this.closeOnNavigate = true,
    this.controller,
    this.padding = const EdgeInsets.all(16),
    this.permanentFrom,
    this.permanentWidth,
    this.permanentPadding,
    this.showClose = false,
    this.closeLabel,
  }) : assert(
         (permanentWidth == null && permanentPadding == null) ||
             permanentFrom != null,
         'permanentWidth / permanentPadding need permanentFrom',
       );

  // web: not in Flutter.
  /// From this breakpoint up the drawer stops being a modal and
  /// is a static panel where it sits in the page (Material 3's standard
  /// drawer; Flutter's version is a `Row` with the panel in it). Put it in
  /// a `Row` before the content; its [width] is then the panel's width and
  /// it is as tall as the row.
  ///
  /// One `<dialog>` in the DOM, no JS: while it is closed, CSS shows it in
  /// the flow from the breakpoint up (the page is complete without
  /// scripting), and below it it is the usual modal (focus trap, Esc,
  /// backdrop, inert page). Inline there is no trap and nothing behind is
  /// inert, as a sidebar should be. Hide the button that opens it with
  /// `DialogTrigger(hiddenFrom:)`. A modal already open when the window
  /// grows stays modal until it is closed (the top layer can't be undone).
  ///
  /// `// web:` an inline panel is a non-modal `dialog` for assistive
  /// technology; give it a [label].
  final WindowSizeClass? permanentFrom;

  /// Width of the inline panel (from [permanentFrom] up) when it differs
  /// from the modal's [width]: a 200 px sidebar that is a 320 px sheet on a
  /// phone. Default: [width].
  final double? permanentWidth;

  /// [padding] of the inline panel when it differs from the modal's.
  /// Default: [padding].
  final EdgeInsetsGeometry? permanentPadding;

  /// `// web:` space inside the panel, around [child] (Flutter's `Drawer`
  /// has none: pass `EdgeInsets.zero` for a child that draws edge to edge).
  final EdgeInsetsGeometry padding;

  /// DOM id (the triggers point at it). Optional: in a `Scaffold`'s
  /// `drawer:` / `endDrawer:` the scaffold names it (its `AppBar` button
  /// opens it); anywhere else it is named by its [controller], its
  /// `ValueKey` or its place in the page (the same on every render).
  final String? id;

  /// Opens and closes it from a `ThorState` method (a field of the state).
  ///
  /// `// web:` no Flutter counterpart (see `DialogController`).
  final DialogController? controller;

  /// Content of the drawer.
  final Widget child;

  /// Whether the drawer brings its own close button in the top corner
  /// (`DialogClose` with a close icon, named by the localized "Close"); it is
  /// not drawn once [permanentFrom] makes the drawer an inline panel.
  ///
  /// `// web:` Flutter's drawers have no built-in close button.
  final bool showClose;

  /// The name of the [showClose] button, for assistive technology and the
  /// tooltip. Null is the localized "Close" of `MaterialLocalizations`; give
  /// it when the page's text is not in the app's locale.
  final String? closeLabel;

  /// The edge it slides from (default: the start; in a `Scaffold`'s
  /// `endDrawer:`, the end).
  final DrawerSide? side;

  /// Width in pixels (default: the theme's, else Flutter's 304).
  final double? width;

  /// Fill (default: the theme's `drawerTheme`, else the surface).
  final Color? backgroundColor;

  /// Accessible name.
  final String? label;

  /// Whether following a link inside closes the drawer on the tap (see
  /// [closeOnNavigateHandler]); otherwise it stays open until the next page
  /// arrives.
  final bool closeOnNavigate;

  @override
  Widget build(BuildContext context) {
    if (permanentFrom != null) {
      ThorStyleRegistry.active(
        context,
      )?.addKeyframes(_permanentName, _permanentFrames);
    }
    lockScrollWhileModal(context);
    final slot = DrawerSlot.maybeOf(context);
    final id = nativeId(
      context,
      prefix: 'drawer',
      id: this.id ?? slot?.id,
      key: key,
      controller: controller,
      owner: this,
    );
    final edge =
        side ?? (slot?.end == true ? DrawerSide.end : DrawerSide.start);
    // The parameter, else `ThemeData.drawerTheme`, else Flutter's default.
    final theme = Theme.of(context).drawerTheme;
    // The content gets a clean slot: a drawer inside it is not the
    // scaffold's.
    return DrawerSlot(
      child: DialogScope(
        id: id,
        child: _element(
          id,
          edge,
          theme,
          scaffoldColumn: slot == null ? null : (slot.end ? 3 : 1),
          scrim: slot?.scrimColor,
        ),
      ),
    );
  }

  Widget _element(
    String id,
    DrawerSide edge,
    DrawerThemeData? theme, {
    int? scaffoldColumn,
    Color? scrim,
  }) {
    final shape = theme?.shape;
    final depth = theme?.elevation;
    final panelWidth = width ?? theme?.width ?? 304;
    final start = edge == DrawerSide.start;
    final hidden = start ? '-100%' : '100%';
    return thorElement(
      'dialog',
      id: id,
      debugName: 'Drawer',
      css: {
        'box-sizing': 'border-box',
        // Logical, not left/right: an RTL page slides the start drawer
        // from the right, as Flutter's does.
        'margin-inline': start ? '0 auto' : 'auto 0',
        'width': 'min(${cssPx(panelWidth)}, 85vw)',
        'max-width': '100%',
        'height': '100dvh',
        'max-height': '100dvh',
        ...padding.toCss('padding'),
        'border': switch (shape?.side) {
          final side? when side != BorderSide.none => side.css,
          _ => '0',
        },
        // A panel taller than the window (an open section in a long list)
        // scrolls in the panel, not in the page behind it.
        'overflow-y': 'auto',
        ...modalOverscroll,
        if (shape != null)
          'border-radius': shape.radiusCss
        else if (start) ...{
          'border-start-end-radius': '16px',
          'border-end-end-radius': '16px',
        } else ...{
          'border-start-start-radius': '16px',
          'border-end-start-radius': '16px',
        },
        'background-color':
            (backgroundColor ?? theme?.backgroundColor)?.css ??
            ThemeTokens.surfaceContainerLow,
        'color': 'inherit',
        if (depth != null && depth > 0)
          'box-shadow':
              '0 ${cssPx(depth / 2)} ${cssPx(depth * 1.5)} rgba(0, 0, 0, 0.2)',
        'translate': '$hidden 0',
        'transition-property': 'translate, display, overlay',
        'transition-duration': '250ms',
        'transition-timing-function': 'cubic-bezier(0.2, 0, 0, 1)',
        'transition-behavior': 'allow-discrete',
      },
      conditions: [
        const ConditionalCss(CssCondition.selector('[open]'), {
          'display': 'flex',
          'flex-direction': 'column',
          'translate': '0 0',
        }),
        ConditionalCss(const CssCondition.startingStyle('[open]'), {
          'translate': '$hidden 0',
        }),
        // `translate` has no logical form: RTL waits on the other side.
        ConditionalCss(const CssCondition.selector(':not([open]):dir(rtl)'), {
          'translate': '${start ? '100%' : '-100%'} 0',
        }),
        ConditionalCss(const CssCondition.startingStyle('[open]:dir(rtl)'), {
          'translate': '${start ? '100%' : '-100%'} 0',
        }),
        ...fadingBackdrop('250ms', color: scrim ?? theme?.scrimColor),
        const ConditionalCss(CssCondition.reducedMotion, {
          'transition-duration': '1ms',
        }),
        if (permanentFrom case final bp?)
          ..._permanent(
            bp,
            start,
            scaffoldColumn,
            width: permanentWidth,
            padding: permanentPadding,
          ),
      ],
      attributes: {
        'closedby': 'any',
        'aria-label': ?label,
        if (closeOnNavigate) 'onclick': closeOnNavigateHandler('this.close()'),
        // The animation of `_permanent` starts when an open modal meets the
        // breakpoint: closing it leaves the inline panel (see there).
        if (permanentFrom != null) ...{
          'onanimationstart': 'if(event.target===this)this.close()',
          // Firefox and WebKit make a displayed `dialog` a Tab stop of its
          // own; the inline panel is a box that holds the stops, not one.
          'tabindex': '-1',
        },
        dialogControllerAttr: ?controllerIdOf(controller),
      },
      childRules: ChildRules.column,
      // Like Flutter's, the child gets the panel's full height.
      children: [
        if (showClose)
          DialogCloseCorner(hiddenFrom: permanentFrom, label: closeLabel),
        Expanded(child: child),
      ],
    );
  }
}

const _permanentName = 't-drawer-permanent';

// Nothing visible: it only has to start, once, for `onanimationstart`.
const _permanentFrames =
    'from{--t-drawer-permanent:0}to{--t-drawer-permanent:1}';

/// The rules that make a closed drawer an inline panel from [bp] up. They
/// name `:not([open])`, so a modal that is open keeps the modal look (the top
/// layer cannot be undone); instead an open one, at the breakpoint or when the
/// window grows to it, starts a 1 ms animation whose `animationstart` handler
/// closes it, and a closed drawer is the inline panel: no listener, no
/// script, and the same on every engine. The `flex` of the child is `auto`
/// so a panel taller than the page makes the row taller (the child's
/// `Expanded` basis of 0 would let its content spill out of the box); the
/// last rule undoes the right-to-left waiting place (as specific as that
/// rule, and later).
List<ConditionalCss> _permanent(
  WindowSizeClass bp,
  bool start,
  int? scaffoldColumn, {
  double? width,
  EdgeInsetsGeometry? padding,
}) => [
  ConditionalCss(
    CssCondition.both(
      CssCondition.breakpoint(bp),
      const CssCondition.selector(':not([open])'),
    ),
    {
      'display': 'flex',
      'flex-direction': 'column',
      'position': 'static',
      // In a `Scaffold`: its side column, in the body's row.
      if (scaffoldColumn != null) ...{
        'grid-column': '$scaffoldColumn',
        'grid-row': '2',
      },
      'flex': '0 0 auto',
      if (width != null) 'width': cssPx(width),
      if (padding != null) ...padding.toCss('padding'),
      'align-self': 'stretch',
      'translate': 'none',
      'margin': '0',
      'height': 'auto',
      'max-height': 'none',
      'max-width': 'none',
      // The inline panel is as tall as the page: it never scrolls itself, so
      // a sticky box inside it sticks to the page's scroll (the modal panel
      // keeps `overflow-y: auto`).
      'overflow': 'visible',
      'border-radius': '0',
      'transition': 'none',
    },
  ),
  ConditionalCss(
    CssCondition.both(
      CssCondition.breakpoint(bp),
      const CssCondition.selector(':not([open]) > *'),
    ),
    const {'flex': '1 1 auto'},
  ),
  ConditionalCss(
    CssCondition.both(
      CssCondition.breakpoint(bp),
      const CssCondition.selector(':not([open]):dir(rtl)'),
    ),
    const {'translate': 'none'},
  ),
  ConditionalCss(
    CssCondition.both(
      CssCondition.breakpoint(bp),
      const CssCondition.selector('[open]'),
    ),
    const {'animation': '$_permanentName 1ms'},
  ),
];

/// Flutter's `DrawerHeader`: the block at the top of a [Drawer], 160 px
/// tall, with [child] at the bottom start and a divider underneath.
///
/// ```dart
/// Drawer(child: ListView(padding: EdgeInsets.zero, children: [
///   DrawerHeader(
///     decoration: BoxDecoration(color: primary),
///     child: Text('Menu'),
///   ),
///   ListTile(title: Text('Settings'), onTap: settings.open),
/// ]))
/// ```
///
/// `// web:` [duration] and [curve] are accepted and ignored: Flutter
/// animates a change of [decoration] and the browser swaps it at once (a
/// state that changes it would need a CSS transition, which the server does
/// not generate). There is no status bar inset (the `<dialog>` is the
/// viewport); the [Drawer]'s own `padding` (16 by default, unlike Flutter's)
/// still surrounds the header: pass `padding: EdgeInsets.zero` to the
/// drawer for an edge-to-edge one. The divider is 1 px of the theme's
/// outline-variant, or the bottom side of a [decoration] with a border.
class DrawerHeader extends StatelessWidget
    implements ThorElementWidget, ThorBuiltIn {
  /// Creates a drawer header.
  const DrawerHeader({
    super.key,
    this.decoration,
    this.margin = const EdgeInsets.only(bottom: 8),
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 8),
    this.duration = const Duration(milliseconds: 250),
    this.curve = Curves.fastOutSlowIn,
    required this.child,
  });

  /// Drawn behind [child] (Flutter's default: none).
  final BoxDecoration? decoration;

  /// Space around the header (Flutter's default: 8 at the bottom).
  final EdgeInsetsGeometry margin;

  /// Space between the header's edge and [child] (Flutter's default:
  /// 16 16 8 16).
  final EdgeInsetsGeometry padding;

  /// Ignored (`// web:` see the class).
  final Duration duration;

  /// Ignored (`// web:` see the class).
  final Curve curve;

  /// The content, at the bottom start corner (Flutter: `Align(bottomStart)`).
  final Widget? child;

  @override
  Widget build(BuildContext context) => thorElement(
    'div',
    debugName: 'DrawerHeader',
    css: {
      'display': 'flex',
      'flex-direction': 'column',
      // Bottom start, like `Align(alignment: bottomStart)`: logical, so RTL
      // mirrors it.
      'justify-content': 'flex-end',
      'align-items': 'flex-start',
      'box-sizing': 'border-box',
      'flex': '0 0 auto',
      'height': '160px',
      ...margin.toCss('margin'),
      ...padding.toCss('padding'),
      'border-bottom': '1px solid ${ThemeTokens.outlineVariant}',
      ...?decoration?.toCss(),
      'font-size': ThemeTokens.bodyLargeSize,
      'letter-spacing': ThemeTokens.bodyLargeTracking,
      'line-height': ThemeTokens.bodyLargeLine,
    },
    childRules: ChildRules.column,
    children: [?child],
  );
}

/// A button that opens arbitrary content anchored under it (Flutter's
/// `PopupMenuButton` / `MenuAnchor` with any widgets), on the Popover API:
/// light dismiss and Esc are native, CSS anchor positioning places the panel
/// (with fallbacks when it doesn't fit). Following a link inside closes it
/// on the tap ([closeOnNavigate]).
///
/// ```dart
/// Popover(
///   id: 'filters',
///   trigger: const Text('Filter'),
///   style: const ButtonStyle(padding: WidgetStatePropertyAll(EdgeInsets.all(8))),
///   decoration: BoxDecoration(color: surface, borderRadius: radius8),
///   menuPadding: const EdgeInsets.all(12),
///   constraints: const BoxConstraints(minWidth: 260),
///   child: filterPanel,
/// )
/// ```
class Popover extends StatelessWidget
    implements ThorElementWidget, ThorBuiltIn, MultipleRoots {
  /// Creates a popover.
  const Popover({
    super.key,
    this.id,
    required this.trigger,
    required this.child,
    this.width,
    this.label,
    this.style,
    this.decoration,
    this.menuPadding,
    this.constraints,
    this.closeOnNavigate = true,
  });

  /// DOM id of the panel; optional: without one it is named by its
  /// `ValueKey` or its place in the page (the same on every render).
  final String? id;

  /// Content of the button that opens it.
  final Widget trigger;

  /// Content of the panel.
  final Widget child;

  /// Panel width in pixels (default: its content).
  final double? width;

  /// Accessible name of the button, when [trigger] has no text.
  final String? label;

  /// The look of the button that opens the panel (`PopupMenuButton`'s
  /// `style`): padding, minimum size, shape, text, colors and hover fill.
  final ButtonStyle? style;

  /// The panel's fill, border, corners and shadow.
  ///
  /// `// web:` Flutter's menus spell these as `color`, `shape`, `elevation`
  /// and `shadowColor`; one `BoxDecoration` carries them all, with the exact
  /// shadow a design asks for instead of Material's elevation steps.
  final BoxDecoration? decoration;

  /// Space inside the panel, around [child] (`PopupMenuButton`'s
  /// `menuPadding`; default none).
  final EdgeInsetsGeometry? menuPadding;

  /// The panel's size limits (`PopupMenuButton`'s `constraints`). A max
  /// width never goes past the viewport minus 16px, so a phone keeps a
  /// gutter.
  final BoxConstraints? constraints;

  /// Whether following a link inside closes the panel on the tap (see
  /// [closeOnNavigateHandler]).
  final bool closeOnNavigate;

  static const _viewportWidth = 'calc(100vw - 16px)';

  @override
  Widget build(BuildContext context) {
    final id = nativeId(context, prefix: 'pop', id: this.id, key: key);
    final anchor = '--$id';
    final s = style;
    final limits = {...?constraints?.toCss()};
    if (limits['max-width'] case final max? when !isAdaptive(max)) {
      limits['max-width'] = 'min($max, $_viewportWidth)';
    }
    return Widget.fragment([
      thorElement(
        'button',
        debugName: 'Popover',
        css: {
          'appearance': 'none',
          'border': '0',
          'margin': '0',
          'font': 'inherit',
          'background': 'none',
          'color': 'inherit',
          'cursor': 'pointer',
          'display': 'inline-flex',
          'align-items': 'center',
          'gap': '4px',
          'anchor-name': anchor,
          if (s != null) ...buttonStyleCss(s),
        },
        conditions: [
          if (s?.overlayAt(WidgetState.hovered) case final hover?)
            ConditionalCss(CssCondition.hoverEnabled, {
              'background-color': hover.css,
            }),
        ],
        attributes: {
          'type': 'button',
          'popovertarget': id,
          // The panel is free content, not a menu (`true` means `menu`).
          'aria-haspopup': 'dialog',
          'aria-label': ?label,
        },
        children: [trigger],
      ),
      thorElement(
        'div',
        id: id,
        debugName: 'PopoverPanel',
        css: {
          'position-anchor': anchor,
          'inset': 'auto',
          'position-area': 'block-end',
          'position-try-fallbacks': 'flip-block, flip-inline',
          'margin': '8px 0',
          ...(menuPadding?.toCss('padding') ?? const {'padding': '0'}),
          'border': '0',
          // The theme's surface and text, not the browser's for popovers
          // (`Canvas`/`CanvasText`, `#121212` in a dark scheme), like a
          // Flutter menu; a `decoration` color replaces the surface.
          'background-color': 'var(--t-surface-container, Canvas)',
          'color': 'var(--t-on-surface, inherit)',
          'color-scheme': 'inherit',
          'width': ?(width == null ? null : cssPx(width!)),
          'max-width': _viewportWidth,
          'box-sizing': 'border-box',
          ...?decoration?.toCss(),
          ...limits,
        },
        attributes: {
          'popover': 'auto',
          if (closeOnNavigate)
            'onclick': closeOnNavigateHandler('this.hidePopover()'),
        },
        childRules: ChildRules.box,
        children: [child],
      ),
    ]);
  }
}
