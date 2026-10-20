import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';
import 'package:thor_lints/src/stateful_set_state_rule.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(StatefulSetStateAdversarialTest);
  });
}

/// A stand-in for thor_ui: a Flutter-shaped StatefulWidget, its State, and
/// widgets with callbacks.
const _thor = r'''
abstract class Widget {
  const Widget();
}
class BuildContext {}
abstract class StatefulWidget extends Widget {
  const StatefulWidget();
  State createState();
}
abstract class State<T extends StatefulWidget> {
  void initState() {}
  void dispose() {}
  Widget build(BuildContext context);
  void setState(void Function() fn) => fn();
}
class Text extends Widget {
  Text(this.text);
  final String text;
}
class Button extends Widget {
  Button({this.onPressed, required this.child});
  final void Function()? onPressed;
  final Widget child;
}
''';

@reflectiveTest
class StatefulSetStateAdversarialTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = StatefulSetState();
    super.setUp();
  }

  (String, int) _at(String code, String needle) {
    final all = '$_thor$code';
    final offset = all.indexOf(needle, _thor.length);
    expect(offset, greaterThan(0), reason: needle);
    return (all, offset);
  }

  Future<void> test_aMethodNamedSetStateOfAnotherClassIsFine() async {
    await assertNoDiagnostics('''
$_thor
class Store {
  int n = 0;
  void setState(void Function() f) => f();
  void bump() => setState(() => n++);
}
void run(void Function(void Function()) setState) {
  setState(() {});
}
''');
  }

  Future<void> test_setStateOfAMixinOnState() async {
    const call = 'setState(() {})';
    final (code, at) = _at('''
mixin Bumper<T extends StatefulWidget> on State<T> {
  void bump() => $call;
}
''', call);
    await assertDiagnostics(code, [lint(at, call.length)]);
  }
}
