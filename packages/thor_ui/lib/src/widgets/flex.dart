import 'package:thor_style/thor_style.dart';

import '../core/core.dart';
import '../foundation/child_rules.dart';
import '../foundation/element.dart';
import '../foundation/layout_hint.dart';
import '../foundation/parent_data.dart';
import '../foundation/transparent.dart';
import 'basic.dart' show SizedBox;

/// Flutter's `VerticalDirection`: the order a `Column` stacks its children.
enum VerticalDirection {
  /// From the bottom up (`column-reverse`): the first child is the lowest.
  up,

  /// From the top down (the default).
  down,
}

/// Flex values a `Row`/`Column` switches per breakpoint (web extra), giving
/// only what changes. The variants are named parameters, so the value stays
/// `const`; `.when()` is the same thing as a method call:
///
/// ```dart
/// const Column(
///   spacing: 16,
///   layout: FlexLayout(medium: FlexLayout(direction: Axis.horizontal)),
///   children: [...],
/// )
/// // = FlexLayout().when(medium: FlexLayout(direction: Axis.horizontal))
/// ```
class FlexLayout extends ConstAdaptable<FlexLayout> {
  /// Flex values; unset ones keep the widget's own.
  const FlexLayout({
    this.direction,
    this.mainAxisAlignment,
    this.crossAxisAlignment,
    this.spacing,
    this.wrap,
    this.verticalDirection,
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

  /// Row (`Axis.horizontal`) or column.
  final Axis? direction;

  /// A column's order (`VerticalDirection.up` = `column-reverse`).
  final VerticalDirection? verticalDirection;

  /// `justify-content`.
  final MainAxisAlignment? mainAxisAlignment;

  /// `align-items`.
  final CrossAxisAlignment? crossAxisAlignment;

  /// `gap`.
  final double? spacing;

  // web: not in Flutter.
  /// Let children wrap onto new lines.
  final bool? wrap;

  @override
  FlexLayout withVariants(Adaptive<FlexLayout> variants) =>
      _AdaptiveFlexLayout(variants);

  /// The CSS of the values that are set, with the variants of
  /// the `.when()` or the constructor.
  CssDeclarations toCss() {
    final a = adaptive;
    if (a == null) return _ownCss();
    return a.declarations((l) => identical(l, this) ? _ownCss() : l.toCss());
  }

  CssDeclarations _ownCss() => {
    if (direction != null || verticalDirection != null)
      'flex-direction': direction == Axis.horizontal
          ? 'row'
          : verticalDirection == VerticalDirection.up
          ? 'column-reverse'
          : 'column',
    if (mainAxisAlignment != null) 'justify-content': mainAxisAlignment!.css,
    if (crossAxisAlignment != null) 'align-items': crossAxisAlignment!.css,
    if (spacing != null) 'gap': cssPx(spacing!),
    if (wrap != null) 'flex-wrap': wrap! ? 'wrap' : 'nowrap',
  };
}

class _AdaptiveFlexLayout extends FlexLayout {
  const _AdaptiveFlexLayout(this.adaptive);

  @override
  final Adaptive<FlexLayout> adaptive;

  @override
  CssDeclarations toCss() => adaptive.declarations((l) => l.toCss());
}

/// Flutter's `Flex`: a CSS flexbox with Flutter's defaults
/// (`crossAxisAlignment: center`, non-flex children never shrink).
class Flex extends StatelessWidget
    implements LayoutHint, HeightHint, ThorElementWidget, ThorBuiltIn {
  /// Creates a flex container along [direction].
  const Flex({
    super.key,
    required this.direction,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.mainAxisSize = MainAxisSize.max,
    this.crossAxisAlignment = CrossAxisAlignment.center,
    this.spacing = 0,
    this.textDirection,
    this.verticalDirection = VerticalDirection.down,
    this.textBaseline,
    this.layout,
    this.children = const [],
  }) : assert(
         crossAxisAlignment != CrossAxisAlignment.baseline ||
             textBaseline != null,
         'textBaseline is required with CrossAxisAlignment.baseline, as in '
         'Flutter',
       );

  /// The axis to lay children out along: `Axis.horizontal` (row) or
  /// `Axis.vertical` (column).
  final Axis direction;

  /// How to place children along the main axis (`justify-content`).
  final MainAxisAlignment mainAxisAlignment;

  /// Whether this flex should occupy the max or min main-axis extent.
  final MainAxisSize mainAxisSize;

  /// How to place children along the cross axis (`align-items`). Flutter
  /// default: center.
  final CrossAxisAlignment crossAxisAlignment;

  /// Space between children (Flutter 3.27+), maps to `gap`.
  final double spacing;

  /// The order of a Row's children: `rtl` lays them out from the right
  /// (`row-reverse`, so the page's own direction and the text inside are
  /// untouched). In a Column, `rtl` swaps the cross axis' start and end
  /// ([CrossAxisAlignment.start] is the right edge), like Flutter's.
  final TextDirection? textDirection;

  /// The order a Column stacks its children: `up` puts the first one at the
  /// bottom (`column-reverse`). In a Row, `up` swaps the cross axis' start
  /// and end ([CrossAxisAlignment.start] is the bottom edge), like
  /// Flutter's.
  final VerticalDirection verticalDirection;

  // The cross axis alignment with start and end swapped when the other
  // axis' direction flips it (a Row's `verticalDirection: up`, a Column's
  // `textDirection: rtl`).
  CrossAxisAlignment get _cross {
    final flipped = direction == Axis.horizontal
        ? verticalDirection == VerticalDirection.up
        : textDirection == TextDirection.rtl;
    if (!flipped) return crossAxisAlignment;
    return switch (crossAxisAlignment) {
      CrossAxisAlignment.start => CrossAxisAlignment.end,
      CrossAxisAlignment.end => CrossAxisAlignment.start,
      final other => other,
    };
  }

  /// The baseline [CrossAxisAlignment.baseline] uses (required with it, as
  /// in Flutter). `// web:` both line up on the alphabetic baseline (see
  /// [TextBaseline]).
  final TextBaseline? textBaseline;

  // web: not in Flutter.
  /// Flex values per breakpoint or state
  /// (`const FlexLayout().when(medium: FlexLayout(direction: Axis.horizontal))`).
  final FlexLayout? layout;

  /// The widgets to lay out.
  final List<Widget> children;

  /// A Row with MainAxisSize.max takes the max width; a Column does when it
  /// stretches its children or when any child takes the max width.
  @override
  bool get fillsWidth => direction == Axis.horizontal
      ? mainAxisSize == MainAxisSize.max
      : crossAxisAlignment == CrossAxisAlignment.stretch ||
            children.any(layoutFillsWidth);

  /// A Column with MainAxisSize.max takes the max height (stretches in a Row).
  @override
  bool get fillsHeight =>
      direction == Axis.vertical && mainAxisSize == MainAxisSize.max;

  // web: a margin folded onto the next child is written for the base
  // direction. A reversed flex (`row-reverse`, `column-reverse`) puts that
  // child before its neighbour, and a [layout] can turn the axis, so
  // neither folds: the Spacer/SizedBox stay elements.
  bool get _canFold =>
      layout == null &&
      !(direction == Axis.horizontal
          ? textDirection == TextDirection.rtl
          : verticalDirection == VerticalDirection.up);

  /// `Spacer` folding: a `Spacer()` between two children becomes an `auto`
  /// margin on the next one (free space goes to auto margins, split evenly,
  /// like `Spacer`s of flex 1), instead of an empty element. Only when no
  /// sibling is flexible (`Expanded`/`Flexible` take free space before auto
  /// margins do), every spacer has flex 1 and none is next to another or
  /// at an end. With [spacing] the layout is the same while the row has
  /// free space (the spacer's own gap goes into the margin); an
  /// overflowing row loses that one gap.
  List<Widget> _foldedSpacers(List<Widget> children) {
    if (!_canFold) return children;
    // Through app components too.
    bool flexible(Widget w) {
      Widget? c = resolveComponent(w);
      while (c is ParentDataWrapper) {
        if (c is Flexible) return true;
        c = resolveComponent(c.child);
      }
      return false;
    }

    // A wrapper that can hide the child (ResponsiveVisibility, Visibility,
    // Offstage: display/visibility, or any condition) would take the auto
    // margin with it: the space would go nowhere.
    bool mayHide(Widget w) {
      Widget? c = resolveComponent(w);
      while (c is ParentDataWrapper) {
        final data = c.wrapData;
        if (data.conditions.isNotEmpty ||
            data.css.containsKey('display') ||
            data.css.containsKey('visibility')) {
          return true;
        }
        c = resolveComponent(c.child);
      }
      return false;
    }

    // A Spacer an app component builds folds like one written inline.
    final resolved = children.any(isTransparent)
        ? [for (final c in children) c is Spacer ? c : resolveComponent(c)!]
        : children;
    final spacers = [
      for (var i = 0; i < children.length; i++)
        if (resolved[i] is Spacer) i,
    ];
    if (spacers.isEmpty ||
        children.any(flexible) ||
        spacers.any(
          (i) =>
              (resolved[i] as Spacer).flex != 1 ||
              i == 0 ||
              i == children.length - 1 ||
              resolved[i + 1] is Spacer ||
              resolved[i + 1] is SizedBox ||
              mayHide(children[i + 1]),
        )) {
      return children;
    }
    final horizontal = direction == Axis.horizontal;
    final out = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (resolved[i] is Spacer) continue;
      out.add(
        i > 0 && resolved[i - 1] is Spacer
            ? WrapWith(
                WrapData(
                  css: {
                    horizontal ? 'margin-inline-start' : 'margin-top': 'auto',
                  },
                ),
                child: children[i],
              )
            : children[i],
      );
    }
    return out;
  }

  /// Spacer folding: a childless `SizedBox` that only sets the main-axis
  /// extent (`SizedBox(height: 8)` in a Column) becomes a margin on the next
  /// child instead of an extra element. Skipped with [spacing] (removing a
  /// child would drop a gap) and for a trailing spacer. `Spacer`s fold
  /// first ([_foldedSpacers]). A [Length] extent folds too when a margin
  /// means the same length (`40.px.when(expanded: 56.px)`, see
  /// [_marginLength]); neighbouring spacers add up (`calc()`).
  List<Widget> _foldedChildren() {
    final children = _foldedSpacers(this.children);
    if (spacing != 0 || !_canFold) return children;
    final horizontal = direction == Axis.horizontal;
    final out = <Widget>[];
    var pending = 0.0;
    final lengths = <Length>[];
    for (var i = 0; i < children.length; i++) {
      final c = children[i];
      // A spacing SizedBox an app component builds folds too.
      final r = c is SizedBox ? c : resolveComponent(c);
      final extent = r is SizedBox && r.child == null
          ? _spacerExtent(r, horizontal)
          : null;
      if (extent != null && i < children.length - 1 && i > 0) {
        switch (extent) {
          case final double px:
            pending += px;
          case final Length length:
            lengths.add(length);
        }
        continue;
      }
      if (pending > 0 || lengths.isNotEmpty) {
        final margin = lengths.isEmpty
            ? cssPx(pending)
            : [
                if (pending > 0) Length.px(pending),
                ...lengths,
              ].reduce((a, b) => a + b).css;
        out.add(
          WrapWith(
            WrapData(
              css: {
                // Logical in a Row, so it follows RTL like Flutter's Row.
                horizontal ? 'margin-inline-start' : 'margin-top': margin,
              },
            ),
            child: c,
          ),
        );
        pending = 0;
        lengths.clear();
      } else {
        out.add(c);
      }
    }
    return out;
  }

  /// The main-axis extent of a spacer [box] (a `double` or a [Length]), or
  /// null when it sets the cross axis too, fills, or has a length a margin
  /// would read differently.
  static Object? _spacerExtent(SizedBox box, bool horizontal) {
    final (px, length, crossPx, crossLength) = horizontal
        ? (box.width, box.widthLength, box.height, box.heightLength)
        : (box.height, box.heightLength, box.width, box.widthLength);
    if (crossPx != null || crossLength != null) return null;
    if (px != null) return px == double.infinity ? null : px;
    if (length != null && _marginLength(length)) return length;
    return null;
  }

  // web: a margin resolves `%` against the parent's *width*, `em`/`ch`
  // against the next child's font, a variable on the next child: only an
  // absolute or viewport length is the same as a margin. Checked on the
  // base and on every breakpoint of a `.when()`.
  static final _absolute = RegExp(
    r'^(0|\d+(\.\d+)?(px|rem|vw|vh|dvh|svh|lvh))$',
  );

  static bool _marginLength(Length length) {
    final split = splitAdaptive({'v': length.css});
    return [
      split.base['v'],
      for (final v in split.byBreakpoint.values) v['v'],
    ].every((v) => v != null && _absolute.hasMatch(v));
  }

  @override
  Widget build(BuildContext context) {
    return thorElement(
      'div',
      debugName: kDebugMode ? runtimeType.toString() : null,
      fillsWidth: fillsWidth,
      fillsHeight: fillsHeight,
      childRules: _childRules(),
      css: switch (layout) {
        null => _ownCss(),
        final layout => mergeAdaptive(_declarations(), layout.toCss()),
      },
      children: _foldedChildren(),
    );
  }

  /// The rules for the children follow the direction in effect: a
  /// [layout] that turns this column into a row (or back) gives them a
  /// row's rules under that condition (`align-self: stretch` is a column's
  /// way to fill the width; in a row it would stretch the height).
  ChildRules _childRules() {
    ChildRules rules(Axis a) => a == Axis.horizontal
        ? ChildRules.row
        : switch (_cross) {
            CrossAxisAlignment.center ||
            CrossAxisAlignment.end => ChildRules.columnAligned,
            _ => ChildRules.column,
          };
    final l = layout;
    if (l == null) return rules(direction);
    final adaptive = l.adaptive;
    if (adaptive == null) return rules(l.direction ?? direction);
    final variants = {
      for (final e in adaptive.variants.entries)
        if (e.value.direction case final d?) e.key: rules(d),
    };
    return ChildRules.directional(
      rules(adaptive.base.direction ?? direction),
      variants,
    );
  }

  CssDeclarations _declarations() {
    final horizontal = direction == Axis.horizontal;
    return {
      ...flexCss(direction),
      if (horizontal && textDirection == TextDirection.rtl)
        'flex-direction': 'row-reverse',
      if (!horizontal && verticalDirection == VerticalDirection.up)
        'flex-direction': 'column-reverse',
      // Flutter's default crossAxisAlignment is center.
      'align-items': _cross.css,
      if (mainAxisAlignment != MainAxisAlignment.start)
        'justify-content': mainAxisAlignment.css,
      if (spacing != 0) 'gap': cssPx(spacing),
      if (mainAxisSize == MainAxisSize.min)
        horizontal ? 'width' : 'height': 'fit-content',
    };
  }

  /// [_declarations] without a [layout]: a pure function of a few enums
  /// and [spacing], built once per process for each combination (every
  /// Row and Column of every page asks).
  CssDeclarations _ownCss() {
    final key = (
      direction,
      textDirection,
      verticalDirection,
      crossAxisAlignment,
      mainAxisAlignment,
      mainAxisSize,
      spacing,
    );
    final known = _cssMemo[key];
    if (known != null) return known;
    // Bounded: a spacing computed from data must not grow it forever.
    if (_cssMemo.length >= 512) _cssMemo.clear();
    return _cssMemo[key] = Map.unmodifiable(_declarations());
  }

  static final _cssMemo =
      <
        (
          Axis,
          TextDirection?,
          VerticalDirection,
          CrossAxisAlignment,
          MainAxisAlignment,
          MainAxisSize,
          double,
        ),
        CssDeclarations
      >{};
}

/// The declarations shared by every flex container.
CssDeclarations flexCss(Axis direction) => {
  'display': 'flex',
  'flex-direction': direction == Axis.horizontal ? 'row' : 'column',
  'box-sizing': 'border-box',
  'min-width': '0',
  'min-height': '0',
};

/// Flutter's `Row`.
class Row extends Flex {
  /// Creates a horizontal Flex.
  const Row({
    super.key,
    super.mainAxisAlignment,
    super.mainAxisSize,
    super.crossAxisAlignment,
    super.spacing,
    super.textDirection,
    super.verticalDirection,
    super.textBaseline,
    super.layout,
    super.children,
  }) : super(direction: Axis.horizontal);
}

/// Flutter's `Column`.
class Column extends Flex {
  /// Creates a vertical Flex.
  const Column({
    super.key,
    super.mainAxisAlignment,
    super.mainAxisSize,
    super.crossAxisAlignment,
    super.spacing,
    super.textDirection,
    super.verticalDirection,
    super.textBaseline,
    super.layout,
    super.children,
  }) : super(direction: Axis.vertical);
}

/// Flutter's `Flexible`. Decorates the child element as a flex item; no
/// extra DOM node is created.
class Flexible extends ParentDataWrapper {
  /// Creates a widget that controls how [child] flexes in a Row/Column.
  const Flexible({
    super.key,
    this.flex = 1,
    this.fit = FlexFit.loose,
    required super.child,
  });

