import 'package:thor_engine/thor_engine.dart' show untracked;
import 'package:thor_style/thor_style.dart';

import '../core/core.dart';
import '../engine/watch.dart' show WatchAttributes;
import '../foundation/child_rules.dart';
import '../foundation/element.dart';
import '../foundation/html_attributes.dart';
import '../foundation/layout_hint.dart';
import '../foundation/parent_data.dart';
import '../foundation/style_registry.dart' show ConditionalCss, CssCondition;
import '../foundation/transparent.dart';

/// Flutter's `Stack`.
///
/// Implemented as a single-cell CSS grid (every child in `grid-area: 1/1`)
/// instead of relative/absolute positioning, so the Stack sizes to its
/// largest non-positioned child — exactly Flutter's behavior. [Positioned]
/// children are taken out of flow with `position: absolute`.
class Stack extends StatelessWidget
    implements LayoutHint, ThorElementWidget, ThorBuiltIn {
  /// Creates a stack.
  const Stack({
    super.key,
    this.alignment = Alignment.topLeft,
    this.fit = StackFit.loose,
    this.clipBehavior = Clip.hardEdge,
    this.children = const [],
  });

  /// How to align non-positioned children (`place-items`).
  final AlignmentGeometry alignment;

  /// How to size the stack relative to its non-positioned children.
  final StackFit fit;

  /// Whether to clip children that overflow the stack (`overflow`).
  final Clip clipBehavior;

  /// The stack's children, painted in order.
  final List<Widget> children;

  /// Flutter: a Stack with no non-positioned children (or `StackFit.expand`)
  /// takes the biggest size its constraints allow.
  @override
  bool get fillsWidth =>
      fit == StackFit.expand ||
      children.every(_positioned) ||
      children.where((c) => !_positioned(c)).any(layoutFillsWidth);

  @override
  Widget build(BuildContext context) => thorElement(
    'div',
    debugName: 'Stack',
    fillsWidth: fillsWidth,
    childRules: ChildRules.stack,
    css: {
      'display': 'grid',
      'position': 'relative',
      'place-items': fit == StackFit.expand
          ? 'stretch'
          : (alignment.isKeyword ? alignment.placeItems : 'start'),
      if (fit == StackFit.expand) ...{'width': '100%', 'height': '100%'},
      if (clipBehavior != Clip.none) 'overflow': clipBehavior.css,
    },
    children: _aligned(children, alignment),
  );
}

/// [children] with the stack's fractional [alignment] applied to the
/// non-positioned ones, the technique `Align` uses: the cell's `place-items`
/// is `start` and each child gets `left: p%; top: q%; translate: -p% -q%`.
/// The nine named alignments are `place-items` keywords, so nothing changes.
List<Widget> _aligned(List<Widget> children, AlignmentGeometry alignment) {
  if (alignment.isKeyword) return children;
  final css = alignment.fractionalChildCss();
  return [
    for (final c in children)
      _positioned(c) ? c : WrapWith(WrapData(css: css), child: c),
  ];
}

/// The attribute that holds the shown child of an [IndexedStack].
const _indexAttribute = AttributeName('data-stack-index');

