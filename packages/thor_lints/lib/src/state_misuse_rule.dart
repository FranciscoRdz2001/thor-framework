import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';

import '../state_misuse.dart';
import 'errors.dart';

/// `state_misuse`: code the browser can't run around a `ThorState`
/// ([findStateMisuses]): a closure as a widget's callback that uses a state
/// (THOR-S011), a closure as the source of `Watch` (THOR-S001) and a state
/// created anywhere but the top level of a file (THOR-S012).
class StateMisuseRule extends MultiAnalysisRule {
  /// A closure as a callback: the element does nothing in the browser.
  static const LintCode callback = LintCode(
    'state_callback_closure',
    '{0} (THOR-S011 · ${errorsUrl}THOR-S011)',
    correctionMessage: '{1}',
    severity: DiagnosticSeverity.WARNING,
    uniqueName: 'LintCode.state_callback_closure',
  );

  /// A closure as the source of `Watch`.
  static const LintCode watch = LintCode(
    'state_watch_closure',
    '{0} (THOR-S001 · ${errorsUrl}THOR-S001)',
    correctionMessage: '{1}',
    severity: DiagnosticSeverity.WARNING,
    uniqueName: 'LintCode.state_watch_closure',
  );

  /// A state instance that is not a top-level variable.
  static const LintCode instance = LintCode(
    'state_instance_not_top_level',
    '{0} (THOR-S012 · ${errorsUrl}THOR-S012)',
    correctionMessage: '{1}',
    severity: DiagnosticSeverity.WARNING,
    uniqueName: 'LintCode.state_instance_not_top_level',
  );

  /// Creates the rule.
  StateMisuseRule()
    : super(
        name: 'state_misuse',
        description:
            'A widget passes a ThorState member, not a closure, and states '
            'are top-level variables.',
      );

  @override
  List<DiagnosticCode> get diagnosticCodes => const [callback, watch, instance];

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

  final StateMisuseRule rule;

  @override
  void visitCompilationUnit(CompilationUnit node) {
    for (final m in findStateMisuses(node)) {
      rule.reportAtNode(
        m.node,
        diagnosticCode: switch (m.code) {
          'THOR-S011' => StateMisuseRule.callback,
          'THOR-S001' => StateMisuseRule.watch,
          _ => StateMisuseRule.instance,
        },
        arguments: [m.message, m.correction],
      );
    }
  }
}

/// Replaces a closure that is one call of a state method by the member
/// itself (`counter.increment`, `todos.remove.withArg(id)`).
class PassStateMember extends ResolvedCorrectionProducer {
  static const _kind = FixKind(
    'thor.fix.passStateMember',
    DartFixKindPriority.standard,
    "Pass '{0}'",
  );

  /// Creates the fix.
  PassStateMember({required super.context});

  String? _replacement;

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _kind;

  @override
  List<String>? get fixArguments => [?_replacement];

  @override
  Future<void> compute(ChangeBuilder builder) async {
    final closure = node.thisOrAncestorOfType<FunctionExpression>();
    if (closure == null) return;
    final replacement = stateCallbackReplacement(closure);
    if (replacement == null) return;
    _replacement = replacement;
    await builder.addDartFileEdit(file, (b) {
      b.addSimpleReplacement(
        SourceRange(closure.offset, closure.length),
        replacement,
      );
    });
  }
}
