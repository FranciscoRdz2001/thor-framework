import 'package:thor_style/thor_style.dart';

import '../core/core.dart';
import '../foundation/child_rules.dart';
import '../foundation/dialog_scope.dart';
import '../foundation/element.dart';
import '../foundation/layout_hint.dart';
import '../foundation/material_localizations.dart' show ThorLocalizations;
import '../foundation/native_id.dart';
import '../foundation/parent_data.dart';
import '../foundation/style_registry.dart' show ConditionalCss, CssCondition;
import '../foundation/stylesheet.dart' show WindowSizeClass;
import '../foundation/theme_tokens.dart';
import '../foundation/transparent.dart';
import 'app_bar.dart' show AppBar;
import 'basic.dart' show Padding, boxCss, padInto;
import 'flex.dart' show Flex;
import 'navigation.dart' show Drawer;
import 'navigation_bar.dart' show NavigationBar;
import 'scroll.dart'
    show CustomScrollView, GridView, ListView, SingleChildScrollView;
import 'stack.dart' show Stack;
import 'text.dart' show Text;
import 'theme.dart' show Theme;

// Also what an app component builds.
bool _fillsMain(Widget? body) => switch (resolveComponent(body)) {
  Stack() ||
  Flex() ||
  SingleChildScrollView() ||
  ListView() ||
  CustomScrollView() ||
  GridView() => true,
  _ => false,
};

/// The id of the drawer of a scaffold slot: the `Drawer`'s own, or the one
/// the page names for it (see [nativeId]).
String _drawerId(BuildContext context, Widget drawer, String slot) {
  final resolved = resolveComponent(drawer);
  if (resolved is! Drawer) {
    throw StateError(
      'Scaffold($slot:) takes a Drawer (or an app widget that builds one): '
      'got ${resolved.runtimeType}. To open another kind of panel, use '
      'DialogTrigger.',
    );
  }
  return nativeId(
    context,
    prefix: 'drawer',
    id: resolved.id,
    key: resolved.key ?? drawer.key,
    controller: resolved.controller,
  );
}

/// The breakpoint from which [drawer] (already checked by [_drawerId]) is
/// an inline panel, if it is.
WindowSizeClass? _permanentFrom(Widget? drawer) =>
    drawer == null ? null : (resolveComponent(drawer) as Drawer).permanentFrom;

/// Tells the [Scaffold]s below that the page already has a skip link (the
/// first Tab stop, to its `<main>`): they do not add theirs. A layout that
/// draws its own (`StudioScaffold`) wraps its page in this.
///
/// `// web:` not in Flutter.
class SkipLinkProvided extends InheritedWidget implements InheritedMemoKey {
  /// Marks [child] as a page that has its own skip link.
  const SkipLinkProvided({super.key, required super.child});

  /// Whether [context] is inside a page that has a skip link.
  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SkipLinkProvided>() != null;

  @override
  bool updateShouldNotify(covariant SkipLinkProvided oldWidget) => false;

  @override
  Object? get memoKey => true;
}

enum _FabX { start, center, end }

enum _FabY { top, float, docked }

/// Flutter's `FloatingActionButtonLocation`: where the `Scaffold` puts its
/// `floatingActionButton`.
///
/// `// web:` Flutter computes the offset in Dart (`getOffset`); here a
/// location is only a place for the browser's CSS (`position: fixed`), so
/// there is no custom location. `top` places the button on the bottom edge of
/// the app bar, taking the app bar to be its toolbar's height; `docked` on
/// the top edge of the `NavigationBar` (without one, it floats).
class FloatingActionButtonLocation {
  const FloatingActionButtonLocation._(this._x, this._y, {bool mini = false})
    : _mini = mini;

  final _FabX _x;
  final _FabY _y;
  final bool _mini;

  /// Start edge, over the bottom bar.
  static const startFloat = FloatingActionButtonLocation._(
    _FabX.start,
    _FabY.float,
  );

  /// Centered, over the bottom bar.
  static const centerFloat = FloatingActionButtonLocation._(
    _FabX.center,
    _FabY.float,
  );

  /// End edge, over the bottom bar (the default).
  static const endFloat = FloatingActionButtonLocation._(
    _FabX.end,
    _FabY.float,
  );

  /// Start edge, on the top edge of the bottom bar.
  static const startDocked = FloatingActionButtonLocation._(
    _FabX.start,
    _FabY.docked,
  );

