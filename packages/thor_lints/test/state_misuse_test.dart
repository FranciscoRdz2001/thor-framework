import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';
import 'package:thor_lints/src/state_misuse_rule.dart';
import 'package:thor_lints/state_misuse.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(StateMisuseTest);
  });
}

/// A stand-in for thor_ui: widgets with callbacks, Watch and ThorState.
const _thor = r'''
abstract class ThorState {}
abstract class Widget {}
abstract class StatelessWidget extends Widget {
  Widget build();
}
class Text extends Widget {
  Text(this.text);
  final String text;
}
class Button extends Widget {
  Button({this.onPressed, this.onChanged, required this.child});
  final void Function()? onPressed;
  final void Function(String)? onChanged;
  final Widget child;
}
class Watch<T> extends Widget {
  Watch(this.source, {this.builder});
  final T Function() source;
  final Widget Function(T value)? builder;
  static Widget list<I>(List<I> Function() source, {required Object Function(I item) itemKey, required Widget Function(WatchRow<I> row) each}) => Text('');
}
class WatchRow<I> {
  Widget text(String Function(I item) field) => Text('');
  Widget attribute(String name, Object? Function(I item) value, {required Widget child}) => child;
}
extension WithArg<A> on void Function(A) {
  void Function() withArg(A arg) => () => this(arg);
}
class CounterState extends ThorState {
  int count = 0;
  String label() => '$count';
  List<String> items() => [];
  String nameOf(String s) => s;
  void increment() => count++;
  void add(int n) => count += n;
  void set(String v) {}
  void pick(int id, String v) {}
  void save() {
    // Inside the state: its own closures run in the browser.
    Button(onPressed: () { increment(); }, child: Text(''));
  }
}
final counter = CounterState();
void log(Object o) {}
''';

