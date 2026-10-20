import 'dart:math' as math;

import 'package:thor_style/thor_style.dart';

import '../core/core.dart';
import '../foundation/child_rules.dart';
import '../foundation/element.dart';
import '../foundation/layout_hint.dart';
import '../foundation/transparent.dart';
import 'scroll.dart' show IndexedWidgetBuilder, NullableIndexedWidgetBuilder;

// The most items a builder with no `childCount` may make before the render
// gives up: a server render builds every item, so a builder that never
// returns null would never end.
const _unboundedItemCap = 100000;

/// Flutter's `IndexedWidgetBuilder`-like callback of a sliver delegate: builds
/// the widget at `index`, or null when there are no more.
typedef SliverChildBuilder = Widget? Function(BuildContext context, int index);

/// Flutter's `SliverChildDelegate`: where a sliver list or grid gets its
/// items. [SliverChildBuilderDelegate] and [SliverChildListDelegate] are the
/// two Flutter has.
///
/// `// web:` a page is written whole, so a delegate builds every item on
/// the server (the browser scrolls them); there is no lazy building and a
/// custom delegate only needs [build] and [estimatedChildCount].
abstract class SliverChildDelegate {
  /// Creates a delegate.
  const SliverChildDelegate();

  /// Builds the child at [index], or null past the end.
  Widget? build(BuildContext context, int index);

  /// How many children there are, if known.
  int? get estimatedChildCount => null;
}

/// Flutter's `SliverChildBuilderDelegate`: [childCount] items made by
/// [builder].
class SliverChildBuilderDelegate extends SliverChildDelegate {
  /// Creates a delegate that builds its items with [builder].
  const SliverChildBuilderDelegate(
    this.builder, {
    this.childCount,
    this.addAutomaticKeepAlives = true,
    this.addRepaintBoundaries = true,
    this.addSemanticIndexes = true,
  }) : assert(childCount == null || childCount >= 0);

  /// Builds the item at `index`; null ends the list.
  final SliverChildBuilder builder;

  /// How many items there are; null builds until [builder] returns null.
  ///
  /// `// web:` a server render builds every item, so a builder with no count
  /// that never returns null stops with an error after 100000 items.
  final int? childCount;

  /// Accepted so Flutter code compiles; changes nothing.
  // web: the browser owns the items' lifetime.
  final bool addAutomaticKeepAlives;

  /// Accepted so Flutter code compiles; changes nothing.
  // web: the browser owns painting.
  final bool addRepaintBoundaries;

  /// Accepted so Flutter code compiles; changes nothing.
  // web: the DOM order is the semantic order.
  final bool addSemanticIndexes;

  @override
  int? get estimatedChildCount => childCount;

  @override
  Widget? build(BuildContext context, int index) =>
      childCount != null && index >= childCount!
      ? null
      : builder(context, index);
}

/// Flutter's `SliverChildListDelegate`: an explicit list of [children].
class SliverChildListDelegate extends SliverChildDelegate {
  /// Creates a delegate over [children].
  const SliverChildListDelegate(
    this.children, {
    this.addAutomaticKeepAlives = true,
    this.addRepaintBoundaries = true,
    this.addSemanticIndexes = true,
  });

  /// The items.
  final List<Widget> children;

  /// Accepted so Flutter code compiles; changes nothing.
  // web: the browser owns the items' lifetime.
  final bool addAutomaticKeepAlives;

  /// Accepted so Flutter code compiles; changes nothing.
  // web: the browser owns painting.
  final bool addRepaintBoundaries;

  /// Accepted so Flutter code compiles; changes nothing.
  // web: the DOM order is the semantic order.
  final bool addSemanticIndexes;

  @override
  int? get estimatedChildCount => children.length;

  @override
  Widget? build(BuildContext context, int index) =>
      index < children.length ? children[index] : null;
}

