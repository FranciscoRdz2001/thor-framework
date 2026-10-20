import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';
import 'package:thor_lints/src/icon_button_without_name.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(IconButtonWithoutNameTest);
  });
}

const _widgets = r'''
class Widget {
  const Widget();
}
class Text extends Widget {
  const Text(String data);
}
class Icon extends Widget {
  const Icon(Object icon, {String? semanticLabel});
}
class Semantics extends Widget {
  const Semantics({String? label, Widget? child});
}
class Tooltip extends Widget {
  const Tooltip({String? message, Widget? child});
}
class IconButton extends Widget {
  const IconButton({required Widget icon, Function? onPressed, String? tooltip, String? href});
  const IconButton.filled({required Widget icon, Function? onPressed, String? tooltip});
  const IconButton.filledTonal({required Widget icon, Function? onPressed, String? tooltip});
  const IconButton.outlined({required Widget icon, Function? onPressed, String? tooltip});
}
class FloatingActionButton extends Widget {
  const FloatingActionButton({Widget? child, Function? onPressed, String? tooltip});
  const FloatingActionButton.small({Widget? child, Function? onPressed, String? tooltip});
  const FloatingActionButton.extended({required Widget label, Widget? icon, Function? onPressed});
}
const home = 1;
''';

@reflectiveTest
class IconButtonWithoutNameTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = IconButtonWithoutName();
    super.setUp();
  }

  /// Runs the rule on [code] after the stubs; [lints] are the button
  /// constructors reported, in order, as the text they are written with.
  Future<void> _check(String code, [List<String> lints = const []]) {
    final source = '$_widgets\n$code';
    return assertDiagnostics(source, [
      for (final l in lints)
        lint(_widgets.length + 1 + code.indexOf(l), l.length),
    ]);
  }

  Future<void> test_iconWithoutTooltip() => _check(
    'final a = IconButton(icon: Icon(home), onPressed: null);',
    ['IconButton'],
  );

  Future<void> test_namedConstructor() => _check(
    'final a = IconButton.filled(icon: Icon(home));',
    ['IconButton.filled'],
  );

  Future<void> test_hrefWithoutTooltip() => _check(
    "final a = IconButton(href: '/x', icon: Icon(home));",
    ['IconButton'],
  );

  Future<void> test_tooltipNull() => _check(
    'final a = IconButton(icon: Icon(home), tooltip: null);',
    ['IconButton'],
  );

  Future<void> test_tooltipNamesIt() =>
      _check("final a = IconButton(icon: Icon(home), tooltip: 'Home');");

  Future<void> test_tooltipFromVariable() => _check(
    "String label() => 'x';\nfinal a = IconButton(icon: Icon(home), tooltip: label());",
  );

  Future<void> test_iconWithSemanticLabel() =>
      _check("final a = IconButton(icon: Icon(home, semanticLabel: 'Home'));");

  Future<void> test_semanticLabelNull() => _check(
    'final a = IconButton(icon: Icon(home, semanticLabel: null));',
    ['IconButton'],
  );

  Future<void> test_textChildNamesIt() =>
      _check("final a = IconButton(icon: Text('Home'));");

  Future<void> test_iconFromVariable() =>
      _check('const icon = Icon(home);\nfinal a = IconButton(icon: icon);');

  Future<void> test_semanticsAroundIt() => _check(
    "final a = Semantics(label: 'Home', child: IconButton(icon: Icon(home)));",
  );

  Future<void> test_tooltipWidgetAroundIt() => _check(
    "final a = Tooltip(message: 'Home', child: IconButton(icon: Icon(home)));",
  );

  Future<void> test_semanticsWithoutLabelDoesNot() => _check(
    'final a = Semantics(child: IconButton(icon: Icon(home)));',
    ['IconButton'],
  );

  Future<void> test_semanticsOfAnotherWidgetDoesNot() => _check(
    "Widget f() {\n  final s = Semantics(label: 'x');\n  return IconButton(icon: Icon(home));\n}",
    ['IconButton'],
  );

  Future<void> test_floatingActionButton() => _check(
    'final a = FloatingActionButton(child: Icon(home));',
    ['FloatingActionButton'],
  );

  Future<void> test_floatingActionButtonWithTooltip() => _check(
    "final a = FloatingActionButton(child: Icon(home), tooltip: 'New');",
  );

  Future<void> test_extendedHasALabel() => _check(
    "final a = FloatingActionButton.extended(icon: Icon(home), label: Text('New'));",
  );

  Future<void> test_otherWidgetsAreNotChecked() => _check(
    'class Chip { const Chip({Widget? icon}); }\nfinal a = Chip(icon: Icon(home));',
  );

  Future<void> test_emptyTooltipNamesNothing() => _check(
    "final a = IconButton(icon: Icon(home), tooltip: '');",
    ['IconButton'],
  );

  Future<void> test_emptySemanticLabelNamesNothing() => _check(
    "final a = IconButton(icon: Icon(home, semanticLabel: ''));",
    ['IconButton'],
  );

  Future<void> test_emptySemanticsLabelNamesNothing() => _check(
    "final a = Semantics(label: '', child: IconButton(icon: Icon(home)));",
    ['IconButton'],
  );

  Future<void> test_nullTooltipWidgetMessageNamesNothing() => _check(
    'final a = Tooltip(message: null, child: IconButton(icon: Icon(home)));',
    ['IconButton'],
  );

  Future<void> test_filledTonalAndOutlined() => _check(
    'final a = [\n  IconButton.filledTonal(icon: Icon(home)),\n  IconButton.outlined(icon: Icon(home)),\n];',
    ['IconButton.filledTonal', 'IconButton.outlined'],
  );

  Future<void> test_filledTonalWithTooltip() => _check(
    "final a = IconButton.filledTonal(icon: Icon(home), tooltip: 'Home');",
  );

  Future<void> test_smallFloatingActionButton() => _check(
    'final a = FloatingActionButton.small(child: Icon(home));',
    ['FloatingActionButton.small'],
  );

  Future<void> test_constIcon() =>
      _check('final a = IconButton(icon: const Icon(home));', ['IconButton']);

  Future<void> test_tooltipInsideAnotherWidgetsList() => _check(
    "final a = Tooltip(message: 'x', child: Semantics(child: IconButton(icon: Icon(home))));",
  );
}
