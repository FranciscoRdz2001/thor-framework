import 'package:test/test.dart';
import 'package:thor_style/thor_style.dart';

const _fluid = Length.clamp(Length.px(40), Length.vw(5), Length.px(72));

void main() {
  test('a Length size wins over the number in the CSS', () {
    const style = TextStyle(fontSize: 40, fontSizeLength: _fluid);
    expect(style.toCss()['font-size'], 'clamp(40px, 5vw, 72px)');
    expect(style.fontSize, 40, reason: 'Dart code still reads the number');
  });

  test('letter spacing in em follows every size with one value', () {
    const style = TextStyle(
      letterSpacing: -0.8,
      letterSpacingLength: Length.em(-0.02),
    );
    expect(style.toCss()['letter-spacing'], '-0.02em');
    expect(
      const TextStyle(letterSpacing: 1.5).toCss()['letter-spacing'],
      '1.5px',
    );
  });

  test('a new number in copyWith replaces the old Length', () {
    const fluid = TextStyle(
      fontSizeLength: _fluid,
      letterSpacingLength: Length.em(-0.02),
    );
    final fixed = fluid.copyWith(fontSize: 20, letterSpacing: 0.5);
    expect(fixed.toCss()['font-size'], '20px');
    expect(fixed.toCss()['letter-spacing'], '0.5px');
    // Anything else keeps it.
    final bold = fluid.copyWith(fontWeight: FontWeight.w700);
    expect(bold.toCss()['font-size'], 'clamp(40px, 5vw, 72px)');
    expect(bold.toCss()['letter-spacing'], '-0.02em');
  });

  test('merge: the other style’s Length wins', () {
    const base = TextStyle(fontSize: 16);
    final merged = base.merge(
      const TextStyle(fontSizeLength: Length.rem(1.25)),
    );
    expect(merged.toCss()['font-size'], '1.25rem');
  });

  test('a theme role reads its variable, with the Length as fallback', () {
    final role = const TextStyle(
      fontSize: 40,
      fontSizeLength: _fluid,
      letterSpacingLength: Length.em(-0.02),
    ).withRole(TextThemeRole.displayLarge);
    final css = role.toCss();
    expect(
      css['font-size'],
      'var(--t-display-large-size, clamp(40px, 5vw, 72px))',
    );
    expect(css['letter-spacing'], 'var(--t-display-large-tracking, -0.02em)');
    // Overriding with another Length is emitted as is.
    final other = role.copyWith(fontSizeLength: const Length.rem(3));
    expect(other.toCss()['font-size'], '3rem');
  });

  group('heightLength', () {
    test('a line height in px or em wins over the factor', () {
      const px = TextStyle(
        fontSize: 14.8,
        height: 1.3514,
        heightLength: Length.px(20),
      );
      expect(px.toCss()['line-height'], '20px');
      expect(px.height, 1.3514, reason: 'Dart code still reads the number');
      expect(
        const TextStyle(heightLength: Length.em(1.75)).toCss()['line-height'],
        '1.75em',
      );
      expect(const TextStyle(height: 1.5).toCss()['line-height'], '1.5');
    });

    test('copyWith(height:) replaces it, merge keeps the other one', () {
      const em = TextStyle(heightLength: Length.em(1.75));
      expect(em.copyWith(height: 1.2).toCss()['line-height'], '1.2');
      expect(em.copyWith(fontSize: 12).toCss()['line-height'], '1.75em');
      expect(
        const TextStyle(height: 1.2).merge(em).toCss()['line-height'],
        '1.75em',
      );
    });

    test('a role follows its variable unless the length differs', () {
      final role = const TextStyle(
        fontSize: 14,
        heightLength: Length.px(20),
      ).withRole(TextThemeRole.bodyMedium);
      expect(role.toCss()['line-height'], 'var(--t-body-medium-line, 20px)');
      expect(role.copyWith(heightLength: 24.px).toCss()['line-height'], '24px');
    });
  });

  test('a font size relative to the text around it', () {
    const code = TextStyle(fontSizeLength: Length.em(0.9));
    expect(code.toCss()['font-size'], '0.9em');
  });
}
