import 'dart:convert' show jsonEncode;
import 'dart:math' as math;

import 'package:thor_engine/thor_engine.dart'
    show
        ScrollController,
        carouselAttr,
        carouselControlsAttr,
        carouselDotsAttr,
        carouselNextAttr,
        carouselPrevAttr,
        carouselDotOfAttr,
        carouselDotTemplateAttr,
        horizontalScrollAttr,
        listTemplateAttr,
        scrollControllerAttr;
import 'package:thor_style/thor_style.dart';

import '../core/core.dart';
import '../core/framework.dart' show isElementWith;
import '../core/markup.dart' show scrollFocusAttr;
import '../foundation/child_rules.dart';
import '../foundation/element.dart';
import '../foundation/errors.dart' show numericHorizontal;
import '../foundation/layout_hint.dart';
import '../foundation/lazy_layout.dart';
import '../foundation/material_localizations.dart' show ThorLocalizations;
import '../foundation/parent_data.dart';
import '../foundation/style_registry.dart';
import '../foundation/stylesheet.dart' show WindowSizeClass;
import '../foundation/theme_tokens.dart';
import '../foundation/transparent.dart';
import '../foundation/widget_state.dart';
import 'basic.dart' show boxCss;
import 'buttons.dart' show ButtonStyle, ButtonStyleResolved;
import 'flex.dart' show Flex, flexCss;
import 'grid.dart' show GridLayout, gridCellCss;
import 'shortcuts.dart' show controllerIdOf;
import 'slivers.dart';

// What a grid that is part of a bigger scroll view keeps of `_scrollCss`.
const _flowCss = <String, String>{'min-width': '0', 'box-sizing': 'border-box'};

const _scrollCss = <String, String>{
  'overflow': 'auto',
  'min-width': '0',
  'min-height': '0',
  'box-sizing': 'border-box',
};

// web: [NeverScrollableScrollPhysics] clips instead of scrolling: with
// `overflow: auto` the wheel and touch would still scroll it while the
// keyboard could not (no tab stop), like PageView's `locked`.
const _lockedCss = <String, String>{
  'overflow': 'hidden',
  'min-width': '0',
  'min-height': '0',
  'box-sizing': 'border-box',
};

Map<String, String> _scrollCssOf(ScrollPhysics? physics) =>
    physics is NeverScrollableScrollPhysics ? _lockedCss : _scrollCss;

/// Flutter's `IndexedWidgetBuilder`: builds the widget at `index`.
typedef IndexedWidgetBuilder = Widget Function(BuildContext context, int index);

/// Flutter's `NullableIndexedWidgetBuilder`: like [IndexedWidgetBuilder], but
/// it may return null to say there are no more items (what ends a
/// [ListView.builder] with no `itemCount`).
typedef NullableIndexedWidgetBuilder =
    Widget? Function(BuildContext context, int index);

// The most items a builder with no `itemCount` may make before the render
// gives up: a server render builds every item, so a builder that never
// returns null would never end.
const _unboundedItemCap = 100000;

/// The page's marks of a scroll view: that a keyboard must reach it when
/// nothing inside does (unless its [physics] never scroll), and, if driven
/// by [controller] (a field of a `ThorState`), its id and that it scrolls
/// sideways.
Map<String, String> _scrollControllerMarks(
  ScrollController? controller,
  Axis direction, {
  ScrollPhysics? physics,
}) {
  final id = controllerIdOf(controller);
  return {
    if (physics is! NeverScrollableScrollPhysics) scrollFocusAttr: '',
    if (id != null) ...{
      scrollControllerAttr: id,
      if (direction == Axis.horizontal) horizontalScrollAttr: '',
    },
  };
}

/// Flutter's `SingleChildScrollView` → native `overflow: auto` (the browser
/// does the scrolling, momentum, scrollbars and a11y).
///
/// Like in Flutter, it needs a bounded extent on its scroll axis: inside a
/// `Column`, wrap it in `Expanded`.
class SingleChildScrollView extends StatelessWidget
    implements LayoutHint, HeightHint, ThorElementWidget, ThorBuiltIn {
  /// Creates a scroll view around [child].
  const SingleChildScrollView({
    super.key,
    this.scrollDirection = Axis.vertical,
    this.padding,
    this.controller,
    this.physics,
    this.restorationId,
    this.child,
  });

  /// The scrolling axis.
  final Axis scrollDirection;

  /// Accepted so Flutter code compiles; changes nothing.
  // web: the browser owns scrolling (and its overscroll behavior).
  final ScrollPhysics? physics;

  /// A `ScrollController` field of a `ThorState`: it follows this view's
  /// offset in the page and moves it (`jumpTo`). `// web:` a vertical view
  /// also scrolls sideways when its child is wider (native `overflow:
  /// auto`); the controller follows the vertical offset.
  final ScrollController? controller;

  Map<String, String> get _controllerAttributes =>
      _scrollControllerMarks(controller, scrollDirection, physics: physics);

  /// Same as Flutter's `SingleChildScrollView.padding`.
  final EdgeInsetsGeometry? padding;

  /// Same as Flutter's `restorationId`: the offset survives going to
  /// another page, so a sidebar that every page repeats stays where the
  /// visitor left it. `// web:` a page is a new document, so a tiny inline
  /// script keeps the offset per tab (`sessionStorage`, under this id) and
  /// restores it before the first paint; then, if the link to the current
  /// page (`aria-current="page"`) is out of sight, it brings it into view
  /// (a first visit, a page reached from the text). Without
  /// JavaScript the view starts at the top, as without it.
  final String? restorationId;

  /// The scrolled content.
  final Widget? child;

  @override
  bool get fillsWidth => true;

  // Like Flutter's viewport, a horizontal one is as tall as its content:
  // only its scroll axis takes the space. In a row it must not stretch to
  // the row's height (a menu that scrolls sideways stays centered).
  @override
  bool get fillsHeight => scrollDirection == Axis.vertical;

  @override
  Widget build(BuildContext context) {
    final c = child;
    final f = resolveComponent(c); // through app components
    // With a restorationId the view keeps its own element: the script that
    // restores it goes inside, after the content.
    if (restorationId != null) return _box();
    // Scrolling a Row/Column along its own axis: the flex element is the
    // scroll container (one node, like a ListView). Only when the flex
    // would not distribute free space (start alignment, max size) and has
    // no breakpoints that could change its direction.
    if (f is Flex &&
        f.direction == scrollDirection &&
        f.mainAxisAlignment == MainAxisAlignment.start &&
        f.mainAxisSize == MainAxisSize.max &&
        f.layout == null) {
      return WrapWith(
        WrapData(
          fillsWidth: true,
          fillsHeight: fillsHeight,
          css: {..._scrollCssOf(physics), ..._axisCss, ..._paddingCss},
          attributes: _controllerAttributes,
        ),
        child: c!,
      );
    }
    return _box();
  }

  CssDeclarations get _axisCss =>
      scrollDirection == Axis.horizontal &&
          physics is! NeverScrollableScrollPhysics
      ? const {'overflow-x': 'auto', 'overflow-y': 'hidden'}
      : const {};

  CssDeclarations get _paddingCss => padding?.toCss('padding') ?? const {};

  Widget _box() => thorElement(
    'div',
    debugName: 'SingleChildScrollView',
    fillsWidth: true,
    fillsHeight: fillsHeight,
    childRules: scrollDirection == Axis.horizontal
        ? _horizontalChild
        : ChildRules.box,
    css: {..._scrollCssOf(physics), ..._axisCss, ..._paddingCss},
    attributes: _controllerAttributes,
    children: [
      ?child,
      if (restorationId case final id?)
        Widget.element(
          tag: 'script',
          // Marks it as the view's own progressive enhancement (a page
          // audit can tell it from app code).
          attributes: const {'data-thor-restore': ''},
          children: [
            RawText(
              scrollRestorationScript(
                id,
                horizontal: scrollDirection == Axis.horizontal,
              ),
            ),
          ],
        ),
    ],
  );

  /// Flutter gives the child of a horizontal scroll view an unbounded
  /// width: it is as wide as its content (a Column as its widest Row, a
  /// Text on one line), never the view's width with the rest overflowing.
  /// Its own width, if it sets one, wins.
  static const _horizontalChild = ChildRules(
    all: {
      'flex': '1 1 auto',
      'min-width': '0',
      'min-height': '0',
      'width': 'max-content',
    },
  );
}

