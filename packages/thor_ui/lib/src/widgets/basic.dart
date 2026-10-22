import 'package:thor_style/thor_style.dart';

import '../core/core.dart';
import '../foundation/child_rules.dart';
import '../foundation/element.dart';
import '../foundation/layout_hint.dart';
import '../foundation/parent_data.dart';
import '../foundation/transparent.dart';
import 'align_fold.dart' show foldAlign;
import 'flex.dart' show Flex, Wrap;
import 'icon.dart' show Icon;
import 'scroll.dart' show GridView, ListView, SingleChildScrollView;
import 'text.dart' show Text;

CssDeclarations _size(
  double? width,
  double? height, [
  Length? widthLength,
  Length? heightLength,
]) => {
  if (width != null) 'width': cssPx(width),
  if (height != null) 'height': cssPx(height),
  if (widthLength != null) 'width': widthLength.css,
  if (heightLength != null) 'height': heightLength.css,
};

/// A box: Flutter's box model on a column flexbox. The box sizes to its child
/// when unconstrained; when sized, the child is stretched across
/// (`align-items: stretch`) and down (`flex-grow`) — tight constraints.
/// (A single-cell grid gives the same result but costs ~6x more layout time
/// at scale.)
const boxCss = <String, String>{
  'display': 'flex',
  'flex-direction': 'column',
  'box-sizing': 'border-box',
  'min-width': '0',
  'min-height': '0',
};

/// Resets a list's (`<ul>`/`<ol>`) UA bullets and indentation, so a Row,
/// Column or ListView with a list tag lays out like a `<div>`.
const listResetCss = <String, String>{
  'list-style': 'none',
  'margin': '0',
  'padding': '0',
};

/// Resets a `<button>`'s UA chrome so it renders exactly like a `<div>` box.
const buttonResetCss = <String, String>{
  'appearance': 'none',
  'border': '0',
  'margin': '0',
  'padding': '0',
  'font': 'inherit',
  'color': 'inherit',
  'background': 'none',
  'text-align': 'inherit',
  'cursor': 'pointer',
};

