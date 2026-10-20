// `package:thor_lints/assists.dart`: the assists as a library. The
// behavior of each assist is in widget_assists_test.dart; here, that what a
// tool needs is reachable from the public library.
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:test/test.dart';
import 'package:thor_lints/assists.dart';

void main() {
  test('the wrappers "Wrap with" offers are public data', () {
    expect(
      [for (final w in Wrapper.all) w.name],
      containsAll([
        'Padding',
        'Center',
        'Container',
        'SizedBox',
        'Expanded',
        'Flexible',
        'Align',
        'Semantics',
        'Link',
      ]),
    );
    final padding = Wrapper.all.firstWhere((w) => w.name == 'Padding');
    expect(padding.imports, ['EdgeInsets']);
    expect(padding.kind.id, 'thor.assist.wrap.padding');
  });

  test('named arguments and the thor_ui library are reachable', () {
    expect(thorUiLibrary, 'package:thor_ui/thor_ui.dart');
    final unit = parseString(
      content: 'var x = new Foo(child: 1, other: 2);',
    ).unit;
    final visitor = _First();
    unit.accept(visitor);
    final creation = visitor.found!;
    expect(namedArgument(creation, 'child'), isNotNull);
    expect(namedArgument(creation, 'missing'), isNull);
    // unresolved code has no thor type
    expect(isThorWidgetType(null), isFalse);
  });
}

class _First extends RecursiveAstVisitor<void> {
  InstanceCreationExpression? found;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    found ??= node;
  }
}
