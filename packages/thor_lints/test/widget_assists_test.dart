import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer/utilities/package_config_file_builder.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';
import 'package:thor_lints/src/state_misuse_rule.dart';
import 'package:thor_lints/assists.dart'
    show
        EditStyle,
        moveWidgetEdits,
        removeWidgetEdits,
        swapWithChildEdits,
        swapWithParentEdits,
        wrapEdits,
        wrapFlexEdits,
        wrapWatchEdits;
import 'package:thor_lints/src/widget_assists.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(WidgetAssistsTest);
  });
}

/// A stand-in for `package:thor_ui/thor_ui.dart`: the widgets the assists
/// write, with thor's signatures.
const _thorUi = r'''
abstract class Widget {
  const Widget();
}
abstract class StatelessWidget extends Widget {
  const StatelessWidget();
  Widget build();
}
abstract class ParentDataWrapper extends Widget {
  const ParentDataWrapper({required this.child});
  final Widget child;
}
class Text extends Widget {
  const Text(this.data);
  final String data;
}
class EdgeInsets {
  const EdgeInsets.all(double value);
}
class Alignment {
  const Alignment(this.x, this.y);
  final double x;
  final double y;
  static const center = Alignment(0, 0);
}
class Padding extends Widget {
  const Padding({required this.padding, this.child});
  final EdgeInsets padding;
  final Widget? child;
}
class Align extends Widget {
  const Align({this.alignment = Alignment.center, this.child});
  final Alignment alignment;
  final Widget? child;
}
class Center extends Align {
  const Center({super.child});
}
class Container extends Widget {
  const Container({this.child});
  final Widget? child;
}
class SizedBox extends Widget {
  const SizedBox({this.width, this.height, this.child});
  final double? width;
  final double? height;
  final Widget? child;
}
class Flexible extends ParentDataWrapper {
  const Flexible({this.flex = 1, required super.child});
  final int flex;
}
class Expanded extends Flexible {
  const Expanded({super.flex, required super.child});
}
class Semantics extends ParentDataWrapper {
  const Semantics({this.label, required super.child});
  final String? label;
}
class Link extends ParentDataWrapper {
  const Link({required this.href, required super.child});
  final String href;
}
abstract class Flex extends Widget {
  const Flex({this.spacing = 0, this.children = const []});
  final double spacing;
  final List<Widget> children;
}
class Column extends Flex {
  const Column({super.spacing, super.children});
}
class Row extends Flex {
  const Row({super.spacing, super.children});
}
class Watch<T> extends Widget {
  const Watch(this.source, {this.builder});
  final T Function() source;
  final Widget Function(T value)? builder;
}
''';

/// The app's side: its own widget, a state and a non-widget class.
const _app = r'''
import 'package:thor_ui/thor_ui.dart';

class Card extends StatelessWidget {
  const Card({this.child});
  final Widget? child;
  @override
  Widget build() => child ?? const Text('');
}

class Point {
  const Point(this.x);
  final int x;
}

class Counter {
  int count() => 0;
}

final counter = Counter();
''';

@reflectiveTest
class WidgetAssistsTest extends AnalysisRuleTest {
  int _files = 0;

  @override
  void setUp() {
    // AnalysisRuleTest needs a rule; the assists don't look at it.
    rule = StateMisuseRule();
    super.setUp();
    newPackage('thor_ui').addFile('lib/thor_ui.dart', _thorUi);
    writeTestPackageConfig(PackageConfigFileBuilder());
  }

  /// A fresh file of the app with [body] after its declarations; `^` marks
  /// the caret.
  Future<(ResolvedLibraryResult, ResolvedUnitResult, int)> _resolve(
    String body, {
    String header = _app,
  }) async {
    final caret = body.indexOf('^');
    expect(caret, isNot(-1), reason: 'no caret in $body');
    final content = '$header${body.replaceFirst('^', '')}';
    final path = newFile('$testPackageLibPath/f${_files++}.dart', content).path;
    final unit = await resolveFile(path);
    final library =
        await unit.session.getResolvedLibrary(path) as ResolvedLibraryResult;
    return (library, unit, header.length + caret);
  }

