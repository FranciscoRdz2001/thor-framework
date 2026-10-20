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
}
