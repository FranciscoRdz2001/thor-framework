// The compiler's own errors come with the lint; their codes only live here.
// ignore: implementation_imports
import 'package:analyzer/src/diagnostic/diagnostic.dart' as diag;
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';
import 'package:thor_lints/src/style_css_names.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(StyleCssNamesTest);
  });
}

@reflectiveTest
class StyleCssNamesTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = StyleCssNames();
    newPackage('thor_ui').addFile('lib/web.dart', r'''
class Length {
  const Length.px(double v);
}
class EdgeInsets {
  const EdgeInsets.all(double v);
}
class Style {
  const Style({Length? padding, Length? gap, Object? textDecoration});
}
''');
    super.setUp();
  }

  Future<void> test_aFlutterName() async {
    await assertDiagnostics(
      r'''
import 'package:thor_ui/web.dart';
final a = Style(spacing: Length.px(8));
''',
      [
        error(diag.undefinedNamedParameter, 51, 7),
        lint(51, 7, correctionContains: 'Write gap.'),
      ],
    );
  }

  Future<void> test_aTypo() async {
    await assertDiagnostics(
      r'''
import 'package:thor_ui/web.dart';
final a = Style(paddin: Length.px(8));
''',
      [
        error(diag.undefinedNamedParameter, 51, 6),
        lint(51, 6, correctionContains: 'Write padding.'),
      ],
    );
  }

  Future<void> test_aFlutterValue() async {
    await assertDiagnostics(
      r'''
import 'package:thor_ui/web.dart';
final a = Style(padding: EdgeInsets.all(16));
''',
      [
        error(diag.argumentTypeNotAssignable, 60, 18),
        lint(60, 18, correctionContains: 'paddingInline'),
      ],
    );
  }

  Future<void> test_rightNamesAndValues() async {
    await assertNoDiagnostics(r'''
import 'package:thor_ui/web.dart';
class Other {
  const Other({Object? spacing});
}
final a = Style(padding: Length.px(8), gap: Length.px(4));
final b = Other(spacing: 1);
''');
  }
}
