import 'adaptive.dart';
import 'css.dart';
import 'errors.dart';
import 'layout_enums.dart';
import 'length.dart';

/// Flutter's `EdgeInsetsGeometry`: insets that may or may not depend on the
/// text direction ([EdgeInsets], [EdgeInsetsDirectional]), or that carry a
/// [Length] (`EdgeInsetsGeometry.allLength`).
///
/// Parameters that only write the box into CSS (`Padding.padding`,
/// `Container.margin`, `ListView.padding`…) take this type, as Flutter's do.
/// A widget that computes with the sides takes [EdgeInsets], whose sides are
/// numbers: passing it anything else is a compile error.
///
/// `// web:` the geometry is CSS only: it has no numeric `left`/`right`
/// (a side can be `start`, or a CSS variable the browser resolves), so
/// there is nothing to read wrong. [EdgeInsetsDirectional] is written with
/// CSS logical properties (`padding-inline-start`), which follow the
/// document's direction in the browser.
///
/// ```dart
/// Padding(padding: EdgeInsetsDirectional.only(start: 16), child: …)
/// Padding(
///   padding: EdgeInsetsGeometry.symmetricLength(
///     horizontal: Length.variable(CssVariable('--gutter'), fallback: 16.px),
///   ),
///   child: …,
/// )
/// ```
abstract class EdgeInsetsGeometry {
  /// Creates insets geometry.
  const EdgeInsetsGeometry();

  /// Insets of [value] on every side, as a [Length]: a CSS variable the
  /// browser keeps current, a percentage, a `calc()`.
  ///
  /// `// web:` Flutter's insets are logical pixels (`double`) and stay so
  /// in [EdgeInsets]; a value that changes in the browser (a state's
  /// `card.padding.px`, a CSS variable) has no `double` to give, so the
  /// `*Length` constructors take the web's own type, as `StyleProps`
  /// already does for sizes. The result is not an [EdgeInsets]: a widget
  /// that adds to the sides cannot take it.
  ///
  /// ```dart
  /// EdgeInsetsGeometry.allLength(card.padding.px) // follows a ThorState
  /// EdgeInsetsGeometry.allLength(Length.variable(CssVariable('--pad'), fallback: 16.px))
  /// ```
  const factory EdgeInsetsGeometry.allLength(Length value) = _LengthInsets.all;

  /// [horizontal] on the left/right and [vertical] on the top/bottom, as
  /// [Length]s (see [EdgeInsetsGeometry.allLength]).
  const factory EdgeInsetsGeometry.symmetricLength({
    Length vertical,
    Length horizontal,
  }) = _LengthInsets.symmetric;

  /// Each side set independently as a [Length], defaulting to
  /// [Length.zero] (see [EdgeInsetsGeometry.allLength]). [start] and [end]
  /// follow the text direction, as in [EdgeInsetsDirectional].
  const factory EdgeInsetsGeometry.onlyLength({
    Length left,
    Length top,
    Length right,
    Length bottom,
    Length start,
    Length end,
  }) = _LengthInsets.only;

  /// Only the sides given, as [Length]s; the others are left alone (each
  /// side is its own declaration: `margin-top`, not the `margin` shorthand).
  /// What a rule for HTML no widget builds needs to change one side of a
  /// margin the browser or another rule gives (`p { margin: 1em 0 }`):
  ///
  /// ```dart
  /// Styled(descendants: {
  ///   '> :first-child': StyleProps(margin: EdgeInsetsGeometry.sides(top: Length.zero)),
  /// }, child: …)
  /// ```
  ///
  /// `// web:` not in Flutter, where an inset has every side (`EdgeInsets.only`
  /// sets the others to 0). Read as numbers (a widget that adds insets), a
  /// side not given counts as 0.
  const factory EdgeInsetsGeometry.sides({
    Length? left,
    Length? top,
    Length? right,
    Length? bottom,
    Length? start,
    Length? end,
  }) = _SideInsets;

  /// The top inset, as CSS.
  String get cssTop;

  /// The right inset, as CSS. Throws (THOR-R037) when it depends on the
  /// text direction.
  String get cssRight;

  /// The bottom inset, as CSS.
  String get cssBottom;

  /// The left inset, as CSS. Throws (THOR-R037) when it depends on the text
  /// direction.
  String get cssLeft;

