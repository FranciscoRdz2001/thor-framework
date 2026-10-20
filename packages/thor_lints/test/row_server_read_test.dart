import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';
import 'package:thor_lints/src/row_server_read_rule.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(RowServerReadTest);
  });
}

/// A stand-in for thor: a list row, the widgets that take its `String`s and
/// a state with methods by key and by item.
const _thor = r'''
abstract class Widget {
  const Widget();
}
abstract class ThorState {}
class Signal<T> {
  Signal(this._v);
  T _v;
  T get value => _v;
  set value(T v) => _v = v;
}
class StateSignal<T> extends Signal<T> {
  StateSignal(super.v);
  T call() => value;
}
StateSignal<T> state<T>(T value) => StateSignal(value);
T untracked<T>(T Function() fn) => fn();
class Text extends Widget {
  const Text(this.text);
  final String text;
}
class Row extends Widget {
  const Row({this.children = const []});
  final List<Widget> children;
}
class Padding extends Widget {
  const Padding({this.child});
  final Widget? child;
}
class Checkbox extends Widget {
  const Checkbox({required this.value, this.semanticLabel, this.onChanged});
  final bool value;
  final String? semanticLabel;
  final void Function(bool?)? onChanged;
}
class IconButton extends Widget {
  const IconButton({this.tooltip, this.onPressed});
  final String? tooltip;
  final void Function()? onPressed;
}
class Todo {
  const Todo(this.id, this.title);
  final String id;
  final String title;
}
class WatchRow<I, K> {
  K get key => throw 0;
  Widget watch<V>(V Function(I) f, {required Widget Function(V) builder}) =>
      builder(f(throw 0));
  Widget text(String Function(I) f) => const Text('');
  String bind(String Function(I) f) => '';
  Widget attribute(String name, Object? Function(I) f, {required Widget child}) =>
      child;
}
class Watch<T> extends Widget {
  static Watch<List<I>> list<I, K extends Object>(
    List<I> Function() source, {
    required K Function(I) itemKey,
    required Widget Function(WatchRow<I, K> row) each,
  }) => throw 0;
}
class TodoState extends ThorState {
  final todos = state(const <Todo>[]);
  final selected = state(const <String>[]);
  String idOf(Todo t) => t.id;
  String titleOf(Todo t) => t.title;
  bool isDone(Todo t) => false;
  String titleById(String id) => id;
  String hello() => 'hi';
  void remove(String id) {}
  void toggle(String id, bool? on) {}
}
final todo = TodoState();
extension WithArg1<A> on void Function(A) {
  void Function() withArg(A a) => () {};
}
extension WithArg2<A, B> on void Function(A, B) {
  void Function(B) withArg(A a) => (b) {};
}
''';

