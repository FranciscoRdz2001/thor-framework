import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';
import 'package:thor_lints/src/text_field_without_label.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(TextFieldWithoutLabelTest);
  });
}

const _widgets = r'''
class Widget {
  const Widget();
}
class Text extends Widget {
  const Text(String data);
}
class Semantics extends Widget {
  const Semantics({String? label, Widget? child});
}
class InputDecoration {
  const InputDecoration({Widget? label, String? labelText, String? hintText, String? helperText});
  const InputDecoration.collapsed({String? hintText});
}
class TextField extends Widget {
  const TextField({InputDecoration? decoration = const InputDecoration(), String? name, Map<String, String> inputAttributes = const {}});
}
class TextFormField extends Widget {
  const TextFormField({required String name, InputDecoration decoration = const InputDecoration(), Map<String, String> inputAttributes = const {}});
}
const someDecoration = InputDecoration(labelText: 'x');
String? maybe() => null;
''';

@reflectiveTest
class TextFieldWithoutLabelTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = TextFieldWithoutLabel();
    super.setUp();
  }

  Future<void> _check(String code, [List<String> lints = const []]) {
    final source = '$_widgets\n$code';
    return assertDiagnostics(source, [
      for (final l in lints)
        lint(_widgets.length + 1 + code.indexOf(l), l.length),
    ]);
  }

  Future<void> test_bareTextField() =>
      _check('final a = TextField(name: "q");', ['TextField']);

  Future<void> test_bareTextFormField() =>
      _check('final a = TextFormField(name: "q");', ['TextFormField']);

  Future<void> test_decorationWithoutNames() => _check(
    'final a = TextField(decoration: InputDecoration(helperText: "h"));',
    ['TextField'],
  );

  Future<void> test_emptyLabelsDoNotCount() => _check(
    'final a = TextField(decoration: InputDecoration(labelText: "", hintText: null));',
    ['TextField'],
  );

  Future<void> test_labelText() => assertNoDiagnostics('''
$_widgets
final a = TextField(decoration: InputDecoration(labelText: 'Name'));
final b = TextFormField(name: 'n', decoration: const InputDecoration(labelText: 'Name'));
''');

  Future<void> test_hintText() => assertNoDiagnostics('''
$_widgets
final a = TextField(decoration: InputDecoration(hintText: 'Search'));
final b = TextField(decoration: InputDecoration.collapsed(hintText: 'Search'));
''');

  Future<void> test_aVariableMayHoldTheName() => assertNoDiagnostics('''
$_widgets
final a = TextField(decoration: someDecoration);
final b = TextField(decoration: InputDecoration(labelText: maybe()));
''');

  Future<void> test_semanticsAround() => assertNoDiagnostics('''
$_widgets
final a = Semantics(label: 'Search', child: TextField(name: 'q'));
final b = Semantics(label: 'Search', child: Widget());
''');

  Future<void> test_semanticsWithoutLabelDoesNotName() => _check(
    'final a = Semantics(label: "", child: TextField(name: "q"));',
    ['TextField'],
  );

  Future<void> test_inputAttributesNameIt() => assertNoDiagnostics('''
$_widgets
final a = TextField(inputAttributes: {'aria-label': 'Search'});
final b = TextField(inputAttributes: {'aria-labelledby': 'lbl'});
final c = TextField(inputAttributes: {'title': 'Search'});
''');

  Future<void> test_unreadableInputAttributesAreLeftAlone() =>
      assertNoDiagnostics('''
$_widgets
const attrs = {'aria-label': 'x'};
final a = TextField(inputAttributes: attrs);
''');

  Future<void> test_nullDecorationNamesNothing() =>
      _check('final a = TextField(decoration: null);', ['TextField']);

  Future<void> test_widgetLabelNamesIt() => assertNoDiagnostics('''
$_widgets
final a = TextField(decoration: InputDecoration(label: Text('Name')));
''');

  Future<void> test_emptyLabelWithHintStillNamed() => assertNoDiagnostics('''
$_widgets
final a = TextField(decoration: InputDecoration(labelText: '', hintText: 'Search'));
''');

  Future<void> test_semanticsFartherUp() => assertNoDiagnostics('''
$_widgets
class Column extends Widget {
  const Column({List<Widget> children = const []});
}
final a = Semantics(label: 'Search', child: Column(children: [TextField(name: 'q')]));
''');
}