/// Flutter's `Container`.
///
/// One `<div>`: sizes to its child when unconstrained, stretches
/// the child when [width]/[height]/[constraints] are set, positions it (with
/// loose constraints) when [alignment] is set.
class Container extends StatelessWidget
    implements LayoutHint, ThorElementWidget, ThorBuiltIn {
  /// Creates a box that positions, sizes and decorates [child].
  const Container({
    super.key,
    this.alignment,
    this.padding,
    this.color,
    this.decoration,
    this.width,
    this.height,
    this.constraints,
    this.margin,
    this.transform,
    this.transformAlignment,
    this.clipBehavior = Clip.none,
    this.child,
  }) : assert(
         color == null || decoration == null,
         'Cannot provide both a color and a decoration.',
       );

  /// How to align [child] within the container (loosens its constraints).
  final AlignmentGeometry? alignment;

  /// Empty space inserted inside the decoration/color, around [child].
  final EdgeInsetsGeometry? padding;

  /// Background color. Mutually exclusive with [decoration].
  final Color? color;

  /// Background painted behind [child]. Mutually exclusive with [color].
  final BoxDecoration? decoration;

  /// Container width, in logical pixels; `double.infinity` fills the
  /// available width.
  final double? width;

  /// Container height, in logical pixels; `double.infinity` fills the
  /// available height.
  final double? height;

  /// Additional min/max size constraints applied to the container.
  final BoxConstraints? constraints;

  /// Empty space surrounding the decoration/color and [child].
  final EdgeInsetsGeometry? margin;

  /// Whether and how to clip content that overflows the container.
  final Clip clipBehavior;

  /// A transform applied to the container and its child (a CSS `transform`:
  /// it paints on the compositor and does not move the layout, like
  /// Flutter's).
  final Matrix4? transform;

  /// Where [transform] is anchored. `// web:` null is the top-left corner
  /// like Flutter (CSS would use the center), so the matrix means the same.
  final Alignment? transformAlignment;

  /// The widget below this one in the tree.
  final Widget? child;

  /// Flutter: a Container with an alignment, or whose child wants the max
  /// width, expands; an explicit width wins.
  @override
  bool get fillsWidth =>
      width == double.infinity ||
      (width == null && (alignment != null || layoutFillsWidth(child)));

  @override
  Widget build(BuildContext context) {
    assert(
      padding?.isNonNegative ?? true,
      'Container padding must be non-negative.',
    );
    assert(
      margin?.isNonNegative ?? true,
      'Container margin must be non-negative.',
    );
    final fractional = alignment != null && !alignment!.isKeyword;
    final box = <String, String>{
      ..._size(width, height),
      ...?constraints?.toCss(),
      if (padding != null) ...padding!.toCss('padding'),
      if (margin != null) ...margin!.toCss('margin'),
      if (color != null) 'background-color': color!.css,
      ...?decoration?.toCss(),
      if (clipBehavior != Clip.none) 'overflow': clipBehavior.css,
      if (transform != null) ...{
        'transform': transform!.css,
        'transform-origin': transformAlignment?.cssPosition ?? '0 0',
      },
    };
    final merged = _mergeIntoFlex(box, fillsWidth, alignment, child);
    if (merged != null) return merged;
    final text = _textContent(child, alignment);
    if (text != null) {
      return thorElement(
        'div',
        debugName: 'Container',
        fillsWidth: fillsWidth,
        css: {
          ...boxCss,
          ...box,
          if (alignment != null) ..._textAlignCss(alignment!),
          ...text.css,
        },
        children: [Widget.text(text.data)],
      );
    }
    return thorElement(
      'div',
      debugName: 'Container',
      fillsWidth: fillsWidth,
      css: {
        ...boxCss,
        ...box,
        if (alignment != null)
          'justify-content': fractional ? 'flex-start' : alignment!.flexJustify,
      },
      childRules: alignment == null
          ? ChildRules.box
          : ChildRules.aligned(fractional ? Alignment.topLeft : alignment!),
      children: [
        if (child != null)
          fractional
              ? WrapWith(
                  WrapData(css: alignment!.fractionalChildCss()),
                  child: child!,
                )
              : child!,
      ],
    );
  }
}

