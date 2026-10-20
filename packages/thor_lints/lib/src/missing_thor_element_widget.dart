import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/error.dart';

/// `missing_thor_element_widget`: one of thor's own widgets
/// (`ThorBuiltIn`) whose `build` always returns a thor element widget
/// should implement `ThorElementWidget`, so wrappers around it (`Padding`,
/// `Expanded`, `Opacity`…) fuse into its element instead of adding a
/// second class.
///
/// App components need no marker: thor sees what they build,
/// so the rule leaves them alone.
class MissingThorElementWidget extends AnalysisRule {
  /// The diagnostic reported on the class name.
  static const LintCode code = LintCode(
    'missing_thor_element_widget',
    "'{0}' is one of thor's widgets and builds a thor element but doesn't "
        'implement ThorElementWidget.',
    correctionMessage:
        "Add 'implements ThorElementWidget' so wrappers fuse into its "
        'element (one class instead of two).',
    uniqueName: 'LintCode.missing_thor_element_widget',
    severity: DiagnosticSeverity.WARNING,
  );

  /// Creates the rule.
  MissingThorElementWidget()
    : super(
        name: 'missing_thor_element_widget',
        description:
            "thor's own widgets whose build returns a thor element widget "
            'should implement ThorElementWidget.',
      );

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addClassDeclaration(this, _Visitor(this));
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);

  final AnalysisRule rule;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    if (node.abstractKeyword != null) return;
    final element = node.declaredFragment?.element;
    if (element == null) return;
    if (!_isStatelessWidget(element) || _isThorElement(element.thisType)) {
      return;
    }
    // An app component is transparent: only thor's own widgets,
    // which thor never looks through, need the marker.
    if (!_hasSupertype(
      element.thisType,
      'ThorBuiltIn',
      library: 'package:thor_ui/',
    )) {
      return;
    }
    // Wrappers decorate their child instead of emitting an element.
    if (_hasSupertype(element.thisType, 'ParentDataWrapper')) return;

    final build = node.body.members.whereType<MethodDeclaration>().where(
      (m) => m.name.lexeme == 'build' && !m.isStatic,
    );
    if (build.isEmpty) return;
    final returned = _returnedExpressions(build.first.body);
    if (returned.isEmpty) return;
    for (final e in returned) {
      final type = e.staticType;
      if (type is! InterfaceType || !_isThorElement(type)) return;
    }
    rule.reportAtToken(node.namePart.typeName, arguments: [element.name!]);
  }

  static bool _isStatelessWidget(ClassElement element) =>
      element.allSupertypes.any((t) => t.element.name == 'StatelessWidget');

  static bool _isThorElement(InterfaceType type) =>
      _hasSupertype(type, 'ThorElementWidget', library: 'package:thor_ui/');

  static bool _hasSupertype(
    InterfaceType type,
    String name, {
    String? library,
  }) {
    bool matches(InterfaceType t) =>
        t.element.name == name &&
        (library == null ||
            t.element.library.uri.toString().startsWith(library));
    return matches(type) || type.allSupertypes.any(matches);
  }

  /// The expressions `body` can return (not counting nested functions).
  static List<Expression> _returnedExpressions(FunctionBody body) {
    if (body is ExpressionFunctionBody) return [body.expression];
    final collector = _Returns();
    body.accept(collector);
    return collector.expressions;
  }
}

class _Returns extends RecursiveAstVisitor<void> {
  final expressions = <Expression>[];

  @override
  void visitReturnStatement(ReturnStatement node) {
    final e = node.expression;
    if (e != null) expressions.add(e);
  }

  // Returns inside closures belong to the closure, not to build.
  @override
  void visitFunctionExpression(FunctionExpression node) {}
}