/// Every item [delegate] makes, in order (the render of a page builds them
/// all). Shared by [SliverList] and `SliverGrid`.
List<Widget> sliverItems(
  BuildContext context,
  SliverChildDelegate delegate, {
  String owner = 'SliverList',
}) {
  if (delegate case SliverChildListDelegate(:final children)) return children;
  final count = delegate.estimatedChildCount;
  final out = <Widget>[];
  for (var i = 0; count == null || i < count; i++) {
    if (count == null && i >= _unboundedItemCap) {
      throw StateError(
        '$owner has no child count and its builder did not return null '
        'after $_unboundedItemCap items. Return null from the builder to end '
        'the list, or give a childCount.',
      );
    }
    final item = delegate.build(context, i);
    if (item == null) break;
    out.add(item);
  }
  return out;
}

// What every sliver is: a block that spans the view's width, whose children
// stack down it.
const _sliverCss = <String, String>{
  'display': 'flex',
  'flex-direction': 'column',
  'align-items': 'stretch',
  'box-sizing': 'border-box',
  'min-width': '0',
};

/// Flutter's `SliverList`: items stacked down a `CustomScrollView`.
///
/// ```dart
/// CustomScrollView(slivers: [
///   SliverList.builder(itemCount: rows.length, itemBuilder: (c, i) => RowTile(rows[i])),
/// ])
/// ```
class SliverList extends StatelessWidget
    implements LayoutHint, ThorElementWidget, ThorBuiltIn {
  /// Creates a list of the items [delegate] makes.
  const SliverList({super.key, required this.delegate});

  /// Creates a list of [itemCount] items made by [itemBuilder].
  SliverList.builder({
    super.key,
    required NullableIndexedWidgetBuilder itemBuilder,
    int? itemCount,
  }) : delegate = SliverChildBuilderDelegate(
         itemBuilder,
         childCount: itemCount,
       );

  /// Creates a list of [children].
  SliverList.list({super.key, required List<Widget> children})
    : delegate = SliverChildListDelegate(children);

  /// Creates a list of [itemCount] items with a separator between each.
  SliverList.separated({
    super.key,
    required NullableIndexedWidgetBuilder itemBuilder,
    required IndexedWidgetBuilder separatorBuilder,
    int? itemCount,
  }) : delegate = SliverChildBuilderDelegate(
         _separatedBuilder(itemBuilder, separatorBuilder, itemCount),
         childCount: itemCount == null ? null : math.max(0, itemCount * 2 - 1),
       );

  // Items and separators interleaved. With no [itemCount] a separator is
  // only made when an item follows it, so that item is built to find out
  // (once: the next even index takes it instead of building it again).
  static NullableIndexedWidgetBuilder _separatedBuilder(
    NullableIndexedWidgetBuilder itemBuilder,
    IndexedWidgetBuilder separatorBuilder,
    int? itemCount,
  ) {
    Widget? peeked;
    var peekedAt = -1;
    return (context, index) {
      final item = index ~/ 2;
      if (index.isEven) {
        if (peekedAt == item) {
          final w = peeked;
          peeked = null;
          peekedAt = -1;
          return w;
        }
        return itemBuilder(context, item);
      }
      if (itemCount == null) {
        final next = itemBuilder(context, item + 1);
        if (next == null) return null;
        peeked = next;
        peekedAt = item + 1;
      }
      return separatorBuilder(context, item);
    };
  }

  /// Where the items come from.
  final SliverChildDelegate delegate;

  @override
  bool get fillsWidth => true;

  @override
  Widget build(BuildContext context) => thorElement(
    'div',
    debugName: 'SliverList',
    fillsWidth: true,
    css: _sliverCss,
    childRules: ChildRules.column,
    children: sliverItems(context, delegate),
  );
}

