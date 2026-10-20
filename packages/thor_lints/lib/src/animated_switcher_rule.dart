import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../silent_failures.dart';
import 'errors.dart';

/// `animated_switcher_without_watch`: an `AnimatedSwitcher` around
/// something that is not a `Watch` with states ([findSwitcherMisuses],
/// THOR-S016).
class AnimatedSwitcherWithoutWatch extends AnalysisRule {
  /// The diagnostic reported on the code.
  static const DiagnosticCode code = LintCode(
    'animated_switcher_without_watch',
    '{0} (THOR-S016 · ${errorsUrl}THOR-S016)',
    correctionMessage: '{1}',
    uniqueName: 'LintCode.animated_switcher_without_watch',
  );

  /// Creates the rule.
  AnimatedSwitcherWithoutWatch()
    : super(
        name: 'animated_switcher_without_watch',
        description:
            'AnimatedSwitcher animates the states of the Watch it wraps: '
            'around anything else it does nothing.',
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
    for (final m in findSwitcherMisuses(node)) {
      rule.reportAtNode(m.node, arguments: [m.message, m.correction]);
    }
  }
}
