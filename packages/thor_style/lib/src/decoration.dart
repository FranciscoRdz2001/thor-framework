import 'dart:math' as math;

import 'adaptive.dart';
import 'alignment.dart';
import 'color.dart';
import 'css.dart';
import 'equality.dart';
import 'geometry.dart';
import 'layout_enums.dart';

/// Flutter's `BorderSide`.
class BorderSide {
  /// Creates a border side, defaulting to a solid 1-pixel black line.
  const BorderSide({
    this.color = const Color(0xFF000000),
    this.width = 1,
    this.style = BorderStyle.solid,
  });

  /// A border side that draws nothing.
  static const none = BorderSide(width: 0, style: BorderStyle.none);

  /// Color of the line.
  final Color color;

  /// Thickness of the line, in logical pixels.
  final double width;

  /// Whether the line is drawn (`BorderStyle.none` hides it).
  final BorderStyle style;

  /// CSS `border` shorthand value (`none` when [style] is
  /// `BorderStyle.none`).
  String get css => style == BorderStyle.none
      ? 'none'
      : '${cssPx(width)} ${style.css} ${color.css}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BorderSide &&
          other.color == color &&
          other.width == width &&
          other.style == style;

  @override
  int get hashCode => Object.hash(color, width, style);
}

/// Flutter's `Border`.
class Border {
  /// Creates a border from independent sides, each defaulting to none.
  const Border({
    this.top = BorderSide.none,
    this.right = BorderSide.none,
    this.bottom = BorderSide.none,
    this.left = BorderSide.none,
  });

  /// Creates a border where all four sides use the same [side].
  const Border.fromBorderSide(BorderSide side)
    : top = side,
      right = side,
      bottom = side,
      left = side;

  /// Creates a border with [vertical] sides (top/bottom) and [horizontal]
  /// sides (left/right).
  const Border.symmetric({
    BorderSide vertical = BorderSide.none,
    BorderSide horizontal = BorderSide.none,
  }) : top = horizontal,
       bottom = horizontal,
       left = vertical,
       right = vertical;

  /// Creates a uniform border with the given [color], [width] and [style]
  /// on all four sides.
  factory Border.all({
    Color color = const Color(0xFF000000),
    double width = 1,
    BorderStyle style = BorderStyle.solid,
  }) => Border.fromBorderSide(
    BorderSide(color: color, width: width, style: style),
  );

  /// The top edge.
  final BorderSide top;

  /// The right edge.
  final BorderSide right;

  /// The bottom edge.
  final BorderSide bottom;

  /// The left edge.
  final BorderSide left;

  /// Memoized per instance (value types are mostly `const`); callers must
  /// not mutate the result.
  CssDeclarations toCss() => _cssCache[this] ??= _computeCss();