  /// The source after [assist] at the caret of [body], or `null` when it
  /// isn't offered. The result must resolve without errors unless
  /// [placeholder] (a name the user still has to type).
  Future<String?> _apply(
    ResolvedCorrectionProducer Function({
      required CorrectionProducerContext context,
    })
    assist,
    String body, {
    String header = _app,
    bool placeholder = false,
  }) async {
    final (library, unit, offset) = await _resolve(body, header: header);
    final producer = assist(
      context: CorrectionProducerContext.createResolved(
        libraryResult: library,
        unitResult: unit,
        selectionOffset: offset,
      ),
    );
    expect(producer.assistKind, isNotNull);
    final builder = ChangeBuilder(session: unit.session);
    await producer.compute(builder);
    final edits = builder.sourceChange.edits;
    if (edits.isEmpty) return null;
    final result = SourceEdit.applySequence(unit.content, edits.single.edits);
    if (!placeholder) {
      final check = await resolveFile(
        newFile('$testPackageLibPath/f${_files++}.dart', result).path,
      );
      expect(
        check.diagnostics.where(
          (d) => d.diagnosticCode.severity == DiagnosticSeverity.ERROR,
        ),
        isEmpty,
        reason: result,
      );
    }
    return header.isEmpty ? result : result.substring(header.length);
  }

  WrapWith Function({required CorrectionProducerContext context}) _wrap(
    String name,
  ) =>
      ({required context}) => WrapWith(
        Wrapper.all.firstWhere((w) => w.name == name),
        context: context,
      );

  // --- Offered or not.

  Future<void> test_notOfferedOnANonWidget() async {
    for (final assist in [
      WrapWithWidget.new,
      _wrap('Padding'),
      WrapWithWatch.new,
      RemoveWidget.new,
    ]) {
      expect(await _apply(assist, 'const p = ^Point(1);\n'), isNull);
    }
  }

  Future<void> test_notOfferedInsideTheArguments() async {
    expect(
      await _apply(_wrap('Center'), "Widget f() => Card(child: Te^xt(''));\n"),
      contains("Card(child: Center(child: Text('')))"),
    );
    expect(
      await _apply(_wrap('Center'), "Widget f() => Card(child: Text('^'));\n"),
      isNull,
    );
    expect(
      await _apply(_wrap('Center'), "Widget f() => Card(^child: Text(''));\n"),
      isNull,
    );
  }

  Future<void> test_offeredOnTheAppsOwnWidget() async {
    expect(
      await _apply(_wrap('Center'), 'Widget f() => ^Card();\n'),
      'Widget f() => Center(child: Card());\n',
    );
  }

  Future<void> test_notOfferedWithoutThorUi() async {
    const header = '''
abstract class Widget {}
class Text extends Widget {
  Text(this.data);
  final String data;
}
''';
    expect(
      await _apply(
        _wrap('Center'),
        "Widget f() => ^Text('');\n",
        header: header,
      ),
      isNull,
    );
  }

  // --- Wrap with widget...

  Future<void> test_wrapGeneric_singleLine() async {
    expect(
      await _apply(
        WrapWithWidget.new,
        "Widget f() => ^Text('a');\n",
        placeholder: true,
      ),
      "Widget f() => widget(child: Text('a'));\n",
    );
  }

  Future<void> test_wrapGeneric_linkedName() async {
    final (library, unit, offset) = await _resolve(
      "Widget f() => ^Text('a');\n",
    );
    final producer = WrapWithWidget(
      context: CorrectionProducerContext.createResolved(
        libraryResult: library,
        unitResult: unit,
        selectionOffset: offset,
      ),
    );
    final builder = ChangeBuilder(session: unit.session);
    await producer.compute(builder);
    final group = builder.sourceChange.linkedEditGroups.single;
    expect(group.positions.single.offset, offset);
    expect(group.length, 'widget'.length);
    expect(producer.assistKind.message, 'Wrap with widget...');
  }