/// Flutter's `SizedBox`. `double.infinity` maps to `100%`.
class SizedBox extends StatelessWidget
    implements LayoutHint, ThorElementWidget, ThorBuiltIn {
  /// Creates a box with a fixed [width] and [height].
  ///
  /// `// web:` [widthLength] and [heightLength] are the same sizes as a
  /// [Length], where a `double` can't say it: a state value that changes in
  /// the browser (`SizedBox(widthLength: grid.width.px)`), or a unit
  /// Flutter doesn't have (`100.dvh`).
  const SizedBox({
    super.key,
    this.width,
    this.height,
    this.widthLength,
    this.heightLength,
    this.child,
  }) : assert(
         width == null || widthLength == null,
         'SizedBox takes width or widthLength, not both',
       ),
       assert(
         height == null || heightLength == null,
         'SizedBox takes height or heightLength, not both',
       );

  /// Creates a box that fills the available space.
  const SizedBox.expand({super.key, this.child})
    : width = double.infinity,
      height = double.infinity,
      widthLength = null,
      heightLength = null;

  /// Creates a box with zero width and height.
  ///
  /// `// web:` outside a `Watch` it is a real `0 × 0` element, so a parent's
  /// `spacing` counts it, like Flutter's Column/Row do. As the whole state
  /// of a `Watch` (`Watch(…, builder: (on) => on ? x : SizedBox.shrink())`)
  /// it draws no box at all, so the empty state takes no `gap` slot.
  const SizedBox.shrink({super.key, this.child})
    : width = 0,
      height = 0,
      widthLength = null,
      heightLength = null;

  /// Creates a box with `width` and `height` both set to [dimension].
  const SizedBox.square({super.key, double? dimension, this.child})
    : width = dimension,
      height = dimension,
      widthLength = null,
      heightLength = null;

  /// Whether this is a childless `0 × 0` box (`SizedBox.shrink()`).
  bool get isEmptyShrink =>
      child == null &&
      width == 0 &&
      height == 0 &&
      widthLength == null &&
      heightLength == null;

  /// Box width, in logical pixels.
  final double? width;

  /// Box height, in logical pixels.
  final double? height;

  /// Box width as a [Length] (a `BoundLength`, a `calc()`, `100.vw`).
  final Length? widthLength;

  /// Box height as a [Length].
  final Length? heightLength;

  /// The widget below this one in the tree.
  final Widget? child;

  @override
  bool get fillsWidth =>
      width == double.infinity || (width == null && layoutFillsWidth(child));

  /// Flutter clamps a fixed width to the parent's max width: `max-width:
  /// 100%` where the parent bounds its children's width (a column, a box,
  /// an aligned box). Not in a row or a horizontal scroll view: there the
  /// width is unbounded and Flutter keeps it (and overflows).
  CssDeclarations _clamp(BuildContext context) {
    final w = width;
    if (w == null || !w.isFinite || w <= 0) return const {};
    final rules = ChildRulesScope.maybeOf(context)?.rules;
    final bounded =
        identical(rules, ChildRules.box) ||
        rules?.fillWidth['align-self'] == 'stretch';
    return bounded ? const {'max-width': '100%'} : const {};
  }

  @override
  Widget build(BuildContext context) {
    final c = child;
    final clamp = _clamp(context);
    // A Text is a leaf without decoration: the size goes on its element
    // (through any wrappers around it, e.g. an engine field marker).
    if (_isTextLeaf(c)) {
      return WrapWith(
        WrapData(
          fillsWidth: width == double.infinity,
          baseCss: clamp,
          css: {
            ..._size(width, height, widthLength, heightLength),
            'flex': 'none',
          },
        ),
        child: c!,
      );
    }
    // A sized scroll view / flex takes the size itself: one element.
    final r = resolveComponent(c);
    if (r is Flex ||
        r is ListView ||
        r is GridView ||
        r is SingleChildScrollView) {
      return WrapWith(
        WrapData(
          fillsWidth: fillsWidth && !layoutFillsWidth(c),
          // A fixed width around a child that fills: it no longer does.
          fixesWidth: !fillsWidth && layoutFillsWidth(c),
          baseCss: clamp,
          css: _size(width, height, widthLength, heightLength),
        ),
        child: c!,
      );
    }
    return thorElement(
      'div',
      debugName: 'SizedBox',
      fillsWidth: fillsWidth,
      css: {
        if (child != null) ...boxCss,
        ..._size(width, height, widthLength, heightLength),
        ...clamp,
      },
      childRules: ChildRules.box,
      children: [?child],
    );
  }
}

/// Flutter's `Padding`.
class Padding extends StatelessWidget
    implements LayoutHint, ThorElementWidget, ThorBuiltIn {
  /// Creates a widget that insets [child] by [padding].
  const Padding({super.key, required this.padding, this.child});

  /// The amount of space to inset [child] by.
  final EdgeInsetsGeometry padding;

  /// The widget below this one in the tree.
  final Widget? child;

  @override
  bool get fillsWidth => layoutFillsWidth(child);

  @override
  Widget build(BuildContext context) {
    assert(padding.isNonNegative, 'Padding must be non-negative.');
    return padWith(
      padding.toCss('padding'),
      padding.toCss('margin'),
      child,
      fillsWidth: fillsWidth,
    );
  }
}

