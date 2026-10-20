import 'package:test/test.dart';
import 'package:thor_style/thor_style.dart';

void main() {
  test('opacity of a hex color changes its alpha', () {
    expect(
      const Color(0xFF112233).withOpacity(0.5).css,
      'rgba(17, 34, 51, 0.502)',
    );
  });

  test('opacity of a theme variable mixes it in the browser', () {
    expect(
      const Color.variable(
        CssVariable('--t-primary'),
      ).withValues(alpha: 0.5).css,
      'color-mix(in srgb, var(--t-primary) 50%, transparent)',
    );
    expect(
      const Color.css('hsl(15 100% 50%)').withOpacity(0.125).css,
      'color-mix(in srgb, hsl(15 100% 50%) 12.5%, transparent)',
    );
  });

  test('alphaBlend paints a translucent color over another, like Flutter', () {
    // Flutter: Color.alphaBlend(Color(0x14A32D2D), Color(0xFFF7F6F3)).
    expect(
      Color.alphaBlend(
        const Color(0xFFA32D2D).withValues(alpha: 0.08),
        const Color(0xFFF7F6F3),
      ).css,
      '#f0e6e3',
    );
    const opaque = Color(0xFF112233);
    expect(Color.alphaBlend(opaque, const Color(0xFFFFFFFF)), opaque);
    const clear = Color(0x00FF0000);
    expect(Color.alphaBlend(clear, opaque), opaque);
    // Over a translucent background the result keeps some alpha.
    expect(
      Color.alphaBlend(const Color(0x80FF0000), const Color(0x800000FF)).alpha,
      0xbf,
    );
    expect(
      () => Color.alphaBlend(const Color.variable(CssVariable('--x')), opaque),
      throwsArgumentError,
    );
  });
}
