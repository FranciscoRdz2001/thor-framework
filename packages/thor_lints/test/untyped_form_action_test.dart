import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';
import 'package:thor_lints/src/untyped_form_action.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(UntypedFormActionTest);
  });
}

const _widgets = r'''
class Form {
  const Form({String? action, Function? onPost, Function? onValid});
}
class FilledButton {
  const FilledButton({String? formAction, Function? onPost});
}
''';

@reflectiveTest
class UntypedFormActionTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = UntypedFormAction();
    super.setUp();
  }

  Future<void> test_actionString() async {
    await assertDiagnostics(
      '''
$_widgets
final a = Form(action: '?/send');
''',
      [
        lint(193, 8, messageContainsAll: ["'action:'"]),
      ],
    );
  }

  Future<void> test_formActionString() async {
    await assertDiagnostics(
      '''
$_widgets
final id = 3;
final b = FilledButton(formAction: '?/remove&id=\$id');
''',
      [lint(219, 17, correctionContains: 'onPost: send')],
    );
  }

  Future<void> test_closure() async {
    await assertDiagnostics(
      '''
$_widgets
final c = Form(onPost: (r) async => null);
''',
      [
        lint(193, 17, messageContainsAll: ['THOR-P020']),
      ],
    );
  }

  Future<void> test_tearOffsAndUrls() async {
    await assertNoDiagnostics('''
$_widgets
Future<Object?> send(Object r) async => null;
final d = Form(onPost: send, action: '/other');
final e = Form(action: 'mailto:a@b.c');
''');
  }
}