/// Flutter's `Align`. Expands in both axes (when bounded) and positions its
/// child with loose constraints; fractional alignments work too.
class Align extends StatelessWidget
    implements LayoutHint, HeightHint, ThorElementWidget, ThorBuiltIn {
  /// Creates a widget that aligns [child] within itself.
  const Align({super.key, this.alignment = Alignment.center, this.child});

  /// How to align [child]. Defaults to `Alignment.center`.
  final AlignmentGeometry alignment;

  /// The widget below this one in the tree.
  final Widget? child;

  @override
  bool get fillsWidth => true;

  @override
  bool get fillsHeight => true;

  @override
  Widget build(BuildContext context) {
    // A capped child that fills the width takes the position itself.
    if (foldAlign(context, alignment, child) case final folded?) return folded;
    final fractional = !alignment.isKeyword;
    final text = _textContent(child, alignment);
    if (text != null) {
      return thorElement(
        'div',
        debugName: kDebugMode ? runtimeType.toString() : null,
        fillsWidth: true,
        fillsHeight: true,
        css: {...boxCss, ..._textAlignCss(alignment), ...text.css},
        children: [Widget.text(text.data)],
      );
    }
    return thorElement(
      'div',
      debugName: kDebugMode ? runtimeType.toString() : null,
      fillsWidth: true,
      fillsHeight: true,
      css: {
        ...boxCss,
        'justify-content': fractional ? 'flex-start' : alignment.flexJustify,
      },
      childRules: ChildRules.aligned(
        fractional ? Alignment.topLeft : alignment,
      ),
      children: [
        if (child != null)
          fractional
              ? WrapWith(
                  WrapData(css: alignment.fractionalChildCss()),
                  child: child!,
                )
              : child!,
      ],
    );
  }
}

/// Flutter's `Center`.
class Center extends Align {
  /// Creates a widget that centers [child].
  const Center({super.key, super.child});
}

/// Flutter's `FittedBox`: sizes and positions [child] inside itself by
/// [fit], in CSS only (no measuring, no transform).
///
/// A media child (`Image`, an SVG, a video) is fitted exactly like
/// Flutter: the child fills the box and `object-fit` (the same keyword as
/// [BoxFit]) scales it, [alignment] places it (`object-position`). `// web:`
/// CSS cannot read the natural size of other content, so a box or a text
/// does not scale: [BoxFit.fill], [BoxFit.contain] and [BoxFit.cover] make
/// it fill the box, [BoxFit.scaleDown] caps it at the box (`max-width` /
/// `max-height`), [BoxFit.fitWidth] fills the width and [BoxFit.fitHeight]
/// the height, and [BoxFit.none] keeps its size, aligned inside the box.
///
/// ```dart
/// SizedBox(
///   width: 120,
///   height: 80,
///   child: FittedBox(fit: BoxFit.cover, child: Image.network('/logo.png')),
/// )
/// ```
class FittedBox extends StatelessWidget
    implements LayoutHint, HeightHint, ThorElementWidget, ThorBuiltIn {
  /// Creates a widget that fits [child] inside itself.
  const FittedBox({
    super.key,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
    this.clipBehavior = Clip.none,
    this.child,
  });

  /// How to size [child] inside the box (default: [BoxFit.contain]).
  final BoxFit fit;

  /// Where [child] sits when it does not fill the box (default: center).
  final AlignmentGeometry alignment;

  /// Whether what overflows the box is cut (default: [Clip.none]).
  final Clip clipBehavior;

  /// The widget to fit.
  final Widget? child;

  @override
  bool get fillsWidth => true;

  @override
  bool get fillsHeight => true;

  CssDeclarations _childCss() {
    final position = alignment.isKeyword
        ? null
        : alignment.fractionalChildCss();
    return {
      ...?position,
      'object-fit': fit.css,
      'object-position': _objectPosition(alignment),
      ...switch (fit) {
        BoxFit.fill ||
        BoxFit.contain ||
        BoxFit.cover => {'width': '100%', 'height': '100%'},
        BoxFit.fitWidth => {'width': '100%', 'height': 'auto'},
        BoxFit.fitHeight => {'width': 'auto', 'height': '100%'},
        BoxFit.scaleDown => {'max-width': '100%', 'max-height': '100%'},
        BoxFit.none => const {},
      },
      'box-sizing': 'border-box',
    };
  }

  // `Alignment(x, y)` → `object-position` (-1..1 → 0%..100%).
  static String _objectPosition(AlignmentGeometry a) {
    final al = a.resolve(TextDirection.ltr);
    return '${cssNum((al.x + 1) * 50)}% ${cssNum((al.y + 1) * 50)}%';
  }

  @override
  Widget build(BuildContext context) => thorElement(
    'div',
    debugName: kDebugMode ? runtimeType.toString() : null,
    fillsWidth: true,
    fillsHeight: true,
    css: {
      ...boxCss,
      'justify-content': alignment.isKeyword
          ? alignment.flexJustify
          : 'flex-start',
      if (clipBehavior != Clip.none) 'overflow': clipBehavior.css,
    },
    childRules: ChildRules.aligned(
      alignment.isKeyword ? alignment : Alignment.topLeft,
    ),
    children: [
      if (child != null) WrapWith(WrapData(css: _childCss()), child: child!),
    ],
  );
}