  /// Whether no side is negative (a [Length] side counts as non-negative
  /// unless it is written with a minus sign).
  bool get isNonNegative;

  /// These insets in [direction]: `start` is the left in
  /// [TextDirection.ltr] and the right in [TextDirection.rtl]. An
  /// [EdgeInsets] is its own answer.
  EdgeInsetsGeometry resolve(TextDirection direction);

  /// The sum of these insets and [other], side by side. Two [EdgeInsets]
  /// (or two [EdgeInsetsDirectional]) add into one of the same type; any
  /// other mix is a geometry whose sides are `calc()` sums when a [Length]
  /// is involved.
  ///
  /// A left or right inset added to a `start` or `end` inset cannot be
  /// written as CSS (which side `start` is depends on the direction, only
  /// known in the browser): that sum throws (THOR-R037) when it reaches the
  /// page; [resolve] it first.
  ///
  /// On insets built with `.when()` the sum is taken on the base and on every
  /// variant; two such insets add variant by variant.
  EdgeInsetsGeometry add(EdgeInsetsGeometry other) {
    final a = _variants, b = other._variants;
    if (a != null && b != null) {
      return _AdaptiveInsets(a.zip(b, (x, y) => x.add(y)));
    }
    if (a != null) return _AdaptiveInsets(a.map((x) => x.add(other)));
    if (b != null) return _AdaptiveInsets(b.map(add));
    return _toInsets()._plus(other._toInsets());
  }

  // The variants of insets built with `.when()`, else null.
  Adaptive<EdgeInsetsGeometry>? get _variants => null;

  /// The declarations that write these insets into [property] (`padding`,
  /// `margin`, `scroll-margin`): one shorthand for physical insets, the
  /// logical properties (`padding-inline-start`…) for directional ones.
  ///
  /// Memoized per instance (insets are mostly `const`); callers must not
  /// mutate the result.
  CssDeclarations toCss(String property) =>
      (_declarationsCache[this] ??= {})[property] ??= Map.unmodifiable(
        declarations(property),
      );

  /// [toCss] without the memo: what a subclass writes.
  CssDeclarations declarations(String property);

  _LengthInsets _toInsets();
}

final _declarationsCache = Expando<Map<String, CssDeclarations>>(
  'thor-insets-css',
);

/// `+` on any geometry (an [EdgeInsets] has its own, numeric one).
extension EdgeInsetsGeometryOperators on EdgeInsetsGeometry {
  /// Same as [EdgeInsetsGeometry.add].
  EdgeInsetsGeometry operator +(EdgeInsetsGeometry other) => add(other);
}

/// Breakpoints and states for any [EdgeInsetsGeometry] (an [EdgeInsets] has
/// its own, which keeps it an [EdgeInsets]).
extension EdgeInsetsGeometryAdaptive on EdgeInsetsGeometry {
  /// This value below the first given breakpoint; each variant from its
  /// breakpoint (or while its state holds) up. See [Adaptable.when].
  EdgeInsetsGeometry when({
    EdgeInsetsGeometry? medium,
    EdgeInsetsGeometry? expanded,
    EdgeInsetsGeometry? large,
    EdgeInsetsGeometry? extraLarge,
    EdgeInsetsGeometry? dark,
    EdgeInsetsGeometry? open,
    EdgeInsetsGeometry? hover,
    EdgeInsetsGeometry? focused,
    EdgeInsetsGeometry? focusWithin,
    EdgeInsetsGeometry? disabled,
    EdgeInsetsGeometry? pressed,
    EdgeInsetsGeometry? groupHover,
    Map<String, EdgeInsetsGeometry> groupHovers = const {},
    Map<num, EdgeInsetsGeometry> container = const {},
  }) => _AdaptiveInsets(
    Adaptive<EdgeInsetsGeometry>(
      this,
      medium: medium,
      expanded: expanded,
      large: large,
      extraLarge: extraLarge,
      dark: dark,
      open: open,
      hover: hover,
      focused: focused,
      focusWithin: focusWithin,
      disabled: disabled,
      pressed: pressed,
      groupHover: groupHover,
      groupHovers: groupHovers,
      container: container,
    ),
  );
}