/// Flutter's `IndexedStack`: a [Stack] that shows one child, the one at
/// [index], and keeps the others in the page.
///
/// ```dart
/// IndexedStack(index: 1, children: [Feed(), Search(), Profile()])
/// // the index in a ThorState (a tab bar's selection, a step):
/// IndexedStack.watch(nav.current, children: [Feed(), Search(), Profile()])
/// ```
///
/// `// web:` the children are all there, in one grid cell, so the stack is
/// as big as the biggest one (like Flutter's); the hidden ones are
/// `visibility: hidden` (no focus, no pointer, out of the accessibility
/// tree, no JS), chosen by rules of the stack's class on its
/// `data-stack-index`. [IndexedStack.watch] binds that attribute to a state
/// method, so the browser only flips the attribute: no rebuild, no
/// generated style. Every child is rendered by the server even when it is
/// never shown (Flutter builds them all too).
class IndexedStack extends StatelessWidget
    implements LayoutHint, ThorElementWidget, ThorBuiltIn {
  /// Shows the child at [index] (`null`: none).
  const IndexedStack({
    super.key,
    this.alignment = Alignment.topLeft,
    this.sizing = StackFit.loose,
    this.clipBehavior = Clip.hardEdge,
    this.index = 0,
    this.children = const [],
  }) : _source = null;

  /// Shows the child at the index [source] returns (a `ThorState` method
  /// returning `int?`), kept current in the browser.
  ///
  /// `// web:` no Flutter counterpart: Flutter rebuilds with a new `index`.
  IndexedStack.watch(
    int? Function() source, {
    super.key,
    this.alignment = Alignment.topLeft,
    this.sizing = StackFit.loose,
    this.clipBehavior = Clip.hardEdge,
    this.children = const [],
  }) : index = untracked(source),
       _source = source;

  /// How to align the children (see [Stack.alignment]).
  final AlignmentGeometry alignment;

  /// How to size the stack relative to its children (see [Stack.fit]).
  final StackFit sizing;

  /// Whether to clip children that overflow the stack.
  final Clip clipBehavior;

  /// The child shown: null shows none, and a number outside the children is
  /// a `RangeError` (Flutter's assertion) instead of an empty box.
  final int? index;

  /// The children, all kept in the page.
  final List<Widget> children;

  final int? Function()? _source;

  @override
  bool get fillsWidth =>
      sizing == StackFit.expand || children.any(layoutFillsWidth);

  @override
  Widget build(BuildContext context) {
    final i = index;
    if (i != null && children.isNotEmpty && (i < 0 || i >= children.length)) {
      throw RangeError.range(
        i,
        0,
        children.length - 1,
        'index',
        'IndexedStack.index is outside its ${children.length} children',
      );
    }
    final element = thorElement(
      'div',
      debugName: 'IndexedStack',
      fillsWidth: fillsWidth,
      childRules: ChildRules.stack,
      css: {
        'display': 'grid',
        'position': 'relative',
        'place-items': sizing == StackFit.expand
            ? 'stretch'
            : (alignment.isKeyword ? alignment.placeItems : 'start'),
        if (sizing == StackFit.expand) ...{'width': '100%', 'height': '100%'},
        if (clipBehavior != Clip.none) 'overflow': clipBehavior.css,
      },
      conditions: [
        const ConditionalCss(CssCondition.children, {'visibility': 'hidden'}),
        // One rule per child: the attribute picks which is shown.
        for (var n = 0; n < children.length; n++)
          ConditionalCss(
            CssCondition.selector(
              '[$_indexAttribute="$n"] > :nth-child(${n + 1})',
            ),
            // web: `inherit`, not `visible`: an explicit `visible` would
            // show this child inside an outer stack's hidden child.
            const {'visibility': 'inherit'},
          ),
      ],
      attributes: {_indexAttribute: '${i ?? ''}'},
      children: _aligned(children, alignment),
    );
    final source = _source;
    return source == null
        ? element
        : WatchAttributes({_indexAttribute: source}, child: element);
  }
}

/// Flutter's `Positioned`. Decorates the child element; no extra node.
class Positioned extends ParentDataWrapper {
  /// Positions `child` inside its `Stack`.
  const Positioned({
    super.key,
    this.left,
    this.top,
    this.right,
    this.bottom,
    this.width,
    this.height,
    this.leftLength,
    this.topLength,
    this.rightLength,
    this.bottomLength,
    this.widthLength,
    this.heightLength,
    required super.child,
  });

  /// Pins `child` to all four edges of its `Stack`.
  const Positioned.fill({
    super.key,
    this.left = 0,
    this.top = 0,
    this.right = 0,
    this.bottom = 0,
    required super.child,
  }) : width = null,
       height = null,
       leftLength = null,
       topLength = null,
       rightLength = null,
       bottomLength = null,
       widthLength = null,
       heightLength = null;

  /// Distance from the stack's left edge.
  final double? left;

  /// Distance from the stack's top edge.
  final double? top;

  /// Distance from the stack's right edge.
  final double? right;

  /// Distance from the stack's bottom edge.
  final double? bottom;

  /// Fixed width, overriding the stack's sizing.
  final double? width;

  /// Fixed height, overriding the stack's sizing.
  final double? height;

  /// [left] as a [Length]: a state value that moves in the browser
  /// (`Positioned(leftLength: drag.x.px, …)`), or a unit Flutter doesn't
  /// have (`50.percent`). `// web:` the `*Length` offsets and sizes are the
  /// same properties for what a `double` can't say; one or the other.
  final Length? leftLength;

  /// [top] as a [Length].
  final Length? topLength;

  /// [right] as a [Length].
  final Length? rightLength;

  /// [bottom] as a [Length].
  final Length? bottomLength;

  /// [width] as a [Length].
  final Length? widthLength;

  /// [height] as a [Length].
  final Length? heightLength;

  @override
  WrapData get wrapData {
    assert(
      (left == null || leftLength == null) &&
          (top == null || topLength == null) &&
          (right == null || rightLength == null) &&
          (bottom == null || bottomLength == null) &&
          (width == null || widthLength == null) &&
          (height == null || heightLength == null),
      'Positioned takes an offset or its *Length, not both',
    );
    return WrapData(
      css: {
        'position': 'absolute',
        if (left != null) 'left': cssPx(left!),
        if (top != null) 'top': cssPx(top!),
        if (right != null) 'right': cssPx(right!),
        if (bottom != null) 'bottom': cssPx(bottom!),
        if (width != null) 'width': cssPx(width!),
        if (height != null) 'height': cssPx(height!),
        if (leftLength != null) 'left': leftLength!.css,
        if (topLength != null) 'top': topLength!.css,
        if (rightLength != null) 'right': rightLength!.css,
        if (bottomLength != null) 'bottom': bottomLength!.css,
        if (widthLength != null) 'width': widthLength!.css,
        if (heightLength != null) 'height': heightLength!.css,
      },
    );
  }
}

/// Whether [child] is a [Positioned] (written inline or built by an app
/// component).
bool _positioned(Widget child) => resolveComponent(child) is Positioned;