/// The inline script of a scroll view with a `restorationId` ([id]): it
/// runs as the view's last child, restores the saved offset, brings the
/// current page's link into view if it is out of sight, and saves the
/// offset when the page goes.
String scrollRestorationScript(String id, {bool horizontal = false}) {
  // JSON, with `<` escaped: an id can't close the script.
  final key = jsonEncode('thor-scroll:$id').replaceAll('<', r'\u003c');
  final at = horizontal ? 'scrollLeft' : 'scrollTop';
  final side = horizontal ? 'left' : 'top';
  final size = horizontal ? 'clientWidth' : 'clientHeight';
  return '(()=>{var e=document.currentScript.parentElement,k=$key,L=null,'
      'H=history,'
      // Back or forward: this entry's own offset, as the browser does for
      // the window's scroll; anything else: the tab's last one.
      'B=(performance.getEntriesByType("navigation")[0]||{}).type=="back_forward";'
      // sessionStorage can be missing or throw (private or sandboxed).
      'try{var S=sessionStorage,'
      // Never over what the visitor already did (a late first show).
      'R=()=>{if(L!=null)return;var h=H.state,w=B&&h&&typeof h=="object"?h[k]:null;'
      'if(w!=null){e.$at=w;L=w;return}'
      'var v=S.getItem(k);if(v!=null)e.$at=+v;'
      // Then the current page's link must show (a first visit, or a page
      // reached from a link in the text): out of sight, it goes to the
      // middle. Only the view scrolls, never the page. A hidden one (in a
      // closed group, or a copy shown at another size) has no place to go
      // to: the last one shown is the most specific (a page under its
      // section's).
      'var a=[...e.querySelectorAll("[aria-current=page]")]'
      '.filter(x=>x.getClientRects().length).pop();'
      'if(a){var d=a.getBoundingClientRect().$side-e.getBoundingClientRect().$side;'
      'if(d<0||d+a.$size>e.$size)e.$at+=d-e.$size/2}L=e.$at};'
      // A hidden view (a closed drawer, `display: none`) ignores scrolling:
      // restore when it first shows.
      'if(e.$size)R();else{var o=new ResizeObserver(()=>{'
      'if(e.$size){o.disconnect();R()}});o.observe(e)}'
      // The last offset seen: a drawer closes on a link's click, before
      // the page goes, and then reads 0. A click inside is seen before
      // the drawer's own handler closes it.
      'var N=()=>{if(e.$size)L=e.$at};'
      'e.addEventListener("scroll",N,{passive:!0});'
      'e.addEventListener("click",N,!0);'
      'addEventListener("pagehide",()=>{N();if(L==null)return;'
      'try{S.setItem(k,L)}catch(x){}'
      // Kept in this history entry too (merged with the app's own state).
      'var h=H.state;if(h==null||typeof h=="object")'
      'try{H.replaceState(Object.assign({},h,{[k]:L}),"")}catch(x){}});'
      // Back or forward from the page cache: the script doesn't run again.
      'addEventListener("pageshow",v=>{if(v.persisted&&e.$size){L=null;B=!0;R()}})'
      '}catch(x){}})()';
}