  /// Centered, on the top edge of the bottom bar.
  static const centerDocked = FloatingActionButtonLocation._(
    _FabX.center,
    _FabY.docked,
  );

  /// End edge, on the top edge of the bottom bar.
  static const endDocked = FloatingActionButtonLocation._(
    _FabX.end,
    _FabY.docked,
  );

  /// Start edge, on the bottom edge of the app bar.
  static const startTop = FloatingActionButtonLocation._(
    _FabX.start,
    _FabY.top,
  );

  /// Centered, on the bottom edge of the app bar.
  static const centerTop = FloatingActionButtonLocation._(
    _FabX.center,
    _FabY.top,
  );

  /// End edge, on the bottom edge of the app bar.
  static const endTop = FloatingActionButtonLocation._(_FabX.end, _FabY.top);

  /// [startFloat] for a mini button.
  static const miniStartFloat = FloatingActionButtonLocation._(
    _FabX.start,
    _FabY.float,
    mini: true,
  );

  /// [centerFloat] for a mini button.
  static const miniCenterFloat = FloatingActionButtonLocation._(
    _FabX.center,
    _FabY.float,
    mini: true,
  );

  /// [endFloat] for a mini button.
  static const miniEndFloat = FloatingActionButtonLocation._(
    _FabX.end,
    _FabY.float,
    mini: true,
  );

  /// [startDocked] for a mini button.
  static const miniStartDocked = FloatingActionButtonLocation._(
    _FabX.start,
    _FabY.docked,
    mini: true,
  );

  /// [centerDocked] for a mini button.
  static const miniCenterDocked = FloatingActionButtonLocation._(
    _FabX.center,
    _FabY.docked,
    mini: true,
  );

  /// [endDocked] for a mini button.
  static const miniEndDocked = FloatingActionButtonLocation._(
    _FabX.end,
    _FabY.docked,
    mini: true,
  );

  /// [startTop] for a mini button.
  static const miniStartTop = FloatingActionButtonLocation._(
    _FabX.start,
    _FabY.top,
    mini: true,
  );

  /// [centerTop] for a mini button.
  static const miniCenterTop = FloatingActionButtonLocation._(
    _FabX.center,
    _FabY.top,
    mini: true,
  );

  /// [endTop] for a mini button.
  static const miniEndTop = FloatingActionButtonLocation._(
    _FabX.end,
    _FabY.top,
    mini: true,
  );
}