/// Flutter's `SliverFixedExtentList`: like [SliverList], every item
/// [itemExtent] tall.
class SliverFixedExtentList extends StatelessWidget
    implements LayoutHint, ThorElementWidget, ThorBuiltIn {
  /// Creates a list of the items [delegate] makes, each [itemExtent] tall.
  const SliverFixedExtentList({
    super.key,
    required this.delegate,
    required this.itemExtent,
  });

  /// Creates a list of [itemCount] items made by [itemBuilder].
  SliverFixedExtentList.builder({
    super.key,
    required NullableIndexedWidgetBuilder itemBuilder,
    required this.itemExtent,
    int? itemCount,
  }) : delegate = SliverChildBuilderDelegate(
         itemBuilder,
         childCount: itemCount,
       );

  /// Where the items come from.
  final SliverChildDelegate delegate;

  /// The height of every item.
  final double itemExtent;

  @override
  bool get fillsWidth => true;

  @override
  Widget build(BuildContext context) => thorElement(
    'div',
    debugName: 'SliverFixedExtentList',
    fillsWidth: true,
    css: _sliverCss,
    childRules: ChildRules(
      all: {...ChildRules.column.all, 'height': cssPx(itemExtent)},
      fillWidth: ChildRules.column.fillWidth,
      fillHeight: ChildRules.column.fillHeight,
    ),
    children: sliverItems(context, delegate, owner: 'SliverFixedExtentList'),
  );
}

/// Flutter's `SliverToBoxAdapter`: an ordinary widget inside a
/// `CustomScrollView`.
class SliverToBoxAdapter extends StatelessWidget
    implements LayoutHint, ThorElementWidget, ThorBuiltIn {
  /// Creates an adapter around [child].
  const SliverToBoxAdapter({super.key, this.child});

  /// The widget shown in the view.
  final Widget? child;

  @override
  bool get fillsWidth => true;

  @override
  Widget build(BuildContext context) => thorElement(
    'div',
    debugName: 'SliverToBoxAdapter',
    fillsWidth: true,
    css: _sliverCss,
    childRules: ChildRules.column,
    children: [?child],
  );
}

/// Flutter's `SliverPadding`: space around a [sliver].
class SliverPadding extends StatelessWidget
    implements LayoutHint, ThorElementWidget, ThorBuiltIn {
  /// Creates padding around [sliver].
  const SliverPadding({super.key, required this.padding, this.sliver});

  /// The space around the sliver.
  final EdgeInsetsGeometry padding;

  /// The sliver inside.
  final Widget? sliver;

  @override
  bool get fillsWidth => true;

  @override
  Widget build(BuildContext context) => thorElement(
    'div',
    debugName: 'SliverPadding',
    fillsWidth: true,
    css: {
      ..._sliverCss,
      ...padding.toCss('padding'),
      // Around a box that fills the rest of the view: it fills it too.
      if (resolveComponent(sliver) is SliverFillRemaining) 'flex-grow': '1',
    },
    childRules: ChildRules.column,
    children: [?sliver],
  );
}

/// Flutter's `SliverFillRemaining`: a box that takes what is left of the
/// view after the slivers before it (all of it, if they are shorter).
///
/// With [hasScrollBody] (Flutter's default) the [child] is stretched to the
/// remaining space (a scrollable fills it); with `false` it keeps its own
/// size at the top of the box.
///
/// `// web:` [fillOverscroll] needs the overscroll the browser does not
/// report to CSS: it is accepted and the box ends where the content does.
class SliverFillRemaining extends StatelessWidget
    implements LayoutHint, ThorElementWidget, ThorBuiltIn {
  /// Creates a box that fills the rest of the view.
  const SliverFillRemaining({
    super.key,
    this.child,
    this.hasScrollBody = true,
    this.fillOverscroll = false,
  });

  /// The widget in the box.
  final Widget? child;

  /// Whether [child] is a scrollable that fills the remaining space.
  final bool hasScrollBody;

  /// Accepted so Flutter code compiles; changes nothing.
  // web: the browser does not tell CSS about overscroll.
  final bool fillOverscroll;

  @override
  bool get fillsWidth => true;

  @override
  Widget build(BuildContext context) => thorElement(
    'div',
    debugName: 'SliverFillRemaining',
    fillsWidth: true,
    css: {..._sliverCss, 'flex-grow': '1', 'min-height': '0'},
    childRules: hasScrollBody ? ChildRules.box : ChildRules.column,
    children: [?child],
  );
}