/// Flutter's `ListView` (children, `.builder` and `.separated`).
///
/// Renders every item (SSR/SEO friendly). Virtualization is not implemented
/// yet; for very long lists prefer pagination.
class ListView extends StatelessWidget
    implements LayoutHint, HeightHint, ThorElementWidget, ThorBuiltIn {
  /// Creates a list view from an explicit list of [children].
  const ListView({
    this.lazyLayout = false,
    this.itemExtent,
    this.itemExtentEstimate = 300,
    super.key,
    this.scrollDirection = Axis.vertical,
    this.controller,
    this.shrinkWrap = false,
    this.physics,
    this.padding,
    this.spacing = 0,
    List<Widget> this.children = const [],
  }) : itemCount = null,
       itemBuilder = null,
       separatorBuilder = null;

  /// Creates a list view that builds [itemCount] items lazily with
  /// [itemBuilder].
  const ListView.builder({
    this.lazyLayout = false,
    this.itemExtent,
    this.itemExtentEstimate = 300,
    super.key,
    this.scrollDirection = Axis.vertical,
    this.controller,
    this.shrinkWrap = false,
    this.physics,
    this.padding,
    this.spacing = 0,
    this.itemCount,
    required NullableIndexedWidgetBuilder this.itemBuilder,
  }) : children = null,
       separatorBuilder = null;

  /// Same as [ListView.builder], with a [separatorBuilder] between items.
  const ListView.separated({
    this.lazyLayout = false,
    this.itemExtent,
    this.itemExtentEstimate = 300,
    super.key,
    this.scrollDirection = Axis.vertical,
    this.controller,
    this.shrinkWrap = false,
    this.physics,
    this.padding,
    this.itemCount,
    required NullableIndexedWidgetBuilder this.itemBuilder,
    required IndexedWidgetBuilder this.separatorBuilder,
  }) : children = null,
       spacing = 0;

  /// The scrolling axis.
  final Axis scrollDirection;

  /// A `ScrollController` field of a `ThorState`: it follows this list's
  /// offset and moves it (`jumpTo`, `animateTo`). One controller drives one
  /// scroll view, as in Flutter. Its `initialScrollOffset` applies when the
  /// engine takes the page over, unless the view already restored an
  /// offset (`restorationId` wins).
  final ScrollController? controller;

  /// Accepted so Flutter code compiles; changes nothing.
  // web: a list is a block in the page's flow: it is as tall as its items
  // unless a parent gives it a height, which is what `shrinkWrap` asks of a
  // scroll view in Flutter.
  final bool shrinkWrap;

  /// Accepted so Flutter code compiles; changes nothing.
  // web: the browser owns scrolling (and its overscroll behavior).
  final ScrollPhysics? physics;

  /// Same as Flutter's `ListView.padding`.
  final EdgeInsetsGeometry? padding;

  // web: not in Flutter.
  /// Render off-screen items lazily (`content-visibility: auto`),
  /// the counterpart of Flutter building only visible slivers. All items stay
  /// in the DOM (SEO, find in page) but the browser skips their style,
  /// layout and paint until they approach the viewport, which cuts the
  /// relayout work of long lists.
  ///
  /// `// web:` off by default: Chrome leaves the skipped items out of the
  /// accessibility tree until they near the viewport (a 700-row list showed a
  /// screen reader 56 rows, not 700), so a long list that must be read whole
  /// is better off with `itemExtent` and no `lazyLayout`, or paginated.
  final bool lazyLayout;

  /// Estimated item extent (px) used for off-screen items when [lazyLayout];
  /// the browser remembers the real size once an item was rendered.
  final double itemExtentEstimate;

  /// The main-axis extent of every item, like Flutter's `ListView.itemExtent`.
  ///
  /// `// web:` it is the item's `height` (`width` in a horizontal list) and
  /// the size the browser reserves for it while it is off screen, so the
  /// scrollbar is exact before anything is rendered when [lazyLayout] is on.
  final double? itemExtent;

  // web: not in Flutter.
  /// Gap between items.
  final double spacing;

  /// The items, for the default constructor.
  final List<Widget>? children;

  /// Number of items, for [ListView.builder] and [ListView.separated]. Null
  /// builds until [itemBuilder] returns null.
  // web: a server render builds every item (the browser scrolls them), so a
  // builder with no `itemCount` that never returns null stops with an error
  // after 100000 items instead of running forever.
  final int? itemCount;

  /// Builds item `index`, for [ListView.builder] and [ListView.separated].
  final NullableIndexedWidgetBuilder? itemBuilder;

  /// Builds the separator after item `index`, for [ListView.separated].
  final IndexedWidgetBuilder? separatorBuilder;

  @override
  bool get fillsWidth => true;

  @override
  bool get fillsHeight => true;

  // The items [itemBuilder] makes, with the separators between them.
  List<Widget> _built(BuildContext context) {
    final count = itemCount;
    final out = <Widget>[];
    for (var i = 0; count == null || i < count; i++) {
      if (count == null && i >= _unboundedItemCap) {
        throw StateError(
          'ListView.builder has no itemCount and itemBuilder did not return '
          'null after $_unboundedItemCap items. Return null from itemBuilder '
          'to end the list, or give an itemCount.',
        );
      }
      final item = itemBuilder!(context, i);
      if (item == null) break;
      if (i > 0 && separatorBuilder != null) {
        out.add(separatorBuilder!(context, i - 1));
      }
      out.add(item);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final items = children ?? _built(context);
    final vertical = scrollDirection == Axis.vertical;
    final rules = vertical ? ChildRules.column : ChildRules.row;
    final extent = itemExtent;
    return thorElement(
      'div',
      debugName: 'ListView',
      fillsWidth: true,
      fillsHeight: true,
      childRules: ChildRules(
        all: {
          ...rules.all,
          if (extent != null) (vertical ? 'height' : 'width'): cssPx(extent),
          ...lazyLayoutCss(lazyLayout, extent ?? itemExtentEstimate),
        },
        fillWidth: rules.fillWidth,
        fillHeight: rules.fillHeight,
      ),
      attributes: _scrollControllerMarks(
        controller,
        scrollDirection,
        physics: physics,
      ),
      css: {
        ...flexCss(scrollDirection),
        ..._scrollCssOf(physics),
        'align-items': 'stretch',
        if (!vertical) 'overflow-y': 'hidden',
        if (padding != null) ...padding!.toCss('padding'),
        if (spacing != 0) 'gap': cssPx(spacing),
      },
      children: items,
    );
  }
}

/// Flutter's `CustomScrollView`: slivers (`SliverAppBar`, `SliverList`,
/// `SliverGrid`, `SliverToBoxAdapter`, `SliverPadding`,
/// `SliverFillRemaining`) stacked in one scrolling box.
///
/// ```dart
/// CustomScrollView(
///   slivers: [
///     SliverAppBar(pinned: true, title: Text('Catalog')),
///     SliverPadding(
///       padding: EdgeInsets.all(16),
///       sliver: SliverGrid.extent(maxCrossAxisExtent: 240, children: cards),
///     ),
///     SliverList.builder(itemCount: rows.length, itemBuilder: (c, i) => RowTile(rows[i])),
///   ],
/// )
/// ```
///
/// `// web:` a sliver is a block of the box, the browser scrolls the box
/// and a pinned `SliverAppBar` is `position: sticky`: no scroll listeners,
/// and every item is in the HTML. It scrolls when something gives it a
/// height (`Expanded`, `SizedBox`, a `Scaffold` body); with none it is as
/// tall as its slivers. Only the vertical axis exists.
class CustomScrollView extends StatelessWidget
    implements LayoutHint, HeightHint, ThorElementWidget, ThorBuiltIn {
  /// Creates a scroll view of [slivers].
  const CustomScrollView({
    super.key,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.controller,
    this.primary,
    this.physics,
    this.shrinkWrap = false,
    this.cacheExtent,
    this.semanticChildCount,
    this.slivers = const [],
  });

  /// The scrolling axis. `// web:` only [Axis.vertical].
  final Axis scrollDirection;

  /// Whether the slivers start at the end. `// web:` not supported.
  final bool reverse;

  /// A `ScrollController` field of a `ThorState` that follows and moves this
  /// view's offset (see `ListView.controller`).
  final ScrollController? controller;

  /// Accepted so Flutter code compiles; changes nothing.
  // web: the view is the scroller of its box.
  final bool? primary;

  /// Accepted so Flutter code compiles; changes nothing.
  // web: the browser owns scrolling (and its overscroll behavior).
  final ScrollPhysics? physics;

  /// Accepted so Flutter code compiles; changes nothing.
  // web: the view is as tall as its slivers unless a parent gives it a
  // height, which is what `shrinkWrap` asks of a scroll view in Flutter.
  final bool shrinkWrap;

  /// Accepted so Flutter code compiles; changes nothing.
  // web: every sliver is in the page.
  final double? cacheExtent;

  /// Accepted so Flutter code compiles; changes nothing.
  // web: the DOM order is the semantic order.
  final int? semanticChildCount;

  /// The slivers, in order.
  final List<Widget> slivers;

  @override
  bool get fillsWidth => true;

  @override
  bool get fillsHeight => true;

  @override
  Widget build(BuildContext context) {
    if (scrollDirection != Axis.vertical) {
      throw UnsupportedError(
        'CustomScrollView(scrollDirection: Axis.horizontal) has no CSS '
        'version: slivers stack down the box. For a row of items use '
        'ListView(scrollDirection: Axis.horizontal).',
      );
    }
    if (reverse) {
      throw UnsupportedError(
        'CustomScrollView(reverse: true) is not supported: the browser '
        'starts every scroll box at its top.',
      );
    }
    return thorElement(
      'div',
      debugName: 'CustomScrollView',
      fillsWidth: true,
      fillsHeight: true,
      // A sliver keeps its own height whatever the box holds.
      childRules: const ChildRules(
        all: {'flex-shrink': '0'},
        fillWidth: {'align-self': 'stretch'},
      ),
      attributes: _scrollControllerMarks(
        controller,
        Axis.vertical,
        physics: physics,
      ),
      css: {
        ...flexCss(Axis.vertical),
        ..._scrollCssOf(physics),
        'align-items': 'stretch',
      },
      children: slivers,
    );
  }
}

/// Flutter's `SliverGridDelegate`: how a [GridView] lays out its tiles.
/// [SliverGridDelegateWithFixedCrossAxisCount] and
/// [SliverGridDelegateWithMaxCrossAxisExtent] are the two that map to CSS
/// grid.
///
/// `// web:` Flutter's delegates compute each tile's offset in Dart
/// (`getLayout`); here they only carry the numbers, and the browser lays the
/// grid out. A custom delegate has no CSS to become, so [GridView] rejects
/// it.
abstract class SliverGridDelegate {
  /// Creates a grid delegate.
  const SliverGridDelegate();
}

/// A grid with a fixed number of columns (`GridView.count`'s CSS:
/// `repeat(n, minmax(0, 1fr))`).
class SliverGridDelegateWithFixedCrossAxisCount extends SliverGridDelegate {
  /// Creates a delegate with [crossAxisCount] columns.
  const SliverGridDelegateWithFixedCrossAxisCount({
    required this.crossAxisCount,
    this.mainAxisSpacing = 0,
    this.crossAxisSpacing = 0,
    this.childAspectRatio = 1,
    this.mainAxisExtent,
  }) : assert(crossAxisCount > 0),
       assert(mainAxisSpacing >= 0),
       assert(crossAxisSpacing >= 0),
       assert(childAspectRatio > 0),
       assert(mainAxisExtent == null || mainAxisExtent >= 0);

  /// The number of columns.
  final int crossAxisCount;

  /// The space between rows.
  final double mainAxisSpacing;

  /// The space between columns.
  final double crossAxisSpacing;

  /// The ratio of a tile's width to its height.
  final double childAspectRatio;

  /// The height of each tile (instead of [childAspectRatio]).
  final double? mainAxisExtent;
}

/// A grid whose tiles are at most [maxCrossAxisExtent] wide: like Flutter's
/// `getLayout`, `ceil(width / (max + crossAxisSpacing))` columns (a 360px
/// phone with `max: 200` gets two), counted by container-query steps.
class SliverGridDelegateWithMaxCrossAxisExtent extends SliverGridDelegate {
  /// Creates a delegate with tiles about [maxCrossAxisExtent] wide.
  const SliverGridDelegateWithMaxCrossAxisExtent({
    required this.maxCrossAxisExtent,
    this.mainAxisSpacing = 0,
    this.crossAxisSpacing = 0,
    this.childAspectRatio = 1,
    this.mainAxisExtent,
    this.stretch = true,
    this.alignment = WrapAlignment.start,
  }) : assert(maxCrossAxisExtent > 0),
       assert(mainAxisSpacing >= 0),
       assert(crossAxisSpacing >= 0),
       assert(childAspectRatio > 0),
       assert(mainAxisExtent == null || mainAxisExtent >= 0);

  /// The tile width the columns are counted from.
  final double maxCrossAxisExtent;

  // web: not in Flutter.
  /// `false` keeps every tile exactly [maxCrossAxisExtent] wide
  /// with exactly [crossAxisSpacing] between them, as many columns as fit
  /// (`floor((width + spacing) / (max + spacing))`, at least one), instead of
  /// stretching the tiles to fill the row (Flutter's `ceil`). The space left
  /// over goes where [alignment] says.
  ///
  /// `// web:` Flutter's delegates always stretch; a fixed-size flowing
  /// layout is a `Wrap` there.
  final bool stretch;

  // web: not in Flutter.
  /// Where the space left over goes when [stretch] is `false`
  /// (Flutter's `Wrap(alignment:)`).
  final WrapAlignment alignment;

  /// The space between rows.
  final double mainAxisSpacing;

  /// The space between columns.
  final double crossAxisSpacing;

  /// The ratio of a tile's width to its height.
  final double childAspectRatio;

  /// The height of each tile (instead of [childAspectRatio]).
  final double? mainAxisExtent;
}

/// Scrolling behavior of a scroll view (Flutter's `ScrollPhysics`).
///
/// `// web:` the browser decides how a view scrolls: these are accepted so
/// Flutter code compiles and change nothing.
class ScrollPhysics {
  /// Creates the default physics.
  const ScrollPhysics();
}

/// Flutter's `NeverScrollableScrollPhysics`. `// web:` the view clips its
/// overflow (`overflow: hidden`) instead of scrolling, and is not a tab
/// stop.
class NeverScrollableScrollPhysics extends ScrollPhysics {
  /// Creates physics that Flutter would not let scroll.
  const NeverScrollableScrollPhysics();
}

/// Flutter's `AlwaysScrollableScrollPhysics`; no effect on the web.
class AlwaysScrollableScrollPhysics extends ScrollPhysics {
  /// Creates physics that always scroll in Flutter.
  const AlwaysScrollableScrollPhysics();
}

/// Flutter's `BouncingScrollPhysics`; no effect on the web.
class BouncingScrollPhysics extends ScrollPhysics {
  /// Creates iOS-style physics.
  const BouncingScrollPhysics();
}

/// Flutter's `ClampingScrollPhysics`; no effect on the web.
class ClampingScrollPhysics extends ScrollPhysics {
  /// Creates Android-style physics.
  const ClampingScrollPhysics();
}

/// Flutter's `GridView.count` / `GridView.extent` → CSS grid; also
/// `GridView(gridDelegate:)` and `GridView.builder(gridDelegate:,
/// itemCount:, itemBuilder:)` with Flutter's delegates, which give the same
/// CSS.
///
/// `GridView.extent` is responsive without any breakpoint code or resize
/// listener: the columns follow the grid's own width by Flutter's formula
/// (`ceil(width / (max + spacing))`; the padding is not part of the width),
/// with one `@container` rule per column count, up to 64 columns or 4096px.
/// It is the only grid with a wrapper element (its query container).
///
/// ```dart
/// GridView.builder(
///   gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 240, mainAxisSpacing: 16, crossAxisSpacing: 16),
///   itemCount: products.length,
///   itemBuilder: (context, i) => ProductCard(products[i]),
/// )
/// ```
///
/// `// web:` `.builder` builds every item on the server (a page is HTML, not
/// a viewport): `itemCount` is required, and `lazyLayout: true` keeps the
/// browser from laying out the off-screen ones.
class GridView extends StatelessWidget
    implements LayoutHint, HeightHint, ThorElementWidget, ThorBuiltIn {
  /// Creates a grid with a fixed [crossAxisCount] of columns.
  const GridView.count({
    this.lazyLayout = false,
    this.itemExtentEstimate = 300,
    super.key,
    required int this.crossAxisCount,
    this.mainAxisSpacing = 0,
    this.crossAxisSpacing = 0,
    this.childAspectRatio = 1,
    this.controller,
    this.padding,
    this.shrinkWrap = false,
    this.physics,
    this.autoRowHeight = false,
    this.layout,
    this.children = const [],
  }) : maxCrossAxisExtent = null,
       stretch = true,
       alignment = WrapAlignment.start,
       gridDelegate = null,
       itemCount = null,
       itemBuilder = null;

  /// Creates a grid with as many columns as fit [maxCrossAxisExtent].
  const GridView.extent({
    this.lazyLayout = false,
    this.itemExtentEstimate = 300,
    super.key,
    required double this.maxCrossAxisExtent,
    this.stretch = true,
    this.alignment = WrapAlignment.start,
    this.mainAxisSpacing = 0,
    this.crossAxisSpacing = 0,
    this.childAspectRatio = 1,
    this.controller,
    this.padding,
    this.shrinkWrap = false,
    this.physics,
    this.autoRowHeight = false,
    this.layout,
    this.children = const [],
  }) : crossAxisCount = null,
       gridDelegate = null,
       itemCount = null,
       itemBuilder = null;

  /// Creates a grid laid out by [gridDelegate] (Flutter's spelling of
  /// [GridView.count] and [GridView.extent]) from an explicit list of
  /// [children].
  const GridView({
    this.lazyLayout = false,
    this.itemExtentEstimate = 300,
    super.key,
    required SliverGridDelegate this.gridDelegate,
    this.controller,
    this.padding,
    this.shrinkWrap = false,
    this.physics,
    this.autoRowHeight = false,
    this.layout,
    this.children = const [],
  }) : crossAxisCount = null,
       maxCrossAxisExtent = null,
       stretch = true,
       alignment = WrapAlignment.start,
       mainAxisSpacing = 0,
       crossAxisSpacing = 0,
       childAspectRatio = 1,
       itemCount = null,
       itemBuilder = null;

  /// Creates a grid laid out by [gridDelegate] with [itemCount] items built
  /// by [itemBuilder].
  ///
  /// `// web:` Flutter's [itemCount] may be null (an endless grid built as
  /// it scrolls); a page has to know how many to write: without it the build
  /// fails and says so.
  const GridView.builder({
    this.lazyLayout = false,
    this.itemExtentEstimate = 300,
    super.key,
    required SliverGridDelegate this.gridDelegate,
    required IndexedWidgetBuilder this.itemBuilder,
    this.itemCount,
    this.controller,
    this.padding,
    this.shrinkWrap = false,
    this.physics,
    this.autoRowHeight = false,
    this.layout,
  }) : assert(itemCount == null || itemCount >= 0),
       crossAxisCount = null,
       maxCrossAxisExtent = null,
       stretch = true,
       alignment = WrapAlignment.start,
       mainAxisSpacing = 0,
       crossAxisSpacing = 0,
       childAspectRatio = 1,
       children = const [];

  /// The delegate of [GridView.new] and [GridView.builder].
  final SliverGridDelegate? gridDelegate;

  /// Number of items, for [GridView.builder].
  final int? itemCount;

  /// Builds item `index`, for [GridView.builder].
  final IndexedWidgetBuilder? itemBuilder;

  /// Fixed number of columns, for [GridView.count].
  final int? crossAxisCount;

  /// Max column width, for [GridView.extent].
  final double? maxCrossAxisExtent;

  // web: not in Flutter.
  /// For [GridView.extent]: `false` keeps every tile exactly
  /// [maxCrossAxisExtent] wide with exactly [crossAxisSpacing] between them
  /// (see [SliverGridDelegateWithMaxCrossAxisExtent.stretch]).
  ///
  /// ```dart
  /// GridView.extent(maxCrossAxisExtent: 260, crossAxisSpacing: 73, stretch: false, children: cards)
  /// ```
  final bool stretch;

  // web: not in Flutter.
  /// Where the space left over goes when [stretch] is `false`.
  final WrapAlignment alignment;

  /// Same as Flutter's `GridView.mainAxisSpacing`.
  final double mainAxisSpacing;

  /// Same as Flutter's `GridView.crossAxisSpacing`.
  final double crossAxisSpacing;

  /// Same as Flutter's `GridView.childAspectRatio`.
  final double childAspectRatio;

  /// A `ScrollController` field of a `ThorState` that follows and moves this
  /// grid's offset (see `ListView.controller`).
  final ScrollController? controller;

  /// Same as Flutter's `GridView.padding`.
  final EdgeInsetsGeometry? padding;

  /// Accepted so Flutter code compiles; changes nothing.
  // web: a grid is a block in the page's flow: it is as tall as its rows
  // unless a parent gives it a height, which is what `shrinkWrap` asks of a
  // scroll view in Flutter.
  final bool shrinkWrap;

  /// Accepted so Flutter code compiles; changes nothing.
  // web: the browser owns scrolling (and its overscroll behavior): a grid
  // taller than its box scrolls, one that fits does not.
  final ScrollPhysics? physics;

  // web: not in Flutter.
  /// Size each row by its tallest item instead of the delegate's
  /// [childAspectRatio] (a product-card grid whose cards differ in height,
  /// with no ratio to guess). Flutter's `mainAxisExtent: null` already means
  /// "use the ratio", so this is a separate switch, off by default (Flutter's
  /// square tiles); `mainAxisExtent` still wins when it is given.
  ///
  /// ```dart
  /// GridView.extent(maxCrossAxisExtent: 240, autoRowHeight: true, children: cards)
  /// ```
  final bool autoRowHeight;

  // web: not in Flutter.
  /// Render off-screen items lazily (`content-visibility: auto`),
  /// the counterpart of Flutter building only visible slivers. All items stay
  /// in the DOM (SEO, find in page) but the browser skips their style,
  /// layout and paint until they approach the viewport, which cuts the
  /// relayout work of long lists.
  final bool lazyLayout;

  /// Estimated item extent (px) used for off-screen items when [lazyLayout];
  /// the browser remembers the real size once an item was rendered.
  final double itemExtentEstimate;

  // web: not in Flutter.
  /// Columns and gaps that change per breakpoint, state or
  /// container width, over the ones above (instead of
  /// `MediaQuery.of(context).size.width` branches):
  /// `layout: const GridLayout().when(medium: GridLayout(columns: 3))`, or
  /// `.when(container: {400: GridLayout(columns: 2)})` inside a `LayoutScope`.
  final GridLayout? layout;

  /// The grid's items.
  final List<Widget> children;

  @override
  bool get fillsWidth => true;

  @override
  bool get fillsHeight => _scrolls;

  // A `SliverGrid` is this grid inside a scroll view that is not its own.
  bool get _scrolls => true;

  @override
  Widget build(BuildContext context) {
    String columns(int n) => 'repeat($n, minmax(0, 1fr))';
    int? count = crossAxisCount;
    double? extent = maxCrossAxisExtent;
    var stretching = stretch;
    var align = alignment;
    var mainSpacing = mainAxisSpacing;
    var crossSpacing = crossAxisSpacing;
    var aspect = childAspectRatio;
    double? rowHeight;
    switch (gridDelegate) {
      case null:
        break;
      case final SliverGridDelegateWithFixedCrossAxisCount d:
        count = d.crossAxisCount;
        mainSpacing = d.mainAxisSpacing;
        crossSpacing = d.crossAxisSpacing;
        aspect = d.childAspectRatio;
        rowHeight = d.mainAxisExtent;
      case final SliverGridDelegateWithMaxCrossAxisExtent d:
        extent = d.maxCrossAxisExtent;
        stretching = d.stretch;
        align = d.alignment;
        mainSpacing = d.mainAxisSpacing;
        crossSpacing = d.crossAxisSpacing;
        aspect = d.childAspectRatio;
        rowHeight = d.mainAxisExtent;
      case final other:
        throw UnsupportedError(
          '${other.runtimeType} has no CSS: GridView takes '
          'SliverGridDelegateWithFixedCrossAxisCount or '
          'SliverGridDelegateWithMaxCrossAxisExtent (the browser lays the '
          'grid out; Flutter\'s getLayout runs in Dart).',
        );
    }
    final builder = itemBuilder;
    final List<Widget> items;
    if (builder == null) {
      items = children;
    } else {
      final n = itemCount;
      if (n == null) {
        throw StateError(
          'GridView.builder needs an itemCount: a page is written whole, so '
          'it has to know how many items to build (Flutter builds an '
          'endless grid as it scrolls).',
        );
      }
      items = [for (var i = 0; i < n; i++) builder(context, i)];
    }
    // `// web:` `maxCrossAxisExtent` is a cap, not a minimum: Flutter's
    // `getLayout` takes `ceil(width / (max + spacing))` columns, so a tile
    // is never wider than `max` (a 360px phone with `max: 200` gets two
    // columns). CSS `auto-fill` counts `floor`, with tiles at least `max`
    // wide (one column of 360px), and no `minmax` makes the two agree, so
    // the count is written by hand: a container of its own (this grid can't
    // query itself) and one `@container` step per column count.
    //
    // `// web:` `stretch: false` is the other reading: fixed tracks (`auto-fill`
    // of exactly `max`, shrinking only below one tile's width), so the browser
    // counts and no query steps are needed.
    final fixed = count == null && !stretching;
    final capped = count == null && !fixed;
    final takenOver = capped ? _stepsGivenWay(layout) : null;
    final horizontal = padding == null
        ? 0.0
        : numericHorizontal(padding!, 'GridView.padding');
    final stride = capped ? extent! + crossSpacing : 0.0;
    final grid = thorElement(
      'div',
      debugName: capped ? 'GridViewGrid' : 'GridView',
      fillsWidth: true,
      fillsHeight: _scrolls,
      childRules: ChildRules(
        all: {
          ...gridCellCss(
            layout,
            base: rowHeight == null && !autoRowHeight ? aspect : null,
          ),
          'min-width': '0',
          ..._lazy(lazyLayout, itemExtentEstimate),
        },
      ),
      attributes: _scrolls
          ? _scrollControllerMarks(controller, Axis.vertical, physics: physics)
          : null,
      css: mergeAdaptive({
        ...(_scrolls ? _scrollCssOf(physics) : _flowCss),
        'display': 'grid',
        'grid-template-columns': fixed
            ? 'repeat(auto-fill, minmax(min(${cssPx(extent!)}, 100%), '
                  '${cssPx(extent)}))'
            : columns(count ?? 1),
        if (fixed) 'justify-content': align.css,
        'grid-auto-rows': ?(rowHeight == null ? null : cssPx(rowHeight)),
        if (mainSpacing != 0) 'row-gap': cssPx(mainSpacing),
        if (crossSpacing != 0) 'column-gap': cssPx(crossSpacing),
        if (padding != null) ...padding!.toCss('padding'),
      }, layout?.toCss() ?? const {}),
      conditions: [
        if (capped)
          // Up to 4096px wide (a 4K screen); wider keeps the last count.
          if (takenOver?.always != true)
            for (var n = 2; n <= _maxColumns(stride); n++)
              ConditionalCss(
                // `(n - 1) * stride` is where n - 1 columns stop being enough
                // (`ceil` moves up just past it); the padding is not part of
                // Flutter's cross extent.
                _below(
                  takenOver,
                  CssCondition.container((n - 1) * stride + horizontal + 0.02),
                ),
                {'grid-template-columns': columns(n)},
              ),
      ],
      children: items,
    );
    if (!capped) return grid;
    return thorElement(
      'div',
      debugName: 'GridView',
      fillsWidth: true,
      fillsHeight: _scrolls,
      css: const {...boxCss, 'container-type': 'inline-size'},
      childRules: ChildRules.box,
      children: [grid],
    );
  }

  /// Where [layout] sets the columns: the capped grid's steps (container
  /// queries, written after the layout's own rules) would beat it, so they
  /// are left out where it applies.
  static ({bool always, WindowSizeClass? from, num? container})? _stepsGivenWay(
    GridLayout? layout,
  ) {
    if (layout == null) return null;
    final split = splitAdaptive(layout.toCss());
    const columns = 'grid-template-columns';
    if (split.base.containsKey(columns)) {
      return (always: true, from: null, container: null);
    }
    WindowSizeClass? from;
    num? container;
    for (final MapEntry(:key, :value) in split.byBreakpoint.entries) {
      if (!value.containsKey(columns)) continue;
      if (containerWidthOf(key) case final w?) {
        if (container == null || w < container) container = w;
      } else if (adaptiveBreakpoints.contains(key)) {
        final bp = WindowSizeClass.values.byName(key);
        if (from == null || bp.index < from.index) from = bp;
      }
    }
    if (from == null && container == null) return null;
    return (always: false, from: from, container: container);
  }

  /// [step] only below where the layout takes the columns over.
  static CssCondition _below(
    ({bool always, WindowSizeClass? from, num? container})? over,
    CssCondition step,
  ) {
    var out = step;
    if (over?.from case final bp?) {
      out = CssCondition.both(CssCondition.belowBreakpoint(bp), out);
    }
    if (over?.container case final w?) {
      out = CssCondition.both(CssCondition.belowContainer(w.toDouble()), out);
    }
    return out;
  }

  /// The most columns a capped grid writes rules for.
  static int _maxColumns(double stride) => math.min(64, (4096 / stride).ceil());
}

/// Flutter's `SliverGrid`: a grid of tiles inside a [CustomScrollView], laid
/// out by a [SliverGridDelegate] (the browser's CSS grid, see
/// [GridView]).
///
/// ```dart
/// SliverGrid.extent(maxCrossAxisExtent: 240, mainAxisSpacing: 16, crossAxisSpacing: 16, children: cards)
/// ```
class SliverGrid extends StatelessWidget
    implements LayoutHint, ThorElementWidget, ThorBuiltIn {
  /// Creates a grid of the tiles [delegate] makes, laid out by
  /// [gridDelegate].
  const SliverGrid({
    super.key,
    required this.delegate,
    required SliverGridDelegate this.gridDelegate,
  });

  /// Creates a grid of [itemCount] tiles made by [itemBuilder].
  SliverGrid.builder({
    super.key,
    required SliverGridDelegate this.gridDelegate,
    required IndexedWidgetBuilder itemBuilder,
    int? itemCount,
  }) : delegate = SliverChildBuilderDelegate(
         itemBuilder,
         childCount: itemCount,
       );

  /// Creates a grid of [children] with a fixed [crossAxisCount] of columns.
  SliverGrid.count({
    super.key,
    required int crossAxisCount,
    double mainAxisSpacing = 0,
    double crossAxisSpacing = 0,
    double childAspectRatio = 1,
    List<Widget> children = const [],
  }) : gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
         crossAxisCount: crossAxisCount,
         mainAxisSpacing: mainAxisSpacing,
         crossAxisSpacing: crossAxisSpacing,
         childAspectRatio: childAspectRatio,
       ),
       delegate = SliverChildListDelegate(children);

  /// Creates a grid of [children] with as many columns as fit
  /// [maxCrossAxisExtent].
  SliverGrid.extent({
    super.key,
    required double maxCrossAxisExtent,
    double mainAxisSpacing = 0,
    double crossAxisSpacing = 0,
    double childAspectRatio = 1,
    List<Widget> children = const [],
  }) : gridDelegate = SliverGridDelegateWithMaxCrossAxisExtent(
         maxCrossAxisExtent: maxCrossAxisExtent,
         mainAxisSpacing: mainAxisSpacing,
         crossAxisSpacing: crossAxisSpacing,
         childAspectRatio: childAspectRatio,
       ),
       delegate = SliverChildListDelegate(children);

  /// Where the tiles come from.
  final SliverChildDelegate delegate;

  /// How the tiles are laid out.
  final SliverGridDelegate? gridDelegate;

  @override
  bool get fillsWidth => true;

  @override
  Widget build(BuildContext context) => _SliverGridView(
    gridDelegate: gridDelegate!,
    children: sliverItems(context, delegate, owner: 'SliverGrid'),
  );
}