/// Flutter's `Scaffold`, as a semantic page grid:
/// `header` (appBar) / `main` (body) / `footer` (bottomNavigationBar),
/// at least one viewport tall (`100dvh`, correct on mobile browsers).
///
/// A [drawer] (or [endDrawer]) is a native modal `<dialog>` the [AppBar]
/// opens with a menu button it adds by itself (see `DrawerButton`); no JS.
/// A `Drawer(permanentFrom:)` there is the same panel from that breakpoint
/// up, beside the body under the bars (the menu button goes away).
///
/// It starts with a skip link (the first Tab stop: "Skip to content", shown
/// only while it has the focus) to its `<main>`; [skipLink] turns it off.
///
/// ```dart
/// Scaffold(
///   appBar: AppBar(title: const Text('Sales')),
///   body: ListView(children: rows),
///   floatingActionButton: FloatingActionButton(onPressed: add, child: Icon(plus)),
///   floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
///   bottomNavigationBar: NavigationBar(destinations: tabs),
/// )
/// ```
///
/// With a `CustomScrollView` as the [body] the body scrolls inside the
/// scaffold (the bars stay where they are), as in Flutter: the scaffold is
/// then exactly one viewport tall.
class Scaffold extends StatelessWidget
    implements ThorElementWidget, ThorBuiltIn {
  /// Creates a page scaffold.
  const Scaffold({
    super.key,
    this.appBar,
    this.body,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.persistentFooterButtons,
    this.drawer,
    this.endDrawer,
    this.bottomNavigationBar,
    this.bottomSheet,
    this.backgroundColor,
    this.resizeToAvoidBottomInset,
    this.primary = true,
    this.extendBody = false,
    this.extendBodyBehindAppBar = false,
    this.drawerScrimColor,
    this.skipLink = true,
    this.skipLinkLabel,
  });

  /// Rendered as the `header` landmark, if given. An [AppBar] is that
  /// header itself (no wrapper) and sticks to the top.
  final Widget? appBar;

  /// Rendered as the `main` landmark; null leaves it empty.
  final Widget? body;

  /// A [Drawer] that slides in from the start edge. Its id is chosen by the
  /// scaffold (or is the `Drawer`'s own `id`), and the [appBar] shows the
  /// button that opens it (`AppBar.automaticallyImplyLeading`).
  ///
  /// `// web:` Flutter opens it with `Scaffold.of(context).openDrawer()`;
  /// here it is a native `<dialog>` and the button a native invoker, so it
  /// works without JS (Esc and a click outside close it, the focus returns
  /// to the button). It must be a `Drawer`.
  ///
  /// With `Drawer(permanentFrom: WindowSizeClass.medium)` it is a panel in the page
  /// from that breakpoint up (Material 3's standard drawer): the first column
  /// of the scaffold, as tall as the body, under the bars, and the [appBar]
  /// no longer shows its button.
  final Widget? drawer;

  /// A [Drawer] that slides in from the end edge (the [appBar] gets an
  /// `EndDrawerButton` unless it has `actions`).
  final Widget? endDrawer;

  /// Rendered as the `footer` landmark, if given. A [NavigationBar] is
  /// its own `nav` landmark instead (no footer) and sticks to the bottom.
  final Widget? bottomNavigationBar;

  /// Fixed to a corner of the page, if given: the bottom end by default (see
  /// [floatingActionButtonLocation]).
  final Widget? floatingActionButton;

  /// Where the [floatingActionButton] sits (default:
  /// [FloatingActionButtonLocation.endFloat]). A button over a
  /// [NavigationBar] rises above it.
  final FloatingActionButtonLocation? floatingActionButtonLocation;

  /// Buttons in a bar at the bottom, over the [body] and under the
  /// [bottomSheet]: they stay in view while the page scrolls, aligned to the
  /// end (Flutter's default).
  final List<Widget>? persistentFooterButtons;

  /// A panel stuck to the bottom edge, over the [body] (and over the
  /// [bottomNavigationBar] and [persistentFooterButtons]), like Flutter's
  /// persistent bottom sheet.
  ///
  /// `// web:` Flutter's `showBottomSheet` opens one from code; here it is
  /// always present, so to open and close one use `ModalBottomSheet`.
  final Widget? bottomSheet;

  /// Same as Flutter's `Scaffold.backgroundColor`; null uses the theme's
  /// `scaffoldBackgroundColor`, or `colorScheme.surface` without one.
  final Color? backgroundColor;

  /// Accepted so Flutter code compiles; changes nothing.
  // web: the browser decides what the on-screen keyboard does to the layout
  // (the `interactive-widget` key of the viewport meta); the page always
  // avoids it.
  final bool? resizeToAvoidBottomInset;

  /// Whether the [appBar] clears the device's top inset (the notch); `false`
  /// turns that off for the bar inside (see [AppBar.primary]).
  final bool primary;

  /// Whether the [body] goes on under the [bottomNavigationBar] (and
  /// [persistentFooterButtons]), which stay on top of it, instead of ending
  /// where they begin.
  ///
  /// `// web:` Flutter also gives the body the bar's height as padding; here
  /// the body scrolls under the bar and it is the content that clears it.
  final bool extendBody;

  /// Whether the [body] goes on under the [appBar], which stays on top of it
  /// (give the bar a translucent or transparent `backgroundColor`).
  final bool extendBodyBehindAppBar;

  /// The color the page takes behind an open [drawer] or [endDrawer]
  /// (default: black at 32 %).
  final Color? drawerScrimColor;

  // web: not in Flutter.
  /// Whether the scaffold starts with a skip link (WCAG 2.4.1): the first
  /// Tab stop, hidden until it has the focus, that jumps to the `<main>`.
  /// Not added when the page already has one ([SkipLinkProvided]) or inside
  /// another `Scaffold`.
  final bool skipLink;

  // web: not in Flutter.
  /// The skip link's text (default: the locale's `ThorLocalizations.skipToContent`).
  final String? skipLinkLabel;

  @override
  Widget build(BuildContext context) {
    final drawerId = drawer == null
        ? null
        : _drawerId(context, drawer!, 'drawer');
    final endDrawerId = endDrawer == null
        ? null
        : _drawerId(context, endDrawer!, 'endDrawer');
    final start = _permanentFrom(drawer);
    final end = _permanentFrom(endDrawer);
    final scrolls = resolveComponent(body) is CustomScrollView;
    // Nested in another scaffold or in a page with its own link: no second one.
    final skip =
        skipLink &&
        !SkipLinkProvided.of(context) &&
        ScaffoldScope.maybeOf(context) == null;
    final mainId = skip
        ? nativeId(context, prefix: 'main', id: 'main-content')
        : null;
    return ScaffoldScope(
      drawerId: drawerId,
      endDrawerId: endDrawerId,
      drawerPermanentFrom: start,
      endDrawerPermanentFrom: end,
      scrollBody: scrolls,
      primary: primary,
      child: SkipLinkProvided(
        child: _element(
          context,
          drawerId,
          endDrawerId,
          inline: start != null || end != null,
          scrolls: scrolls,
          mainId: mainId,
        ),
      ),
    );
  }

  // The height of the bottom bar that sticks to the page's bottom (a
  // `NavigationBar`); any other widget's is not known.
  double get _navHeight {
    final bar = resolveComponent(bottomNavigationBar);
    return bar is NavigationBar ? (bar.height ?? 80) : 0;
  }

  // [px] above the bottom of the viewport, over the navigation bar: its
  // height plus the inset it pads itself with (`viewport-fit=cover`).
  String _aboveNav(double px) => _navHeight > 0
      ? 'calc(${cssPx(_navHeight + px)} + env(safe-area-inset-bottom, 0px))'
      : cssPx(px);

  // How far up a snack bar inside the scaffold sits: the navigation bar's
  // height plus the button's box (56 px and its 16 px margin).
  double get _snackOffset =>
      _navHeight + (floatingActionButton != null ? 72 : 0);

  // The floating action button's wrapper declarations for its location.
  CssDeclarations _fabCss() {
    final where =
        floatingActionButtonLocation ?? FloatingActionButtonLocation.endFloat;
    final half = where._mini ? 20.0 : 28.0;
    final nav = _navHeight;
    final bar = resolveComponent(appBar);
    final barHeight = bar is AppBar ? (bar.toolbarHeight ?? 64) : 0.0;
    return {
      'position': 'fixed',
      'z-index': '10',
      ...switch (where._x) {
        _FabX.start => {
          'inset-inline-start': 'max(16px, env(safe-area-inset-left))',
        },
        _FabX.end => {
          'inset-inline-end': 'max(16px, env(safe-area-inset-right))',
        },
        _FabX.center => {'left': '50%'},
      },
      if (where._x == _FabX.center) 'translate': '-50% 0',
      ...switch (where._y) {
        _FabY.top => {
          'top': barHeight > 0
              ? 'calc(env(safe-area-inset-top, 0px) + ${cssPx(barHeight - half)})'
              : '16px',
        },
        // Docked on a bar: centered on its top edge. Without one it floats.
        _FabY.docked when nav > 0 => {'bottom': _aboveNav(-half)},
        _ => {
          'bottom': nav > 0
              ? _aboveNav(16)
              : 'max(16px, env(safe-area-inset-bottom))',
        },
      },
    };
  }

  // [inline]: a drawer is a panel in the page from some breakpoint, so the
  // grid has a column for each side (an empty one is 0 wide: the closed
  // drawer is `display: none` below the breakpoint) and the bars span them.
  Widget _element(
    BuildContext context,
    String? drawerId,
    String? endDrawerId, {
    required bool inline,
    required bool scrolls,
    required String? mainId,
  }) {
    final across = inline
        ? const {'grid-column': '1 / -1'}
        : const <String, String>{};
    final footerButtons = persistentFooterButtons;
    final hasFooterButtons = footerButtons != null && footerButtons.isNotEmpty;
    // Rows: bar, body, [footer buttons], [bottom sheet], bottom bar. The
    // bottom bar's is always there (empty, it is 0 high).
    var nextRow = 3;
    final footerRow = hasFooterButtons ? nextRow++ : 0;
    final sheetRow = bottomSheet != null ? nextRow++ : 0;
    final navRow = nextRow;
    final bodyFrom = extendBodyBehindAppBar ? 1 : 2;
    final bodyTo = extendBody ? -1 : 3;
    final bodyRow = bodyFrom == 2 && bodyTo == 3 ? '2' : '$bodyFrom / $bodyTo';
    final l10n = skipLinkLabel ?? ThorLocalizations.of(context).skipToContent;
    return thorElement(
      'div',
      debugName: 'Scaffold',
      css: {
        'display': 'grid',
        if (inline) 'grid-template-columns': 'auto minmax(0, 1fr) auto',
        'grid-template-rows': 'auto minmax(0, 1fr)${' auto' * (navRow - 2)}',
        // A body that scrolls by itself needs a box to scroll in.
        if (scrolls) 'height': '100dvh',
        'min-height': '100dvh',
        'background-color':
            backgroundColor?.css ??
            (Theme.of(context).scaffoldBackgroundColor != null
                ? 'var(--t-scaffold, ${ThemeTokens.surface})'
                : ThemeTokens.surface),
        'color': ThemeTokens.onSurface,
        // The body's scroll, for the app bar's scrolled-under shadow.
        if (scrolls) 'timeline-scope': '--t-body-scroll',
        // web: a `SnackBar` inside the scaffold sits above these (Flutter
        // moves it for the button and the bar).
        if (_snackOffset case final offset when offset > 0)
          '--t-snack-offset': _navHeight > 0
              ? _aboveNav(offset - _navHeight)
              : cssPx(offset),
      },
      children: [
        if (mainId != null) _SkipLink(label: l10n, target: mainId),
        // Landmarks only when they have content: empty banner/contentinfo
        // regions are noise for screen-reader navigation.
        // An AppBar is already a <header>: it becomes the banner itself and,
        // like Flutter's app bar over a scrolling body, stays on top.
        if (resolveComponent(appBar) is AppBar)
          WrapWith(
            WrapData(
              css: {
                'grid-row': '1',
                ...across,
                'position': 'sticky',
                'top': '0',
                'z-index': '5',
              },
            ),
            child: appBar!,
          )
        else if (appBar != null)
          thorElement(
            'header',
            css: {'grid-row': '1', ...across},
            children: [appBar!],
          ),
        // A layout body (Stack, Flex, scroll view…) fills the grid row by
        // itself: it becomes the <main> landmark instead of being wrapped.
        if (_fillsMain(body))
          WrapWith(
            WrapData(
              tag: 'main',
              css: {
                'grid-row': bodyRow,
                if (inline) 'grid-column': '2',
                'min-width': '0',
                'min-height': '0',
                if (scrolls) 'scroll-timeline': '--t-body-scroll block',
              },
              attributes: {'id': ?mainId},
            ),
            child: body!,
          )
        else
          thorElement(
            'main',
            id: mainId,
            // Like Flutter, the body gets the full remaining height.
            css: {
              ...boxCss,
              'grid-row': bodyRow,
              if (inline) 'grid-column': '2',
            },
            childRules: ChildRules.box,
            children: [?body],
          ),
        if (hasFooterButtons)
          thorElement(
            'div',
            debugName: 'PersistentFooterButtons',
            css: {
              'grid-row': '$footerRow',
              ...across,
              'position': 'sticky',
              'bottom': _aboveNav(0),
              'z-index': '5',
              'display': 'flex',
              'align-items': 'center',
              'justify-content': 'flex-end',
              'gap': '8px',
              'box-sizing': 'border-box',
              'min-height': '56px',
              'padding': '8px',
              'background-color': ThemeTokens.surface,
              'border-top': '1px solid var(--t-outline-variant, #cac4d0)',
            },
            childRules: ChildRules.row,
            children: footerButtons,
          ),
        if (bottomSheet != null)
          thorElement(
            'div',
            debugName: 'BottomSheet',
            css: {
              'grid-row': '$sheetRow',
              ...across,
              'position': 'sticky',
              'bottom': _aboveNav(hasFooterButtons ? 56 : 0),
              'z-index': '6',
              'min-width': '0',
            },
            childRules: ChildRules.box,
            children: [bottomSheet!],
          ),
        // A NavigationBar is already a <nav> landmark: no footer around it; it
        // stays at the bottom of the viewport like Flutter's.
        if (resolveComponent(bottomNavigationBar) is NavigationBar)
          WrapWith(
            WrapData(
              css: {
                'grid-row': '$navRow',
                ...across,
                'position': 'sticky',
                'bottom': '0',
                'z-index': '5',
              },
            ),
            child: bottomNavigationBar!,
          )
        else if (bottomNavigationBar != null)
          thorElement(
            'footer',
            css: {'grid-row': '$navRow', ...across},
            children: [bottomNavigationBar!],
          ),
        // web: `position: fixed` is measured against the nearest ancestor with
        // `container-type`, `transform` or `contain`; a Scaffold is the page's
        // frame, so that is its own box and not a surprise. A popover would
        // need a script for a button that must work with none (rule 3), and
        // would leave the Scaffold's stacking (drawers, the bottom bar).
        if (floatingActionButton != null)
          thorElement('div', css: _fabCss(), children: [floatingActionButton!]),
        // Top-layer dialogs: where they sit in the DOM does not matter.
        if (drawer != null)
          DrawerSlot(
            id: drawerId,
            scrimColor: drawerScrimColor,
            child: drawer!,
          ),
        if (endDrawer != null)
          DrawerSlot(
            id: endDrawerId,
            end: true,
            scrimColor: drawerScrimColor,
            child: endDrawer!,
          ),
      ],
    );
  }
}

