// ThemeData.fontFamily with a name that has a space ('Exo 2') is quoted:
// an unquoted `Exo 2` is an invalid font-family and the browser drops it.
import 'package:test/test.dart';
import 'package:thor_ui/thor_ui.dart';

void main() {
  test('a single name with a space is quoted', () {
    final vars = ThemeData(fontFamily: 'Exo 2').toCssVariables();
    expect(vars['font-family'], '"Exo 2"');
  });

  test('quoted names, generic families and stacks are left alone', () {
    expect(
      ThemeData(fontFamily: '"Exo 2"').toCssVariables()['font-family'],
      '"Exo 2"',
    );
    expect(
      ThemeData(fontFamily: "'Exo 2'").toCssVariables()['font-family'],
      "'Exo 2'",
    );
    expect(
      ThemeData(fontFamily: 'Inter').toCssVariables()['font-family'],
      'Inter',
    );
    expect(
      ThemeData(
        fontFamily: 'Source Sans 3, sans-serif',
      ).toCssVariables()['font-family'],
      'Source Sans 3, sans-serif',
    );
  });

  test('with fallbacks the name is quoted once', () {
    final vars = ThemeData(
      fontFamily: 'Baloo 2',
      fontFamilyFallback: const ['Noto Sans', 'sans-serif'],
    ).toCssVariables();
    expect(vars['font-family'], '"Baloo 2", "Noto Sans", sans-serif');
  });

  test('TextStyle accepts names already in single quotes', () {
    final css = const TextStyle(fontFamily: "'Exo 2'").toCss();
    expect(css['font-family'], "'Exo 2'");
  });
}