@reflectiveTest
class RowServerReadTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = RowServerRead();
    super.setUp();
  }

  int _i(String code, String needle) => code.indexOf(needle, _thor.length);

  (String, int) _at(String code, String needle) {
    final all = '$_thor$code';
    final offset = _i(all, needle);
    expect(offset, greaterThan(0), reason: needle);
    return (all, offset);
  }

  /// A page whose row builds [row].
  String _page(String row) =>
      '''
Widget page() => Watch.list(
  () => const <Todo>[],
  itemKey: todo.idOf,
  each: (row) => $row,
);
''';

  Future<void> test_methodCalledWithTheRowKey() async {
    const call = 'todo.titleById(row.key)';
    final (code, at) = _at(
      _page('Checkbox(value: false, semanticLabel: $call)'),
      call,
    );
    await assertDiagnostics(code, [
      lint(
        at,
        call.length,
        messageContainsAll: [call, 'server', 'THOR-S034'],
        correctionContains: 'row.bind',
      ),
    ]);
  }

  Future<void> test_inATextAndInAnInterpolation() async {
    final (code, at) = _at(
      _page(
        r"Row(children: [Text(todo.titleById(row.key)), Text('a ${todo.titleById(row.key)}')])",
      ),
      'todo.titleById(row.key)',
    );
    await assertDiagnostics(code, [
      lint(at, 'todo.titleById(row.key)'.length),
      lint(
        _i(code, r'${todo.titleById(row.key)}') + 2,
        'todo.titleById(row.key)'.length,
      ),
    ]);
  }

  Future<void> test_aSignalReadThatDependsOnTheRow() async {
    const read = 'todo.selected.value.contains(row.key)';
    final (code, at) = _at(_page("Text($read ? 'x' : '')"), read);
    await assertDiagnostics(code, [
      lint(at, read.length, messageContainsAll: ['THOR-S034']),
    ]);
  }

  Future<void> test_inTheBuilderOfRowWatchAndInAHelperRow() async {
    final (code, at) = _at(r'''
Widget help(WatchRow<Todo, String> row) =>
    Text(todo.titleById(row.key));
Widget page() => Watch.list(
  () => const <Todo>[],
  itemKey: todo.idOf,
  each: (row) => row.watch(
    todo.isDone,
    builder: (done) => Padding(child: Text(todo.titleById(row.key))),
  ),
);
''', 'todo.titleById(row.key)');
    await assertDiagnostics(code, [
      lint(at, 'todo.titleById(row.key)'.length),
      lint(
        _i(code, 'todo.titleById(row.key)))'),
        'todo.titleById(row.key)'.length,
      ),
    ]);
  }

  Future<void> test_whatIsBoundIsFine() async {
    await assertNoDiagnostics(
      '$_thor${_page('''Row(children: [
  row.text(todo.titleOf),
  row.text((t) => t.title),
  row.attribute('aria-label', todo.titleOf, child: Checkbox(value: false)),
  Checkbox(
    value: false,
    semanticLabel: row.bind(todo.titleOf),
    onChanged: todo.toggle.withArg(row.key),
  ),
  IconButton(tooltip: 'Eliminar', onPressed: todo.remove.withArg(row.key)),
  Text(row.key),
])''')}',
    );
  }

  Future<void> test_aCallWithoutTheRowOrOutsideARowIsNotOurs() async {
    await assertNoDiagnostics('''
$_thor
Widget page() => Watch.list(
  () => const <Todo>[],
  itemKey: todo.idOf,
  each: (row) => Text(todo.titleById('fixed')),
);
Widget plain(String id) => Text(todo.titleById(id));
Widget other(WatchRow<Todo, String> row) => Text(todo.hello());
''');
  }

  Future<void> test_callbacksAndUntrackedAreLeftAlone() async {
    await assertNoDiagnostics(
      '$_thor${_page('''Row(children: [
  IconButton(onPressed: () => todo.remove(row.key)),
  Text(untracked(() => todo.titleById(row.key))),
])''')}',
    );
  }

  Future<void> test_aSignalCalledLikeAFunctionAndAFirstWhereOnTheValue() async {
    const call = 'todo.selected().contains(row.key)';
    const find = 'todo.todos.value.firstWhere((t) => t.id == row.key).title';
    final (code, at) = _at(
      _page("Row(children: [Text($call ? 'x' : ''), Text($find)])"),
      call,
    );
    await assertDiagnostics(code, [
      lint(at, call.length),
      lint(_i(code, find), find.length),
    ]);
  }

  Future<void> test_aLocalMadeFromTheRow() async {
    final (code, at) = _at(r'''
Widget page() => Watch.list(
  () => const <Todo>[],
  itemKey: todo.idOf,
  each: (row) {
    final id = row.key;
    final label = 'a ${row.key}';
    return Row(children: [
      Text(todo.titleById(id)),
      Text(todo.titleById(label)),
    ]);
  },
);
''', 'todo.titleById(id)');
    await assertDiagnostics(code, [
      lint(at, 'todo.titleById(id)'.length),
      lint(_i(code, 'todo.titleById(label)'), 'todo.titleById(label)'.length),
    ]);
  }

  Future<void> test_aLocalUnrelatedToTheRowIsFine() async {
    await assertNoDiagnostics('''
$_thor
Widget page() => Watch.list(
  () => const <Todo>[],
  itemKey: todo.idOf,
  each: (row) {
    final id = 'fixed';
    return Text(todo.titleById(id));
  },
);
''');
  }
}