/// Flutter's `EdgeInsets`: padding / margin in logical pixels.
class EdgeInsets extends EdgeInsetsGeometry with Adaptable<EdgeInsets> {
  /// Creates insets from the left, top, right and bottom values.
  const EdgeInsets.fromLTRB(this.left, this.top, this.right, this.bottom);

  /// Insets of [value] on every side.
  const EdgeInsets.all(double value)
    : left = value,
      top = value,
      right = value,
      bottom = value;

  /// Insets of [horizontal] on the left/right and [vertical] on the
  /// top/bottom.
  const EdgeInsets.symmetric({double vertical = 0, double horizontal = 0})
    : left = horizontal,
      top = vertical,
      right = horizontal,
      bottom = vertical;

  /// Insets with each side set independently, defaulting to 0.
  const EdgeInsets.only({
    this.left = 0,
    this.top = 0,
    this.right = 0,
    this.bottom = 0,
  });

  @override
  EdgeInsets withVariants(Adaptive<EdgeInsets> variants) =>
      _AdaptiveEdgeInsets(variants);

  /// No insets on any side.
  static const zero = EdgeInsets.all(0);

  /// The insets between [a] and [b] at [t], or null when both are null.
  static EdgeInsets? lerp(EdgeInsets? a, EdgeInsets? b, double t) {
    if (a == null && b == null) return null;
    final x = a ?? zero, y = b ?? zero;
    double mix(double p, double q) => p + (q - p) * t;
    return EdgeInsets.fromLTRB(
      mix(x.left, y.left),
      mix(x.top, y.top),
      mix(x.right, y.right),
      mix(x.bottom, y.bottom),
    );
  }

  /// CSS length of each side (with breakpoint variants when adaptive).
  @override
  String get cssTop => cssPx(top);

  /// See [cssTop].
  @override
  String get cssRight => cssPx(right);

  /// See [cssTop].
  @override
  String get cssBottom => cssPx(bottom);

  /// See [cssTop].
  @override
  String get cssLeft => cssPx(left);

  /// Inset from the left edge.
  final double left;

  /// Inset from the top edge.
  final double top;

  /// Inset from the right edge.
  final double right;

  /// Inset from the bottom edge.
  final double bottom;

  /// Whether a side is a [Length] given with the deprecated `allLength`,
  /// `symmetricLength` or `onlyLength` of [EdgeInsets]: the browser
  /// resolves it, so reading [left], [top], [right] or [bottom] throws
  /// (THOR-R036). It is also true when a breakpoint variant of adaptive
  /// insets is one.
  ///
  /// `// web:` there is no Flutter equivalent; a [Length] is an
  /// [EdgeInsetsGeometry] now (`EdgeInsetsGeometry.allLength`), never an
  /// [EdgeInsets], so this is only true for the deprecated constructors.
  bool get hasLengths => false;

  @override
  bool get isNonNegative => left >= 0 && top >= 0 && right >= 0 && bottom >= 0;

  /// Sum of [left] and [right].
  double get horizontal => left + right;

  /// Sum of [top] and [bottom].
  double get vertical => top + bottom;

  // The operations below work on plain insets; on one built with `.when()`
  // they map over the base and every variant (`_each`, `_with`), so the
  // variants are not dropped.
  EdgeInsets _each(EdgeInsets Function(EdgeInsets plain) f) => f(this);

  EdgeInsets _with(
    EdgeInsets o,
    EdgeInsets Function(EdgeInsets a, EdgeInsets b) f,
  ) {
    final a = this;
    if (a is _AdaptiveEdgeInsets && o is _AdaptiveEdgeInsets) {
      return _AdaptiveEdgeInsets(
        a.adaptive.zip(o.adaptive, (x, y) => x._with(y, f)),
      );
    }
    if (a is _AdaptiveEdgeInsets) {
      return _AdaptiveEdgeInsets(a.adaptive.map((x) => x._with(o, f)));
    }
    if (o is _AdaptiveEdgeInsets) {
      return _AdaptiveEdgeInsets(o.adaptive.map((y) => _with(y, f)));
    }
    return f(a, o);
  }

  /// These insets with the given sides replaced (on every variant too, when
  /// built with `.when()`).
  EdgeInsets copyWith({
    double? left,
    double? top,
    double? right,
    double? bottom,
  }) => _each(
    (e) => EdgeInsets.fromLTRB(
      left ?? e.left,
      top ?? e.top,
      right ?? e.right,
      bottom ?? e.bottom,
    ),
  );

