// ColorTween over colors whose channels the server doesn't know (a CSS
// expression, a color with `.when()` variants) mixes them in the browser
// instead of reading the channels (THOR-R023).
@TestOn('vm')
library;

import 'package:test/test.dart';
import 'package:thor_ui/thor_ui.dart';

void main() {
  const css = Color.css('hsl(15 100% 50%)');
  final adaptive = const Color(0xFFFFFFFF).when(dark: const Color(0xFF000000));

  test('a CSS or adaptive color lerps with color-mix', () {
    for (final c in [css, adaptive]) {
      expect(
        ColorTween(begin: c, end: Colors.black).lerp(.25)!.css,
        'color-mix(in srgb, ${c.css} 75%, #000000)',
      );
      expect(
        ColorTween(begin: Colors.black, end: c).lerp(.5)!.css,
        'color-mix(in srgb, #000000 50%, ${c.css})',
      );
    }
  });

  test('a missing end is the transparent version of a CSS color', () {
    final mid = ColorTween(begin: css, end: null).lerp(.5)!;
    expect(mid.hasChannels, isFalse);
    expect(mid.css, contains('transparent'));
    expect(mid.css, contains(css.css));
  });
}