  Future<void> test_wrapGeneric_multiLine() async {
    expect(
      await _apply(WrapWithWidget.new, '''
Widget f() {
  return ^Card(
    child: Text('a'),
  );
}
''', placeholder: true),
      '''
Widget f() {
  return widget(
    child: Card(
      child: Text('a'),
    ),
  );
}
''',
    );
  }

  // --- Wrap with a named widget.

  Future<void> test_wrapPadding_alwaysOneArgumentPerLine() async {
    expect(
      await _apply(_wrap('Padding'), '''
Widget f() {
  return ^Text('a');
}
'''),
      '''
Widget f() {
  return Padding(
    padding: const EdgeInsets.all(8),
    child: Text('a'),
  );
}
''',
    );
  }

  Future<void> test_wrapPadding_inAConstContextNoConst() async {
    expect(
      await _apply(_wrap('Padding'), '''
const w = Card(
  child: ^Text('a'),
);
'''),
      '''
const w = Card(
  child: Padding(
    padding: EdgeInsets.all(8),
    child: Text('a'),
  ),
);
''',
    );
  }

  Future<void> test_wrapCenter_multiLine() async {
    expect(
      await _apply(_wrap('Center'), '''
Widget f() => Card(
  child: ^Card(
    child: Text('a'),
  ),
);
'''),
      '''
Widget f() => Card(
  child: Center(
    child: Card(
      child: Text('a'),
    ),
  ),
);
''',
    );
  }

  Future<void> test_wrapEachNamedWidget() async {
    final expected = {
      'Center': "Center(child: Text('a'))",
      'Container': "Container(child: Text('a'))",
      'SizedBox': "SizedBox(child: Text('a'))",
      'Expanded': "Expanded(child: Text('a'))",
      'Flexible': "Flexible(child: Text('a'))",
      'Semantics': "Semantics(child: Text('a'))",
      'Align': "Align(\n  alignment: Alignment.center,\n  child: Text('a'),\n)",
      'Link': "Link(\n  href: '',\n  child: Text('a'),\n)",
    };
    for (final MapEntry(:key, :value) in expected.entries) {
      expect(
        await _apply(_wrap(key), "Widget f() => ^Text('a');\n"),
        'Widget f() => $value;\n',
        reason: key,
      );
    }
    expect(Wrapper.all.map((w) => w.name), containsAll(expected.keys));
  }

  Future<void> test_wrapNotOfferedAroundTheSameWidget() async {
    expect(await _apply(_wrap('Center'), 'Widget f() => ^Center();\n'), isNull);
  }

  Future<void> test_wrap_addsAPrefixedImport() async {
    const header = "import 'package:thor_ui/thor_ui.dart' as ui;\n";
    expect(
      await _apply(
        _wrap('Padding'),
        "ui.Widget f() => ui.^Text('a');\n",
        header: header,
      ),
      "ui.Widget f() => ui.Padding(\n"
      '  padding: const ui.EdgeInsets.all(8),\n'
      "  child: ui.Text('a'),\n"
      ');\n',
    );
  }

  /// The result of [assist] with [header] above [body].
  Future<String> _applyRaw(
    ResolvedCorrectionProducer Function({
      required CorrectionProducerContext context,
    })
    assist,
    String body,
    String header,
  ) async {
    final (library, unit, offset) = await _resolve(body, header: header);
    final producer = assist(
      context: CorrectionProducerContext.createResolved(
        libraryResult: library,
        unitResult: unit,
        selectionOffset: offset,
      ),
    );
    final builder = ChangeBuilder(session: unit.session);
    await producer.compute(builder);
    return SourceEdit.applySequence(
      unit.content,
      builder.sourceChange.edits.single.edits,
    );
  }

  Future<void> _expectNoErrors(String source) async {
    final check = await resolveFile(
      newFile('$testPackageLibPath/f${_files++}.dart', source).path,
    );
    expect(
      check.diagnostics.where(
        (d) => d.diagnosticCode.severity == DiagnosticSeverity.ERROR,
      ),
      isEmpty,
      reason: source,
    );
  }