  /// Adds two insets side by side (variants included).
  EdgeInsets operator +(EdgeInsets o) => _with(
    o,
    (a, b) => EdgeInsets.fromLTRB(
      a.left + b.left,
      a.top + b.top,
      a.right + b.right,
      a.bottom + b.bottom,
    ),
  );

  /// Subtracts [o] side by side (variants included).
  EdgeInsets operator -(EdgeInsets o) => _with(
    o,
    (a, b) => EdgeInsets.fromLTRB(
      a.left - b.left,
      a.top - b.top,
      a.right - b.right,
      a.bottom - b.bottom,
    ),
  );

  /// The negation of these insets (variants included).
  EdgeInsets operator -() =>
      _each((e) => EdgeInsets.fromLTRB(-e.left, -e.top, -e.right, -e.bottom));

  /// These insets scaled by [factor] (variants included).
  EdgeInsets operator *(double factor) => _each(
    (e) => EdgeInsets.fromLTRB(
      e.left * factor,
      e.top * factor,
      e.right * factor,
      e.bottom * factor,
    ),
  );

  /// These insets divided by [divisor] (variants included).
  EdgeInsets operator /(double divisor) => _each(
    (e) => EdgeInsets.fromLTRB(
      e.left / divisor,
      e.top / divisor,
      e.right / divisor,
      e.bottom / divisor,
    ),
  );

  @override
  EdgeInsetsGeometry add(EdgeInsetsGeometry other) =>
      other is EdgeInsets && !other.hasLengths && !hasLengths
      ? this + other
      : super.add(other);

  @override
  EdgeInsets resolve(TextDirection direction) => this;

  /// Shortest valid CSS shorthand (`8px`, `8px 16px`, `1px 2px 3px 4px`).
  String get css => cssBox(cssTop, cssRight, cssBottom, cssLeft);

  @override
  CssDeclarations declarations(String property) => {property: css};

  @override
  _LengthInsets _toInsets() => _LengthInsets.only(
    left: _len(left),
    top: _len(top),
    right: _len(right),
    bottom: _len(bottom),
  );

  // Plain insets are equal when their numbers are; the variants and the
  // deprecated Length ones override both (and `_plain`) so `==` stays
  // symmetric.
  bool get _plain => true;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EdgeInsets &&
          other._plain &&
          _plain &&
          other.left == left &&
          other.top == top &&
          other.right == right &&
          other.bottom == bottom;

  @override
  int get hashCode => Object.hash(left, top, right, bottom);

  @override
  String toString() => 'EdgeInsets($left, $top, $right, $bottom)';
}

/// Flutter's `EdgeInsetsDirectional`: insets whose horizontal sides follow
/// the text direction (`start` is the left in left-to-right text).
///
/// `// web:` written as CSS logical properties (`padding-inline-start`,
/// `padding-inline-end`), which the browser flips by the document's
/// direction: the server never needs a `TextDirection`.
class EdgeInsetsDirectional extends EdgeInsetsGeometry {
  /// Creates insets from the start, top, end and bottom values.
  const EdgeInsetsDirectional.fromSTEB(
    this.start,
    this.top,
    this.end,
    this.bottom,
  );

  /// Insets of [value] on every side.
  const EdgeInsetsDirectional.all(double value)
    : start = value,
      top = value,
      end = value,
      bottom = value;

  /// Insets with each side set independently, defaulting to 0.
  const EdgeInsetsDirectional.only({
    this.start = 0,
    this.top = 0,
    this.end = 0,
    this.bottom = 0,
  });

  /// No insets on any side.
  static const zero = EdgeInsetsDirectional.all(0);

  /// Inset from the start edge (the left in left-to-right text).
  final double start;

  /// Inset from the top edge.
  final double top;

  /// Inset from the end edge (the right in left-to-right text).
  final double end;

  /// Inset from the bottom edge.
  final double bottom;

  /// Sum of [start] and [end].
  double get horizontal => start + end;

  /// Sum of [top] and [bottom].
  double get vertical => top + bottom;

  /// These insets with [start] and [end] swapped.
  EdgeInsetsDirectional get flipped =>
      EdgeInsetsDirectional.fromSTEB(end, top, start, bottom);

