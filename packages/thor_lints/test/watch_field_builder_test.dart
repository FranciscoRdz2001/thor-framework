import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';
import 'package:thor_lints/src/watch_field_builder.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(WatchFieldBuilderTest);
  });
}

/// A stand-in for thor: a callable state field, Watch and a widget.
const _thor = r'''
abstract class ThorState {}
class StateSignal<T> {
  StateSignal(this.value);
  T value;
  T call() => value;
}
StateSignal<T> state<T>(T value) => StateSignal(value);
abstract class Widget {}
class Text extends Widget {
  Text(this.text);
  final String text;
}
class SnackBar extends Widget {
  SnackBar({required this.visible});
  final bool visible;
}
class Watch<T> extends Widget {
  Watch(this.source, {this.builder});
  final T Function() source;
  final Widget Function(T value)? builder;
}
class ToastState extends ThorState {
  final visible = state(false);
  bool isVisible() => visible.value;
}
final toast = ToastState();
''';

@reflectiveTest
class WatchFieldBuilderTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = WatchFieldBuilder();
    super.setUp();
  }

  Future<void> test_fieldWithBuilder() async {
    const code = '''
Widget page() =>
    Watch(toast.visible, builder: (visible) => SnackBar(visible: visible));
''';
    final all = '$_thor$code';
    await assertDiagnostics(all, [
      lint(
        all.indexOf('toast.visible', _thor.length),
        'toast.visible'.length,
        messageContainsAll: ['toast.visible', 'Object?'],
        correctionContains: 'Watch.field(toast.visible',
      ),
    ]);
  }

  Future<void> test_methodsCallAndTextAreFine() async {
    await assertNoDiagnostics('''
$_thor
Widget a() => Watch(toast.isVisible, builder: (v) => SnackBar(visible: v));
Widget b() =>
    Watch(toast.visible.call, builder: (v) => SnackBar(visible: v));
Widget c() => Watch(toast.visible);
Widget d() =>
    Watch(toast.visible, builder: (bool v) => SnackBar(visible: v));
''');
  }
}