// The grid of a [SliverGrid]: a [GridView] that leaves scrolling to the
// view it is in.
class _SliverGridView extends GridView {
  const _SliverGridView({required super.gridDelegate, super.children});

  @override
  bool get _scrolls => false;
}

/// Skips the layout and paint of [child] while it is off screen
/// (`content-visibility: auto`), the page-level version of
/// `ListView(lazyLayout: true)`. [extentEstimate] is its height until it is
/// first rendered (then the browser remembers the real one).
///
/// Useful for long pages of many sections. `// web:` it also clips the child's own painting
/// to its box (paint containment), so don't use it on a section whose
/// glows/shadows overflow, nor on the first screen.
class LazyLayout extends ParentDataWrapper {
  /// Renders `child` only when it nears the viewport.
  const LazyLayout({
    super.key,
    this.extentEstimate = 600,
    required super.child,
  });

  /// Height (px) reserved while the child hasn't been rendered yet.
  final double extentEstimate;

  @override
  WrapData get wrapData => WrapData(css: _lazy(true, extentEstimate));
}

CssDeclarations _lazy(bool on, double estimate) => lazyLayoutCss(on, estimate);

/// Flutter's `CarouselView`: a horizontal row of items that scrolls and
/// snaps item by item, on native scroll snapping (touch, trackpad and
/// keyboard scrolling for free, no JS).
///
/// Size items with [itemExtent] (px, as in Flutter) or, web extra, with a
/// [layout]: whole items per view and spacing, per breakpoint with
/// `.when()`
/// (`CarouselLayout(itemsPerView: 1).when(medium: CarouselLayout(itemsPerView: 2))`).
///
/// `// web:` all progressive: with [showArrows] the browser draws
/// previous/next buttons and with [showIndicators] one dot per item
/// (`::scroll-button` and `::scroll-marker`, Chromium 135+; elsewhere the
/// carousel still scrolls, by touch, wheel and keyboard, and shows no
/// buttons that would do nothing). Style the arrows like a button
/// (`arrowStyle: IconButton.styleFrom(...)`) and the dots with
/// [CarouselIndicatorStyle]. [autoPlay] advances it by itself.
///
/// `// web:` Flutter's carousel has no arrows, dots or autoplay.
class CarouselView extends StatelessWidget
    implements LayoutHint, ThorElementWidget, ThorBuiltIn {
  /// Creates a carousel.
  const CarouselView({
    super.key,
    this.itemExtent,
    this.layout = const CarouselLayout(),
    this.itemSnapping = true,
    this.showArrows = true,
    this.arrowStyle,
    this.arrowPosition = CarouselArrowPosition.inside,
    this.arrowIcon,
    this.arrowInset,
    this.showIndicators = false,
    this.indicatorStyle,
    this.autoPlay,
    this.previousLabel,
    this.nextLabel,
    this.slideLabel,
    this.slideOfLabel,
    this.label,
    required this.children,
  }) : assert(
         autoPlay == null || autoPlay > Duration.zero,
         'CarouselView(autoPlay:) needs a positive interval',
       ),
       assert(
         arrowInset == null || arrowInset >= 0,
         'CarouselView(arrowInset:) is a distance: zero or more',
       );

  /// Width of each item in px (wins over [layout]'s items per view).
  final double? itemExtent;

  // web: not in Flutter.
  /// Items per view and spacing (per breakpoint with `.when()`).
  final CarouselLayout layout;

  /// Whether scrolling rests on an item's edge (Flutter's default: false;
  /// here true, the common case for a carousel).
  final bool itemSnapping;

  // web: not in Flutter.
  /// The browser's previous/next buttons.
  final bool showArrows;

  // web: not in Flutter.
  /// The look of the arrows, like an icon button's:
  /// `IconButton.styleFrom(backgroundColor:, foregroundColor:,
  /// minimumSize:, shape:, side:, overlayColor:)`. Null: a 36 px round
  /// button on the theme's surface.
  ///
  /// `// web:` the arrow is a pseudo-element, so its glyph is an image:
  /// [ButtonStyle.foregroundColor] is baked into it (a theme variable
  /// contributes its fallback).
  final ButtonStyle? arrowStyle;

  // web: not in Flutter.
  /// Where the arrows sit. Inside by default.
  final CarouselArrowPosition arrowPosition;

  // web: not in Flutter.
  /// The arrows' glyph, an SVG icon (`Icons.arrow_forward_ios`, or
  /// your own `IconData.svg`) that points **forward** (to the right): the
  /// previous arrow draws it mirrored. Null: a chevron.
  ///
  /// `// web:` the arrow is a pseudo-element (`::scroll-button`), so its
  /// glyph is an image: it takes the SVG icons (not a font glyph) and the
  /// color of [ButtonStyle.foregroundColor], baked into it, like
  /// [arrowStyle]. The fallback buttons (Firefox, Safari) draw the same one.
  final IconData? arrowIcon;

  // web: not in Flutter.
  /// How far the arrows are from the carousel's edge, in px: in
  /// from it with [CarouselArrowPosition.inside] (8 by default), out from it
  /// with `outside` (16 by default; the page still never scrolls sideways).
  final double? arrowInset;

  // web: not in Flutter.
  /// One dot per item that shows where the carousel is and
  /// jumps to an item.
  final bool showIndicators;

  // web: not in Flutter.
  /// The dots' colors, size and place.
  final CarouselIndicatorStyle? indicatorStyle;

  // web: not in Flutter.
  /// Advance to the next item every this long (back to the first
  /// after the last). It pauses while the pointer or the focus is in the
  /// carousel, while the page is hidden, and never runs with
  /// `prefers-reduced-motion`. Needs the engine; without it the carousel
  /// is static.
  ///
  /// `// web:` opt-in: moving content is a WCAG 2.2.2 concern, so offer
  /// controls ([showArrows]) next to it.
  final Duration? autoPlay;

  /// Accessible name of the previous arrow.
  final String? previousLabel;

  /// Accessible name of the next arrow.
  final String? nextLabel;

  /// Accessible name of a dot: followed by the item's number.
  final String? slideLabel;

  // web: not in Flutter.
  /// The word between a dot's number and the item count, so a dot
  /// is named "Slide 2 of 5" (translate it with [slideLabel]).
  ///
  /// `// web:` a live list's dots drawn by the browser (Firefox, Safari) say
  /// it too; the browser's own dots (Chromium) can only say it for a static
  /// carousel: CSS can't count the rows of a list that has not arrived.
  final String? slideOfLabel;

  /// Accessible name of the carousel region.
  final String? label;

  /// The items.
  final List<Widget> children;

  @override
  bool get fillsWidth => true;

  static const _defaultArrow = 36.0;
  static const _arrowInset = 8.0;
  static const _arrowGap = 16.0;
  static const _defaultGlyph = '#888888';

  /// A CSS string literal: quotes, backslashes and anything that could end
  /// the stylesheet are written as escapes.
  static String _str(String s) {
    final out = StringBuffer("'");
    for (final c in s.runes) {
      if (c < 0x20 || c == 0x22 || c == 0x27 || c == 0x5c || c == 0x3c) {
        out.write('\\${c.toRadixString(16)} ');
      } else {
        out.writeCharCode(c);
      }
    }
    return (out..write("'")).toString();
  }

  static String _svgImage(String svg) =>
      'url("data:image/svg+xml,${Uri.encodeComponent(svg)}")';

  /// The default chevron: [d] is its path.
  static String _arrow(String d, String color) => _svgImage(
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" '
    'stroke="$color" stroke-width="2" stroke-linecap="round" '
    'stroke-linejoin="round"><path d="$d"/></svg>',
  );

  /// [icon] (pointing forward) as the arrow's image, mirrored when [flip].
  static String _iconImage(IconData icon, String color, {required bool flip}) {
    assert(
      icon.isSvg,
      'CarouselView(arrowIcon:) draws an image: use an SVG icon '
      '(`Icons.…` or `IconData.svg`), not a font glyph',
    );
    final box = icon.viewBox.trim().split(RegExp(r'[\s,]+'));
    final width = box.length == 4 ? (double.tryParse(box[2]) ?? 24.0) : 24.0;
    String plain(double n) => n == n.roundToDouble() ? '${n.round()}' : '$n';
    final shown = plain(width);
    final stroke = icon.strokeWidth;
    final paint = stroke == null
        ? 'fill="$color"'
        : 'fill="none" stroke="$color" stroke-width="${plain(stroke)}" '
              'stroke-linecap="round" stroke-linejoin="round"';
    final body = flip
        ? '<g transform="matrix(-1 0 0 1 $shown 0)">${icon.svgBody}</g>'
        : icon.svgBody!;
    return _svgImage(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="${icon.viewBox}" '
      '$paint>$body</svg>',
    );
  }

  /// The color of the arrow's glyph: a plain color or the fallback of a
  /// theme variable (an image can't read a custom property).
  static String _glyph(Color? c) {
    final css = (c?.variableName != null ? c!.fallback : c)?.css;
    if (css != null &&
        (css.startsWith('#') ||
            css.startsWith('rgb') ||
            css.startsWith('hsl'))) {
      return css;
    }
    return _defaultGlyph;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ThorLocalizations.of(context);
    final previousLabel = this.previousLabel ?? l10n.carouselPrevious;
    final nextLabel = this.nextLabel ?? l10n.carouselNext;
    final slideLabel = this.slideLabel ?? l10n.carouselSlide;
    final slideOfLabel = this.slideOfLabel ?? l10n.carouselOf;
    final basis = itemExtent != null
        ? cssPx(itemExtent!)
        : 'calc((100% - (var(--t-per-view) - 1) * var(--t-gap)) / '
              'var(--t-per-view))';
    final arrow = arrowStyle;
    final dots = indicatorStyle ?? const CarouselIndicatorStyle();
    final size = arrow?.plainMinimumSize?.width.isFinite ?? false
        ? arrow!.plainMinimumSize!.width
        : _defaultArrow;
    final height = arrow?.plainMinimumSize?.height.isFinite ?? false
        ? arrow!.plainMinimumSize!.height
        : size;
    final border = arrow?.plainSide ?? arrow?.plainShape?.side;
    final glyph = _glyph(arrow?.plainForeground);
    final outside = arrowPosition == CarouselArrowPosition.outside;
    // The picture of each arrow: the chevrons, or the icon (mirrored on the
    // left, the previous one in a left-to-right page).
    final icon = arrowIcon;
    final previousImage = icon == null
        ? _arrow('m15 18-6-6 6-6', glyph)
        : _iconImage(icon, glyph, flip: true);
    final nextImage = icon == null
        ? _arrow('m9 18 6-6-6-6', glyph)
        : _iconImage(icon, glyph, flip: false);
    // From the carousel's edge; the viewport's edge keeps its own 8 px.
    final inset = arrowInset ?? (outside ? _arrowGap : _arrowInset);
    final below = dots.position == CarouselIndicatorPosition.below;
    final dotRadius = dots.shape?.radiusCss ?? '9999px';
    // The room a dot takes: the taller of the plain and the active one.
    final dotBox = math.max(dots.size, dots.activeSize?.height ?? 0);
    final look = <String, String>{
      'box-sizing': 'border-box',
      'width': cssPx(size),
      'height': cssPx(height),
      'padding': '0',
      'border':
          (border != null && border != BorderSide.none ? border : null)?.css ??
          (arrow == null ? '1px solid ${ThemeTokens.outlineVariant}' : 'none'),
      'border-radius': arrow?.plainShape?.radiusCss ?? '9999px',
      'background-color':
          arrow?.plainBackground?.css ?? 'var(--t-surface, #fff)',
      'background-repeat': 'no-repeat',
      'background-position': 'center',
      'background-size': arrow?.plainIconSize != null
          ? cssPx(arrow!.plainIconSize!)
          : '50%',
      'color': arrow?.plainForeground?.css ?? ThemeTokens.onSurface,
      'cursor': 'pointer',
    };
    final arrowBase = <String, String>{
      'position': 'absolute',
      'position-anchor': '--t-carousel',
      'top': 'anchor(center)',
      'translate': '0 -50%',
      ...look,
    };
    // web: a live list (`Watch.list` with this carousel as its container)
    // reaches the server as its row template alone: how many items there
    // will be is the browser's to know, so the controls are drawn and hide
    // themselves (CSS for the native ones, the engine part for the fallback)
    // while there are fewer than two.
    final live = children.any(
      (c) => isElementWith(c, 'template', listTemplateAttr),
    );
    // web: one item (or none) has nowhere to go: no arrows and no dots.
    final arrowsOn = showArrows && (live || children.length > 1);
    final dotsOn = showIndicators && (live || children.length > 1);
    const fewer = ':not(:has(> :nth-child(2 of :not(template))))';
    final controls = arrowsOn || dotsOn;
    // Autoplay is the engine's whatever the browser: the full engine.
    if (autoPlay != null) ThorStyleRegistry.active(context)?.useEngine();
    if (controls) {
      // The engine's `carousel` part shows the fallback controls where the
      // browser has no `::scroll-button`; the page loads it only there.
      ThorStyleRegistry.active(context)?.useCarouselControls();
    }
    final activeDot = dots.activeSize == null
        ? null
        : {
            'width': cssPx(dots.activeSize!.width),
            'height': cssPx(dots.activeSize!.height),
          };
    final scroller = thorElement(
      'div',
      debugName: 'CarouselView',
      fillsWidth: true,
      css: {
        ...flexCss(Axis.horizontal),
        ..._scrollCss,
        'overflow-y': 'hidden',
        ...mergeAdaptive(const {
          '--t-per-view': '1',
          '--t-gap': '16px',
        }, layout.toCss()),
        'gap': 'var(--t-gap)',
        'align-items': 'stretch',
        'scrollbar-width': 'none',
        'overscroll-behavior-x': 'contain',
        if (itemSnapping) 'scroll-snap-type': 'x mandatory',
        if (controls) 'grid-area': '1 / 1',
        // The arrows and dots anchor to this carousel only (scoped name).
        if (arrowsOn || dotsOn) ...{
          'anchor-name': '--t-carousel',
          'anchor-scope': '--t-carousel',
        },
        if (dotsOn) ...{
          'scroll-marker-group': 'after',
          'counter-reset': 't-slide',
        },
      },
      conditions: [
        if (arrowsOn) ...[
          if (arrow?.overlayAt(WidgetState.hovered) case final hover?)
            ConditionalCss(
              const CssCondition.selector('::scroll-button(*):hover'),
              {'background-color': hover.css},
            ),
          const ConditionalCss(
            CssCondition.selector('::scroll-button(*):focus-visible'),
            {
              'outline': '2px solid ${ThemeTokens.primary}',
              'outline-offset': '2px',
            },
          ),
          const ConditionalCss(
            CssCondition.selector('::scroll-button(*):disabled'),
            {'opacity': '0.4', 'cursor': 'default'},
          ),
          if (live)
            const ConditionalCss(
              CssCondition.selector('$fewer::scroll-button(*)'),
              {'display': 'none'},
            ),
          ConditionalCss(const CssCondition.selector('::scroll-button(left)'), {
            ...arrowBase,
            'content': "'' / ${_str(previousLabel)}",
            // web: outside, a button that would pass the viewport's edge
            // falls back over the carousel: the page never scrolls sideways.
            'left': outside
                ? 'max(${cssPx(_arrowInset)}, '
                      'calc(anchor(left) - ${cssPx(size + inset)}))'
                : 'calc(anchor(left) + ${cssPx(inset)})',
            'background-image': previousImage,
          }),
          ConditionalCss(
            const CssCondition.selector('::scroll-button(right)'),
            {
              ...arrowBase,
              'content': "'' / ${_str(nextLabel)}",
              'left': outside
                  ? 'min(calc(100% - ${cssPx(size + _arrowInset)}), '
                        'calc(anchor(right) + ${cssPx(inset)}))'
                  : 'calc(anchor(right) - ${cssPx(size + inset)})',
              'background-image': nextImage,
            },
          ),
          // web: the buttons are physical (left, right): in a right-to-left
          // page the one on the left goes forward, so it is the Next.
          ConditionalCss(
            const CssCondition.selector(':dir(rtl)::scroll-button(left)'),
            {'content': "'' / ${_str(nextLabel)}"},
          ),
          ConditionalCss(
            const CssCondition.selector(':dir(rtl)::scroll-button(right)'),
            {'content': "'' / ${_str(previousLabel)}"},
          ),
        ],
        if (dotsOn) ...[
          ConditionalCss(const CssCondition.selector('::scroll-marker-group'), {
            'position': 'absolute',
            'position-anchor': '--t-carousel',
            'left': 'anchor(center)',
            'translate': '-50% 0',
            'top': below
                ? 'calc(anchor(bottom) + ${cssPx(dots.spacing)})'
                : 'calc(anchor(bottom) - ${cssPx(dotBox + dots.spacing * 1.5)})',
            'display': 'flex',
            'gap': cssPx(dots.spacing),
            if (dots.activeSize != null) 'align-items': 'center',
          }),
          if (live)
            const ConditionalCss(
              CssCondition.selector('$fewer::scroll-marker-group'),
              {'display': 'none'},
            ),
          ConditionalCss(const CssCondition.selector(' > *::scroll-marker'), {
            'content':
                "'' / ${_str('$slideLabel ')} counter(t-slide)"
                "${live ? '' : ' ${_str(' $slideOfLabel ${children.length}')}'}",
            'box-sizing': 'border-box',
            'width': cssPx(dots.size),
            'height': cssPx(dots.size),
            'padding': '0',
            'border': 'none',
            'border-radius': dotRadius,
            'background-color': dots.color?.css ?? ThemeTokens.outlineVariant,
            'cursor': 'pointer',
          }),
          ConditionalCss(
            const CssCondition.selector(' > *::scroll-marker:target-current'),
            {
              'background-color': dots.activeColor?.css ?? ThemeTokens.primary,
              ...?activeDot,
            },
          ),
          const ConditionalCss(
            CssCondition.selector(' > *::scroll-marker:focus-visible'),
            {
              'outline': '2px solid ${ThemeTokens.primary}',
              'outline-offset': '2px',
            },
          ),
        ],
      ],
      attributes: {
        'role': 'region',
        'aria-roledescription': l10n.carouselRoleDescription,
        'aria-label': ?label,
        'tabindex': '0',
        if (autoPlay case final d?) carouselAttr: '${d.inMilliseconds}',
      },
      childRules: ChildRules(
        all: {
          'flex': '0 0 $basis',
          'min-width': '0',
          if (itemSnapping) 'scroll-snap-align': 'start',
          if (dotsOn) 'counter-increment': 't-slide',
        },
      ),
      children: children,
    );
    if (!controls) return scroller;
    // web: the controls for browsers without `::scroll-button` /
    // `::scroll-marker` (Firefox, Safari): real buttons beside the scroller,
    // hidden until the engine's `carousel` part finds the browser can't draw
    // its own (so without JS no dead button is ever shown).
    const hide = ConditionalCss(CssCondition.selector('[hidden]'), {
      'display': 'none',
    });
    // Nothing to click on paper.
    const printHide = ConditionalCss(CssCondition.media('print'), {
      'display': 'none',
    });
    const focus = ConditionalCss(CssCondition.selector(':focus-visible'), {
      'outline': '2px solid ${ThemeTokens.primary}',
      'outline-offset': '2px',
    });
    // The fallback buttons sit over the carousel whatever the position.
    final buttonInset = arrowInset ?? _arrowInset;
    Widget arrowButton(String attr, String label, String image, bool end) =>
        thorElement(
          'button',
          debugName: 'CarouselArrow',
          css: {
            ...look,
            'grid-area': '1 / 1',
            // A grid item takes z-index without being positioned.
            'z-index': '1',
            'align-self': 'center',
            'justify-self': end ? 'end' : 'start',
            // Logical, like `justify-self`: both follow the page direction.
            if (end)
              'margin-inline-end': cssPx(buttonInset)
            else
              'margin-inline-start': cssPx(buttonInset),
            'background-image': image,
          },
          conditions: [
            hide,
            focus,
            // The chevron points the other way in a right-to-left page.
            const ConditionalCss(CssCondition.selector(':dir(rtl)'), {
              'transform': 'scaleX(-1)',
            }),
            if (arrow?.overlayAt(WidgetState.hovered) case final hover?)
              ConditionalCss(CssCondition.hover, {
                'background-color': hover.css,
              }),
            // aria-disabled, not disabled: at the end of the carousel the
            // button keeps the keyboard focus the visitor put on it.
            const ConditionalCss(
              CssCondition.selector('[aria-disabled="true"]'),
              {'opacity': '0.4', 'cursor': 'default'},
            ),
            printHide,
          ],
          attributes: {
            'type': 'button',
            'aria-label': label,
            'hidden': '',
            attr: '',
          },
          children: const [],
        );
    Widget dot(String name) => thorElement(
      'button',
      debugName: 'CarouselDot',
      css: {
        'box-sizing': 'border-box',
        'width': cssPx(dots.size),
        'height': cssPx(dots.size),
        'padding': '0',
        'border': 'none',
        'border-radius': dotRadius,
        'background-color': dots.color?.css ?? ThemeTokens.outlineVariant,
        'cursor': 'pointer',
      },
      conditions: [
        focus,
        ConditionalCss(const CssCondition.selector('[aria-current="true"]'), {
          'background-color': dots.activeColor?.css ?? ThemeTokens.primary,
          ...?activeDot,
        }),
      ],
      attributes: {'type': 'button', 'aria-label': name},
      children: const [],
    );
    return thorElement(
      'div',
      debugName: 'CarouselControls',
      fillsWidth: true,
      css: {
        'display': 'grid',
        'grid-template-columns': 'minmax(0, 1fr)',
        'min-width': '0',
        if (dotsOn && below) 'padding-bottom': cssPx(dotBox + 2 * dots.spacing),
      },
      attributes: {carouselControlsAttr: ''},
      children: [
        scroller,
        if (arrowsOn) ...[
          arrowButton(carouselPrevAttr, previousLabel, previousImage, false),
          arrowButton(carouselNextAttr, nextLabel, nextImage, true),
        ],
        if (dotsOn)
          thorElement(
            'div',
            debugName: 'CarouselDots',
            css: {
              'display': 'flex',
              'gap': cssPx(dots.spacing),
              if (dots.activeSize != null) 'align-items': 'center',
              'grid-area': '1 / 1',
              'z-index': '1',
              'align-self': 'end',
              'justify-self': 'center',
              if (below)
                'transform': 'translateY(calc(100% + ${cssPx(dots.spacing)}))'
              else
                'margin-bottom': cssPx(dots.spacing * 1.5),
            },
            conditions: const [hide, printHide],
            attributes: {'hidden': '', carouselDotsAttr: ''},
            children: [
              if (live)
                // web: the browser clones this one per item of the list.
                Widget.element(
                  tag: 'template',
                  attributes: {
                    carouselDotTemplateAttr: '',
                    carouselDotOfAttr: slideOfLabel,
                  },
                  children: [dot('$slideLabel ')],
                )
              else
                for (var i = 0; i < children.length; i++)
                  dot('$slideLabel ${i + 1} $slideOfLabel ${children.length}'),
            ],
          ),
      ],
    );
  }
}