/// Flutter's `ConstrainedBox`. Applies min/max directly to the child element.
class ConstrainedBox extends ParentDataWrapper {
  /// Creates a widget that imposes additional constraints on [child].
  const ConstrainedBox({
    super.key,
    required this.constraints,
    required super.child,
  });

  /// The min/max constraints to impose on `child`.
  final BoxConstraints constraints;

  @override
  WrapData get wrapData => WrapData(css: constraints.toCss());
}

/// Flutter's `FractionallySizedBox`: sizes the child element to a fraction
/// of the available space (a percentage width/height, no extra node).
class FractionallySizedBox extends ParentDataWrapper {
  /// Sizes `child` to [widthFactor] × [heightFactor] of the parent.
  const FractionallySizedBox({
    super.key,
    this.widthFactor,
    this.heightFactor,
    required super.child,
  });

  /// Fraction of the parent's width (null: the child's own).
  final double? widthFactor;

  /// Fraction of the parent's height (null: the child's own).
  final double? heightFactor;

  static String _percent(double f) => '${cssNum(f * 100)}%';

  @override
  WrapData get wrapData => WrapData(
    fixesWidth: widthFactor != null,
    css: {
      if (widthFactor case final w?) 'width': _percent(w),
      if (heightFactor case final h?) 'height': _percent(h),
      'box-sizing': 'border-box',
    },
  );
}

/// Flutter's `AspectRatio` (`width / height`).
class AspectRatio extends StatelessWidget
    implements LayoutHint, HeightHint, ThorElementWidget, ThorBuiltIn {
  /// Creates a widget with a specific [aspectRatio].
  const AspectRatio({super.key, required this.aspectRatio, this.child});

  /// The desired `width / height` ratio.
  final double aspectRatio;

  /// The widget below this one in the tree.
  final Widget? child;

  @override
  bool get fillsWidth => true;

  @override
  bool get fillsHeight => true;

  @override
  Widget build(BuildContext context) => thorElement(
    'div',
    debugName: 'AspectRatio',
    fillsWidth: true,
    fillsHeight: true,
    css: {...boxCss, 'aspect-ratio': cssAspectRatio(aspectRatio)},
    childRules: ChildRules.box,
    children: [?child],
  );
}

