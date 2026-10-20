import 'package:test/test.dart';
import 'package:thor_style/thor_style.dart';

void main() {
  const gutter = CssVariable<Length>('--gutter');

  test('a variable names itself and writes its reference', () {
    expect(gutter.name, '--gutter');
    expect(gutter.css, 'var(--gutter)');
  });

  test('Length.variable and Color.variable take it', () {
    expect(const Length.variable(gutter).css, 'var(--gutter)');
    expect(
      const Length.variable(gutter, fallback: Length.px(16)).css,
      'var(--gutter, 16px)',
    );
    const accent = CssVariable<Color>('--accent');
    expect(const Color.variable(accent).css, 'var(--accent)');
    expect(const Color.variable(accent).variableName, '--accent');
  });

  test('Color.token is the --t-<name> theme variable', () {
    expect(const Color.token('band').variableName, '--t-band');
    expect(const Color.token('band').css, 'var(--t-band)');
  });

  test('two variables with the same name are equal and hash alike', () {
    expect(const CssVariable<Length>('--a'), const CssVariable<Length>('--a'));
    expect({const CssVariable<Length>('--a'): 1}[gutter], isNull);
    expect({gutter: 1}[const CssVariable<Length>('--gutter')], 1);
  });

  test('isValidName accepts custom properties only', () {
    for (final ok in ['--a', '--grid-before', '--col_2', '--X1']) {
      expect(CssVariable.isValidName(ok), isTrue, reason: ok);
    }
    for (final bad in ['a', '-a', '--', '--a b', '--a;color:red', 'color']) {
      expect(CssVariable.isValidName(bad), isFalse, reason: bad);
    }
  });
}