/// Where a [CarouselView]'s arrows sit.
enum CarouselArrowPosition {
  /// Over the carousel's first and last item, inside its box.
  inside,

  /// Beside the carousel, outside its box. `// web:` where there is no room
  /// before the viewport's edge, the arrow falls back inside.
  outside,
}

/// Where a [CarouselView]'s dots sit.
enum CarouselIndicatorPosition {
  /// Under the carousel (it reserves the room).
  below,

  /// Over the items' bottom edge.
  inside,
}

/// The dots of a [CarouselView] (web extra).
class CarouselIndicatorStyle {
  /// A dots style; unset fields keep the theme's look.
  const CarouselIndicatorStyle({
    this.color,
    this.activeColor,
    this.size = 8,
    this.activeSize,
    this.shape,
    this.spacing = 8,
    this.position = CarouselIndicatorPosition.below,
  });

  /// The dots of the other items (default: the theme's outline).
  final Color? color;

  /// The dot of the item in view (default: the theme's primary).
  final Color? activeColor;

  /// Diameter in px.
  final double size;

  /// Size of the dot of the item in view, when it differs from the others:
  /// `Size(24, 8)` with `size: 8` makes the active dot a pill.
  /// Null: the same as [size].
  final Size? activeSize;

  /// The dots' corners (default: round). A `StadiumBorder` or a
  /// `RoundedRectangleBorder(borderRadius:)` makes them pills or squares.
  final OutlinedBorder? shape;

