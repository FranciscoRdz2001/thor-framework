import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../silent_failures.dart';
import 'errors.dart';

/// `row_server_read`: a state member called with the row's key (or a state
/// read that depends on the row) in a `Watch.list` row builder
/// ([findRowServerReads], THOR-S034).
class RowServerRead extends AnalysisRule {
  /// The diagnostic reported on the code.
  static const DiagnosticCode code = LintCode(
    'row_server_read',
    '{0} (THOR-S034 · ${errorsUrl}THOR-S034)',
    correctionMessage: '{1}',
    uniqueName: 'LintCode.row_server_read',
  );

  /// Creates the rule.
  RowServerRead()
    : super(
        name: 'row_server_read',
        description:
            "A list row's builder runs on the server with the template's "
            'key: a state value computed from the row key there is wrong in '
            'the rows the browser adds; it goes through row.bind, row.text '
            'or row.watch.',
      );

  @override
  DiagnosticCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addCompilationUnit(this, _Visitor(this));
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);

  final AnalysisRule rule;

  @override
  void visitCompilationUnit(CompilationUnit node) {
    for (final m in findRowServerReads(node)) {
      rule.reportAtNode(m.node, arguments: [m.message, m.correction]);
    }
  }
}