  @override
  String get cssTop => cssPx(top);

  @override
  String get cssBottom => cssPx(bottom);

  @override
  String get cssLeft => throw _needsDirection('cssLeft');

  @override
  String get cssRight => throw _needsDirection('cssRight');

  @override
  bool get isNonNegative => start >= 0 && top >= 0 && end >= 0 && bottom >= 0;

  /// These insets with the given sides replaced.
  EdgeInsetsDirectional copyWith({
    double? start,
    double? top,
    double? end,
    double? bottom,
  }) => EdgeInsetsDirectional.fromSTEB(
    start ?? this.start,
    top ?? this.top,
    end ?? this.end,
    bottom ?? this.bottom,
  );

  /// Adds two insets side by side.
  EdgeInsetsDirectional operator +(EdgeInsetsDirectional o) =>
      EdgeInsetsDirectional.fromSTEB(
        start + o.start,
        top + o.top,
        end + o.end,
        bottom + o.bottom,
      );

  /// Subtracts [o] side by side.
  EdgeInsetsDirectional operator -(EdgeInsetsDirectional o) =>
      EdgeInsetsDirectional.fromSTEB(
        start - o.start,
        top - o.top,
        end - o.end,
        bottom - o.bottom,
      );

  /// The negation of these insets.
  EdgeInsetsDirectional operator -() =>
      EdgeInsetsDirectional.fromSTEB(-start, -top, -end, -bottom);

  /// These insets scaled by [factor].
  EdgeInsetsDirectional operator *(double factor) =>
      EdgeInsetsDirectional.fromSTEB(
        start * factor,
        top * factor,
        end * factor,
        bottom * factor,
      );

  /// These insets divided by [divisor].
  EdgeInsetsDirectional operator /(double divisor) =>
      EdgeInsetsDirectional.fromSTEB(
        start / divisor,
        top / divisor,
        end / divisor,
        bottom / divisor,
      );

  @override
  EdgeInsetsGeometry add(EdgeInsetsGeometry other) =>
      other is EdgeInsetsDirectional ? this + other : super.add(other);

  @override
  EdgeInsets resolve(TextDirection direction) => switch (direction) {
    TextDirection.ltr => EdgeInsets.fromLTRB(start, top, end, bottom),
    TextDirection.rtl => EdgeInsets.fromLTRB(end, top, start, bottom),
  };

  @override
  CssDeclarations declarations(String property) => _logicalCss(
    property,
    cssPx(start),
    cssPx(end),
    cssPx(top),
    cssPx(bottom),
  );

  @override
  _LengthInsets _toInsets() => _LengthInsets.only(
    start: _len(start),
    top: _len(top),
    end: _len(end),
    bottom: _len(bottom),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EdgeInsetsDirectional &&
          other.start == start &&
          other.top == top &&
          other.end == end &&
          other.bottom == bottom;

  @override
  int get hashCode => Object.hash(start, top, end, bottom);

  @override
  String toString() => 'EdgeInsetsDirectional($start, $top, $end, $bottom)';
}

// `padding: <top> <right> <bottom> <left>` with a `start`/`end`: the logical
// properties, one declaration per axis when both sides agree.
CssDeclarations _logicalCss(
  String property,
  String start,
  String end,
  String top,
  String bottom,
) => {
  if (top == bottom)
    '$property-block': top
  else ...{
    '$property-top': top,
    '$property-bottom': bottom,
  },
  if (start == end)
    '$property-inline': start
  else ...{
    '$property-inline-start': start,
    '$property-inline-end': end,
  },
};

StateError _needsDirection(String what) => StateError(
  thorError(
    'THOR-R037',
    '$what: these insets depend on the text direction (a `start`/`end` '
        'side), which only the browser knows. Write the physical sides '
        '(EdgeInsets), or resolve them with a TextDirection '
        '(`insets.resolve(TextDirection.ltr)`).',
  ),
);

// Insets with a `Length` per side and, optionally, `start`/`end`: what a
// `Length` inset and a mixed sum are. The CSS is the source of truth.
class _LengthInsets extends EdgeInsetsGeometry {
  const _LengthInsets.only({
    this.left = Length.zero,
    this.top = Length.zero,
    this.right = Length.zero,
    this.bottom = Length.zero,
    this.start = Length.zero,
    this.end = Length.zero,
  });

