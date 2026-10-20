import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';
import 'package:thor_lints/src/frozen_state_read_rule.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(FrozenStateReadTest);
  });
}

/// A stand-in for thor: signals, ThorState, ServerQuery, widgets and the
/// builders that bind a state.
const _thor = r'''
abstract class Widget {
  const Widget();
}
abstract class BuildContext {}
abstract class StatelessWidget extends Widget {
  const StatelessWidget();
  Widget build(BuildContext context);
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
  T peek() => _v;
}
StateSignal<T> state<T>(T value) => StateSignal(value);
T untracked<T>(T Function() fn) => fn();
class ServerQuery<A, T> {
  final StateSignal<T?> data = state<T?>(null);
}
class Text extends Widget {
  const Text(this.text);
  final String text;
}
class Column extends Widget {
  const Column({this.children = const []});
  final List<Widget> children;
}
class ListView extends Widget {
  const ListView({this.children = const []});
  ListView.builder({
    required int itemCount,
    required Widget Function(BuildContext, int) itemBuilder,
  }) : children = const [];
  final List<Widget> children;
}
class Button extends Widget {
  const Button({this.onPressed, this.child});
  final void Function()? onPressed;
  final Widget? child;
}
class Checkbox extends Widget {
  const Checkbox({required this.value, this.onChanged});
  final bool value;
  final void Function()? onChanged;
}
class Slider extends Widget {
  const Slider({required this.value, this.onChanged});
  final double value;
  final void Function()? onChanged;
}
class Chip extends Widget {
  const Chip({required this.value});
  final int value;
}
class WatchItem {
  Widget text(String Function(Object) f) => const Text('');
  Widget watch<T>(T Function(Object) f, {required Widget Function(T) builder}) =>
      builder(f(0));
}
class WatchRow<I, K> {
  K get key => throw 0;
  Widget text(String Function(I) f) => const Text('');
}
class Watch<T> extends Widget {
  static Watch<List<I>> list<I, K extends Object>(
    List<I> Function() source, {
    required K Function(I) itemKey,
    required Widget Function(WatchRow<I, K> row) each,
  }) => throw 0;
  const Watch(this.source, {this.builder, this.each, this.itemKey});
  final T Function() source;
  final Widget Function(T value)? builder;
  final Widget Function(WatchItem row)? each;
  final Function? itemKey;
}
class ValueListenableBuilder<T> extends Widget {
  const ValueListenableBuilder({required this.valueListenable, required this.builder});
  final StateSignal<T> valueListenable;
  final Widget Function(BuildContext, T, Widget?) builder;
}
class QueryBuilder<T> extends Widget {
  const QueryBuilder({required this.builder});
  final Widget Function(BuildContext, T) builder;
}
class CounterState extends ThorState {
  final count = state(0);
  final name = state('');
  final orders = ServerQuery<int, List<String>>();
  final labels = ['a', 'b'];
  List<String> rows() => orders.data.value ?? [];
  List<String> get lines => rows();
  String label() => '${count.value}';
  String labelOf(String s) => s;
  int twice() => count.value * 2;
  Widget peekWidget() => Text('${count.value}');
  void bump() {
    count.value = count.value + 1;
    for (final r in rows()) {
      r.length;
    }
  }
}
final counter = CounterState();
''';

