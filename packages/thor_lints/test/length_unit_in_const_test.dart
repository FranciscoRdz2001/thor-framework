// The compiler's own error comes with the lint; its code only lives here.
// ignore: implementation_imports
import 'package:analyzer/src/diagnostic/diagnostic.dart' as diag;
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';
import 'package:thor_lints/src/length_unit_in_const.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(LengthUnitInConstTest);
  });
}

@reflectiveTest
class LengthUnitInConstTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = LengthUnitInConst();
    newPackage('thor_style').addFile('lib/thor_style.dart', r'''
final class Length {
  const Length.px(double value);
  const Length.rem(double value);
}
extension LengthUnits on num {
  Length get px => Length.px(toDouble());
  Length get rem => Length.rem(toDouble());
}
''');
    super.setUp();
  }

  Future<void> test_unitInAConst() async {
    await assertDiagnostics(
      r'''
import 'package:thor_style/thor_style.dart';
class Style {
  const Style({Length? gap});
}
const a = Style(gap: 8.px);
final b = const [Style(gap: 1.5.rem)];
''',
      [
        error(diag.constEvalExtensionMethod, 112, 4),
        lint(
          112,
          4,
          messageContainsAll: ['THOR-R015'],
          correctionContains: 'Length.px(8)',
        ),
        error(diag.constEvalExtensionMethod, 147, 7),
        lint(147, 7, correctionContains: 'Length.rem(1.5)'),
      ],
    );
  }

  Future<void> test_notAConst() async {
    await assertNoDiagnostics(r'''
import 'package:thor_style/thor_style.dart';
class Style {
  const Style({Length? gap});
}
final a = Style(gap: 8.px);
const b = Style(gap: Length.px(8));
''');
  }

  Future<void> test_anotherPx() async {
    await assertNoDiagnostics(r'''
extension on num {
  int get px => toInt();
}
const n = 1;
final a = n.px;
''');
  }
}
