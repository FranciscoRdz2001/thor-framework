import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

/// `query_builder_reads_data`: `QueryBuilder(builder: (context, snapshot) =>
/// … snapshot.data …)`.
///
/// The builder runs on the server, once per state, and the browser only
/// switches among the results: what the builder reads out of `snapshot.data`
/// stays as the server saw it when the query answers again. The value
/// belongs to a `Watch` or a `row.text` (bound to the state); the builder
/// only chooses the structure, with `snapshot.hasData`.
class QueryBuilderReadsData extends AnalysisRule {
  /// The diagnostic reported on the read.
  static const DiagnosticCode code = LintCode(
    'query_builder_reads_data',
    "'{0}' is read while the server draws the page: what it shows stays as "
        "that state saw it and doesn't follow the query in the browser.",
    correctionMessage:
        "Show the value with Watch or row.text (bound to the state) and use "
        "'{1}.hasData' to choose what to draw.",
    uniqueName: 'LintCode.query_builder_reads_data',
  );

  /// Creates the rule.
  QueryBuilderReadsData()
    : super(
        name: 'query_builder_reads_data',
        description:
            "A QueryBuilder's builder chooses the structure with "
            "`snapshot.hasData`; the value goes through Watch.",
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
    if (node.constructorName.type.name.lexeme != 'QueryBuilder') return;
    for (final arg in node.argumentList.arguments) {
      if (arg is! NamedExpression || arg.name.label.name != 'builder') {
        continue;
      }
      final fn = arg.expression;
      if (fn is! FunctionExpression) continue;
      final params = fn.parameters?.parameters ?? const <FormalParameter>[];
      if (params.length < 2) continue;
      final name = params[1].name?.lexeme;
      if (name == null || name == '_') continue;
      fn.body.accept(_Reads(rule, name));
    }
  }
}

/// The reads of `<snapshot>.data` and `<snapshot>.requireData` in a builder.
class _Reads extends RecursiveAstVisitor<void> {
  _Reads(this.rule, this.snapshot);

  final AnalysisRule rule;
  final String snapshot;

  bool _isRead(String property) =>
      property == 'data' || property == 'requireData';

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    if (node.prefix.name == snapshot && _isRead(node.identifier.name)) {
      rule.reportAtNode(node, arguments: [node.toSource(), snapshot]);
    }
    super.visitPrefixedIdentifier(node);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    final target = node.target;
    if (target is SimpleIdentifier &&
        target.name == snapshot &&
        _isRead(node.propertyName.name)) {
      rule.reportAtNode(node, arguments: [node.toSource(), snapshot]);
    }
    super.visitPropertyAccess(node);
  }
}