/// The scaffold's skip link: off screen until the keyboard reaches it (the
/// page's first stop), then over the app bar.
class _SkipLink extends StatelessWidget
    implements ThorElementWidget, ThorBuiltIn {
  const _SkipLink({required this.label, required this.target});

  final String label;
  final String target;

  @override
  Widget build(BuildContext context) => thorElement(
    'a',
    debugName: 'SkipLink',
    css: const {
      'position': 'absolute',
      'inset-block-start': '-100px',
      'inset-inline-start': '8px',
      'z-index': '100',
      'padding': '12px 20px',
      'border-radius': '20px',
      'background-color': 'var(--t-primary, #6750a4)',
      'color': 'var(--t-on-primary, #ffffff)',
      'font-size': 'var(--t-label-large-size, 14px)',
      'font-weight': 'var(--t-label-large-weight, 500)',
      'text-decoration': 'none',
    },
    conditions: const [
      ConditionalCss(CssCondition.focused, {
        'inset-block-start': '8px',
        'outline': '2px solid var(--t-on-primary, #ffffff)',
        'outline-offset': '-4px',
      }),
    ],
    attributes: {'href': '#$target'},
    children: [Text(label)],
  );
}

/// Flutter's `SafeArea` → `env(safe-area-inset-*)` (notches, home indicator).
/// Requires `<meta name="viewport" content="…, viewport-fit=cover">`.
class SafeArea extends StatelessWidget
    implements ThorElementWidget, ThorBuiltIn {
  /// Pads [child] away from unsafe screen areas on the given sides.
  const SafeArea({
    super.key,
    this.left = true,
    this.top = true,
    this.right = true,
    this.bottom = true,
    this.minimum = EdgeInsets.zero,
    required this.child,
  });

  /// Whether to avoid the left inset.
  final bool left;

  /// Whether to avoid the top inset.
  final bool top;

  /// Whether to avoid the right inset.
  final bool right;

  /// Whether to avoid the bottom inset.
  final bool bottom;

  /// The least padding on each side, whatever the device's inset is: a side
  /// takes the larger of the two (`max(env(...), minimum)`), and one that is
  /// not avoided still takes its minimum.
  final EdgeInsets minimum;

  /// The padded subtree.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // SafeArea(Padding(x)) → one element: `calc(env(inset) + x)` per side.
    final c = resolveComponent(child)!; // through app components
    final inner = c is Padding ? c.padding : EdgeInsets.zero;
    // The padding's own CSS per side, so a `Length` inset (a variable, a
    // percentage) adds to the safe area as well as a number does.
    String side(bool on, String inset, String least, String extra) {
      final zero = extra == '0' || extra == '0px';
      final none = least == '0' || least == '0px';
      // The device's inset (or nothing, on a side that is not avoided), at
      // least [least].
      final safe = on
          ? (none ? 'env($inset)' : 'max(env($inset), $least)')
          : (none ? null : least);
      if (safe == null) return extra;
      if (extra == '0' || (!on && zero)) return safe;
      return 'calc($safe + $extra)';
    }

    return padInto(
      side(top, 'safe-area-inset-top', minimum.cssTop, inner.cssTop),
      side(right, 'safe-area-inset-right', minimum.cssRight, inner.cssRight),
      side(
        bottom,
        'safe-area-inset-bottom',
        minimum.cssBottom,
        inner.cssBottom,
      ),
      side(left, 'safe-area-inset-left', minimum.cssLeft, inner.cssLeft),
      c is Padding ? c.child : child,
      fillsWidth: layoutFillsWidth(c),
    );
  }
}