  Future<void> test_wrap_showsTheNameAHiddenImportLacks() async {
    const header = "import 'package:thor_ui/thor_ui.dart' show Text, Widget;\n";
    final result = await _applyRaw(
      _wrap('Center'),
      "Widget f() => ^Text('a');\n",
      header,
    );
    expect(result, contains('show Center, Text, Widget;'));
    await _expectNoErrors(result);
    // Padding needs EdgeInsets too: one edit can't show both.
    expect(
      await _apply(
        _wrap('Padding'),
        "Widget f() => ^Text('a');\n",
        header: header,
      ),
      isNull,
    );
  }

  Future<void> test_wrap_importsThorUiWhenMissing() async {
    newFile('$testPackageLibPath/app.dart', _app);
    final result = await _applyRaw(
      _wrap('Center'),
      'final w = ^Card();\n',
      "import 'app.dart';\n",
    );
    expect(result, contains("import 'package:thor_ui/thor_ui.dart';"));
    expect(result, contains('final w = Center(child: Card());'));
    await _expectNoErrors(result);
  }

  // --- Wrap with Column / Row.

  Future<void> test_wrapColumn_inAChildrenList() async {
    expect(
      await _apply(
        ({required context}) => WrapWithFlex('Column', context: context),
        '''
Widget f() => Row(
  children: [
    Text('a'),
    ^Text('b'),
  ],
);
''',
      ),
      '''
Widget f() => Row(
  children: [
    Text('a'),
    Column(
      children: [
        Text('b'),
      ],
    ),
  ],
);
''',
    );
  }

  Future<void> test_wrapRow_multiLine() async {
    expect(
      await _apply(
        ({required context}) => WrapWithFlex('Row', context: context),
        '''
Widget f() {
  return ^Card(
    child: Text('a'),
  );
}
''',
      ),
      '''
Widget f() {
  return Row(
    children: [
      Card(
        child: Text('a'),
      ),
    ],
  );
}
''',
    );
  }

  // --- Wrap with Watch.

  Future<void> test_wrapWatch_singleLine() async {
    expect(
      await _apply(
        WrapWithWatch.new,
        "Widget f() => ^Text('a');\n",
        placeholder: true,
      ),
      "Widget f() => Watch(source, builder: (value) => Text('a'));\n",
    );
  }

  Future<void> test_wrapWatch_multiLine() async {
    expect(
      await _apply(WrapWithWatch.new, '''
Widget f() => ^Card(
  child: Text('a'),
);
''', placeholder: true),
      '''
Widget f() => Watch(
  source,
  builder: (value) => Card(
    child: Text('a'),
  ),
);
''',
    );
  }

  Future<void> test_wrapWatch_withTheSourceTyped() async {
    final result = await _apply(
      WrapWithWatch.new,
      "Widget f() => ^Text('a');\n",
      placeholder: true,
    );
    // The user types the state's member where `source` is.
    final typed = result!.replaceFirst('source', 'counter.count');
    newFile('$testPackageLibPath/typed.dart', '$_app$typed');
    final unit = await resolveFile('$testPackageLibPath/typed.dart');
    expect(
      unit.diagnostics.where(
        (d) => d.diagnosticCode.severity == DiagnosticSeverity.ERROR,
      ),
      isEmpty,
    );
  }

  // --- Remove this widget.

  Future<void> test_remove_singleChild() async {
    expect(
      await _apply(RemoveWidget.new, '''
Widget f() => Card(
  child: ^Center(
    child: Card(
      child: Text('a'),
    ),
  ),
);
'''),
      '''
Widget f() => Card(
  child: Card(
    child: Text('a'),
  ),
);
''',
    );
  }

  Future<void> test_remove_childrenIntoTheParentsList() async {
    expect(
      await _apply(RemoveWidget.new, '''
Widget f() => Column(
  children: [
    Text('a'),
    ^Row(
      children: [
        Text('b'),
        Text('c'),
      ],
    ),
  ],
);
'''),
      '''
Widget f() => Column(
  children: [
    Text('a'),
    Text('b'),
    Text('c'),
  ],
);
''',
    );
  }

