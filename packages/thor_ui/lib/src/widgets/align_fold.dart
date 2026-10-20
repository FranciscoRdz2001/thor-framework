import 'package:thor_style/thor_style.dart';

import '../core/core.dart';
import '../foundation/child_rules.dart';
import '../foundation/layout_hint.dart';
import '../foundation/parent_data.dart';
import '../foundation/transparent.dart' show resolveComponent;
import 'basic.dart' show Container, SizedBox;
import 'flex.dart' show Flex, Flexible;
import 'grid.dart' show Grid;
import 'text.dart' show Text;

/// Align folding: a horizontally centered `Align`/`Center` around a
/// `Row`, `Column`, `Grid`, `Container` or `Text` (`Center(child: ConstrainedBox(
/// constraints: BoxConstraints(maxWidth: 1160), child: Column(…)))`, the
/// page-width container of every section of a landing) renders no element
/// of its own: the child is centered by auto margins, which is what the
/// `Align` did inside its element. A child that takes the max width and
/// caps it keeps `width: 100%` under its `max-width`. In a box that may be
/// taller than the child, the vertical position is an auto margin too.
/// Null when it can't fold.
///
/// Only where the result is the same layout:
/// - the parent is a column box: a sized box (`ChildRules.box`), where the
///   `Align` fills it, or a `Column`, where the `Align` is as tall as its
///   child (the vertical alignment does nothing) and auto margins beat the
///   column's own cross alignment;
/// - no wrapper data waits for the `Align`'s element (a `Padding` around it
///   is outside the centered box, an `Expanded` makes it a flex item),
///   except one that only names it ([_onlyNames]: `Semantics(role:
///   region)`, a landmark tag, an `aria-label`), which names the child's
///   element instead: the landmark costs no node;
/// - the child has no margins of its own (thor's `Row`/`Column`/`Grid`/
///   `Text`, a `Container` whose only constraint is a `maxWidth`, without
///   `margin` or, in a Column, with a fixed one (centered by `align-self`),
///   or a `SizedBox(height:)` around a `Row`/`Column`) and its
///   node-less wrappers set no margin nor a tag other than a landmark;
/// - a child that takes the max width caps it (without a cap, the `Align`
///   stretched it: nothing to fold).
///
/// `// web:` a child taller than a sized box overflows at the bottom (auto
/// margins) instead of on both sides (`justify-content: center`).
Widget? foldAlign(
  BuildContext context,
  AlignmentGeometry alignment,
  Widget? child,
) {
  if (child == null ||
      !alignment.isKeyword ||
      !alignment.isHorizontallyCentered) {
    return null;
  }
  final scope = ChildRulesScope.maybeOf(context);
  if (scope == null) return null;
  if (scope.pending case final pending? when !_onlyNames(pending)) {
    return null;
  }
  final parent = scope.rules;
  final box = identical(parent, ChildRules.box);
  if (!box &&
      !identical(parent, ChildRules.column) &&
      !identical(parent, ChildRules.columnAligned)) {
    return null;
  }
  // Through app components too: the wrapper data reaches the
  // element the component builds.
  var data = const WrapData();
  Widget? leaf = resolveComponent(child);
  while (leaf is ParentDataWrapper) {
    if (leaf is Flexible) return null;
    data = data.merge(leaf.wrapData);
    leaf = resolveComponent(leaf.child);
  }
  // A height around a flex is its own (`SizedBox` merges into it).
  if (leaf is SizedBox && leaf.width == null) {
    final inner = resolveComponent(leaf.child);
    if (inner is Flex) leaf = inner;
  }
  final grid = leaf is Grid;
  // A Container's own `max-width` (also per breakpoint): it caps the child
  // like a `ConstrainedBox` around it would.
  final own = leaf is Container ? _maxWidthOnly(leaf.constraints) : null;
  // A Container's fixed horizontal margin (`EdgeInsets.symmetric(horizontal:
  // 16)`) in a Column: centered by `align-self` instead of auto margins, its
  // width less the margin. Not in a sized box (the vertical auto margin).
  final margin = leaf is Container && leaf.margin != null && !box
      ? ChildRules.marginSum(leaf.margin!.toCss('margin'))
      : null;
  if (!(leaf is Flex ||
      grid ||
      (leaf is Container &&
          own != null &&
          (leaf.margin == null || (margin != null && own.isNotEmpty))) ||
      (leaf is Text && leaf.runtimeType == Text))) {
    return null;
  }
  if (data.flexible || !_landmark(data.tag) || _margin(data)) {
    return null;
  }
  final fills = !data.fixesWidth && (data.fillsWidth || layoutFillsWidth(leaf));
  if (fills &&
      !ChildRules.capsWidth(
        [data.css, data.classCss, ?own],
        [for (final c in data.conditions) c.css],
      )) {
    return null;
  }
  // Its own max width stays: `max-width: 100%` would beat it.
  final capped = own != null && own.isNotEmpty;
  return WrapWith(
    WrapData(
      css: {
        if (grid) 'min-width': '0',
        if (margin != null)
          // web: not auto margins, the child's own would replace them; a
          // child wider than the Column overflows both ways, like the Center.
          'align-self': 'center'
        else if (box && alignment.y == 0)
          'margin': 'auto'
        else
          'margin-inline': 'auto',
        if (box) ...{
          'flex': '0 1 auto',
          if (alignment.y > 0) 'margin-top': 'auto',
        },
        if (fills) ...{
          'box-sizing': 'border-box',
          'width': margin == null || margin.isEmpty
              ? '100%'
              : 'calc(100% - $margin)',
        }
        // Within its parent, like the `Align`'s children.
        else if (!capped)
          'max-width': '100%',
      },
    ),
    child: child,
  );
}

/// The CSS of [constraints] when they only set a `maxWidth` (or nothing),
/// per breakpoint too; null when they set anything else (a min width, a
/// height: the `Align` positioned that box, its auto margins would not).
CssDeclarations? _maxWidthOnly(BoxConstraints? constraints) {
  if (constraints == null) return const {};
  final css = constraints.toCss();
  return css.keys.every((k) => k == 'max-width') ? css : null;
}

/// Whether [tag] (a wrapper's) leaves the box as it was: none, or a
/// sectioning landmark (a block with no styles of its own in thor). Not a
/// list, a button or a heading: those bring resets or a different box.
bool _landmark(String? tag) =>
    tag == null ||
    const {
      'section',
      'main',
      'nav',
      'aside',
      'header',
      'footer',
      'article',
    }.contains(tag);

/// Whether the wrapper data waiting for the `Align`'s element only names
/// it (a landmark tag, an `id`, a `role`, `aria-*`): it can name the
/// folded child's element instead, the box is the same. Anything with
/// layout, styles, events or classes keeps the `Align`'s element.
bool _onlyNames(WrapData data) =>
    _landmark(data.tag) &&
    data.css.isEmpty &&
    data.classCss.isEmpty &&
    data.baseCss.isEmpty &&
    data.conditions.isEmpty &&
    data.classes.isEmpty &&
    !data.flexible &&
    !data.fillsWidth &&
    !data.fixesWidth &&
    !data.fillsHeight &&
    data.viewTransitionName == null &&
    !data.closesDialog &&
    data.attributes.keys.every(
      (k) => k == 'id' || k == 'role' || k.startsWith('aria-'),
    );

/// Whether [data] sets any margin (the auto margins would fight it).
bool _margin(WrapData data) {
  for (final css in [
    data.css,
    data.classCss,
    for (final c in data.conditions) c.css,
  ]) {
    for (final key in css.keys) {
      if (key.startsWith('margin')) return true;
    }
  }
  return false;
}
