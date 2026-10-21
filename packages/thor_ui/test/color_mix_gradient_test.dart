import 'package:test/test.dart';
import 'package:thor_ui/thor_ui.dart';

void main() {
  test('RadialGradient.ellipse writes an elliptical gradient at a point', () {
    const g = RadialGradient.ellipse(
      center: Alignment(-0.48, -0.68),
      radiusX: 1.2,
      radiusY: 1,
      colors: [Color(0xFFFF0000), Color(0x00FF0000)],
    );
    expect(
      g.css,
      'radial-gradient(120% 100% at 26% 16%, #ff0000, rgba(255, 0, 0, 0))',
    );
    expect(
      const RadialGradient.ellipse(
        radiusX: 1,
        radiusY: 1,
        colors: [Color(0xFF000000), Color(0xFFFFFFFF)],
      ),
      isNot(
        equals(
          const RadialGradient(colors: [Color(0xFF000000), Color(0xFFFFFFFF)]),
        ),
      ),
    );
  });

  test('Color.lerp mixes a plain color on the server', () {
    expect(
      Color.lerp(const Color(0xFF000000), const Color(0xFFFFFFFF), 0.5),
      const Color(0xFF808080),
    );
    expect(Color.lerp(null, null, 0.5), isNull);
  });

  test('Color.lerp with a theme color is a color-mix the browser resolves', () {
    final mixed = Color.lerp(
      const Color.css('var(--accent)'),
      const Color(0xFFFFFFFF),
      0.78,
    )!;
    expect(mixed.css, 'color-mix(in srgb, var(--accent) 22%, #ffffff)');
  });

  test('withOpacity of a data color is the translucent color', () {
    expect(const Color(0xFF3366FF).withOpacity(0.22).css, startsWith('rgba('));
  });
}
