import 'adaptive.dart';
import 'css.dart';
import 'layout_enums.dart';
import 'length.dart';

/// Flutter's `Offset`.
class Offset {
  /// Creates an offset from [dx]/[dy] displacement in logical pixels.
  const Offset(this.dx, this.dy);

  /// No displacement.
  static const zero = Offset(0, 0);

  /// The offset between [a] and [b] at [t], or null when both are null.
  static Offset? lerp(Offset? a, Offset? b, double t) {
    if (a == null && b == null) return null;
    final x = a ?? zero, y = b ?? zero;
    return Offset(x.dx + (y.dx - x.dx) * t, x.dy + (y.dy - x.dy) * t);
  }

  /// Horizontal displacement, in logical pixels.
  final double dx;

  /// Vertical displacement, in logical pixels.
  final double dy;

  /// The sum of both displacements.
  Offset operator +(Offset other) => Offset(dx + other.dx, dy + other.dy);

  /// The difference of both displacements.
  Offset operator -(Offset other) => Offset(dx - other.dx, dy - other.dy);

  /// The negated displacement.
  Offset operator -() => Offset(-dx, -dy);

  /// This displacement scaled by [operand].
  Offset operator *(double operand) => Offset(dx * operand, dy * operand);

  /// This displacement divided by [operand].
  Offset operator /(double operand) => Offset(dx / operand, dy / operand);

  @override
  bool operator ==(Object other) =>
      other is Offset && other.dx == dx && other.dy == dy;

  @override
  int get hashCode => Object.hash(dx, dy);

  @override
  String toString() => 'Offset($dx, $dy)';
}

/// Flutter's `Radius`.
class Radius {
  /// Creates a circular radius of [radius] on both axes.
  const Radius.circular(double radius) : x = radius, y = radius, _length = null;

  /// Creates an elliptical radius with independent [x]/[y] values.
  const Radius.elliptical(this.x, this.y) : _length = null;

  /// A circular radius of [length]: a CSS variable the browser keeps
  /// current, a percentage, a `calc()`.
  ///
  /// `// web:` Flutter's radii are logical pixels (`double`) and stay so; a
  /// value that reaches the page as a CSS variable
  /// (`WatchVariables({'--radius': ...})`) has no `double` to give. [x] and
  /// [y] answer 0 for a radius given as a [Length]: the browser resolves it.
  ///
  /// ```dart
  /// BorderRadius.circularLength(Length.variable(CssVariable('--radius'), fallback: 16.px))
  /// ```
  const Radius.circularLength(Length length) : x = 0, y = 0, _length = length;

  /// No rounding.
  static const zero = Radius.circular(0);

  final Length? _length;

  /// Radius on the horizontal axis, in logical pixels.
  final double x;

  /// Radius on the vertical axis, in logical pixels.
  final double y;

  /// CSS `border-radius` value for a single corner (`8px` or `8px 4px`).
  String get css =>
      _length?.css ??
      (x == y ? cssRadiusPx(x) : '${cssRadiusPx(x)} ${cssRadiusPx(y)}');

  bool get _circular => _length != null || x == y;

  String get _cssX => _length?.css ?? cssRadiusPx(x);

  String get _cssY => _length?.css ?? cssRadiusPx(y);

  @override
  bool operator ==(Object other) =>
      other is Radius &&
      other.x == x &&
      other.y == y &&
      other._length == _length;

  @override
  int get hashCode => Object.hash(x, y, _length);

  @override
  String toString() => _length != null
      ? 'Radius.circularLength(${_length.css})'
      : _circular
      ? 'Radius.circular(${cssNum(x)})'
      : 'Radius.elliptical(${cssNum(x)}, ${cssNum(y)})';
}

