import 'package:test/test.dart';
import 'package:thor_style/thor_style.dart';

void main() {
  test('fontFeatures: font-feature-settings, like Flutter', () {
    const style = TextStyle(
      fontFeatures: [FontFeature.tabularFigures(), FontFeature.disable('liga')],
    );
    expect(style.toCss()['font-feature-settings'], '"tnum" 1, "liga" 0');
    expect(const TextStyle().toCss(), isNot(contains('font-feature-settings')));
  });

  test('merge and copyWith keep them; a tag is sanitized', () {
    const base = TextStyle(fontFeatures: [FontFeature.tabularFigures()]);
    expect(
      base.merge(const TextStyle(fontSize: 12)).toCss(),
      containsPair('font-feature-settings', '"tnum" 1'),
    );
    expect(
      base.copyWith(fontFeatures: const [FontFeature('ss01')]).toCss(),
      containsPair('font-feature-settings', '"ss01" 1'),
    );
    expect(const FontFeature('a"};x').css, '"ax" 1');
  });
}
