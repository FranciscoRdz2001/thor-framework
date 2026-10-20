import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/error.dart';

import 'errors.dart';

/// `length_unit_in_const`: `8.px` (a unit getter of thor_style's `num`
/// extension) inside a `const`.
///
/// Dart can't call a getter in a constant, so the compiler's own message
/// ("Invalid constant value") says nothing about the fix, and Flutter
/// habits put `const` in front of every constructor. The typed value has a
/// const form: `Length.px(8)`.
class LengthUnitInConst extends AnalysisRule {
  /// The diagnostic reported on the unit.
  static const DiagnosticCode code = LintCode(
    'length_unit_in_const',
    "'{0}' can't be in a const: a getter never is "
        '(THOR-R015 · ${errorsUrl}THOR-R015).',
    correctionMessage: 'Write {1}, or drop the const.',
    uniqueName: 'LintCode.length_unit_in_const',
  );

  /// Creates the rule.
  LengthUnitInConst()
    : super(
        name: 'length_unit_in_const',
        description:
            "Use Length's const constructors (Length.px(8)) in a const; "
            '8.px is a getter.',
      );

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    final visitor = _Visitor(this);
    registry
      ..addPropertyAccess(this, visitor)
      ..addPrefixedIdentifier(this, visitor);
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);

  final AnalysisRule rule;

  @override
  void visitPropertyAccess(PropertyAccess node) =>
      _check(node, node.target, node.propertyName);

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) =>
      _check(node, node.prefix, node.identifier);

  void _check(Expression node, Expression? target, SimpleIdentifier unit) {
    if (target == null || !node.inConstantContext) return;
    final element = unit.element;
    if (element is! PropertyAccessorElement) return;
    final owner = element.enclosingElement;
    if (owner is! ExtensionElement || owner.name != 'LengthUnits') return;
    if (!(owner.library.uri.toString().startsWith('package:thor_style/'))) {
      return;
    }
    rule.reportAtNode(
      node,
      arguments: [node.toSource(), 'Length.${unit.name}(${target.toSource()})'],
    );
  }
}
