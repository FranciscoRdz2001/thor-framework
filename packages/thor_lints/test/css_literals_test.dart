import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';
import 'package:thor_lints/src/css_literals.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(DuplicateCssVariableNameTest);
    defineReflectiveTests(AvoidColorCssStringTest);
  });
}

const _style = r'''
final class CssVariable<T> {
  const CssVariable(String name);
}
final class Length {
  const Length.px(double value);
  const Length.variable(CssVariable<Length> name, {Length? fallback});
}
final class Color {
  const Color(int value);
  const Color.css(String raw);
  const Color.variable(CssVariable<Color> name, {Color? fallback});
}
''';

@reflectiveTest
class DuplicateCssVariableNameTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = DuplicateCssVariableName();
    newPackage('thor_style').addFile('lib/thor_style.dart', _style);
    super.setUp();
  }

  Future<void> test_repeatedName() async {
    const source = r'''
import 'package:thor_style/thor_style.dart';
const a = Length.variable(CssVariable('--row-h'));
const b = Length.variable(CssVariable('--row-h'), fallback: Length.px(1));
final c = Color.variable(CssVariable('--row-h'));
''';
    final second = source.indexOf('Length.variable', source.indexOf('const b'));
    final third = source.indexOf('Color.variable');
    await assertDiagnostics(source, [
      lint(
        second,
        "Length.variable(CssVariable('--row-h'), fallback: Length.px(1))"
            .length,
        messageContainsAll: ["'--row-h'"],
      ),
      lint(third, "Color.variable(CssVariable('--row-h'))".length),
    ]);
  }

  Future<void> test_distinctNamesAndComputedNames() async {
    await assertNoDiagnostics(r'''
import 'package:thor_style/thor_style.dart';
const a = Length.variable(CssVariable('--row-h'));
const b = Length.variable(CssVariable('--sel-top'));
Length c(int n) => Length.variable(CssVariable('--w$n'));
Length d(int n) => Length.variable(CssVariable('--w$n'));
Length e(String name) => Length.variable(CssVariable(name));
Length f(String name) => Length.variable(CssVariable(name));
''');
  }

  Future<void> test_anotherVariable() async {
    await assertNoDiagnostics(r'''
class Length {
  const Length.variable(String name);
}
const a = Length.variable('--x');
const b = Length.variable('--x');
''');
  }
}

@reflectiveTest
class AvoidColorCssStringTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = AvoidColorCssString();
    newPackage('thor_style').addFile('lib/thor_style.dart', _style);
    super.setUp();
  }

  Future<void> test_hexAndVariable() async {
    const source = r'''
import 'package:thor_style/thor_style.dart';
const a = Color.css('#16a34a');
const b = Color.css('var(--brand)');
''';
    await assertDiagnostics(source, [
      lint(source.indexOf("'#16a34a'"), "'#16a34a'".length),
      lint(source.indexOf("'var(--brand)'"), "'var(--brand)'".length),
    ]);
  }

  Future<void> test_colorFunctionsAndTypedColors() async {
    await assertNoDiagnostics(r'''
import 'package:thor_style/thor_style.dart';
const a = Color.css('color-mix(in srgb, red 50%, blue)');
const b = Color.css('hsl(15 100% 50%)');
const c = Color(0xFF16A34A);
const d = Color.variable(CssVariable('--brand'));
''');
  }
}
