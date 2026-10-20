import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';
import 'package:thor_lints/src/missing_thor_element_widget.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(MissingThorElementWidgetTest);
  });
}

@reflectiveTest
class MissingThorElementWidgetTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = MissingThorElementWidget();
    newPackage('thor_ui').addFile('lib/thor_ui.dart', r'''
abstract class Widget { const Widget(); }
abstract class BuildContext {}
abstract class StatelessWidget extends Widget {
  const StatelessWidget();
  Widget build(BuildContext context);
}
abstract interface class ThorElementWidget {}
abstract interface class ThorBuiltIn {}
class Row extends StatelessWidget implements ThorElementWidget, ThorBuiltIn {
  const Row();
  @override
  Widget build(BuildContext context) => this;
}
''');
    super.setUp();
  }

  // thor's own widget without the marker: wrappers would not fuse.
  Future<void> test_builtInWithoutMarker() async {
    await assertDiagnostics(
      r'''
import 'package:thor_ui/thor_ui.dart';
class Toolbar extends StatelessWidget implements ThorBuiltIn {
  const Toolbar();
  @override
  Widget build(BuildContext context) => const Row();
}
''',
      [
        lint(45, 7, messageContainsAll: ['Toolbar', 'ThorElementWidget']),
      ],
    );
  }

  Future<void> test_builtInWithMarker() async {
    await assertNoDiagnostics(r'''
import 'package:thor_ui/thor_ui.dart';
class Toolbar extends StatelessWidget
    implements ThorElementWidget, ThorBuiltIn {
  const Toolbar();
  @override
  Widget build(BuildContext context) => const Row();
}
''');
  }

  // An app component is transparent, it needs no marker.
  Future<void> test_appComponent() async {
    await assertNoDiagnostics(r'''
import 'package:thor_ui/thor_ui.dart';
class Logo extends StatelessWidget {
  const Logo();
  @override
  Widget build(BuildContext context) => const Row();
}
''');
  }
}
