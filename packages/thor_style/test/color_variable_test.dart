import 'package:test/test.dart';
import 'package:thor_style/thor_style.dart';

/// A color that is a theme variable has no channels on the server: light or
/// dark is only known in the browser. Reading them used to answer 0 (a
/// transparent black), silently wrong; it fails with the way out (THOR-R023).
void main() {
  cssColorMain();
  const themed = Color.variable(
    CssVariable('--t-primary'),
    fallback: Color(0xFF6750A4),
  );
  const bare = Color.variable(CssVariable('--t-primary'));

  for (final (name, read) in <(String, Object? Function(Color))>[
    ('value', (c) => c.value),
    ('alpha', (c) => c.alpha),
    ('red', (c) => c.red),
    ('green', (c) => c.green),
    ('blue', (c) => c.blue),
    ('opacity', (c) => c.opacity),
  ]) {
    test('reading $name of a theme variable fails, with the fix', () {
      for (final c in [themed, bare]) {
        expect(
          () => read(c),
          throwsA(
            isA<UnsupportedError>().having(
              (e) => e.message,
              'message',
              allOf(
                contains('THOR-R023'),
                contains('--t-primary'),
                contains('withValues(alpha:'),
              ),
            ),
          ),
        );
      }
    });
  }

  test('plain colors keep every channel', () {
    const c = Color(0x80112233);
    expect(
      [c.value, c.alpha, c.red, c.green, c.blue],
      [0x80112233, 0x80, 0x11, 0x22, 0x33],
    );
    expect(c.opacity, closeTo(0.502, 0.001));
  });

  test('withAlpha of a variable mixes it in the browser, not black', () {
    expect(
      themed.withAlpha(128).css,
      'color-mix(in srgb, var(--t-primary, #6750a4) 50.2%, transparent)',
    );
    expect(
      bare.withAlpha(0).css,
      'color-mix(in srgb, var(--t-primary) 0%, transparent)',
    );
  });

  test('withValues(alpha:) and withOpacity keep following the theme', () {
    expect(
      themed.withValues(alpha: 0.5).css,
      'color-mix(in srgb, var(--t-primary, #6750a4) 50%, transparent)',
    );
    expect(
      bare.withOpacity(0.25).css,
      'color-mix(in srgb, var(--t-primary) 25%, transparent)',
    );
  });

  test('alphaBlend says why, with its code', () {
    expect(
      () => Color.alphaBlend(themed, const Color(0xFFFFFFFF)),
      throwsA(
        isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('THOR-R023'),
        ),
      ),
    );
  });

  test('equality and css still tell variables apart', () {
    expect(
      themed,
      const Color.variable(
        CssVariable('--t-primary'),
        fallback: Color(0xFF6750A4),
      ),
    );
    expect(themed, isNot(bare));
    expect(themed.css, 'var(--t-primary, #6750a4)');
    expect(const Color(0xFF6750A4), isNot(themed));
  });
}

/// Color.css and a color with `.when()` variants are resolved in the browser
/// too: their channels throw instead of answering 0.
void cssColorMain() {
  const css = Color.css('hsl(15 100% 50%)');
  final adaptive = const Color(0xFFFFFFFF).when(dark: const Color(0xFF000000));

  test('channels of a CSS or adaptive color throw THOR-R023', () {
    for (final c in [css, adaptive]) {
      expect(c.hasChannels, isFalse);
      for (final read in <Object? Function(Color)>[
        (c) => c.value,
        (c) => c.alpha,
        (c) => c.red,
        (c) => c.opacity,
      ]) {
        expect(
          () => read(c),
          throwsA(
            isA<UnsupportedError>().having(
              (e) => e.message,
              'message',
              contains('THOR-R023'),
            ),
          ),
        );
      }
    }
    expect(const Color(0xFF112233).hasChannels, isTrue);
  });
}
