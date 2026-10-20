import 'package:test/test.dart';
import 'package:thor_style/thor_style.dart';

const _amber = ColorScale(
  0xFFD6A514,
  shade50: Color(0xFFFCF9EE),
  shade100: Color(0xFFF8EFCF),
  shade200: Color(0xFFF1DF9B),
  shade300: Color(0xFFE9CC63),
  shade400: Color(0xFFE0B93A),
  shade500: Color(0xFFD6A514),
  shade600: Color(0xFFB58A0F),
  shade700: Color(0xFF926D0E),
  shade800: Color(0xFF785A14),
  shade900: Color(0xFF664C17),
  shade950: Color(0xFF3B2A09),
);

void main() {
  group('ColorSwatch', () {
    test('is its primary color, and looks up the rest by key', () {
      const swatch = ColorSwatch<String>(0xFF112233, {
        'light': Color(0xFFAABBCC),
      });
      expect(swatch.css, '#112233');
      expect(swatch['light'], const Color(0xFFAABBCC));
      expect(swatch['missing'], isNull);
      expect(swatch.keys, ['light']);
    });

    test('two swatches are equal only with the same shades', () {
      const a = ColorSwatch<int>(0xFF000000, {1: Color(0xFF111111)});
      const b = ColorSwatch<int>(0xFF000000, {1: Color(0xFF111111)});
      const c = ColorSwatch<int>(0xFF000000, {1: Color(0xFF222222)});
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });
  });

  test('MaterialColor gives the ten Material shades by name', () {
    const blue = MaterialColor(0xFF2196F3, {
      50: Color(0xFFE3F2FD),
      100: Color(0xFFBBDEFB),
      200: Color(0xFF90CAF9),
      300: Color(0xFF64B5F6),
      400: Color(0xFF42A5F5),
      500: Color(0xFF2196F3),
      600: Color(0xFF1E88E5),
      700: Color(0xFF1976D2),
      800: Color(0xFF1565C0),
      900: Color(0xFF0D47A1),
    });
    expect(blue.css, '#2196f3');
    expect(blue.shade50.css, '#e3f2fd');
    expect(blue.shade900.css, '#0d47a1');
    expect(blue[950], isNull);
  });

  group('ColorScale', () {
    test('has the eleven steps, lightest first, up to 950', () {
      expect(_amber.keys, [
        50,
        100,
        200,
        300,
        400,
        500,
        600,
        700,
        800,
        900,
        950,
      ]);
      expect(_amber.shade950.css, '#3b2a09');
      expect(_amber.shade50.css, '#fcf9ee');
    });

    test('is its 500 shade wherever a Color goes', () {
      expect(_amber.css, '#d6a514');
      expect(_amber.value, _amber.shade500.value);
      const style = TextStyle(color: _amber);
      expect(style.toCss()['color'], '#d6a514');
    });

    test('each named step returns its own shade', () {
      final named = [
        _amber.shade50,
        _amber.shade100,
        _amber.shade200,
        _amber.shade300,
        _amber.shade400,
        _amber.shade500,
        _amber.shade600,
        _amber.shade700,
        _amber.shade800,
        _amber.shade900,
        _amber.shade950,
      ];
      expect(named, [for (final k in _amber.keys) _amber[k]]);
      expect(named.toSet(), hasLength(11), reason: 'no step repeats another');
    });
  });
}
