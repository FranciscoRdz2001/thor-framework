import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';
import 'package:thor_lints/src/stateful_set_state_rule.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(StatefulSetStateTest);
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
class StatefulSetStateTest extends AnalysisRuleTest {
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

  Future<void> test_setStateInAButtonClosure() async {
    const call = 'setState(() => count++)';
    final (code, at) = _at('''
class Counter extends StatefulWidget {
  const Counter();
  @override
  State createState() => _CounterState();
}
class _CounterState extends State<Counter> {
  int count = 0;
  @override
  Widget build(BuildContext context) =>
      Button(onPressed: () => $call, child: Text('\$count'));
}
''', call);
    await assertDiagnostics(code, [
      lint(
        at,
        call.length,
        messageContainsAll: ['setState', 'THOR-S014', 'browser'],
        correctionContains: 'ThorState',
      ),
    ]);
  }

  Future<void> test_setStateInATornOffMethod() async {
    const call = 'setState(() { count++; })';
    final (code, at) = _at('''
class Counter extends StatefulWidget {
  const Counter();
  @override
  State createState() => _CounterState();
}
class _CounterState extends State<Counter> {
  int count = 0;
  void _inc() {
    $call;
  }
  @override
  Widget build(BuildContext context) =>
      Button(onPressed: _inc, child: Text('\$count'));
}
''', call);
    await assertDiagnostics(code, [lint(at, call.length)]);
  }

  Future<void> test_setStateInInitStateIsAlsoReported() async {
    // The server draws once and thor's State asserts in debug: there is no
    // place where setState is fine.
    const call = 'setState(() {})';
    final (code, at) = _at('''
class Counter extends StatefulWidget {
  const Counter();
  @override
  State createState() => _CounterState();
}
class _CounterState extends State<Counter> {
  @override
  void initState() {
    $call;
  }
  @override
  Widget build(BuildContext context) => Text('x');
}
''', call);
    await assertDiagnostics(code, [lint(at, call.length)]);
  }

  Future<void> test_thisQualifiedAndTearOffAndOtherReceivers() async {
    final (code, at) = _at('''
class Counter extends StatefulWidget {
  const Counter();
  @override
  State createState() => _CounterState();
}
class _CounterState extends State<Counter> {
  @override
  Widget build(BuildContext context) => Text('x');
}
void other(State s) {
  s.setState(() {});
}
class _Own extends _CounterState {
  void a() {
    this.setState(() {});
    final f = setState;
    f(() {});
  }
}
extension Bump on State {
  void bump() => setState(() {});
}
''', 's.setState(() {})');
    await assertDiagnostics(code, [
      lint(at, 's.setState(() {})'.length),
      lint(
        code.indexOf('this.setState', _thor.length),
        'this.setState(() {})'.length,
      ),
      lint(
        code.indexOf('final f = setState', _thor.length) + 'final f = '.length,
        8,
      ),
      lint(code.lastIndexOf('setState(() {})'), 'setState(() {})'.length),
    ]);
  }

  Future<void> test_aStatefulWidgetWithoutSetStateIsFine() async {
    await assertNoDiagnostics('''
$_thor
class Badge extends StatefulWidget {
  const Badge();
  @override
  State createState() => _BadgeState();
}
class _BadgeState extends State<Badge> {
  final int count = 3;
  @override
  void initState() {
    count.toString();
  }
  @override
  Widget build(BuildContext context) => Text('\$count');
}
// A method that only shares the name.
class Grid {
  void setState(void Function() fn) => fn();
}
void use(Grid g) {
  g.setState(() {});
}
''');
  }
}