@reflectiveTest
class StateMisuseTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = StateMisuseRule();
    super.setUp();
  }

  /// [code] after the stand-in, with the offset of [needle] in the whole.
  (String, int) _at(String code, String needle) {
    final all = '$_thor$code';
    final offset = all.indexOf(needle, _thor.length);
    expect(offset, greaterThan(0), reason: needle);
    return (all, offset);
  }

  Future<void> test_closureCallingAStateMethod() async {
    const closure = '() { counter.increment(); }';
    final (code, at) = _at('''
Widget page() => Button(onPressed: $closure, child: Text(''));
''', closure);
    await assertDiagnostics(code, [
      lint(
        at,
        closure.length,
        name: 'state_callback_closure',
        messageContainsAll: ["can't run a function", 'THOR-S011'],
        correctionContains: 'Pass `counter.increment`.',
      ),
    ]);
  }

  Future<void> test_closureWithAnArgument() async {
    const closure = '() => counter.add(3)';
    final (code, at) = _at('''
Widget page() => Button(onPressed: $closure, child: Text(''));
''', closure);
    await assertDiagnostics(code, [
      lint(
        at,
        closure.length,
        name: 'state_callback_closure',
        correctionContains: 'Pass `counter.add.withArg(3)`.',
      ),
    ]);
  }

  Future<void> test_closurePassingItsParameterThrough() async {
    const closure = '(v) => counter.set(v)';
    final (code, at) = _at('''
Widget page() => Button(onChanged: $closure, child: Text(''));
''', closure);
    await assertDiagnostics(code, [
      lint(
        at,
        closure.length,
        name: 'state_callback_closure',
        correctionContains: 'Pass `counter.set`.',
      ),
    ]);
  }

  Future<void> test_closureDoingMore() async {
    const closure = '() { counter.increment(); counter.add(2); }';
    final (code, at) = _at('''
Widget page() => Button(onPressed: $closure, child: Text(''));
''', closure);
    await assertDiagnostics(code, [
      lint(
        at,
        closure.length,
        name: 'state_callback_closure',
        correctionContains: 'Move this into a method of the state',
      ),
    ]);
  }

  Future<void> test_closureReadingAField() async {
    const closure = '() => log(counter.count)';
    final (code, at) = _at('''
Widget page() => Button(onPressed: $closure, child: Text(''));
''', closure);
    await assertDiagnostics(code, [
      lint(at, closure.length, name: 'state_callback_closure'),
    ]);
  }

  Future<void> test_watchClosure() async {
    const closure = '() => counter.count';
    final (code, at) = _at('''
Widget page() => Watch($closure, builder: (v) => Text('\$v'));
''', closure);
    await assertDiagnostics(code, [
      lint(
        at,
        closure.length,
        name: 'state_watch_closure',
        messageContainsAll: ['THOR-S001'],
        correctionContains: 'Watch(counterState.label)',
      ),
    ]);
  }

  Future<void> test_watchListClosureSource() async {
    const closure = '() => counter.items()';
    final (code, at) = _at('''
Widget page() => Watch.list($closure, itemKey: (s) => s, each: (row) => Text(''));
''', closure);
    await assertDiagnostics(code, [
      lint(
        at,
        closure.length,
        name: 'state_watch_closure',
        messageContainsAll: ['THOR-S001'],
      ),
    ]);
  }

  Future<void> test_rowTextAndAttributeClosures() async {
    const text = '(s) => counter.nameOf(s)';
    const attribute = '(s) => counter.label()';
    final (code, at) = _at('''
Widget page() => Watch.list(
  counter.items,
  itemKey: (s) => s,
  each: (row) => row.attribute('title', $attribute, child: row.text($text)),
);
''', attribute);
    final textAt = code.indexOf(text);
    await assertDiagnostics(code, [
      lint(at, attribute.length, name: 'state_watch_closure'),
      lint(textAt, text.length, name: 'state_watch_closure'),
    ]);
  }

  Future<void> test_watchListWithMembersIsQuiet() async {
    await assertNoDiagnostics('''
$_thor
Widget page() => Watch.list(
  counter.items,
  itemKey: counter.nameOf,
  each: (row) => row.attribute('title', (s) => s, child: row.text(counter.nameOf)),
);
''');
  }

  Future<void> test_instanceInAField() async {
    const creation = 'CounterState()';
    final (code, at) = _at('''
class CounterWidget extends StatelessWidget {
  final counterState = $creation;
  @override
  Widget build() => Button(onPressed: counterState.increment, child: Text(''));
}
''', creation);
    await assertDiagnostics(code, [
      lint(
        at,
        creation.length,
        name: 'state_instance_not_top_level',
        messageContainsAll: ['THOR-S012'],
        correctionContains: '`final counter = CounterState();`',
      ),
    ]);
  }

  Future<void> test_instanceInBuild() async {
    const creation = 'CounterState()';
    final (code, at) = _at('''
Widget page() {
  final local = $creation;
  return Button(onPressed: local.increment, child: Text(''));
}
''', creation);
    await assertDiagnostics(code, [
      lint(at, creation.length, name: 'state_instance_not_top_level'),
    ]);
  }

  Future<void> test_notFlagged() async {
    await assertNoDiagnostics('''
$_thor
final other = CounterState();
Widget page(int id) => Button(
  onPressed: () {},
  onChanged: (v) => log(v),
  child: Watch(counter.label, builder: (v) => Text('\$v')),
);
Widget torn() => Button(onPressed: counter.increment, child: Text(''));
Widget bound(int id) =>
    Button(onPressed: counter.add.withArg(id), child: Text(''));
Widget quiet() => Watch(() => 3, builder: (v) => Text('\$v'));
void server() {
  // Not a widget's callback: ordinary server code.
  [1, 2].forEach((n) => counter.add(n));
}
''');
  }

  Future<void> test_replacements() async {
    final result = await resolveFile(
      newFile('$testPackageLibPath/fix.dart', '''
$_thor
Widget a() => Button(onPressed: () { counter.increment(); }, child: Text(''));
Widget b(int id) => Button(onPressed: () => counter.add(id), child: Text(''));
Widget c() => Button(onChanged: (v) => counter.pick(7, v), child: Text(''));
Widget d() => Button(onChanged: (v) => counter.add(v.length), child: Text(''));
''').path,
    );
    final closures = <FunctionExpression>[];
    result.unit.accept(_Closures(closures));
    final top = [
      for (final c in closures)
        if (c.parent?.parent?.parent is InstanceCreationExpression &&
            c.thisOrAncestorOfType<ClassDeclaration>() == null)
          stateCallbackReplacement(c),
    ];
    expect(top, [
      'counter.increment',
      'counter.add.withArg(id)',
      'counter.pick.withArg(7)',
      null,
    ]);
    expect(
      findStateMisuses(result.unit).map((m) => m.code),
      everyElement('THOR-S011'),
    );
  }
}

class _Closures extends RecursiveAstVisitor<void> {
  _Closures(this.found);

  final List<FunctionExpression> found;

  @override
  void visitFunctionExpression(FunctionExpression node) {
    if (node.parent is! FunctionDeclaration) found.add(node);
    super.visitFunctionExpression(node);
  }
}