  const _LengthInsets.all(Length value)
    : this.only(left: value, top: value, right: value, bottom: value);

  const _LengthInsets.symmetric({
    Length vertical = Length.zero,
    Length horizontal = Length.zero,
  }) : this.only(
         left: horizontal,
         top: vertical,
         right: horizontal,
         bottom: vertical,
       );

  final Length left;
  final Length top;
  final Length right;
  final Length bottom;
  final Length start;
  final Length end;

  static bool _isZero(Length l) => l.css == '0' || l.css == '0px';

  // Whether the horizontal axis mixes physical and logical sides.
  bool get _logical => !_isZero(start) || !_isZero(end);

  @override
  String get cssTop => top.css;

  @override
  String get cssBottom => bottom.css;

  @override
  String get cssLeft => _logical ? throw _needsDirection('cssLeft') : left.css;

  @override
  String get cssRight =>
      _logical ? throw _needsDirection('cssRight') : right.css;

  @override
  bool get isNonNegative => [
    left,
    top,
    right,
    bottom,
    start,
    end,
  ].every((l) => !l.css.startsWith('-'));

  @override
  EdgeInsetsGeometry resolve(TextDirection direction) {
    final ltr = direction == TextDirection.ltr;
    return _LengthInsets.only(
      left: _sum(left, ltr ? start : end),
      right: _sum(right, ltr ? end : start),
      top: top,
      bottom: bottom,
    );
  }

  @override
  CssDeclarations declarations(String property) {
    if (!_logical) {
      return {property: cssBox(top.css, right.css, bottom.css, left.css)};
    }
    // `start` and `end` next to a left or right inset: which side `start`
    // is only the browser knows, and the two cannot be summed in CSS.
    if (!_isZero(left) || !_isZero(right)) {
      throw _needsDirection('The sum of a physical and a directional inset');
    }
    return _logicalCss(property, start.css, end.css, top.css, bottom.css);
  }

  _LengthInsets _plus(_LengthInsets o) => _LengthInsets.only(
    left: _sum(left, o.left),
    top: _sum(top, o.top),
    right: _sum(right, o.right),
    bottom: _sum(bottom, o.bottom),
    start: _sum(start, o.start),
    end: _sum(end, o.end),
  );

  @override
  _LengthInsets _toInsets() => this;

  String get _key =>
      '${left.css}|${top.css}|${right.css}|${bottom.css}|${start.css}|${end.css}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is _LengthInsets && other._key == _key;

  @override
  int get hashCode => _key.hashCode;

  @override
  String toString() => 'EdgeInsetsGeometry($_key)';
}

// `EdgeInsetsGeometry.sides`: one longhand per side given, nothing for the
// others.
class _SideInsets extends EdgeInsetsGeometry {
  const _SideInsets({
    this.left,
    this.top,
    this.right,
    this.bottom,
    this.start,
    this.end,
  });

  final Length? left;
  final Length? top;
  final Length? right;
  final Length? bottom;
  final Length? start;
  final Length? end;

  bool get _logical => start != null || end != null;

  @override
  String get cssTop => (top ?? Length.zero).css;

  @override
  String get cssBottom => (bottom ?? Length.zero).css;

  @override
  String get cssLeft =>
      _logical ? throw _needsDirection('cssLeft') : (left ?? Length.zero).css;

  @override
  String get cssRight =>
      _logical ? throw _needsDirection('cssRight') : (right ?? Length.zero).css;

  @override
  bool get isNonNegative => [
    left,
    top,
    right,
    bottom,
    start,
    end,
  ].every((l) => l == null || !l.css.startsWith('-'));

  @override
  EdgeInsetsGeometry resolve(TextDirection direction) {
    final ltr = direction == TextDirection.ltr;
    return _SideInsets(
      left: (ltr ? start : end) ?? left,
      right: (ltr ? end : start) ?? right,
      top: top,
      bottom: bottom,
    );
  }

  @override
  CssDeclarations declarations(String property) => {
    if (top case final v?) '$property-top': v.css,
    if (right case final v?) '$property-right': v.css,
    if (bottom case final v?) '$property-bottom': v.css,
    if (left case final v?) '$property-left': v.css,
    if (start case final v?) '$property-inline-start': v.css,
    if (end case final v?) '$property-inline-end': v.css,
  };