/// Flutter's `BorderRadiusGeometry`: a rounding that may or may not depend
/// on the text direction ([BorderRadius], [BorderRadiusDirectional]).
///
/// Parameters that only write the rounding into CSS
/// (`BoxDecoration.borderRadius`, `ClipRRect.borderRadius`) take this type,
/// as Flutter's do. A corner may be a [Radius.circularLength] (a CSS
/// variable, a percentage): the browser resolves it.
///
/// `// web:` [BorderRadiusDirectional] is written with CSS logical
/// properties (`border-start-start-radius`…), which the browser flips by
/// the document's direction.
abstract class BorderRadiusGeometry {
  /// Creates a border radius geometry.
  const BorderRadiusGeometry();

  /// This rounding in [direction]: `topStart` is the top left corner in
  /// [TextDirection.ltr] and the top right one in [TextDirection.rtl].
  BorderRadius resolve(TextDirection direction);

  /// The declarations that round a box: `border-radius`, or the four
  /// logical corner properties of a directional rounding that differs by
  /// corner.
  CssDeclarations toCss();
}

/// Flutter's `BorderRadius`.
class BorderRadius extends BorderRadiusGeometry with Adaptable<BorderRadius> {
  /// Creates a border radius with each corner set independently,
  /// defaulting to no rounding.
  const BorderRadius.only({
    this.topLeft = Radius.zero,
    this.topRight = Radius.zero,
    this.bottomRight = Radius.zero,
    this.bottomLeft = Radius.zero,
  });

  /// Creates a border radius where all four corners use the same [radius].
  const BorderRadius.all(Radius radius)
    : topLeft = radius,
      topRight = radius,
      bottomRight = radius,
      bottomLeft = radius;

  /// Creates a border radius with a uniform circular [radius] on every
  /// corner.
  BorderRadius.circular(double radius) : this.all(Radius.circular(radius));

  /// A uniform circular radius of [length] on every corner (see
  /// [Radius.circularLength]).
  const factory BorderRadius.circularLength(Length length) =
      _LengthBorderRadius;

  /// Creates a border radius with [top] corners and [bottom] corners set
  /// independently.
  const BorderRadius.vertical({
    Radius top = Radius.zero,
    Radius bottom = Radius.zero,
  }) : topLeft = top,
       topRight = top,
       bottomRight = bottom,
       bottomLeft = bottom;

  /// Creates a border radius with [left] corners and [right] corners set
  /// independently.
  const BorderRadius.horizontal({
    Radius left = Radius.zero,
    Radius right = Radius.zero,
  }) : topLeft = left,
       topRight = right,
       bottomRight = right,
       bottomLeft = left;

  @override
  BorderRadius withVariants(Adaptive<BorderRadius> variants) =>
      _AdaptiveBorderRadius(variants);

  /// No rounding on any corner.
  static const zero = BorderRadius.all(Radius.zero);

  /// Radius of the top left corner.
  final Radius topLeft;

  /// Radius of the top right corner.
  final Radius topRight;

  /// Radius of the bottom right corner.
  final Radius bottomRight;

  /// Radius of the bottom left corner.
  final Radius bottomLeft;

  /// This border radius with the given corners replaced (on every variant
  /// too, when built with `.when()`).
  BorderRadius copyWith({
    Radius? topLeft,
    Radius? topRight,
    Radius? bottomLeft,
    Radius? bottomRight,
  }) => _each(
    (r) => BorderRadius.only(
      topLeft: topLeft ?? r.topLeft,
      topRight: topRight ?? r.topRight,
      bottomRight: bottomRight ?? r.bottomRight,
      bottomLeft: bottomLeft ?? r.bottomLeft,
    ),
  );

  // Maps over the variants when built with `.when()`.
  BorderRadius _each(BorderRadius Function(BorderRadius plain) f) => f(this);

  @override
  BorderRadius resolve(TextDirection direction) => this;

  /// CSS `border-radius` shorthand, splitting into `x / y` axes when the
  /// corners are elliptical.
  String get css {
    final all = [topLeft, topRight, bottomRight, bottomLeft];
    if (all.every((r) => r._circular)) {
      final v = all.map((r) => r._cssX).toList();
      if (v.toSet().length == 1) return v.first;
      return v.join(' ');
    }
    final xs = all.map((r) => r._cssX).join(' ');
    final ys = all.map((r) => r._cssY).join(' ');
    return '$xs / $ys';
  }

