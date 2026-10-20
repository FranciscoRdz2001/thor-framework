import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';
import 'package:thor_lints/src/frozen_state_read_rule.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(FrozenStateReadAdversarialTest);
  });
}

/// The stand-in of frozen_state_read_test.dart plus controls and helpers.
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
class Watch<T> extends Widget {
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
  String fixedLabel() => 'x';
  String describe(int n) => '${name.value}$n';
  bool get open => count.value > 0;
  final mode = state(0);
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

class ValueNotifier<T> {
  ValueNotifier(this.value);
  T value;
}
class TextEditingController extends ValueNotifier<String> {
  TextEditingController({String text = ''}) : super(text);
}
class Switch extends Widget {
  const Switch({required this.value, this.onChanged});
  final bool value;
  final void Function()? onChanged;
}
class DropdownMenu extends Widget {
  const DropdownMenu({this.initialSelection, this.onSelected});
  final String? initialSelection;
  final void Function()? onSelected;
}
class SegmentedButton extends Widget {
  const SegmentedButton({required this.selected, this.onSelectionChanged});
  final Set<String> selected;
  final void Function()? onSelectionChanged;
}
class RangeSlider extends Widget {
  const RangeSlider({required this.values, this.onChanged});
  final List<double> values;
  final void Function()? onChanged;
}
class TextField extends Widget {
  const TextField({this.controller, this.onChanged});
  final TextEditingController? controller;
  final void Function()? onChanged;
}
class Tile extends StatelessWidget {
  const Tile({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) => Text(title);
}
class Builder extends Widget {
  const Builder({required this.builder});
  final Widget Function(BuildContext) builder;
}
class TextFormField extends Widget {
  const TextFormField({this.initialValue, this.validator, this.onChanged});
  final String? initialValue;
  final String? Function(String?)? validator;
  final void Function()? onChanged;
}
''';

@reflectiveTest
class FrozenStateReadAdversarialTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = FrozenStateRead();
    super.setUp();
  }

  (String, int) _at(String code, String needle) {
    final all = '$_thor$code';
    final offset = all.indexOf(needle, _thor.length);
    expect(offset, greaterThan(0), reason: needle);
    return (all, offset);
  }

  /// [code] (after the stand-in) has exactly one warning, at [needle].
  Future<void> _one(String code, String needle) async {
    final (all, at) = _at(code, needle);
    await assertDiagnostics(all, [lint(at, needle.length)]);
  }

  // ---- false negatives ----

  Future<void> test_switchOnAValue() => _one('''
Widget page() => switch (counter.mode.value) {
  0 => const Text('a'),
  _ => const Text('b'),
};
''', 'counter.mode.value');

  Future<void> test_conditionalChoosingAWidget() => _one('''
Widget page() => counter.count.value > 0 ? const Text('a') : const Text('b');
''', 'counter.count.value');

  Future<void> test_ifElementInAList() => _one('''
Widget page() => Column(children: [
  if (counter.count.value > 0) const Text('a'),
]);
''', 'counter.count.value');

  Future<void> test_constructorArgument() => _one('''
Widget page() => Tile(title: counter.name.value);
''', 'counter.name.value');

  Future<void> test_widgetFieldInitializer() => _one('''
class Header extends StatelessWidget {
  Header();
  final String title = counter.name.value;
  @override
  Widget build(BuildContext context) => Text(title);
}
''', 'counter.name.value');

  Future<void> test_lateFinalFieldOfAWidget() => _one('''
class Header extends StatelessWidget {
  Header();
  late final String title = counter.name.value;
  @override
  Widget build(BuildContext context) => Text(title);
}
''', 'counter.name.value');

  Future<void> test_helperReturningAStringGetsTheReadAsArgument() => _one('''
String formatted(int n) => 'n=\$n';
Widget page() => Text(formatted(counter.count.value));
''', 'counter.count.value');

  // ---- false positives ----

  Future<void> test_valueNotifierAndControllerAreNotSignals() async {
    await assertNoDiagnostics('''
$_thor
class Panel extends StatelessWidget {
  Panel();
  final notifier = ValueNotifier<int>(1);
  final controller = TextEditingController(text: 'a');
  @override
  Widget build(BuildContext context) =>
      Column(children: [Text('\${notifier.value}'), Text(controller.value)]);
}
''');
  }

  Future<void> test_pureStateMethodIsNotFrozen() async {
    // A method that reads no state has nothing to freeze.
    await assertNoDiagnostics('''
$_thor
Widget page() => Text(counter.fixedLabel());
''');
  }

  Future<void> test_initialValueOfEveryControl() async {
    await assertNoDiagnostics('''
$_thor
Widget page() => Column(children: [
  Switch(value: counter.count.value > 0, onChanged: counter.bump),
  DropdownMenu(initialSelection: counter.name.value, onSelected: counter.bump),
  TextFormField(initialValue: counter.name.value, onChanged: counter.bump),
]);
''');
  }

  Future<void> test_segmentedButtonAndRangeSlider() async {
    await assertNoDiagnostics('''
$_thor
Widget page() => Column(children: [
  SegmentedButton(
    selected: {counter.name.value},
    onSelectionChanged: counter.bump,
  ),
  RangeSlider(
    values: [counter.count.value.toDouble(), 1],
    onChanged: counter.bump,
  ),
]);
''');
  }

  Future<void> test_validatorRunsLater() async {
    await assertNoDiagnostics('''
$_thor
Widget page() => TextFormField(
  validator: (v) => counter.name.value.isEmpty ? 'x' : null,
);
''');
  }

  Future<void> test_watchNestedInOtherClosures() async {
    await assertNoDiagnostics('''
$_thor
Widget page() => Watch(
  counter.label,
  builder: (l) => Column(children: [
    Builder(builder: (c) => Text('\${counter.count.value}')),
    for (final i in [1, 2]) Text('\${counter.name.value}'),
  ]),
);
''');
  }

  Future<void> test_pageLoadAndMeta() async {
    await assertNoDiagnostics('''
$_thor
class Page {
  Future<String> load() async => counter.name.value;
  String meta() => counter.name.value;
}
''');
  }
}
