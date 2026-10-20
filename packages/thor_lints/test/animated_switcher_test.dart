import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';
import 'package:thor_lints/src/animated_switcher_rule.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(AnimatedSwitcherWithoutWatchTest);
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
  static Watch<List<I>> list<I, K extends Object>(
    List<I> Function() source, {
    required K Function(I) itemKey,
    required Widget Function(Object row) each,
  }) => throw 0;
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
class AnimatedSwitcherWithoutWatchTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = AnimatedSwitcherWithoutWatch();
    super.setUp();
  }

  (String, int) _at(String code, String needle) {
    final all = '$_thor$code';
    final offset = all.indexOf(needle, _thor.length);
    expect(offset, greaterThan(0), reason: needle);
    return (all, offset);
  }

  Future<void> test_aBuiltInThatIsNotAWatch() async {
    const child = "Text('hola')";
    final (code, at) = _at('''
Widget a() => AnimatedSwitcher(duration: d, child: $child);
''', child);
    await assertDiagnostics(code, [
      lint(
        at,
        child.length,
        messageContainsAll: ['AnimatedSwitcher', 'THOR-S016', 'Watch'],
        correctionContains: 'builder',
      ),
    ]);
  }

  Future<void> test_insideTheBuilderOfAWatchTheWatchSwapsIt() async {
    // The Watch swaps its whole element between its states, and the switcher
    // marks that element: `Watch(builder: (v) => AnimatedSwitcher(child: ...))`
    // animates, whatever the child is.
    final (code, _) = _at('''
Widget a() => Watch(
  isRow,
  builder: (row) => AnimatedSwitcher(duration: d, child: Text(row ? 'a' : 'b')),
);
Widget b() => Watch(
  mode,
  builder: (m) => Padding(
    child: AnimatedSwitcher(duration: d, child: const Column()),
  ),
);
''', 'Widget a');
    await assertNoDiagnostics(code);
  }

  Future<void> test_insideAWatchBuilderButNotItsRootIsStillInert() async {
    // Only the element the Watch swaps carries the timing: a switcher deeper
    // in the builder's tree marks an element nothing animates.
    const child = "Text('hola')";
    final (code, at) = _at('''
Widget a() => Watch(
  isRow,
  builder: (row) => Column(children: [AnimatedSwitcher(duration: d, child: $child)]),
);
''', child);
    await assertDiagnostics(code, [
      lint(at, child.length, messageContainsAll: ['AnimatedSwitcher']),
    ]);
  }

  Future<void> test_theRootThroughABlockBodyAndAConditional() async {
    final (code, _) = _at('''
Widget a() => Watch(
  isRow,
  builder: (row) {
    return row
        ? AnimatedSwitcher(duration: d, child: Padding(child: Text('a')))
        : Padding(child: AnimatedSwitcher(duration: d, child: Text('b')));
  },
);
''', 'Widget a');
    await assertNoDiagnostics(code);
  }

  Future<void> test_aWatchWithoutStates() async {
    // A text, a list and an int without count have no finite set of states.
    final all =
        '$_thor'
        '''
Widget a() => AnimatedSwitcher(duration: d, child: Watch(label));
Widget b() => AnimatedSwitcher(
  duration: d,
  child: Watch(names, each: (row) => const Text('x')),
);
Widget l() => AnimatedSwitcher(
  duration: d,
  child: Watch.list(names, itemKey: (String n) => n, each: (row) => const Text('x')),
);
Widget c() => AnimatedSwitcher(
  duration: d,
  child: Watch(label, builder: (s) => Text(s)),
);
Widget e() => AnimatedSwitcher(
  duration: d,
  child: Watch(step, builder: (n) => Text('\$n')),
);
''';
    int at(String s) => all.indexOf(s, _thor.length);
    await assertDiagnostics(all, [
      lint(at('Watch(label))'), 'Watch(label)'.length),
      lint(
        at('Watch(names'),
        "Watch(names, each: (row) => const Text('x'))".length,
      ),
      lint(
        at('Watch.list(names'),
        "Watch.list(names, itemKey: (String n) => n, each: (row) => const Text('x'))"
            .length,
      ),
      lint(
        at('Watch(label, builder'),
        'Watch(label, builder: (s) => Text(s))'.length,
      ),
      lint(
        at('Watch(step'),
        "Watch(step, builder: (n) => Text('\$n'))".length,
        messageContainsAll: ['count'],
      ),
    ]);
  }

  Future<void> test_throughWrappers() async {
    const child = "Padding(child: Text('x'))";
    final (code, at) = _at('''
Widget a() => AnimatedSwitcher(duration: d, child: $child);
Widget b() => AnimatedSwitcher(
  duration: d,
  child: Padding(child: Watch(isRow, builder: (r) => Text('\$r'))),
);
''', child);
    await assertDiagnostics(code, [lint(at, child.length)]);
  }

  Future<void> test_watchWithStatesIsFine() async {
    await assertNoDiagnostics('''
$_thor
Widget a() => AnimatedSwitcher(
  duration: d,
  child: Watch(isRow, builder: (r) => Text('\$r')),
);
Widget b() => AnimatedSwitcher(
  duration: d,
  child: Watch(mode, builder: (m) => Text('\${m.name}')),
);
Widget c() => AnimatedSwitcher(
  duration: d,
  child: Watch(step, count: 3, builder: (n) => Text('\$n')),
);
''');
  }

  Future<void> test_whatTheRuleCannotSeeIsFine() async {
    await assertNoDiagnostics('''
$_thor
// The app's own widget and a helper: they may build a Watch with states.
class Panel extends StatelessWidget {
  const Panel();
  @override
  Widget build(BuildContext context) =>
      Watch(isRow, builder: (r) => Text('\$r'));
}
Widget helper() => Watch(isRow, builder: (r) => Text('\$r'));
Widget a() => const AnimatedSwitcher(duration: d, child: Panel());
Widget b() => AnimatedSwitcher(duration: d, child: helper());
// A nullable bool is THOR-S003's, not this rule's.
Widget c() => AnimatedSwitcher(
  duration: d,
  child: Watch(maybe, builder: (m) => Text('\$m')),
);
// Only an AnimatedSwitcher's child is checked.
Widget f() => const Padding(child: Text('x'));
''');
  }
}