@reflectiveTest
class FrozenStateReadTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = FrozenStateRead();
    super.setUp();
  }

  /// Where [needle] is in [code], after the stand-in.
  int _i(String code, String needle) => code.indexOf(needle, _thor.length);

  /// [code] after the stand-in, and the offset of [needle] in the whole.
  (String, int) _at(String code, String needle) {
    final all = '$_thor$code';
    final offset = _i(all, needle);
    expect(offset, greaterThan(0), reason: needle);
    return (all, offset);
  }

  Future<void> test_valueReadInBuild() async {
    const read = 'counter.count.value';
    final (code, at) = _at('''
class Card extends StatelessWidget {
  const Card();
  @override
  Widget build(BuildContext context) => Text('\${$read}');
}
''', read);
    await assertDiagnostics(code, [
      lint(
        at,
        read.length,
        messageContainsAll: [read, 'frozen', 'THOR-S015'],
        correctionContains: 'Watch(counter.count)',
      ),
    ]);
  }

  Future<void> test_queryData() async {
    const data = 'counter.orders.data.value';
    final (code, at) = _at('''
Widget page() => Column(children: [
  Text('\${$data}'),
]);
''', data);
    await assertDiagnostics(code, [lint(at, data.length)]);
  }

  Future<void> test_aliasesGettersAndTypes() async {
    // Reached through a local, a getter, a parameter and a null-aware read:
    // the type decides, not the spelling.
    final (code, at) = _at('''
StateSignal<int> get shared => counter.count;
Widget a() {
  final c = counter.count;
  return Text('\${c.value}');
}
Widget b() => Text('\${shared.value}');
Widget c(StateSignal<String?> s) => Text(s.value ?? '');
Widget d(StateSignal<String>? s) => Text(s?.value ?? '');
''', 'c.value');
    await assertDiagnostics(code, [
      lint(at, 'c.value'.length),
      lint(_i(code, 'shared.value'), 'shared.value'.length),
      lint(_i(code, 's.value'), 's.value'.length),
      lint(_i(code, 's?.value'), 's?.value'.length),
    ]);
  }

  Future<void> test_helpersReachedFromBuild() async {
    // A function called from a widget's build is server code too; the one
    // nobody calls is left alone.
    final (code, at) = _at('''
String describe() => 'n=\${counter.count.value}';
String unused() => 'n=\${counter.count.value}';
Widget row() => Text(describe());
Widget page(BuildContext context) => Column(children: [row()]);
class Panel extends StatelessWidget {
  const Panel();
  String get title => 'x\${counter.name.value}';
  @override
  Widget build(BuildContext context) => Text(title);
}
''', 'counter.count.value');
    await assertDiagnostics(code, [
      lint(at, 'counter.count.value'.length),
      lint(_i(code, 'counter.name.value'), 'counter.name.value'.length),
    ]);
  }

  Future<void> test_nestedFunctionsAndExtensions() async {
    final (code, at) = _at('''
extension on StateSignal<int> {
  int get doubled => value * 2;
}
Widget page(List<int> items) {
  Widget local() => Text('\${counter.count.value}');
  return Column(children: [
    for (final i in items) Text('\${counter.name.value}'),
    ...items.map((i) => Text('\${counter.count.doubled}')),
    local(),
  ]);
}
''', 'value * 2');
    await assertDiagnostics(code, [
      lint(at, 'value'.length),
      lint(_i(code, 'counter.count.value'), 'counter.count.value'.length),
      lint(_i(code, 'counter.name.value'), 'counter.name.value'.length),
    ]);
  }

  Future<void> test_listsThatIterateAStateMember() async {
    final (code, at) = _at('''
Widget a() => Column(children: [
  for (final r in counter.rows()) Text(r),
]);
Widget b() => ListView(
  children: counter.rows().map((r) => Text(r)).toList(),
);
Widget c() => ListView.builder(
  itemCount: counter.rows().length,
  itemBuilder: (context, i) => Text(counter.rows()[i]),
);
Widget d() => Column(children: [...counter.lines.map(Text.new)]);
Widget e() {
  final rows = counter.rows();
  return Column(children: [for (final r in rows) Text(r)]);
}
''', 'counter.rows()');
    await assertDiagnostics(code, [
      lint(
        at,
        'counter.rows()'.length,
        messageContainsAll: ['counter.rows()', 'frozen', 'THOR-S015'],
        correctionContains: 'Watch.list(counter.rows',
      ),
      lint(_i(code, 'counter.rows().map'), 'counter.rows()'.length),
      lint(_i(code, 'counter.rows().length'), 'counter.rows()'.length),
      lint(_i(code, 'counter.rows()[i]'), 'counter.rows()'.length),
      lint(_i(code, 'counter.lines'), 'counter.lines'.length),
      lint(_i(code, 'counter.rows();'), 'counter.rows()'.length),
    ]);
  }

  Future<void> test_aLabelOrAVariableNamedValueIsNotARead() async {
    await assertNoDiagnostics('''
$_thor
extension on StateSignal<int> {
  Widget shown() {
    final value = 3;
    return Chip(value: value);
  }
  Widget label() => Chip(value: 4);
}
Widget page() => Column(children: [counter.count.shown(), counter.count.label()]);
''');
  }

  Future<void> test_valueOfAWidgetWithoutOnChangedIsARead() async {
    const read = 'counter.count.value';
    final (code, at) = _at('''
Widget a() => Chip(value: $read);
''', read);
    await assertDiagnostics(code, [lint(at, read.length)]);
  }

  Future<void> test_aListValueIsReportedOnceAsARead() async {
    const read = 'counter.orders.data.value';
    final (code, at) = _at('''
Widget a() => Column(children: [
  for (final r in $read ?? <String>[]) Text(r),
]);
''', read);
    await assertDiagnostics(code, [
      lint(at, read.length, correctionContains: 'each:'),
    ]);
  }

  Future<void> test_whereTheBrowserOwnsTheValueIsFine() async {
    await assertNoDiagnostics('''
$_thor
class Card extends StatelessWidget {
  const Card();
  @override
  Widget build(BuildContext context) => Column(children: [
    // The field goes to Watch, not its value.
    Watch(counter.count.call),
    Watch(counter.label),
    Watch(counter.rows, itemKey: counter.label, each: (row) => row.text((o) => '')),
    Watch.list(counter.rows, itemKey: counter.labelOf, each: (row) => Text('\${counter.count.value}')),
    Watch.list(counter.rows, itemKey: counter.labelOf, each: (row) => row.text((o) => '')),
    // A builder bound to the state: what is read inside is its business.
    Watch(counter.label, builder: (l) => Text('\${counter.count.value}')),
    ValueListenableBuilder<int>(
      valueListenable: counter.count,
      builder: (context, v, child) => Text('\${counter.count.value}'),
    ),
    QueryBuilder<int>(builder: (context, s) => Text('\${counter.name.value}')),
    const ListView(),
    // A callback runs later, in the browser: reading there is fine.
    Button(onPressed: () => counter.count.value.toString()),
    // Constant data of a state is not a snapshot of anything.
    for (final l in counter.labels) Text(l),
    // A snapshot on purpose: the names say so.
    Text('\${counter.count.peek()}'),
    Text('\${untracked(() => counter.count.value)}'),
    // The initial value of a control: the browser keeps its own from then on.
    Checkbox(value: counter.count.value > 0, onChanged: counter.bump),
    Slider(value: counter.count.value.toDouble(), onChanged: counter.bump),
  ]);
}
// The state's own code runs in the browser.
class OtherState extends ThorState {
  final n = state(0);
  Widget w() => Text('\${n.value}');
  void go() {
    for (final r in counter.rows()) {
      r.length;
    }
  }
}
// Not build code: nothing draws with it.
void main() {
  counter.count.value = 3;
  print(counter.count.value);
  counter.count.value++;
}
Future<void> save() async {
  final v = counter.name.value;
  v.length;
}
// A signal-like class that is not a StateSignal.
class Cell {
  int value = 0;
}
Widget cell(Cell c) => Text('\${c.value}');
''');
  }
}