  @override
  CssDeclarations toCss() => {'border-radius': css};

  bool get _plain => true;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BorderRadius &&
          other._plain &&
          _plain &&
          other.topLeft == topLeft &&
          other.topRight == topRight &&
          other.bottomRight == bottomRight &&
          other.bottomLeft == bottomLeft;

  @override
  int get hashCode => Object.hash(topLeft, topRight, bottomRight, bottomLeft);

  @override
  String toString() => 'BorderRadius($css)';
}

/// Flutter's `BorderRadiusDirectional`: a rounding whose horizontal corners
/// follow the text direction (`topStart` is the top left corner in
/// left-to-right text).
///
/// `// web:` written as CSS logical properties (`border-start-start-radius`
/// for [topStart]…), which the browser flips by the document's direction.
/// A rounding that is the same on every corner is one `border-radius`.
class BorderRadiusDirectional extends BorderRadiusGeometry {
  /// Creates a border radius with each corner set independently,
  /// defaulting to no rounding.
  const BorderRadiusDirectional.only({
    this.topStart = Radius.zero,
    this.topEnd = Radius.zero,
    this.bottomStart = Radius.zero,
    this.bottomEnd = Radius.zero,
  });

  /// Creates a border radius where all four corners use the same [radius].
  const BorderRadiusDirectional.all(Radius radius)
    : topStart = radius,
      topEnd = radius,
      bottomStart = radius,
      bottomEnd = radius;

  /// Creates a border radius with a uniform circular [radius] on every
  /// corner.
  BorderRadiusDirectional.circular(double radius)
    : this.all(Radius.circular(radius));

  /// A uniform circular radius of [length] on every corner (see
  /// [Radius.circularLength]).
  const factory BorderRadiusDirectional.circularLength(Length length) =
      _LengthBorderRadiusDirectional;

  /// Creates a border radius with [top] corners and [bottom] corners set
  /// independently.
  const BorderRadiusDirectional.vertical({
    Radius top = Radius.zero,
    Radius bottom = Radius.zero,
  }) : topStart = top,
       topEnd = top,
       bottomStart = bottom,
       bottomEnd = bottom;

  /// Creates a border radius with [start] corners and [end] corners set
  /// independently.
  const BorderRadiusDirectional.horizontal({
    Radius start = Radius.zero,
    Radius end = Radius.zero,
  }) : topStart = start,
       topEnd = end,
       bottomStart = start,
       bottomEnd = end;

  /// No rounding on any corner.
  static const zero = BorderRadiusDirectional.all(Radius.zero);

  /// Radius of the top start corner (top left in left-to-right text).
  final Radius topStart;

  /// Radius of the top end corner (top right in left-to-right text).
  final Radius topEnd;

  /// Radius of the bottom start corner (bottom left in left-to-right text).
  final Radius bottomStart;

  /// Radius of the bottom end corner (bottom right in left-to-right text).
  final Radius bottomEnd;

  /// This border radius with the given corners replaced.
  BorderRadiusDirectional copyWith({
    Radius? topStart,
    Radius? topEnd,
    Radius? bottomStart,
    Radius? bottomEnd,
  }) => BorderRadiusDirectional.only(
    topStart: topStart ?? this.topStart,
    topEnd: topEnd ?? this.topEnd,
    bottomStart: bottomStart ?? this.bottomStart,
    bottomEnd: bottomEnd ?? this.bottomEnd,
  );

  @override
  BorderRadius resolve(TextDirection direction) => switch (direction) {
    TextDirection.ltr => BorderRadius.only(
      topLeft: topStart,
      topRight: topEnd,
      bottomRight: bottomEnd,
      bottomLeft: bottomStart,
    ),
    TextDirection.rtl => BorderRadius.only(
      topLeft: topEnd,
      topRight: topStart,
      bottomRight: bottomStart,
      bottomLeft: bottomEnd,
    ),
  };