  /// The flex factor: how much space `child` takes relative to siblings.
  final int flex;

  /// Whether `child` is forced to fill (`FlexFit.tight`) or may be smaller
  /// (`FlexFit.loose`) than its allotted space.
  final FlexFit fit;

  // FlexFit.tight fills its share of the main axis; loose may shrink to it
  // but never grows past its content (CSS flex-grow would).
  //
  // web: the basis is `0%`, not `0`. A percentage basis against a container
  // whose main size is indefinite computes to `content` (CSS Flexbox 9.2),
  // so a Column that grows with its content (a phone, a `FlexLayout` that
  // is a row only from `lg`) keeps the Expanded's content instead of
  // collapsing it to a height of 0 (Flutter throws there). With a definite
  // main size it is still 0: the same exact share as before.
  // Limit: `content` ignores the child's own `height` (`Container(height:
  // 120)` is 0 high in a Column without a definite height; the same
  // `flex-basis: 0` already did that). No CSS form tells a definite parent
  // from an indefinite one and keeps the exact shares of the definite one
  // (tried `flex-basis: auto`, `min-height: calc(120px - 1000%)`: the first
  // breaks the ratios, the second only works in Chromium). Put the size on
  // the content (`Container(child: SizedBox(height: 120))`) or use `Flexible`.
  @override
  WrapData get wrapData => WrapData(
    css: {'flex': fit == FlexFit.tight ? '$flex 1 0%' : '0 $flex auto'},
    // The parent's main axis only (ChildRules.flexible): a button in a Row
    // keeps its minimum height, like Flutter's.
    flexible: true,
    debugAttributes: kDebugMode
        ? {'data-thor-flex-item': runtimeType.toString()}
        : const {},
  );
}

/// Flutter's `Expanded` (`Flexible` with `FlexFit.tight`).
class Expanded extends Flexible {
  /// Creates a widget that forces [child] to fill the available space.
  const Expanded({super.key, super.flex, required super.child})
    : super(fit: FlexFit.tight);
}

/// Flutter's `Spacer`.
class Spacer extends StatelessWidget implements ThorElementWidget, ThorBuiltIn {
  /// Creates a flexible empty space.
  const Spacer({super.key, this.flex = 1});

