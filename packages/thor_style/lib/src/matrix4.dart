import 'dart:math' as math;

import 'css.dart';

/// Flutter's `Matrix4` (the subset a CSS transform needs): a 4x4 matrix in
/// column-major order that compiles to `matrix()` / `matrix3d()`.
///
/// ```dart
/// Container(transform: Matrix4.rotationZ(0.1) * Matrix4.translationValues(8, 0, 0))
/// ```
///
/// `// web:` Flutter's is `vector_math`'s `Matrix4` (mutable, with the full
/// API); this one is immutable and only builds, multiplies and prints.
class Matrix4 {
  const Matrix4._(this._m);

  /// The identity matrix (no transform).
  factory Matrix4.identity() => const Matrix4._(_identity);

  /// A matrix from 16 [values] in column-major order, like Flutter's
  /// `Matrix4.fromList`.
  factory Matrix4.fromList(List<double> values) {
    assert(values.length == 16, 'A Matrix4 has 16 values.');
    return Matrix4._(List.unmodifiable(values));
  }

  /// Moves by `(x, y, z)` logical pixels.
  factory Matrix4.translationValues(double x, double y, double z) =>
      Matrix4._(_with({12: x, 13: y, 14: z}));

  /// Scales by `(x, y, z)` (a diagonal matrix).
  factory Matrix4.diagonal3Values(double x, double y, double z) =>
      Matrix4._(_with({0: x, 5: y, 10: z}));

  /// Rotates around the z axis by [radians] (what a 2D rotation is).
  factory Matrix4.rotationZ(double radians) {
    final c = math.cos(radians), s = math.sin(radians);
    return Matrix4._(_with({0: c, 1: s, 4: -s, 5: c}));
  }

  /// Rotates around the x axis by [radians].
  factory Matrix4.rotationX(double radians) {
    final c = math.cos(radians), s = math.sin(radians);
    return Matrix4._(_with({5: c, 6: s, 9: -s, 10: c}));
  }

  /// Rotates around the y axis by [radians].
  factory Matrix4.rotationY(double radians) {
    final c = math.cos(radians), s = math.sin(radians);
    return Matrix4._(_with({0: c, 2: -s, 8: s, 10: c}));
  }

  static const _identity = <double>[
    1,
    0,
    0,
    0,
    0,
    1,
    0,
    0,
    0,
    0,
    1,
    0,
    0,
    0,
    0,
    1,
  ];

  static List<double> _with(Map<int, double> changes) {
    final out = [..._identity];
    changes.forEach((i, v) => out[i] = v);
    return List.unmodifiable(out);
  }

  final List<double> _m;

  /// This matrix times [other]: [other] applies to a point first, like
  /// Flutter (`translate * scale` scales, then moves).
  Matrix4 operator *(Matrix4 other) {
    final out = List<double>.filled(16, 0);
    for (var col = 0; col < 4; col++) {
      for (var row = 0; row < 4; row++) {
        var sum = 0.0;
        for (var k = 0; k < 4; k++) {
          sum += _m[k * 4 + row] * other._m[col * 4 + k];
        }
        out[col * 4 + row] = sum;
      }
    }
    return Matrix4._(List.unmodifiable(out));
  }

  /// Same as `this * other`.
  Matrix4 multiplied(Matrix4 other) => this * other;

  /// The value at [index] (0..15, column-major).
  double operator [](int index) => _m[index];

  bool get _is2D =>
      _m[2] == 0 &&
      _m[3] == 0 &&
      _m[6] == 0 &&
      _m[7] == 0 &&
      _m[8] == 0 &&
      _m[9] == 0 &&
      _m[10] == 1 &&
      _m[11] == 0 &&
      _m[14] == 0 &&
      _m[15] == 1;

  static String _n(double v) {
    final r = (v * 1e6).roundToDouble() / 1e6;
    return cssNum(r == 0 ? 0 : r);
  }

  /// The CSS `transform` value: `none` for the identity, `matrix()` for a
  /// 2D one, `matrix3d()` otherwise.
  String get css {
    var identity = true;
    for (var i = 0; i < 16; i++) {
      if (_n(_m[i]) != _n(_identity[i])) {
        identity = false;
        break;
      }
    }
    if (identity) return 'none';
    if (_is2D) {
      return 'matrix(${[_m[0], _m[1], _m[4], _m[5], _m[12], _m[13]].map(_n).join(', ')})';
    }
    return 'matrix3d(${_m.map(_n).join(', ')})';
  }

  @override
  bool operator ==(Object other) {
    if (other is! Matrix4) return false;
    for (var i = 0; i < 16; i++) {
      if (_m[i] != other._m[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(_m);

  @override
  String toString() => 'Matrix4($css)';
}

final _originPattern = RegExp(r'^(-?[\d.]+(?:%|px)?) (-?[\d.]+(?:%|px)?)$');

/// Composes the `transform` of an [outer] element's wrapper with the one of
/// the [inner] element it fuses into, like Flutter nests them (the inner
/// applies to the point first). CSS has one `transform` per element, so
/// without this the inner one is silently lost.
///
/// Returns the `transform` (and `transform-origin`) to use, or `null` when
/// there is nothing to compose (one side has no `transform`) or an origin
/// is not a plain `x y` position: the caller keeps its own precedence.
/// Different origins are baked into the list as `translate(origin) t
/// translate(-origin)` (percentages refer to the element's own box, like
/// the origin does), so the result is anchored at `0 0`.
CssDeclarations? composeTransforms(
  CssDeclarations outer,
  CssDeclarations inner,
) {
  final o = outer['transform'], i = inner['transform'];
  if (o == null || i == null || o == 'none' || i == 'none') return null;
  final oo = outer['transform-origin'], io = inner['transform-origin'];
  final same = (oo ?? '50% 50%') == (io ?? '50% 50%');
  if (same) {
    return {'transform': '$o $i', 'transform-origin': ?(io ?? oo)};
  }
  String? bake(String t, String? origin) {
    final m = _originPattern.firstMatch(origin ?? '50% 50%');
    if (m == null) return null;
    final x = m[1]!, y = m[2]!;
    if (double.parse(x.replaceAll(RegExp('[^0-9.-]'), '')) == 0 &&
        double.parse(y.replaceAll(RegExp('[^0-9.-]'), '')) == 0) {
      return t;
    }
    String neg(String v) => v.startsWith('-') ? v.substring(1) : '-$v';
    return 'translate($x, $y) $t translate(${neg(x)}, ${neg(y)})';
  }

  final a = bake(o, oo), b = bake(i, io);
  if (a == null || b == null) return null;
  return {'transform': '$a $b', 'transform-origin': '0 0'};
}
