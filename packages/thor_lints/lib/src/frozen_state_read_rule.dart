import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../silent_failures.dart';
import 'errors.dart';

/// `frozen_state_read`: a state read (or a state's list iterated) while the
/// server draws the page ([findFrozenReads], THOR-S015).
class FrozenStateRead extends AnalysisRule {
  /// The diagnostic reported on the code.
  static const DiagnosticCode code = LintCode(
    'frozen_state_read',
    '{0} (THOR-S015 · ${errorsUrl}THOR-S015)',
    correctionMessage: '{1}',
    uniqueName: 'LintCode.frozen_state_read',
  );

  /// Creates the rule.
  FrozenStateRead()
    : super(
        name: 'frozen_state_read',
        description:
            "A widget's build runs once on the server: a state's value read "
            'there is frozen in the browser; it goes through Watch.',
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
    for (final m in findFrozenReads(node)) {
      rule.reportAtNode(m.node, arguments: [m.message, m.correction]);
    }
  }
}