  CssDeclarations _computeCss() {
    final t = top.css, r = right.css, b = bottom.css, l = left.css;
    if (t == r && r == b && b == l) return {'border': t};
    return {
      if (t != 'none') 'border-top': t,
      if (r != 'none') 'border-right': r,
      if (b != 'none') 'border-bottom': b,
      if (l != 'none') 'border-left': l,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Border &&
          other.top == top &&
          other.right == right &&
          other.bottom == bottom &&
          other.left == left;

  @override
  int get hashCode => Object.hash(top, right, bottom, left);
}

/// Flutter's `BoxShadow`. [inset] is a web extra.
class BoxShadow {
  /// Creates a box shadow, defaulting to an opaque black shadow with no
  /// offset or blur.
  const BoxShadow({
    this.color = const Color(0xFF000000),
    this.offset = Offset.zero,
    this.blurRadius = 0,
    this.spreadRadius = 0,
    this.inset = false,
  });

  /// Color of the shadow.
  final Color color;

  /// Translation of the shadow from the box, in logical pixels.
  final Offset offset;

  /// Standard deviation of the blur, in logical pixels.
  final double blurRadius;

  /// Amount the shadow expands (or shrinks, if negative) before blurring.
  final double spreadRadius;

  /// Whether the shadow is drawn inside the box (`inset` in CSS terms).
  final bool inset;

  /// The `box-shadow` value: `[inset] offsetX offsetY blur spread color`.
  String get css =>
      '${inset ? 'inset ' : ''}${cssPx(offset.dx)} ${cssPx(offset.dy)} '
      '${cssPx(blurRadius)} ${cssPx(spreadRadius)} ${color.css}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BoxShadow &&
          other.color == color &&
          other.offset == offset &&
          other.blurRadius == blurRadius &&
          other.spreadRadius == spreadRadius &&
          other.inset == inset;

  @override
  int get hashCode =>
      Object.hash(color, offset, blurRadius, spreadRadius, inset);
}

/// Base for gradients.
sealed class Gradient {
  const Gradient({required this.colors, this.stops, this.tile});

  /// Colors to use for the gradient stops.
  final List<Color> colors;

  /// Position of each color, as a fraction (0..1) along the gradient. Null
  /// spaces [colors] evenly.
  final List<double>? stops;

  /// `// web:` repeats the gradient in tiles of this size (a dotted or
  /// striped pattern; Flutter paints one with a `CustomPainter`).
  final Size? tile;

  /// CSS gradient function (`linear-gradient(...)`, `radial-gradient(...)`).
  String get css;

  /// The gradients painted, top first: this one, or a [LayeredGradient]'s.
  List<Gradient> get layers => [this];

  /// The color stops, remapped from 0..1 onto [from]..[to] of the line.
  String _stops([double from = 0, double to = 1]) {
    final remap = from != 0 || to != 1;
    final n = colors.length;
    return [
      for (var i = 0; i < n; i++)
        if (stops == null && !remap)
          colors[i].css
        else
          '${colors[i].css} ${cssNum(_pct(stops?[i] ?? (n > 1 ? i / (n - 1) : 0), from, to))}%',
    ].join(', ');
  }

  static double _pct(double s, double from, double to) =>
      double.parse(((from + s * (to - from)) * 100).toStringAsFixed(4));

  // The fields every gradient shares; the subclasses add their own.
  bool _sameBase(Gradient o) =>
      listsEqual(o.colors, colors) &&
      listsEqual(o.stops, stops) &&
      o.tile == tile;

  int get _baseHash => Object.hash(hashList(colors), hashList(stops), tile);
}

/// Flutter's `LinearGradient`.
class LinearGradient extends Gradient {
  /// Creates a linear gradient running from [begin] to [end], defaulting
  /// to left-to-right.
  const LinearGradient({
    this.begin = Alignment.centerLeft,
    this.end = Alignment.centerRight,
    required super.colors,
    super.stops,
    super.tile,
  });

  /// Point where the gradient starts.
  final Alignment begin;

  /// Point where the gradient ends.
  final Alignment end;

  @override
  String get css {
    // Direction vector in CSS space (y grows downward, 0deg = to top).
    final dx = end.x - begin.x, dy = end.y - begin.y;
    final deg = (math.atan2(dx, -dy) * 180 / math.pi) % 360;
    // web: CSS draws the gradient line across the whole box, so a gradient
    // that covers only part of an axis (`topCenter` to `center`) has its
    // stops remapped onto that part. Diagonals use the box's own line.
    var a0 = 0.0, a1 = 1.0;
    if (dx == 0 && dy != 0) {
      (a0, a1) = _span(begin.y, end.y);
    } else if (dy == 0 && dx != 0) {
      (a0, a1) = _span(begin.x, end.x);
    }
    final angle = cssNum(double.parse(deg.toStringAsFixed(2)));
    return 'linear-gradient(${angle}deg, ${_stops(a0, a1)})';
  }

  /// Where [from] and [to] (-1..1) sit along the travel direction, 0..1.
  static (double, double) _span(double from, double to) => to > from
      ? ((from + 1) / 2, (to + 1) / 2)
      : ((1 - from) / 2, (1 - to) / 2);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LinearGradient &&
          other.begin == begin &&
          other.end == end &&
          _sameBase(other);

  @override
  int get hashCode => Object.hash(LinearGradient, begin, end, _baseHash);
}

/// Flutter's `RadialGradient`: a circle of [radius] times the shortest side
/// of the box.
class RadialGradient extends Gradient {
  /// Creates a circular gradient centered at [center] with the given
  /// [radius] (a fraction of the box's shortest side, 0.5 by default: the
  /// circle touches the sides of a centered gradient).
  const RadialGradient({
    this.center = Alignment.center,
    this.radius = 0.5,
    required super.colors,
    super.stops,
    super.tile,
  }) : radiusX = null,
       radiusY = null;

  /// Creates an elliptical gradient: [radiusX] and [radiusY] are shares of
  /// the box's width and height (`1.2` and `1.0` are 120% and 100%), so it
  /// stretches with the box. [center] is where it starts.
  ///
  /// `// web:` not in Flutter (its radial gradients are circles, scaled by a
  /// transform); CSS has `radial-gradient(120% 100% at 26% 16%, …)`. The
  /// [stops] are shares of the radius, as in the circle.
  const RadialGradient.ellipse({
    this.center = Alignment.center,
    required double this.radiusX,
    required double this.radiusY,
    required super.colors,
    super.stops,
    super.tile,
  }) : radius = 0.5;

  /// The horizontal and vertical radius of an [RadialGradient.ellipse], as
  /// shares of the box; null on a circle.
  final double? radiusX;

  /// See [radiusX].
  final double? radiusY;

  /// Center of the gradient circle.
  final Alignment center;

  /// Radius of the gradient circle, as a fraction of the box's shortest
  /// side (the [stops] are fractions of this radius).
  final double radius;

  @override
  String get css {
    if (radiusX case final rx?) {
      return 'radial-gradient(${cssNum(rx * 100)}% ${cssNum(radiusY! * 100)}% '
          'at ${center.cssPosition}, ${_stops()})';
    }
    // web: CSS has no radius relative to the shortest side, so the stops are
    // laid on a keyword radius whose length is known. Centered, the nearest
    // side is half the shortest one (exact on any box). Off-center the
    // nearest side shrinks, so the farthest corner is used and the box is
    // taken as a square (exact there, an approximation elsewhere).
    final cx = (center.x + 1) / 2, cy = (center.y + 1) / 2;
    final centered = center.x == 0 && center.y == 0;
    final reference = centered
        ? 0.5
        : math.sqrt(
            math.pow(math.max(cx, 1 - cx), 2) +
                math.pow(math.max(cy, 1 - cy), 2),
          );
    final scale = radius / reference;
    final size = centered ? 'closest-side' : 'farthest-corner';
    return 'radial-gradient(circle $size at ${center.cssPosition}, '
        '${_stops(0, scale)})';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RadialGradient &&
          other.center == center &&
          other.radius == radius &&
          other.radiusX == radiusX &&
          other.radiusY == radiusY &&
          _sameBase(other);

  @override
  int get hashCode =>
      Object.hash(RadialGradient, center, radius, radiusX, radiusY, _baseHash);
}

/// Several gradients painted on top of each other in one box (the first is
/// the topmost), like CSS's comma-separated `background-image`.
///
/// ```dart
/// BoxDecoration(
///   gradient: LayeredGradient([
///     RadialGradient(colors: [glow, transparent]),
///     RadialGradient(colors: [dot, dot, transparent], stops: [0, .1, .1], tile: Size(16, 16)),
///   ]),
/// )
/// ```
///
/// `// web:` Flutter's [BoxDecoration] holds one gradient; to stack more it
/// nests a `DecoratedBox` per layer (which works here too, at the cost of an
/// element each). The layers share the box's `background-color`, which sits
/// below all of them, and each keeps its own [Gradient.tile].
class LayeredGradient extends Gradient {
  /// Stacks [gradients] in one box, the first on top.
  const LayeredGradient(List<Gradient> gradients)
    : _gradients = gradients,
      super(colors: const []);

  final List<Gradient> _gradients;

  @override
  List<Gradient> get layers => [for (final g in _gradients) ...g.layers];

  @override
  String get css => layers.map((g) => g.css).join(', ');

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LayeredGradient && listsEqual(other._gradients, _gradients);

  @override
  int get hashCode => Object.hash(LayeredGradient, hashList(_gradients));
}

/// Flutter's `DecorationImage` (network/asset URL).
class DecorationImage {
  /// Creates a background image from [url].
  const DecorationImage({
    required this.url,
    this.fit,
    this.alignment = Alignment.center,
    this.repeat = false,
  });

  /// Network or asset URL of the image.
  final String url;

  /// How the image fits its box (`background-size`).
  final BoxFit? fit;

  /// Position of the image within its box (`background-position`).
  final Alignment alignment;

  /// Whether the image tiles to fill its box.
  final bool repeat;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DecorationImage &&
          other.url == url &&
          other.fit == fit &&
          other.alignment == alignment &&
          other.repeat == repeat;

  @override
  int get hashCode => Object.hash(url, fit, alignment, repeat);
}

/// Flutter's `Decoration` (what `DecoratedBoxTransition` animates).
///
/// `// web:` thor has the one kind of decoration, [BoxDecoration], so the
/// two names are the same type.
typedef Decoration = BoxDecoration;

/// Flutter's `BoxDecoration`.
class BoxDecoration with Adaptable<BoxDecoration> {
  @override
  BoxDecoration withVariants(Adaptive<BoxDecoration> variants) =>
      _AdaptiveDecoration(variants);

  /// Creates a box decoration, defaulting to a plain rectangle with no
  /// fill, border or shadow.
  const BoxDecoration({
    this.color,
    this.image,
    this.border,
    this.borderRadius,
    this.boxShadow,
    this.gradient,
    this.shape = BoxShape.rectangle,
  });

  /// Background fill color.
  final Color? color;

  /// Background image.
  final DecorationImage? image;

  /// Outline drawn around the box.
  final Border? border;

  /// Corner rounding, ignored when [shape] is `BoxShape.circle`.
  final BorderRadiusGeometry? borderRadius;

  /// Shadows cast behind (or inset within) the box.
  final List<BoxShadow>? boxShadow;

  /// Background gradient, layered above [color] and below [image].
  final Gradient? gradient;

  /// Rectangle or circle outline.
  final BoxShape shape;

  /// This decoration with the given fields replaced, like Flutter's (on every
  /// variant too, when built with `.when()`).
  BoxDecoration copyWith({
    Color? color,
    DecorationImage? image,
    Border? border,
    BorderRadiusGeometry? borderRadius,
    List<BoxShadow>? boxShadow,
    Gradient? gradient,
    BoxShape? shape,
  }) => _each(
    (d) => BoxDecoration(
      color: color ?? d.color,
      image: image ?? d.image,
      border: border ?? d.border,
      borderRadius: borderRadius ?? d.borderRadius,
      boxShadow: boxShadow ?? d.boxShadow,
      gradient: gradient ?? d.gradient,
      shape: shape ?? d.shape,
    ),
  );

  // Maps over the variants when built with `.when()`.
  BoxDecoration _each(BoxDecoration Function(BoxDecoration plain) f) => f(this);

  // Like Flutter's: by value. A decoration built with `.when()` is equal to
  // another with the same base and variants (`_AdaptiveDecoration`), never to
  // a plain one.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other.runtimeType == runtimeType &&
          other is BoxDecoration &&
          other.color == color &&
          other.image == image &&
          other.border == border &&
          other.borderRadius == borderRadius &&
          listsEqual(other.boxShadow, boxShadow) &&
          other.gradient == gradient &&
          other.shape == shape;

  @override
  int get hashCode => Object.hash(
    runtimeType,
    color,
    image,
    border,
    borderRadius,
    hashList(boxShadow),
    gradient,
    shape,
  );

  /// Memoized per instance (value types are mostly `const`); callers must
  /// not mutate the result.
  CssDeclarations toCss() => _cssCache[this] ??= _computeCss();

  CssDeclarations _computeCss() {
    final layers = gradient?.layers ?? const <Gradient>[];
    final images = [
      for (final g in layers) g.css,
      if (image != null) cssUrl(image!.url),
    ];
    return {
      if (color != null) 'background-color': color!.css,
      if (images.isNotEmpty) 'background-image': images.join(', '),
      if (layers.any((g) => g.tile != null) || image?.fit != null)
        'background-size': [
          for (final g in layers)
            switch (g.tile) {
              final t? => '${cssPx(t.width)} ${cssPx(t.height)}',
              null => 'auto',
            },
          if (image != null)
            switch (image!.fit) {
              BoxFit.fill => '100% 100%',
              BoxFit.fitWidth => '100% auto',
              BoxFit.fitHeight => 'auto 100%',
              BoxFit.none || null => 'auto',
              BoxFit.scaleDown => 'contain',
              final f => f.css,
            },
        ].join(', '),
      if (image != null) ...{
        // One value per layer: the image's position and repeat must not
        // reach the gradients under it (a tile needs `repeat`).
        'background-position': [
          for (final _ in layers) '0% 0%',
          image!.alignment.cssPosition,
        ].join(', '),
        'background-repeat': [
          for (final _ in layers) 'repeat',
          image!.repeat ? 'repeat' : 'no-repeat',
        ].join(', '),
      },
      ...?border?.toCss(),
      if (shape == BoxShape.circle)
        'border-radius': '50%'
      else if (borderRadius != null)
        ...borderRadius!.toCss(),
      if (boxShadow != null && boxShadow!.isNotEmpty)
        'box-shadow': boxShadow!.map((s) => s.css).join(', '),
    };
  }
}

final _cssCache = Expando<CssDeclarations>('thor-css');

/// Flutter's `OutlinedBorder`: the shape of a button or a card.
sealed class OutlinedBorder {
  const OutlinedBorder({this.side = BorderSide.none});

  /// The outline (none by default).
  final BorderSide side;

  /// CSS `border-radius`.
  String get radiusCss;
}

/// Flutter's `RoundedRectangleBorder`.
class RoundedRectangleBorder extends OutlinedBorder {
  /// A rectangle with [borderRadius] corners and an optional [side].
  const RoundedRectangleBorder({
    super.side,
    this.borderRadius = BorderRadius.zero,
  });

  /// Corner radii.
  final BorderRadius borderRadius;

  @override
  String get radiusCss => borderRadius.css;
}

/// Flutter's `StadiumBorder`: fully rounded ends.
class StadiumBorder extends OutlinedBorder {
  /// A pill shape with an optional [side].
  const StadiumBorder({super.side});

  @override
  String get radiusCss => cssPillRadius;
}

/// Flutter's `CircleBorder`: a circle (an avatar, a round button).
///
/// `// web:` it is `border-radius: 50%`: on a non-square box that is an oval,
/// where Flutter draws the circle of the shorter side ([eccentricity] 0).
/// Give the box equal sides, as the round buttons do.
class CircleBorder extends OutlinedBorder {
  /// A circle with an optional [side]; [eccentricity] 1 is an oval.
  const CircleBorder({super.side, this.eccentricity = 0.0})
    : assert(eccentricity >= 0.0 && eccentricity <= 1.0);

  /// How much it deforms to fit a non-square box: 0 is a circle, 1 an oval.
  /// `// web:` not applied; the CSS ellipse follows the box.
  final double eccentricity;

  @override
  String get radiusCss => '50%';
}

/// Flutter's `OvalBorder`: `CircleBorder(eccentricity: 1)`.
class OvalBorder extends CircleBorder {
  /// An oval that fills its box, with an optional [side].
  const OvalBorder({super.side, super.eccentricity = 1.0});
}

/// Flutter's `ContinuousRectangleBorder`: the squircle corners of iOS.
///
/// `// web:` CSS has no superellipse corner, so it is a plain
/// `border-radius` (the same radii, a little less smooth).
class ContinuousRectangleBorder extends OutlinedBorder {
  /// A rectangle with [borderRadius] corners and an optional [side].
  const ContinuousRectangleBorder({
    super.side,
    this.borderRadius = BorderRadius.zero,
  });

  /// Corner radii.
  final BorderRadius borderRadius;

  @override
  String get radiusCss => borderRadius.css;
}

class _AdaptiveDecoration extends BoxDecoration {
  _AdaptiveDecoration(this.adaptive)
    : super(
        color: adaptive.base.color,
        image: adaptive.base.image,
        border: adaptive.base.border,
        borderRadius: adaptive.base.borderRadius,
        boxShadow: adaptive.base.boxShadow,
        gradient: adaptive.base.gradient,
        shape: adaptive.base.shape,
      );

  @override
  final Adaptive<BoxDecoration> adaptive;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _AdaptiveDecoration && other.adaptive == adaptive;

  @override
  int get hashCode => adaptive.hashCode;

  @override
  BoxDecoration _each(BoxDecoration Function(BoxDecoration plain) f) =>
      _AdaptiveDecoration(adaptive.map((d) => d._each(f)));

  @override
  CssDeclarations _computeCss() => adaptive.declarations(
    (d) => d.toCss(),
    resets: const {
      'background-color': 'transparent',
      'background-image': 'none',
      'border': 'none',
      'border-top': 'none',
      'border-right': 'none',
      'border-bottom': 'none',
      'border-left': 'none',
      'border-radius': '0',
      'border-start-start-radius': '0',
      'border-start-end-radius': '0',
      'border-end-start-radius': '0',
      'border-end-end-radius': '0',
      'box-shadow': 'none',
    },
  );
}