  Future<void> test_remove_notOfferedWithManyChildrenOutsideAList() async {
    expect(
      await _apply(
        RemoveWidget.new,
        "Widget f() => ^Row(children: [Text('a'), Text('b')]);\n",
      ),
      isNull,
    );
    expect(
      await _apply(
        RemoveWidget.new,
        "Widget f() => ^Row(children: [Text('a')]);\n",
      ),
      "Widget f() => Text('a');\n",
    );
  }

  Future<void> test_remove_notOfferedWithoutChild() async {
    expect(
      await _apply(RemoveWidget.new, "Widget f() => ^Text('a');\n"),
      isNull,
    );
  }

  // --- Swap with child / parent.

  static const _pair = '''
Widget f() => Card(
  child: {p}Padding(
    padding: const EdgeInsets.all(8),
    child: {c}Center(
      child: Text('a'),
    ),
  ),
);
''';

  static const _swapped = '''
Widget f() => Card(
  child: Center(
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: Text('a'),
    ),
  ),
);
''';

  Future<void> test_swapWithChild() async {
    expect(
      await _apply(
        SwapWithChild.new,
        _pair.replaceFirst('{p}', '^').replaceFirst('{c}', ''),
      ),
      _swapped,
    );
  }

  Future<void> test_swapWithParent() async {
    expect(
      await _apply(
        SwapWithParent.new,
        _pair.replaceFirst('{p}', '').replaceFirst('{c}', '^'),
      ),
      _swapped,
    );
  }

  Future<void> test_swap_notOfferedWhenTheChildHasNoChild() async {
    expect(
      await _apply(
        SwapWithChild.new,
        "Widget f() => ^Center(child: Text('a'));\n",
      ),
      isNull,
    );
    expect(
      await _apply(
        SwapWithParent.new,
        "Widget f() => Center(child: ^Text('a'));\n",
      ),
      isNull,
    );
  }

  Future<void> test_swapWithParent_notOfferedInAList() async {
    expect(
      await _apply(
        SwapWithParent.new,
        "Widget f() => Column(children: [^Center(child: Text('a'))]);\n",
      ),
      isNull,
    );
  }

  Future<void> test_swap_parentsConstCoversThePair() async {
    expect(
      await _apply(
        SwapWithChild.new,
        "final w = const ^Center(child: Card(child: Text('a')));\n",
      ),
      'final w = const Card(\n'
      '  child: Center(\n'
      "    child: Text('a'),\n"
      '  ),\n'
      ');\n',
    );
    // The child's own const can't hold around the parent's arguments.
    expect(
      await _apply(
        SwapWithChild.new,
        'Widget f(double d) => ^Padding(\n'
        '  padding: EdgeInsets.all(d),\n'
        "  child: const Center(child: Text('a')),\n"
        ');\n',
      ),
      'Widget f(double d) => Center(\n'
      '  child: Padding(\n'
      '    padding: EdgeInsets.all(d),\n'
      "    child: Text('a'),\n"
      '  ),\n'
      ');\n',
    );
  }

  // --- Move widget up / down.

  static const _list = '''
Widget f() => Column(
  children: [
    Text('a'),
    {b}Card(
      child: Text('b'),
    ),
    Text('c'),
  ],
);
''';

  Future<void> test_moveUp() async {
    expect(
      await _apply(
        ({required context}) => MoveWidget(up: true, context: context),
        _list.replaceFirst('{b}', '^'),
      ),
      '''
Widget f() => Column(
  children: [
    Card(
      child: Text('b'),
    ),
    Text('a'),
    Text('c'),
  ],
);
''',
    );
  }

  Future<void> test_moveDown() async {
    expect(
      await _apply(
        ({required context}) => MoveWidget(up: false, context: context),
        _list.replaceFirst('{b}', '^'),
      ),
      '''
Widget f() => Column(
  children: [
    Text('a'),
    Text('c'),
    Card(
      child: Text('b'),
    ),
  ],
);
''',
    );
  }

