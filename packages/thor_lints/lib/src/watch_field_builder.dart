import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/error.dart';

/// `watch_field_with_builder`: `Watch(state.field, builder: (v) => …)`.
///
/// A state field (`final visible = state(false)`) is a callable object,
/// passed to `Watch` as its `call`. The analyzer infers `Watch<bool>` from
/// it; the compiler infers `Watch<Object?>`, so `builder`'s value is an
/// `Object?` and `thor dev` fails to compile a page that analyzes clean.
/// `Watch.field(state.field, builder: …)` (or a builder whose parameter
/// is typed, `(bool v) => …`) gives both `bool`.
class WatchFieldBuilder extends AnalysisRule {
  /// The diagnostic reported on the field.
  static const DiagnosticCode code = LintCode(
    'watch_field_with_builder',
    "'{0}' is a state field passed as is: the compiler gives the builder's "
        "value the type 'Object?' (the analyzer says '{1}'), and the page "
        "doesn't compile.",
    correctionMessage:
        "Use 'Watch.field({0}, builder: …)', or type the builder's "
        "parameter.",
    uniqueName: 'LintCode.watch_field_with_builder',
  );

  /// Creates the rule.
  WatchFieldBuilder()
    : super(
        name: 'watch_field_with_builder',
        description:
            "Watch with a builder takes a state field's call or a method, "
            'not the field itself.',
      );

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addInstanceCreationExpression(this, _Visitor(this));
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);

  final AnalysisRule rule;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (node.constructorName.type.name.lexeme != 'Watch') return;
    final args = node.argumentList.arguments;
    if (args.isEmpty || args.first is NamedExpression) return;
    final builder = args
        .whereType<NamedExpression>()
        .where((a) => a.name.label.name == 'builder')
        .firstOrNull;
    if (builder == null) return;
    // `(bool v) => …`: the parameter's type fixes `T` for the compiler too.
    final fn = builder.expression;
    if (fn is FunctionExpression &&
        (fn.parameters?.parameters.every(
              (p) => p is SimpleFormalParameter && p.type != null,
            ) ??
            false)) {
      return;
    }
    // A callable object (not a function) whose `call` is torn off
    // implicitly.
    final source = args.first;
    if (source is! ImplicitCallReference) return;
    final type = source.staticType;
    rule.reportAtNode(
      source,
      arguments: [
        source.expression.toSource(),
        if (type is FunctionType)
          type.returnType.getDisplayString()
        else
          'its type',
      ],
    );
  }
}