  @override
  _LengthInsets _toInsets() => _LengthInsets.only(
    left: left ?? Length.zero,
    top: top ?? Length.zero,
    right: right ?? Length.zero,
    bottom: bottom ?? Length.zero,
    start: start ?? Length.zero,
    end: end ?? Length.zero,
  );

  String get _key => [
    for (final l in [left, top, right, bottom, start, end]) l?.css ?? '-',
  ].join('|');

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is _SideInsets && other._key == _key;

  @override
  int get hashCode => _key.hashCode;

  @override
  String toString() => 'EdgeInsetsGeometry.sides($_key)';
}

// `a + b`: plain pixels add up to pixels, zero is the other side, anything
// else is `calc()`.
Length _sum(Length a, Length b) {
  final zeroA = _LengthInsets._isZero(a), zeroB = _LengthInsets._isZero(b);
  if (zeroA && zeroB) return Length.zero;
  if (zeroA) return b;
  if (zeroB) return a;
  final x = _px(a), y = _px(b);
  if (x != null && y != null) return Length.px(x + y);
  return a + b;
}

Length _len(double v) => v == 0 ? Length.zero : Length.px(v);

double? _px(Length l) {
  final css = l.css;
  return css.endsWith('px')
      ? double.tryParse(css.substring(0, css.length - 2))
      : null;
}

class _AdaptiveEdgeInsets extends EdgeInsets {
  const _AdaptiveEdgeInsets(this.adaptive) : super.fromLTRB(0, 0, 0, 0);

  final Adaptive<EdgeInsets> adaptive;

  // The base's numbers (a deprecated Length base throws as it does alone).
  @override
  double get left => adaptive.base.left;

  @override
  double get top => adaptive.base.top;

  @override
  double get right => adaptive.base.right;

  @override
  double get bottom => adaptive.base.bottom;

  @override
  bool get hasLengths =>
      adaptive.base.hasLengths ||
      adaptive.variants.values.any((v) => v.hasLengths);

  @override
  String get cssTop => adaptive.css((e) => e.cssTop);

  @override
  String get cssRight => adaptive.css((e) => e.cssRight);

  @override
  String get cssBottom => adaptive.css((e) => e.cssBottom);

  @override
  String get cssLeft => adaptive.css((e) => e.cssLeft);

  @override
  _LengthInsets _toInsets() => adaptive.base._toInsets();

  @override
  EdgeInsets _each(EdgeInsets Function(EdgeInsets plain) f) =>
      _AdaptiveEdgeInsets(adaptive.map((e) => e._each(f)));

  @override
  Adaptive<EdgeInsetsGeometry> get _variants =>
      adaptive.map<EdgeInsetsGeometry>((e) => e);

  @override
  bool get _plain => false;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _AdaptiveEdgeInsets && other.css == css;

  @override
  int get hashCode => css.hashCode;
}

// `EdgeInsetsGeometry.when`: variants of any geometry (a directional one, a
// Length one), written declaration by declaration.
class _AdaptiveInsets extends EdgeInsetsGeometry {
  const _AdaptiveInsets(this.adaptive);

  final Adaptive<EdgeInsetsGeometry> adaptive;

  @override
  String get cssTop => adaptive.css((e) => e.cssTop);

  @override
  String get cssRight => adaptive.css((e) => e.cssRight);

  @override
  String get cssBottom => adaptive.css((e) => e.cssBottom);

  @override
  String get cssLeft => adaptive.css((e) => e.cssLeft);

  @override
  bool get isNonNegative =>
      adaptive.base.isNonNegative &&
      adaptive.variants.values.every((v) => v.isNonNegative);

  @override
  Adaptive<EdgeInsetsGeometry> get _variants => adaptive;

  @override
  EdgeInsetsGeometry resolve(TextDirection direction) =>
      adaptive.base.resolve(direction);

  @override
  CssDeclarations declarations(String property) =>
      adaptive.declarations((e) => e.toCss(property));

  @override
  _LengthInsets _toInsets() => adaptive.base._toInsets();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _AdaptiveInsets &&
          other.declarations('padding').toString() ==
              declarations('padding').toString();

  @override
  int get hashCode => declarations('padding').toString().hashCode;
}