/// Flutter's `DecoratedBox`.
class DecoratedBox extends StatelessWidget
    implements LayoutHint, ThorElementWidget, ThorBuiltIn {
  /// Creates a widget that paints [decoration] behind [child].
  const DecoratedBox({super.key, required this.decoration, this.child});

  /// What to paint behind `child`.
  final BoxDecoration decoration;

  /// The widget below this one in the tree.
  final Widget? child;

  @override
  bool get fillsWidth => layoutFillsWidth(child);

  @override
  Widget build(BuildContext context) => thorElement(
    'div',
    debugName: 'DecoratedBox',
    fillsWidth: fillsWidth,
    css: {...boxCss, ...decoration.toCss()},
    childRules: ChildRules.box,
    children: [?child],
  );
}

/// Flutter's `ColoredBox`.
class ColoredBox extends StatelessWidget
    implements LayoutHint, ThorElementWidget, ThorBuiltIn {
  /// Creates a widget that paints [color] behind [child].
  const ColoredBox({super.key, required this.color, this.child});

  /// The color to paint behind [child].
  final Color color;

  /// The widget below this one in the tree.
  final Widget? child;

  @override
  bool get fillsWidth => layoutFillsWidth(child);

  @override
  Widget build(BuildContext context) => thorElement(
    'div',
    debugName: 'ColoredBox',
    fillsWidth: fillsWidth,
    css: {...boxCss, 'background-color': color.css},
    childRules: ChildRules.box,
    children: [?child],
  );
}

/// Whether [c] ends (through parent-data wrappers) in a plain [Text]: a leaf
/// with no decoration, so size and padding can go on its own element.
bool _isTextLeaf(Widget? c) {
  final x = resolveLeaf(c);
  return x is Text && x.runtimeType == Text;
}

/// Text merging: a box whose only child is a plain [Text] renders the text
/// itself (one element instead of `div > span`). The text node becomes an
/// anonymous flex item: stretched across without alignment, shrink-wrapped
/// and centered with a horizontally centered one. Other horizontal
/// alignments keep the span (they need physical auto margins).
({CssDeclarations css, String data})? _textContent(
  Widget? child,
  AlignmentGeometry? alignment,
) {
  // Through app components too.
  final text = resolveComponent(child);
  if (text is! Text || text.runtimeType != Text || text.data == null) {
    return null;
  }
  if (alignment != null &&
      !(alignment.isKeyword && alignment.isHorizontallyCentered)) {
    return null;
  }
  final css = text.boxContentCss;
  return css == null ? null : (css: css, data: text.data!);
}

CssDeclarations _textAlignCss(AlignmentGeometry alignment) => {
  'justify-content': alignment.flexJustify,
  'align-items': 'center',
};

/// Box merging: a Container/Padding without alignment around a Row/Column
/// (or a [Wrap]) is rendered as that single flex element carrying the box's
/// padding, decoration and size.
///
/// Equivalent layout: the box was a column flexbox stretching its only child
/// in both axes, so the child already had exactly the box's content size.
Widget? _mergeIntoFlex(
  CssDeclarations box,
  bool boxFillsWidth,
  AlignmentGeometry? alignment,
  Widget? child,
) {
  // Through app components too: the component stays where it
  // is (its element is the flex's).
  final flex = resolveComponent(child);
  // A Wrap is a wrapping flex: stretched by the box the same way. Only
  // without alignment (it would loosen the Wrap's width).
  if (flex is Wrap && alignment == null) {
    return WrapWith(
      WrapData(
        fillsWidth: boxFillsWidth && !flex.fillsWidth,
        fixesWidth: !boxFillsWidth && flex.fillsWidth,
        css: box,
      ),
      child: child!,
    );
  }
  if (flex is! Flex) return null;
  // An aligned box gives its child loose constraints; a max-size Row then
  // takes the full width anyway, and with centered children a vertical
  // center alignment is what the Row's cross axis already does.
  if (alignment != null &&
      !(flex.direction == Axis.horizontal &&
          flex.mainAxisSize == MainAxisSize.max &&
          flex.crossAxisAlignment == CrossAxisAlignment.center &&
          alignment.y == 0 &&
          flex.layout == null)) {
    return null;
  }
  return WrapWith(
    WrapData(
      fillsWidth: boxFillsWidth && !flex.fillsWidth,
      // A fixed width around a max-size flex: the element no longer fills
      // its parent (centered by a Center, as in Flutter).
      fixesWidth: !boxFillsWidth && flex.fillsWidth,
      css: box,
    ),
    child: child!,
  );
}

