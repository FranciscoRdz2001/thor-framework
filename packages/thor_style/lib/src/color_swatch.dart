import 'color.dart';

/// Flutter's `ColorSwatch`: a color that also holds a family of related
/// colors, looked up by [T] (`swatch[500]`). The swatch itself is its
/// primary color.
class ColorSwatch<T> extends Color {
  /// A swatch whose own value is [primary], with the colors of [swatch].
  const ColorSwatch(super.primary, Map<T, Color> swatch) : _swatch = swatch;

  final Map<T, Color> _swatch;

  /// The color for [key], or null if the swatch has none.
  Color? operator [](T key) => _swatch[key];

  /// The keys of the swatch, in its order.
  Iterable<T> get keys => _swatch.keys;

  // Compared through [keys] and `[]`, so a subclass that stores its shades
  // as fields (`ColorScale`) compares the same way.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other.runtimeType != runtimeType) return false;
    if (other is! ColorSwatch<T> || other.value != value) return false;
    final mine = keys.toList(), theirs = other.keys.toList();
    if (mine.length != theirs.length) return false;
    for (final key in mine) {
      if (other[key] != this[key]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    value,
    Object.hashAllUnordered(keys.map((k) => Object.hash(k, this[k]))),
  );
}

/// Flutter's `MaterialColor`: the ten shades of the Material palette, 50 to
/// 900, with the 500 one as its own value.
class MaterialColor extends ColorSwatch<int> {
  /// A Material swatch; [swatch] holds the shades 50, 100 … 900.
  const MaterialColor(super.primary, super.swatch);

  /// The lightest shade.
  Color get shade50 => this[50]!;

  /// The second lightest shade.
  Color get shade100 => this[100]!;

  /// The third lightest shade.
  Color get shade200 => this[200]!;

  /// The fourth lightest shade.
  Color get shade300 => this[300]!;

  /// The fifth lightest shade.
  Color get shade400 => this[400]!;

  /// The default shade.
  Color get shade500 => this[500]!;

  /// The fourth darkest shade.
  Color get shade600 => this[600]!;

  /// The third darkest shade.
  Color get shade700 => this[700]!;

  /// The second darkest shade.
  Color get shade800 => this[800]!;

  /// The darkest shade.
  Color get shade900 => this[900]!;
}

/// A color scale of eleven steps, 50 to 950: the one web design systems
/// use, one step darker than [MaterialColor]. Every shade is a
/// required argument, so a scale can't miss one.
///
/// ```dart
/// const amber = ColorScale(0xFFD6A514,
///     shade50: Color(0xFFFCF9EE), /* … */ shade950: Color(0xFF3B2A09));
/// amber            // the 500 shade
/// amber.shade950   // the darkest
/// ```
///
/// `// web:` Flutter's palettes stop at 900; the web's go to 950.
class ColorScale extends ColorSwatch<int> {
  /// A scale whose own value is [primary] (its 500 shade).
  const ColorScale(
    int primary, {
    required this.shade50,
    required this.shade100,
    required this.shade200,
    required this.shade300,
    required this.shade400,
    required this.shade500,
    required this.shade600,
    required this.shade700,
    required this.shade800,
    required this.shade900,
    required this.shade950,
  }) : super(primary, const {});

  /// The eleven steps, lightest first.
  static const steps = [50, 100, 200, 300, 400, 500, 600, 700, 800, 900, 950];

  /// Step 50, the lightest.
  final Color shade50;

  /// Step 100.
  final Color shade100;

  /// Step 200.
  final Color shade200;

  /// Step 300.
  final Color shade300;

  /// Step 400.
  final Color shade400;

  /// Step 500, the scale's own value.
  final Color shade500;

  /// Step 600.
  final Color shade600;

  /// Step 700.
  final Color shade700;

  /// Step 800.
  final Color shade800;

  /// Step 900.
  final Color shade900;

  /// Step 950, the darkest.
  final Color shade950;

  @override
  Iterable<int> get keys => steps;

  @override
  Color? operator [](int key) => switch (key) {
    50 => shade50,
    100 => shade100,
    200 => shade200,
    300 => shade300,
    400 => shade400,
    500 => shade500,
    600 => shade600,
    700 => shade700,
    800 => shade800,
    900 => shade900,
    950 => shade950,
    _ => null,
  };
}
