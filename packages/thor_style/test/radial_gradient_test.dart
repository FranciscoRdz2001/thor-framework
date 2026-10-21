import 'package:test/test.dart';
import 'package:thor_style/thor_style.dart';

/// Flutter's radius is a fraction of the shortest side (0.5 by default); the
/// stops are fractions of that radius.
void main() {
  const colors = [Color(0xFF000000), Color(0xFFFFFFFF)];

  test('the default radius touches the sides of a centered gradient', () {
    expect(
      const RadialGradient(colors: colors).css,
      'radial-gradient(circle closest-side at 50% 50%, #000000, #ffffff)',
    );
  });

  test('a centered radius scales the stops', () {
    expect(
      const RadialGradient(radius: 0.25, colors: colors).css,
      'radial-gradient(circle closest-side at 50% 50%, '
      '#000000 0%, #ffffff 50%)',
    );
    expect(
      const RadialGradient(radius: 1, colors: colors, stops: [0, 0.5]).css,
      contains('#ffffff 100%'),
    );
  });

  test('off-center the farthest corner is the reference', () {
    final css = const RadialGradient(
      center: Alignment.topLeft,
      radius: 0.5,
      colors: colors,
    ).css;
    expect(css, contains('farthest-corner'));
    // 0.5 / sqrt(2) of the farthest corner distance.
    expect(css, contains('#ffffff 35.3553%'));
  });

  group('LayeredGradient', () {
    const glow = RadialGradient(colors: [Color(0xFF112233), Color(0x00112233)]);
    const dots = RadialGradient(
      colors: [Color(0xFF000000), Color(0x00000000)],
      tile: Size(16, 16),
    );

    test('stacks gradients in one background-image, first on top', () {
      final css = const BoxDecoration(
        color: Color(0xFFFFFFFF),
        gradient: LayeredGradient([glow, dots]),
      ).toCss();
      expect(css['background-image'], '${glow.css}, ${dots.css}');
      expect(css['background-size'], 'auto, 16px 16px');
      expect(css['background-color'], '#ffffff');
    });

    test('a single gradient renders as before', () {
      final css = const BoxDecoration(gradient: dots).toCss();
      expect(css['background-image'], dots.css);
      expect(css['background-size'], '16px 16px');
      expect(css.containsKey('background-repeat'), isFalse);
    });

    test('an image gets its own position and repeat after the layers', () {
      final css = const BoxDecoration(
        gradient: LayeredGradient([glow, dots]),
        image: DecorationImage(url: '/a.png', fit: BoxFit.cover),
      ).toCss();
      expect(
        css['background-image'],
        '${glow.css}, ${dots.css}, url("/a.png")',
      );
      expect(css['background-size'], 'auto, 16px 16px, cover');
      expect(css['background-repeat'], 'repeat, repeat, no-repeat');
      expect(css['background-position'], '0% 0%, 0% 0%, 50% 50%');
    });

    test('equal layers are equal; nesting flattens', () {
      expect(
        const LayeredGradient([glow, dots]),
        const LayeredGradient([glow, dots]),
      );
      expect(
        const LayeredGradient([
          LayeredGradient([glow]),
          dots,
        ]).layers,
        [glow, dots],
      );
    });
  });
}
