import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';
import 'package:thor_lints/src/animated_switcher_rule.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(AnimatedSwitcherAdversarialTest);
  });
}

/// A stand-in for thor_ui: AnimatedSwitcher (a wrapper), Watch, a built-in
/// leaf, a state field and an enum.
const _thor = r'''
abstract class Widget {
  const Widget();
}
abstract class BuildContext {}
abstract class StatelessWidget extends Widget {
  const StatelessWidget();
  Widget build(BuildContext context);
}
abstract interface class ThorBuiltIn {}
abstract class ParentDataWrapper extends StatelessWidget {
  const ParentDataWrapper({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => child;
}
class AnimatedSwitcher extends ParentDataWrapper {
  const AnimatedSwitcher({required this.duration, required super.child});
  final Duration duration;
}
class Padding extends ParentDataWrapper {
  const Padding({required super.child});
}
class Text extends StatelessWidget implements ThorBuiltIn {
  const Text(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => this;
}
class Column extends StatelessWidget implements ThorBuiltIn {
  const Column({this.children = const []});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => this;
}
class Watch<T> extends StatelessWidget implements ThorBuiltIn {
  const Watch(this.source, {this.builder, this.each, this.count});
  final T Function() source;
  final Widget Function(T value)? builder;
  final Widget Function(Object row)? each;
  final int? count;
  @override
  Widget build(BuildContext context) => this;
}
enum Mode { list, grid }
bool isRow() => true;
Mode mode() => Mode.list;
int step() => 0;
String label() => '';
List<String> names() => [];
bool? maybe() => null;
const d = Duration(milliseconds: 300);
''';

@reflectiveTest
class AnimatedSwitcherAdversarialTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = AnimatedSwitcherWithoutWatch();
    super.setUp();
  }

  Future<void> test_aConditionalChildIsLeftAlone() async {
    // The rule only judges a child that is one widget; a branch may be a
    // Watch and the other a leaf, and it can't tell which shows.
    await assertNoDiagnostics('''
$_thor
Widget a(bool z) => AnimatedSwitcher(
  duration: d,
  child: z ? Watch(isRow, builder: (r) => Text('\$r')) : const Text('x'),
);
''');
  }

  Future<void> test_aTypedWatchOfAnEnumOrBoolIsFine() async {
    await assertNoDiagnostics('''
$_thor
Widget a() => AnimatedSwitcher(
  duration: d,
  child: Watch<bool>(isRow, builder: (r) => Text('\$r')),
);
''');
  }
}