  /// Space between dots (and to the carousel) in px.
  final double spacing;

  /// Where the dots sit.
  final CarouselIndicatorPosition position;
}

/// Whole items per view and the space between them for a [CarouselView]
/// (web extra); per breakpoint with `.when()`.
class CarouselLayout extends ConstAdaptable<CarouselLayout> {
  /// Items per view and spacing; unset ones keep the carousel's (1, 16).
  const CarouselLayout({
    this.itemsPerView,
    this.itemSpacing,
    super.medium,
    super.expanded,
    super.large,
    super.extraLarge,
    super.dark,
    super.open,
    super.hover,
    super.focused,
    super.focusWithin,
    super.disabled,
    super.pressed,
    super.groupHover,
    super.groupHovers,
    super.container,
  });

  /// How many whole items fit the view.
  final int? itemsPerView;

  /// Space between items.
  final double? itemSpacing;

  @override
  CarouselLayout withVariants(Adaptive<CarouselLayout> variants) =>
      _AdaptiveCarouselLayout(variants);

  /// The CSS of the values that are set, with the variants of
  /// the `.when()` or the constructor.
  CssDeclarations toCss() {
    final a = adaptive;
    if (a == null) return _ownCss();
    return a.declarations((l) => identical(l, this) ? _ownCss() : l.toCss());
  }

  CssDeclarations _ownCss() => {
    if (itemsPerView case final n?) '--t-per-view': '$n',
    if (itemSpacing case final g?) '--t-gap': cssPx(g),
  };
}

class _AdaptiveCarouselLayout extends CarouselLayout {
  const _AdaptiveCarouselLayout(this.adaptive);

  @override
  final Adaptive<CarouselLayout> adaptive;

  @override
  CssDeclarations toCss() => adaptive.declarations((l) => l.toCss());
}
