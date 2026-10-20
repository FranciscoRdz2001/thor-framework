import 'package:thor_engine/thor_engine.dart'
    show ScrollController, horizontalScrollAttr, scrollControllerAttr;
import 'package:thor_style/thor_style.dart';

import '../core/core.dart';
import '../engine/watch.dart' show elementEventAttributes;
import '../foundation/child_rules.dart';
import '../foundation/element.dart';
import '../foundation/layout_hint.dart';
import '../foundation/parent_data.dart';
import '../foundation/style_registry.dart';
import '../foundation/theme_tokens.dart';
import 'scroll.dart'
    show IndexedWidgetBuilder, NeverScrollableScrollPhysics, ScrollPhysics;
import 'shortcuts.dart' show controllerIdOf;

/// Flutter's `PageView`: swipeable full-size pages that snap into place.
///
/// ```dart
/// PageView(children: const [Text('one'), Text('two'), Text('three')])
/// ```
///
/// With a `PageController` field of a `ThorState` ([controller]) the state
/// reads and moves the page, and [onPageChanged] is a method of the state:
///
/// ```dart
/// final pages = PageController();
/// final dot = state(0);
/// void changed(int page) => dot.value = page;     // PageView(onPageChanged: deck.changed, …)
/// void next() => pages.animateToPage(pages.page!.round() + 1,
///     duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
/// ```
///
/// `// web:` the browser does it all with CSS `scroll-snap` (touch, trackpad
/// and keyboard scrolling, momentum): one element, and each page is the
/// element of its child (a full-size flex item that snaps to its start). It
/// works with no JS. Flutter's `PageController` and `onPageChanged` are
/// Dart objects that read the scroll offset on every frame; here the
/// controller follows the scroller (its `page` is `offset / size`, tracked,
/// and `jumpToPage` / `animateToPage` move the browser's scroll), and
/// [onPageChanged] is told the index (`round(offset / size)`) when a scroll
/// ends (`scrollend`; where a browser has none, when it has paused for 120
/// ms), only if it changed: Flutter reports it past the halfway point while
/// the finger is still down.
class PageView extends StatelessWidget
    implements LayoutHint, HeightHint, ThorElementWidget, ThorBuiltIn {
  /// Creates a page view of [children].
  const PageView({
    super.key,
    this.scrollDirection = Axis.horizontal,
    this.reverse = false,
    this.controller,
    this.physics,
    this.pageSnapping = true,
    this.onPageChanged,
    this.padEnds = true,
    this.allowImplicitScrolling = false,
    this.children = const [],
  }) : itemCount = null,
       itemBuilder = null;

  /// Creates a page view whose pages [itemBuilder] builds, [itemCount] of
  /// them.
  ///
  /// `// web:` every page is built (the server writes them all: they are
  /// the page's HTML), where Flutter builds the visible ones.
  const PageView.builder({
    super.key,
    this.scrollDirection = Axis.horizontal,
    this.reverse = false,
    this.controller,
    this.physics,
    this.pageSnapping = true,
    this.onPageChanged,
    this.padEnds = true,
    this.allowImplicitScrolling = false,
    required int this.itemCount,
    required IndexedWidgetBuilder this.itemBuilder,
  }) : children = const [];

  /// The axis the pages follow.
  final Axis scrollDirection;

  /// Whether the first page is at the end (`row-reverse`).
  final bool reverse;

  /// A `PageController` (or any `ScrollController`) field of a `ThorState`
  /// that follows and moves this view (see the class).
  final ScrollController? controller;

  /// A method of a `ThorState` told the index of the page the view settled
  /// on (`void changed(int page)`, torn off or with `withArg`; see the
  /// class).
  final ValueChanged<int>? onPageChanged;

  /// [NeverScrollableScrollPhysics] stops the visitor from scrolling it
  /// (`overflow: hidden`: a `ScrollController` still moves it, a tab bar
  /// can drive it); any other physics changes nothing.
  // web: the browser owns scrolling (and its overscroll behavior).
  final ScrollPhysics? physics;

  /// Accepted so Flutter code compiles; changes nothing.
  // web: it matters only with a `viewportFraction` (a `PageController`
  /// parameter thor has no use for): every page fills the view.
  final bool padEnds;

  /// Whether the view settles on a page (Flutter's default: true), as CSS
  /// `scroll-snap-type: mandatory`; `false` scrolls freely.
  final bool pageSnapping;

  /// Accepted so Flutter code compiles; changes nothing.
  // web: every page is already in the DOM.
  final bool allowImplicitScrolling;

  /// The pages.
  final List<Widget> children;

  /// Number of pages, for [PageView.builder].
  final int? itemCount;

  /// Builds page `index`, for [PageView.builder].
  final IndexedWidgetBuilder? itemBuilder;

  @override
  bool get fillsWidth => true;

  @override
  bool get fillsHeight => true;

  @override
  Widget build(BuildContext context) {
    final horizontal = scrollDirection == Axis.horizontal;
    final axis = horizontal ? 'x' : 'y';
    final locked = physics is NeverScrollableScrollPhysics;
    final pages = [
      ...children,
      if (itemBuilder case final build?)
        for (var i = 0; i < itemCount!; i++) build(context, i),
    ];
    final id = controllerIdOf(controller);
    return thorElement(
      'div',
      debugName: 'PageView',
      fillsWidth: true,
      fillsHeight: true,
      css: {
        'display': 'flex',
        'flex-direction': horizontal
            ? (reverse ? 'row-reverse' : 'row')
            : (reverse ? 'column-reverse' : 'column'),
        'overflow-$axis': locked ? 'hidden' : 'auto',
        'overscroll-behavior-$axis': 'contain',
        if (pageSnapping && !locked) 'scroll-snap-type': '$axis mandatory',
        'scrollbar-width': 'none',
        'min-width': '0',
        'min-height': '0',
        'box-sizing': 'border-box',
      },
      conditions: [
        if (!locked)
          const ConditionalCss(CssCondition.focused, {
            'outline': '2px solid ${ThemeTokens.primary}',
            'outline-offset': '-2px',
          }),
      ],
      attributes: {
        // A scroller the keyboard can reach: the arrows page it (Safari and
        // Firefox do not focus one by themselves).
        if (!locked) 'tabindex': '0',
        scrollControllerAttr: ?id,
        // The engine needs the axis to read the page of a row.
        if ((id != null || onPageChanged != null) && horizontal)
          horizontalScrollAttr: '',
        ...elementEventAttributes({'page': onPageChanged}),
      },
      children: [
        for (final p in pages)
          WrapWith(
            const WrapData(
              css: {
                'flex': '0 0 100%',
                'min-width': '0',
                'min-height': '0',
                'box-sizing': 'border-box',
                'scroll-snap-align': 'start',
                'scroll-snap-stop': 'always',
              },
            ),
            child: p,
          ),
      ],
    );
  }
}