  /// The flex factor, relative to other flexible widgets in the same flex
  /// container.
  final int flex;

  @override
  Widget build(BuildContext context) => thorElement(
    'div',
    debugName: 'Spacer',
    css: {'flex': '$flex 1 0', 'min-width': '0', 'min-height': '0'},
    attributes: const {'aria-hidden': 'true'},
  );
}

/// Flutter's `Wrap` → `flex-wrap` with `gap`.
class Wrap extends StatelessWidget
    implements LayoutHint, ThorElementWidget, ThorBuiltIn {
  /// Creates a widget that lays children out and wraps onto new lines.
  const Wrap({
    super.key,
    this.direction = Axis.horizontal,
    this.alignment = WrapAlignment.start,
    this.spacing = 0,
    this.runAlignment = WrapAlignment.start,
    this.runSpacing = 0,
    this.crossAxisAlignment = WrapCrossAlignment.start,
    this.children = const [],
  });

  /// The axis along which to lay children out before wrapping.
  final Axis direction;

  /// How to align children within a run, along the main axis.
  final WrapAlignment alignment;

  /// Gap between children within a run.
  final double spacing;

  /// How to align the runs themselves, along the cross axis.
  final WrapAlignment runAlignment;

  /// Gap between runs.
  final double runSpacing;

  /// How to align children within a run, along the cross axis.
  final WrapCrossAlignment crossAxisAlignment;

  /// The widgets to lay out.
  final List<Widget> children;

  @override
  bool get fillsWidth => direction == Axis.horizontal;

  @override
  Widget build(BuildContext context) {
    final horizontal = direction == Axis.horizontal;
    return thorElement(
      'div',
      debugName: 'Wrap',
      // Flutter's Wrap takes the full main-axis extent, like MainAxisSize.max.
      fillsWidth: fillsWidth,
      // A list of chips or tags: no bullets, no browser indent.
      childRules: horizontal ? ChildRules.row : ChildRules.column,
      css: {
        ...flexCss(direction),
        'flex-wrap': 'wrap',
        'align-items': crossAxisAlignment.css,
        if (alignment != WrapAlignment.start) 'justify-content': alignment.css,
        if (runAlignment != WrapAlignment.start)
          'align-content': runAlignment.css,
        if (spacing != 0)
          (horizontal ? 'column-gap' : 'row-gap'): cssPx(spacing),
        if (runSpacing != 0)
          (horizontal ? 'row-gap' : 'column-gap'): cssPx(runSpacing),
      },
      children: children,
    );
  }
}