  @override
  CssDeclarations toCss() {
    if (topStart == topEnd &&
        topEnd == bottomStart &&
        bottomStart == bottomEnd) {
      return BorderRadius.all(topStart).toCss();
    }
    String corner(Radius r) => r._circular ? r._cssX : '${r._cssX} ${r._cssY}';
    return {
      'border-start-start-radius': corner(topStart),
      'border-start-end-radius': corner(topEnd),
      'border-end-end-radius': corner(bottomEnd),
      'border-end-start-radius': corner(bottomStart),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BorderRadiusDirectional &&
          other.topStart == topStart &&
          other.topEnd == topEnd &&
          other.bottomStart == bottomStart &&
          other.bottomEnd == bottomEnd;

  @override
  int get hashCode => Object.hash(topStart, topEnd, bottomStart, bottomEnd);

  @override
  String toString() =>
      'BorderRadiusDirectional($topStart, $topEnd, $bottomEnd, $bottomStart)';
}

// One `Length` on every corner: the corners answer a `Radius.circularLength`
// (the field type can't be built from a parameter in a const constructor).
class _LengthBorderRadius extends BorderRadius {
  const _LengthBorderRadius(this._length) : super.only();

  final Length _length;

  @override
  Radius get topLeft => Radius.circularLength(_length);

  @override
  Radius get topRight => Radius.circularLength(_length);

  @override
  Radius get bottomRight => Radius.circularLength(_length);

  @override
  Radius get bottomLeft => Radius.circularLength(_length);

  @override
  String get css => _length.css;
}

class _LengthBorderRadiusDirectional extends BorderRadiusDirectional {
  const _LengthBorderRadiusDirectional(this._length) : super.only();

  final Length _length;

  @override
  Radius get topStart => Radius.circularLength(_length);

  @override
  Radius get topEnd => Radius.circularLength(_length);

  @override
  Radius get bottomStart => Radius.circularLength(_length);

  @override
  Radius get bottomEnd => Radius.circularLength(_length);
}

class _AdaptiveBorderRadius extends BorderRadius {
  _AdaptiveBorderRadius(this.adaptive)
    : super.only(
        topLeft: adaptive.base.topLeft,
        topRight: adaptive.base.topRight,
        bottomRight: adaptive.base.bottomRight,
        bottomLeft: adaptive.base.bottomLeft,
      );

  @override
  final Adaptive<BorderRadius> adaptive;

  @override
  BorderRadius _each(BorderRadius Function(BorderRadius plain) f) =>
      _AdaptiveBorderRadius(adaptive.map((r) => r._each(f)));

  @override
  String get css => adaptive.css(_plainCss);

  static String _plainCss(BorderRadius r) =>
      r is _AdaptiveBorderRadius ? r.adaptive.base.css : r.css;

  @override
  bool get _plain => false;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _AdaptiveBorderRadius && other.css == css;

  @override
  int get hashCode => css.hashCode;
}

/// Flutter's `BoxConstraints` (min/max width & height).
class BoxConstraints with Adaptable<BoxConstraints> {
  /// Creates constraints, defaulting to unbounded (0 to infinity) on both
  /// axes.
  const BoxConstraints({
    this.minWidth = 0,
    this.maxWidth = double.infinity,
    this.minHeight = 0,
    this.maxHeight = double.infinity,
  });

  @override
  BoxConstraints withVariants(Adaptive<BoxConstraints> variants) =>
      _AdaptiveConstraints(variants);

  /// Creates constraints that force [width] and/or [height] to an exact
  /// value; an omitted dimension stays unbounded.
  const BoxConstraints.tightFor({double? width, double? height})
    : minWidth = width ?? 0,
      maxWidth = width ?? double.infinity,
      minHeight = height ?? 0,
      maxHeight = height ?? double.infinity;

  /// Creates constraints that force [width] and/or [height] to fill the
  /// available space; an omitted dimension stays unbounded.
  const BoxConstraints.expand({double? width, double? height})
    : minWidth = width ?? double.infinity,
      maxWidth = width ?? double.infinity,
      minHeight = height ?? double.infinity,
      maxHeight = height ?? double.infinity;

  /// Minimum width, in logical pixels.
  final double minWidth;

  /// Maximum width, in logical pixels (`double.infinity` for unbounded).
  final double maxWidth;

  /// Minimum height, in logical pixels.
  final double minHeight;

  /// Maximum height, in logical pixels (`double.infinity` for unbounded).
  final double maxHeight;

  /// Memoized per instance (value types are mostly `const`); callers must
  /// not mutate the result.
  CssDeclarations toCss() => _cssCache[this] ??= _computeCss();

  CssDeclarations _computeCss() => {
    if (minWidth > 0) 'min-width': cssPx(minWidth),
    if (maxWidth != double.infinity) 'max-width': cssPx(maxWidth),
    if (minHeight > 0) 'min-height': cssPx(minHeight),
    if (maxHeight != double.infinity) 'max-height': cssPx(maxHeight),
  };
}

final _cssCache = Expando<CssDeclarations>('thor-css');

/// Flutter's `VisualDensity`: how compact a control's layout is. Each step
/// of [horizontal]/[vertical] moves its minimum size by 4 logical pixels
/// ([baseSizeAdjustment]); negative is denser.
class VisualDensity {
  /// A density; 0 on both axes is [standard].
  const VisualDensity({this.horizontal = 0.0, this.vertical = 0.0})
    : assert(horizontal >= minimumDensity && horizontal <= maximumDensity),
      assert(vertical >= minimumDensity && vertical <= maximumDensity);

  /// The lowest density step allowed (Flutter's `minimumDensity`).
  static const double minimumDensity = -4.0;

  /// The highest density step allowed (Flutter's `maximumDensity`).
  static const double maximumDensity = 4.0;

  /// The default: no adjustment.
  static const standard = VisualDensity();

  /// One step denser on both axes.
  static const comfortable = VisualDensity(horizontal: -1, vertical: -1);

  /// Two steps denser on both axes.
  static const compact = VisualDensity(horizontal: -2, vertical: -2);

  /// Horizontal step, from [minimumDensity] to [maximumDensity].
  final double horizontal;

  /// Vertical step, from [minimumDensity] to [maximumDensity].
  final double vertical;

  /// How much a control's minimum size changes: 4 logical pixels a step.
  Offset get baseSizeAdjustment => Offset(horizontal * 4.0, vertical * 4.0);

  @override
  bool operator ==(Object other) =>
      other is VisualDensity &&
      other.horizontal == horizontal &&
      other.vertical == vertical;

  @override
  int get hashCode => Object.hash(horizontal, vertical);
}

/// Flutter's `Size`: a width and a height in logical pixels.
class Size {
  /// A size of [width] × [height].
  const Size(this.width, this.height);

  /// A square of [dimension].
  const Size.square(double dimension) : width = dimension, height = dimension;

  /// An empty size (a `minimumSize` that lets a button shrink to its
  /// content).
  static const zero = Size(0, 0);

  /// Only a width (the height is unconstrained).
  const Size.fromWidth(this.width) : height = double.infinity;

  /// Only a height (the width is unconstrained).
  const Size.fromHeight(this.height) : width = double.infinity;

  /// The width.
  final double width;

  /// The height.
  final double height;

  @override
  bool operator ==(Object other) =>
      other is Size && other.width == width && other.height == height;

  @override
  int get hashCode => Object.hash(width, height);
}

class _AdaptiveConstraints extends BoxConstraints {
  _AdaptiveConstraints(this.adaptive)
    : super(
        minWidth: adaptive.base.minWidth,
        maxWidth: adaptive.base.maxWidth,
        minHeight: adaptive.base.minHeight,
        maxHeight: adaptive.base.maxHeight,
      );

  @override
  final Adaptive<BoxConstraints> adaptive;

  @override
  CssDeclarations _computeCss() => adaptive.declarations(
    (c) => c.toCss(),
    resets: const {
      'min-width': '0',
      'max-width': 'none',
      'min-height': '0',
      'max-height': 'none',
    },
  );
}
