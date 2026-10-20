import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../silent_failures.dart';
import 'errors.dart';

/// `stateful_set_state`: `setState` of a `StatefulWidget`'s `State`
/// ([findSetStateCalls], THOR-S014).
class StatefulSetState extends AnalysisRule {
  /// The diagnostic reported on the code.
  static const DiagnosticCode code = LintCode(
    'stateful_set_state',
    '{0} (THOR-S014 · ${errorsUrl}THOR-S014)',
    correctionMessage: '{1}',
    uniqueName: 'LintCode.stateful_set_state',
  );

  /// Creates the rule.
  StatefulSetState()
    : super(
        name: 'stateful_set_state',
        description:
            'setState does nothing in the browser: what changes there is a '
            'ThorState.',
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
    for (final m in findSetStateCalls(node)) {
      rule.reportAtNode(m.node, arguments: [m.message, m.correction]);
    }
  }
}