  Future<void> test_move_notOfferedAtTheEnds() async {
    expect(
      await _apply(
        ({required context}) => MoveWidget(up: true, context: context),
        "Widget f() => Column(children: [^Text('a'), Text('b')]);\n",
      ),
      isNull,
    );
    expect(
      await _apply(
        ({required context}) => MoveWidget(up: false, context: context),
        "Widget f() => Column(children: [Text('a'), ^Text('b')]);\n",
      ),
      isNull,
    );
    expect(
      await _apply(
        ({required context}) => MoveWidget(up: false, context: context),
        "final l = [^Text('a'), Text('b')];\n",
      ),
      isNull,
    );
  }

  // --- The pure edit functions (package:thor_lints/assists.dart) write what
  // the producers write: same source, same caret, same result.

  Future<void> _parity(
    ResolvedCorrectionProducer Function({
      required CorrectionProducerContext context,
    })
    assist,
    String body,
    List<SourceEdit> Function(String source, int offset) pure,
  ) async {
    final expected = await _apply(assist, body, placeholder: true);
    final source = '$_app${body.replaceFirst('^', '')}';
    final edits = pure(source, _app.length + body.indexOf('^'));
    if (expected == null) {
      expect(edits, isEmpty, reason: body);
      return;
    }
    final got = SourceEdit.applySequence(source, edits);
    expect(got.substring(_app.length), expected, reason: body);
  }

  Future<void> test_pure_wrapEditsMatchTheProducer() async {
    const bodies = [
      "Widget f() => ^Text('a');\n",
      "Widget f() => const ^Text('a');\n",
      "Widget f() => ^Card();\n",
      "Widget f() => Card(child: Te^xt(''));\n",
      "Widget f() => Card(child: Text('^'));\n",
      'final x = ^compute(1);\n',
      "const w = ^Text('a');\n",
      "Widget f() {\n  return ^Card(\n    child: Text('a'),\n  );\n}\n",
      "Widget f() => ^Padding(padding: EdgeInsets.all(1), child: Text(''));\n",
    ];
    for (final w in Wrapper.all) {
      for (final body in bodies) {
        await _parity(
          _wrap(w.name),
          body,
          (source, offset) => wrapEdits(source, offset, w),
        );
      }
    }
  }

  Future<void> test_pure_otherEditsMatchTheProducer() async {
    const column = '''
Widget f() {
  return Column(
    children: [
      Text('a'),
      ^Card(
        child: Text("""
x
y"""),
      ),
      Text('c'),
    ],
  );
}
''';
    const single = "Widget f() => ^Card(child: Text('a'));\n";
    const nested = "Widget f() => Card(child: ^Card(child: Text('a')));\n";
    const chained =
        "Widget f() => const ^Card(child: Card(child: Text('a')));\n";
    const inner = "Widget f() => Card(child: Card(child: ^Text('a')));\n";
    for (final body in [column, single, nested, chained, inner]) {
      for (final name in ['Column', 'Row']) {
        await _parity(
          ({required context}) => WrapWithFlex(name, context: context),
          body,
          (s, o) => wrapFlexEdits(s, o, name),
        );
      }
      await _parity(WrapWithWatch.new, body, (s, o) => wrapWatchEdits(s, o));
      await _parity(RemoveWidget.new, body, (s, o) => removeWidgetEdits(s, o));
      await _parity(
        SwapWithChild.new,
        body,
        (s, o) => swapWithChildEdits(s, o),
      );
      await _parity(
        SwapWithParent.new,
        body,
        (s, o) => swapWithParentEdits(s, o),
      );
      for (final up in [true, false]) {
        await _parity(
          ({required context}) => MoveWidget(up: up, context: context),
          body,
          (s, o) => moveWidgetEdits(s, o, up: up),
        );
      }
    }
  }

  Future<void> test_pure_honoursTheEditStyle() async {
    final edits = wrapEdits(
      "Widget f() {\r\n    return Text('a');\r\n}\r\n",
      28,
      Wrapper.all.first,
      style: const EditStyle(indent: '    '),
    );
    expect(edits.single.replacement, contains('\r\n'));
    expect(edits.single.replacement, isNot(contains('\n\n')));
    expect(edits.single.replacement, contains('        padding'));
  }
}
