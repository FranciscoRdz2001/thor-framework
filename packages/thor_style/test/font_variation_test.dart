import 'package:test/test.dart';
import 'package:thor_style/thor_style.dart';

void main() {
  test('fontVariations: font-variation-settings, like Flutter', () {
    const style = TextStyle(
      fontVariations: [
        FontVariation('FILL', 0),
        FontVariation('GRAD', 0),
        FontVariation.opticalSize(24),
        FontVariation.weight(400),
      ],
    );
    expect(
      style.toCss()['font-variation-settings'],
      '"FILL" 0, "GRAD" 0, "opsz" 24, "wght" 400',
    );
    expect(
      const TextStyle(fontVariations: []).toCss(),
      isNot(contains('font-variation-settings')),
    );
  });

  test('the named axes are Flutter\'s', () {
    expect(const FontVariation.italic(1).axis, 'ital');
    expect(const FontVariation.slant(-10).css, '"slnt" -10');
    expect(const FontVariation.width(87.5).css, '"wdth" 87.5');
  });

  test('merge and copyWith keep them', () {
    const base = TextStyle(fontVariations: [FontVariation('FILL', 1)]);
    expect(
      base.merge(const TextStyle(fontSize: 12)).toCss(),
      containsPair('font-variation-settings', '"FILL" 1'),
    );
    expect(
      base
          .copyWith(fontVariations: const [FontVariation.opticalSize(20)])
          .toCss(),
      containsPair('font-variation-settings', '"opsz" 20'),
    );
  });

  test('lerp on one axis', () {
    expect(
      FontVariation.lerp(
        const FontVariation.weight(400),
        const FontVariation.weight(700),
        0.5,
      ),
      const FontVariation.weight(550),
    );
  });
}