/// [w] without the node-less wrappers around it (`Responsive(child: Icon)`),
/// through app components.
Widget? _leaf(Widget? w) => resolveLeaf(w);

/// Applies padding (per side, any CSS length incl. `calc(env(…) + 8px)`) the
/// cheapest equivalent way instead of always adding a `<div>`:
/// - around a decorated `Container` → the Container's **margin** (Flutter's
///   Padding is outside the child's decoration);
/// - around an `Align`/`Row`/`Column` → that element's own padding;
/// - around a fixed-size `Icon` (through node-less wrappers) → its margin.
Widget padInto(
  String top,
  String right,
  String bottom,
  String left,
  Widget? child, {
  required bool fillsWidth,
}) {
  final box = cssBox(top, right, bottom, left);
  return padWith(
    _boxMap('padding', box),
    _boxMap('margin', box),
    child,
    fillsWidth: fillsWidth,
  );
}

/// [padInto] for declarations already made ([EdgeInsetsGeometry.toCss] of
/// `padding` and of `margin`): the physical ones of an [EdgeInsets], the
/// logical ones of an [EdgeInsetsDirectional].
Widget padWith(
  CssDeclarations padding,
  CssDeclarations margin,
  Widget? child, {
  required bool fillsWidth,
}) {
  final c = child;
  // What an app component builds.
  final r = resolveComponent(c);
  // Around a box with no margin of its own, or a fixed-size icon, padding
  // is the same space as a margin on the child: one node less.
  // web: not when it fills the width or the height: `100%` plus a margin
  // would overflow by the margin (box-sizing does not cover it), so the
  // padding stays on its own element.
  if ((r is Container &&
          r.margin == null &&
          r.width != double.infinity &&
          r.height != double.infinity) ||
      _leaf(c) is Icon) {
    return WrapWith(WrapData(css: margin), child: c!);
  }
  // An Align or a Text has no decoration of its own: the padding goes on
  // its element (same box, one node less).
  if (r is Align || _isTextLeaf(c)) {
    return WrapWith(WrapData(css: padding), child: c!);
  }
  final merged = _mergeIntoFlex(padding, fillsWidth, null, c);
  if (merged != null) return merged;
  final text = _textContent(c, null);
  if (text != null) {
    return thorElement(
      'div',
      debugName: 'Padding',
      fillsWidth: fillsWidth,
      css: {...boxCss, ...padding, ...text.css},
      children: [Widget.text(text.data)],
    );
  }
  return thorElement(
    'div',
    debugName: 'Padding',
    fillsWidth: fillsWidth,
    css: _boxed[padding] ??= Map.unmodifiable({...boxCss, ...padding}),
    childRules: ChildRules.box,
    children: [?c],
  );
}

// A padded box (`boxCss` plus the padding), made once for each padding
// declarations: every Padding of every page asks.
final _boxed = Expando<CssDeclarations>('thor-padded-box');

/// `{property: box}`, made once per process for each value: every Padding
/// of every page asks.
CssDeclarations _boxMap(String property, String box) {
  final key = (property, box);
  final known = _boxMaps[key];
  if (known != null) return known;
  // Bounded: insets computed from data must not grow it forever.
  if (_boxMaps.length >= 1024) _boxMaps.clear();
  return _boxMaps[key] = Map.unmodifiable({property: box});
}

final _boxMaps = <(String, String), CssDeclarations>{};
